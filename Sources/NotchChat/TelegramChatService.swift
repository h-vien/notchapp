import Foundation

actor TelegramChatService: ChatService, TelegramAuthenticating {
    nonisolated let events: AsyncStream<ChatEvent>
    nonisolated let authEvents: AsyncStream<TelegramAuthEvent>
    private let eventContinuation: AsyncStream<ChatEvent>.Continuation
    private let authContinuation: AsyncStream<TelegramAuthEvent>.Continuation

    private var runtime: TDLibRuntime?
    private var clientID: Int32?
    private var receiveTask: Task<Void, Never>?
    private var credentials: TelegramCredentials?
    private var chats: [String: Chat] = [:]
    private var users: [String: String] = [:]
    private var lastMessageIDs: [String: String] = [:]
    private var lastReadOutboxIDs: [String: Int64] = [:]
    private var messageCache: [String: Message] = [:]
    private var mediaBindings: [Int: Set<MediaBinding>] = [:]
    private var requestedDownloads: Set<Int> = []
    private var authorized = false
    private var lastAuthorizationType: String?

    init() {
        let eventPair = AsyncStream<ChatEvent>.makeStream()
        events = eventPair.stream
        eventContinuation = eventPair.continuation
        let authPair = AsyncStream<TelegramAuthEvent>.makeStream()
        authEvents = authPair.stream
        authContinuation = authPair.continuation
    }

    func connect() async {
        guard runtime == nil else { return }
        authContinuation.yield(.step(.checkingSession))
        guard let credentials = Self.configuredCredentials() else {
            authContinuation.yield(.step(.credentials))
            return
        }
        await start(credentials: credentials)
    }

    func submitCredentials(_ credentials: TelegramCredentials) async {
        do {
            try KeychainStore.save(String(credentials.apiID), account: "api_id")
            try KeychainStore.save(credentials.apiHash, account: "api_hash")
            await start(credentials: credentials)
        } catch {
            authContinuation.yield(.error("Could not securely save Telegram API credentials."))
        }
    }

    func submitPhoneNumber(_ phoneNumber: String) async {
        send(["@type": "setAuthenticationPhoneNumber", "phone_number": phoneNumber])
    }

    func submitEmailAddress(_ email: String) async {
        send(["@type": "setAuthenticationEmailAddress", "email_address": email])
    }

    func submitEmailCode(_ code: String) async {
        send(["@type": "checkAuthenticationEmailCode", "code": ["@type": "emailAddressAuthenticationCode", "code": code]])
    }

    func submitCode(_ code: String) async {
        send(["@type": "checkAuthenticationCode", "code": code])
    }

    func submitPassword(_ password: String) async {
        send(["@type": "checkAuthenticationPassword", "password": password])
    }

    func send(_ request: ChatRequest) async {
        switch request {
        case .connect:
            await connect()
        case .fetchChats:
            guard authorized else { return }
            send(["@type": "loadChats", "chat_list": ["@type": "chatListMain"], "limit": 50])
            publishChats()
        case let .fetchMessages(chatID, before):
            guard authorized else { return }
            send([
                "@type": "getChatHistory",
                "chat_id": chatID,
                "from_message_id": before ?? "0",
                "offset": 0,
                "limit": 50,
                "only_local": false,
                "@extra": "history:\(chatID):\(UUID().uuidString)"
            ])
        case let .sendMessage(chatID, text):
            guard authorized else { return }
            send([
                "@type": "sendMessage",
                "chat_id": chatID,
                "input_message_content": [
                    "@type": "inputMessageText",
                    "text": ["@type": "formattedText", "text": text, "entities": []]
                ]
            ])
        case let .markRead(chatID):
            guard let messageID = lastMessageIDs[chatID] else { return }
            send(["@type": "viewMessages", "chat_id": chatID, "message_ids": [messageID], "force_read": true])
        }
    }

    private func start(credentials: TelegramCredentials) async {
        self.credentials = credentials
        do {
            let runtime = try TDLibRuntime()
            self.runtime = runtime
            let id = runtime.createClient()
            clientID = id
            receiveTask = Task.detached(priority: .userInitiated) { [weak self, runtime] in
                while !Task.isCancelled {
                    if let data = runtime.receive(timeout: 0.25) {
                        await self?.consume(data)
                    }
                }
            }
            send(["@type": "getAuthorizationState"])
        } catch {
            authContinuation.yield(.step(.unavailable(error.localizedDescription)))
            eventContinuation.yield(.connectionChanged(.offline(reason: error.localizedDescription)))
        }
    }

    private func consume(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["@type"] as? String else { return }

        if type == "error" {
            let message = json["message"] as? String ?? "Telegram rejected the request."
            authContinuation.yield(.error(message))
            return
        }

        switch type {
        case "updateAuthorizationState":
            if let state = json["authorization_state"] as? [String: Any] { handleAuthorization(state) }
        case "authorizationStateWaitTdlibParameters", "authorizationStateWaitPhoneNumber",
             "authorizationStateWaitEmailAddress", "authorizationStateWaitEmailCode",
             "authorizationStateWaitCode", "authorizationStateWaitPassword", "authorizationStateReady":
            handleAuthorization(json)
        case "updateUser":
            if let user = json["user"] as? [String: Any] { cacheUser(user) }
        case "updateNewChat":
            if let value = json["chat"] as? [String: Any] { cacheChat(value) }
        case "updateChatTitle", "updateChatLastMessage", "updateChatUnreadMessageCount",
             "updateChatNotificationSettings", "updateChatPosition":
            updateChat(json)
        case "updateChatReadOutbox":
            updateOutgoingReadState(json)
        case "updateNewMessage":
            if let value = json["message"] as? [String: Any], let message = parseMessage(value) {
                eventContinuation.yield(.messageAdded(message))
            }
        case "updateFile":
            if let file = json["file"] as? [String: Any] { handleFileUpdate(file) }
        case "messages":
            handleHistory(json)
        default:
            break
        }
    }

    private func handleAuthorization(_ state: [String: Any]) {
        guard let type = state["@type"] as? String else { return }
        guard type != lastAuthorizationType else { return }
        lastAuthorizationType = type
        switch type {
        case "authorizationStateWaitTdlibParameters":
            guard let credentials else { return }
            let directory = Self.databaseDirectory()
            send([
                "@type": "setTdlibParameters",
                "use_test_dc": false,
                "database_directory": directory.path,
                "files_directory": directory.appendingPathComponent("files", isDirectory: true).path,
                "database_encryption_key": "",
                "use_file_database": true,
                "use_chat_info_database": true,
                "use_message_database": true,
                "use_secret_chats": true,
                "api_id": credentials.apiID,
                "api_hash": credentials.apiHash,
                "system_language_code": Locale.current.language.languageCode?.identifier ?? "en",
                "device_model": "Mac",
                "system_version": ProcessInfo.processInfo.operatingSystemVersionString,
                "application_version": "0.2.0"
            ])
        case "authorizationStateWaitPhoneNumber": authContinuation.yield(.step(.phoneNumber))
        case "authorizationStateWaitEmailAddress": authContinuation.yield(.step(.emailAddress))
        case "authorizationStateWaitEmailCode": authContinuation.yield(.step(.emailCode))
        case "authorizationStateWaitCode": authContinuation.yield(.step(.code))
        case "authorizationStateWaitPassword":
            authContinuation.yield(.step(.password(hint: state["password_hint"] as? String ?? "")))
        case "authorizationStateReady":
            authorized = true
            authContinuation.yield(.step(.ready))
            eventContinuation.yield(.connectionChanged(.online))
            send(["@type": "loadChats", "chat_list": ["@type": "chatListMain"], "limit": 50])
        case "authorizationStateClosed":
            authorized = false
            eventContinuation.yield(.connectionChanged(.offline(reason: "Telegram session closed")))
        default: break
        }
    }

    private func cacheUser(_ json: [String: Any]) {
        guard let id = int64String(json["id"]) else { return }
        let first = json["first_name"] as? String ?? ""
        let last = json["last_name"] as? String ?? ""
        users[id] = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func cacheChat(_ json: [String: Any]) {
        guard let id = int64String(json["id"]) else { return }
        let existing = chats[id]
        let last = json["last_message"] as? [String: Any]
        if let lastID = int64String(last?["id"]) { lastMessageIDs[id] = lastID }
        if let lastReadID = int64Value(json["last_read_outbox_message_id"]) {
            lastReadOutboxIDs[id] = lastReadID
        }
        chats[id] = Chat(
            id: id,
            title: json["title"] as? String ?? existing?.title ?? "Telegram",
            initials: initials(json["title"] as? String ?? existing?.title ?? "T"),
            preview: messageText(last) ?? existing?.preview ?? "",
            lastActivity: date(last?["date"]) ?? existing?.lastActivity ?? .distantPast,
            unreadCount: json["unread_count"] as? Int ?? existing?.unreadCount ?? 0,
            isMuted: isMuted(json["notification_settings"]) ?? existing?.isMuted ?? false,
            isPinned: isPinned(json["positions"]) ?? existing?.isPinned ?? false,
            accent: accent(for: id)
        )
        eventContinuation.yield(.chatUpdated(chats[id]!))
    }

    private func updateChat(_ json: [String: Any]) {
        guard let id = int64String(json["chat_id"]), var chat = chats[id] else { return }
        if let title = json["title"] as? String { chat.title = title; chat.initials = initials(title) }
        if let count = json["unread_count"] as? Int { chat.unreadCount = count }
        if let last = json["last_message"] as? [String: Any] {
            if let lastID = int64String(last["id"]) { lastMessageIDs[id] = lastID }
            chat.preview = messageText(last) ?? chat.preview
            chat.lastActivity = date(last["date"]) ?? chat.lastActivity
        }
        if let positions = json["positions"] as? [[String: Any]],
           let pinned = mainListPinnedState(positions) {
            chat.isPinned = pinned
        }
        if let position = json["position"] as? [String: Any],
           isMainListPosition(position),
           let pinned = position["is_pinned"] as? Bool {
            chat.isPinned = pinned
        }
        if let muted = isMuted(json["notification_settings"]) { chat.isMuted = muted }
        chats[id] = chat
        eventContinuation.yield(.chatUpdated(chat))
    }

    private func handleHistory(_ json: [String: Any]) {
        guard let extra = json["@extra"] as? String, extra.hasPrefix("history:"),
              let chatID = extra.split(separator: ":").dropFirst().first.map(String.init) else { return }
        let values = json["messages"] as? [[String: Any]] ?? []
        let parsed = values.compactMap(parseMessage).reversed()
        eventContinuation.yield(.messagesLoaded(chatID: chatID, messages: Array(parsed)))
    }

    private func parseMessage(_ json: [String: Any]) -> Message? {
        guard let id = int64String(json["id"]), let chatID = int64String(json["chat_id"]) else { return nil }
        let sender = json["sender_id"] as? [String: Any]
        let senderID = int64String(sender?["user_id"])
        let media = mediaContent(json)
        let parsedText = messageText(json)
        let text = parsedText ?? (media == nil ? "Unsupported message" : "")
        let isOutgoing = json["is_outgoing"] as? Bool ?? false
        let numericID = Int64(id) ?? 0
        let message = Message(
            id: id,
            chatID: chatID,
            sender: senderID.flatMap { users[$0] } ?? (isOutgoing ? "You" : "Telegram"),
            text: text,
            sentAt: date(json["date"]) ?? .now,
            isOutgoing: isOutgoing,
            isRead: !isOutgoing || numericID <= lastReadOutboxIDs[chatID, default: 0],
            isEdited: (json["edit_date"] as? Int ?? 0) > 0,
            media: media
        )
        cache(message)
        return message
    }

    private func cache(_ message: Message) {
        let key = messageKey(chatID: message.chatID, messageID: message.id)
        messageCache[key] = message
        guard let media = message.media else { return }
        bind(fileID: media.fileID, key: key, role: .media)
        if media.localPath == nil { requestDownload(media.fileID) }
        if let thumbnailFileID = media.thumbnailFileID {
            bind(fileID: thumbnailFileID, key: key, role: .thumbnail)
            if media.thumbnailPath == nil { requestDownload(thumbnailFileID) }
        }
    }

    private func bind(fileID: Int, key: String, role: MediaBinding.Role) {
        mediaBindings[fileID, default: []].insert(MediaBinding(messageKey: key, role: role))
    }

    private func requestDownload(_ fileID: Int) {
        guard requestedDownloads.insert(fileID).inserted else { return }
        send(["@type": "downloadFile", "file_id": fileID, "priority": 24, "offset": 0, "limit": 0, "synchronous": false])
    }

    private func handleFileUpdate(_ file: [String: Any]) {
        guard let fileID = file["id"] as? Int,
              let local = file["local"] as? [String: Any],
              local["is_downloading_completed"] as? Bool == true,
              let path = local["path"] as? String, !path.isEmpty else { return }
        requestedDownloads.remove(fileID)
        for binding in mediaBindings[fileID] ?? [] {
            guard var message = messageCache[binding.messageKey], var media = message.media else { continue }
            switch binding.role {
            case .media: media.localPath = path
            case .thumbnail: media.thumbnailPath = path
            }
            message.media = media
            messageCache[binding.messageKey] = message
            eventContinuation.yield(.messageUpdated(message))
        }
    }

    private func updateOutgoingReadState(_ json: [String: Any]) {
        guard let chatID = int64String(json["chat_id"]),
              let lastReadID = int64Value(json["last_read_outbox_message_id"]) else { return }
        lastReadOutboxIDs[chatID] = lastReadID

        for (key, cached) in messageCache where cached.chatID == chatID && cached.isOutgoing {
            guard let messageID = Int64(cached.id) else { continue }
            let isRead = messageID <= lastReadID
            guard cached.isRead != isRead else { continue }
            var message = cached
            message.isRead = isRead
            messageCache[key] = message
            eventContinuation.yield(.messageUpdated(message))
        }
    }

    private func mediaContent(_ message: [String: Any]) -> MessageMedia? {
        guard let content = message["content"] as? [String: Any], let type = content["@type"] as? String else { return nil }
        switch type {
        case "messagePhoto":
            guard let photo = content["photo"] as? [String: Any],
                  let sizes = photo["sizes"] as? [[String: Any]],
                  let size = sizes.max(by: { (($0["width"] as? Int ?? 0) * ($0["height"] as? Int ?? 0)) < (($1["width"] as? Int ?? 0) * ($1["height"] as? Int ?? 0)) }),
                  let file = size["photo"] as? [String: Any], let fileID = file["id"] as? Int else { return nil }
            return MessageMedia(kind: .photo, fileID: fileID, localPath: localPath(file), width: size["width"] as? Int ?? 0, height: size["height"] as? Int ?? 0)
        case "messageVideo":
            guard let video = content["video"] as? [String: Any],
                  let file = video["video"] as? [String: Any], let fileID = file["id"] as? Int else { return nil }
            let thumbnail = video["thumbnail"] as? [String: Any]
            let thumbnailFile = thumbnail?["file"] as? [String: Any]
            return MessageMedia(
                kind: .video,
                fileID: fileID,
                localPath: localPath(file),
                width: video["width"] as? Int ?? 0,
                height: video["height"] as? Int ?? 0,
                duration: video["duration"] as? Int,
                thumbnailFileID: thumbnailFile?["id"] as? Int,
                thumbnailPath: thumbnailFile.flatMap(localPath)
            )
        default:
            return nil
        }
    }

    private func localPath(_ file: [String: Any]) -> String? {
        guard let local = file["local"] as? [String: Any],
              local["is_downloading_completed"] as? Bool == true,
              let path = local["path"] as? String, !path.isEmpty else { return nil }
        return path
    }

    private func messageKey(chatID: String, messageID: String) -> String { "\(chatID):\(messageID)" }

    private func publishChats() {
        eventContinuation.yield(.chatsLoaded(Array(chats.values)))
    }

    private func send(_ object: [String: Any]) {
        guard let runtime, let clientID else { return }
        do { try runtime.send(clientID: clientID, object: object) }
        catch { authContinuation.yield(.error(error.localizedDescription)) }
    }

    private static func databaseDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotchChat/Telegram", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func configuredCredentials() -> TelegramCredentials? {
        let environment = ProcessInfo.processInfo.environment
        if let id = environment["TG_APIID"].flatMap(Int.init),
           let hash = environment["TG_APIHASH"], !hash.isEmpty {
            return TelegramCredentials(apiID: id, apiHash: hash)
        }

        if let idString = Bundle.main.object(forInfoDictionaryKey: "TelegramAPIID") as? String,
           let id = Int(idString),
           let hash = Bundle.main.object(forInfoDictionaryKey: "TelegramAPIHash") as? String,
           !hash.isEmpty {
            return TelegramCredentials(apiID: id, apiHash: hash)
        }

        if let idString = KeychainStore.read(account: "api_id"),
           let id = Int(idString),
           let hash = KeychainStore.read(account: "api_hash"), !hash.isEmpty {
            return TelegramCredentials(apiID: id, apiHash: hash)
        }

        return nil
    }

    private func int64String(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func int64Value(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String { return Int64(string) }
        return nil
    }

    private func date(_ value: Any?) -> Date? {
        if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        if let string = value as? String, let seconds = Double(string) { return Date(timeIntervalSince1970: seconds) }
        return nil
    }

    private func messageText(_ message: [String: Any]?) -> String? {
        guard let content = message?["content"] as? [String: Any] else { return nil }
        if let text = content["text"] as? [String: Any] { return text["text"] as? String }
        if let caption = content["caption"] as? [String: Any], let value = caption["text"] as? String { return value }
        return nil
    }

    private func initials(_ title: String) -> String {
        title.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private func accent(for id: String) -> ChatAccent {
        let value = UInt(bitPattern: id.hashValue)
        return ChatAccent.allCases[Int(value % UInt(ChatAccent.allCases.count))]
    }

    private func isMuted(_ value: Any?) -> Bool? {
        guard let settings = value as? [String: Any], let until = settings["mute_for"] as? Int else { return nil }
        return until > 0
    }

    private func isPinned(_ value: Any?) -> Bool? {
        guard let positions = value as? [[String: Any]] else { return nil }
        return mainListPinnedState(positions)
    }

    private func mainListPinnedState(_ positions: [[String: Any]]) -> Bool? {
        guard let position = positions.first(where: isMainListPosition) else { return nil }
        return position["is_pinned"] as? Bool
    }

    private func isMainListPosition(_ position: [String: Any]) -> Bool {
        guard let list = position["list"] as? [String: Any] else { return false }
        return list["@type"] as? String == "chatListMain"
    }
}

private struct MediaBinding: Hashable, Sendable {
    enum Role: Hashable, Sendable { case media, thumbnail }
    let messageKey: String
    let role: Role
}

