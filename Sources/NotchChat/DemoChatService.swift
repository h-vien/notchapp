import Foundation

actor DemoChatService: ChatService {
    nonisolated let events: AsyncStream<ChatEvent>
    private let continuation: AsyncStream<ChatEvent>.Continuation
    private var chats: [Chat]
    private var messages: [String: [Message]]

    init(now: Date = .now) {
        let pair = AsyncStream<ChatEvent>.makeStream()
        events = pair.stream
        continuation = pair.continuation

        chats = [
            Chat(id: "studio", title: "Studio North", initials: "SN", preview: "Mina: The motion pass feels right.", lastActivity: now.addingTimeInterval(-140), unreadCount: 3, isMuted: false, isPinned: true, accent: .coral),
            Chat(id: "alex", title: "Alex Chen", initials: "AC", preview: "Can we ship the build tonight?", lastActivity: now.addingTimeInterval(-1_260), unreadCount: 1, isMuted: false, isPinned: true, accent: .cyan),
            Chat(id: "launch", title: "Launch room", initials: "LR", preview: "You: Release notes are ready.", lastActivity: now.addingTimeInterval(-3_900), unreadCount: 0, isMuted: true, isPinned: false, accent: .violet),
            Chat(id: "design", title: "Design systems", initials: "DS", preview: "New file: tokens-v4.fig", lastActivity: now.addingTimeInterval(-8_100), unreadCount: 8, isMuted: true, isPinned: false, accent: .mint),
            Chat(id: "sam", title: "Sam Rivera", initials: "SR", preview: "Perfect — see you Thursday.", lastActivity: now.addingTimeInterval(-86_400), unreadCount: 0, isMuted: false, isPinned: false, accent: .amber)
        ]

        messages = [
            "studio": [
                Message(id: "m1", chatID: "studio", sender: "Mina", text: "The motion pass feels right. It finally behaves like part of the hardware.", sentAt: now.addingTimeInterval(-620), isOutgoing: false, isRead: true, isEdited: false),
                Message(id: "m2", chatID: "studio", sender: "You", text: "Agreed. I tightened the expand curve and removed the extra bounce.", sentAt: now.addingTimeInterval(-510), isOutgoing: true, isRead: true, isEdited: false),
                Message(id: "m3", chatID: "studio", sender: "Noah", text: "Nice. Can we keep the unread glance visible without opening it?", sentAt: now.addingTimeInterval(-250), isOutgoing: false, isRead: false, isEdited: false),
                Message(id: "m4", chatID: "studio", sender: "Mina", text: "Yes — the compact notch can carry the sender and count.", sentAt: now.addingTimeInterval(-140), isOutgoing: false, isRead: false, isEdited: false)
            ],
            "alex": [
                Message(id: "a1", chatID: "alex", sender: "Alex", text: "Can we ship the build tonight?", sentAt: now.addingTimeInterval(-1_260), isOutgoing: false, isRead: false, isEdited: false)
            ]
        ]
    }

    func send(_ request: ChatRequest) async {
        switch request {
        case .connect:
            continuation.yield(.connectionChanged(.connecting))
            try? await Task.sleep(for: .milliseconds(420))
            continuation.yield(.connectionChanged(.online))
        case .fetchChats:
            continuation.yield(.chatsLoaded(chats))
        case let .fetchMessages(chatID, _):
            continuation.yield(.messagesLoaded(chatID: chatID, messages: messages[chatID, default: []]))
        case let .sendMessage(chatID, text):
            let message = Message(id: UUID().uuidString, chatID: chatID, sender: "You", text: text, sentAt: .now, isOutgoing: true, isRead: false, isEdited: false)
            messages[chatID, default: []].append(message)
            if let index = chats.firstIndex(where: { $0.id == chatID }) {
                chats[index].preview = "You: \(text)"
                chats[index].lastActivity = message.sentAt
                continuation.yield(.chatUpdated(chats[index]))
            }
            continuation.yield(.messageAdded(message))
        case let .markRead(chatID):
            if let index = chats.firstIndex(where: { $0.id == chatID }) {
                chats[index].unreadCount = 0
                continuation.yield(.chatUpdated(chats[index]))
            }
        }
    }
}

