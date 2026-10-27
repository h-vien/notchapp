import Foundation

struct Chat: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var initials: String
    var preview: String
    var lastActivity: Date
    var unreadCount: Int
    var isMuted: Bool
    var isPinned: Bool
    var accent: ChatAccent
}

enum ChatAccent: String, CaseIterable, Sendable {
    case cyan, coral, violet, mint, amber
}

struct Message: Identifiable, Hashable, Sendable {
    let id: String
    let chatID: String
    let sender: String
    var text: String
    let sentAt: Date
    let isOutgoing: Bool
    var isRead: Bool
    var isEdited: Bool
    var media: MessageMedia? = nil
}

struct MessageMedia: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case photo
        case video
    }

    let kind: Kind
    let fileID: Int
    var localPath: String?
    let width: Int
    let height: Int
    var duration: Int?
    var thumbnailFileID: Int?
    var thumbnailPath: String?
}

enum ConnectionState: Equatable, Sendable {
    case connecting
    case online
    case offline(reason: String)

    var label: String {
        switch self {
        case .connecting: "Connecting"
        case .online: "Online"
        case .offline: "Offline"
        }
    }
}

enum ChatRequest: Sendable {
    case connect
    case fetchChats
    case fetchMessages(chatID: String, before: String?)
    case sendMessage(chatID: String, text: String)
    case markRead(chatID: String)
}

enum ChatEvent: Sendable {
    case connectionChanged(ConnectionState)
    case chatsLoaded([Chat])
    case messagesLoaded(chatID: String, messages: [Message])
    case messageAdded(Message)
    case messageUpdated(Message)
    case chatUpdated(Chat)
}

struct TelegramCredentials: Sendable {
    let apiID: Int
    let apiHash: String
}

enum TelegramAuthStep: Equatable, Sendable {
    case checkingSession
    case credentials
    case phoneNumber
    case emailAddress
    case emailCode
    case code
    case password(hint: String)
    case ready
    case unavailable(String)
}

enum TelegramAuthEvent: Sendable {
    case step(TelegramAuthStep)
    case error(String)
}

protocol TelegramAuthenticating: Sendable {
    var authEvents: AsyncStream<TelegramAuthEvent> { get }
    func connect() async
    func submitCredentials(_ credentials: TelegramCredentials) async
    func submitPhoneNumber(_ phoneNumber: String) async
    func submitEmailAddress(_ email: String) async
    func submitEmailCode(_ code: String) async
    func submitCode(_ code: String) async
    func submitPassword(_ password: String) async
}

protocol ChatService: Sendable {
    var events: AsyncStream<ChatEvent> { get }
    func send(_ request: ChatRequest) async
}

