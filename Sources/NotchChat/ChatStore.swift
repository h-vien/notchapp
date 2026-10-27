import Foundation

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var chats: [Chat] = []
    @Published private(set) var messages: [String: [Message]] = [:]
    @Published private(set) var connection: ConnectionState = .connecting
    @Published var selectedChatID: String?
    @Published var searchText = ""

    private let service: any ChatService
    private var eventTask: Task<Void, Never>?

    init(service: any ChatService) {
        self.service = service
    }

    var filteredChats: [Chat] {
        guard !searchText.isEmpty else { return chats }
        return chats.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.preview.localizedCaseInsensitiveContains(searchText)
        }
    }

    var totalUnread: Int { chats.reduce(0) { $0 + $1.unreadCount } }
    var selectedChat: Chat? { chats.first { $0.id == selectedChatID } }
    var selectedMessages: [Message] { messages[selectedChatID ?? "", default: []] }

    func start() {
        guard eventTask == nil else { return }
        eventTask = Task { [weak self, service] in
            for await event in service.events {
                guard let self else { return }
                apply(event)
            }
        }
        Task {
            await service.send(.connect)
            await service.send(.fetchChats)
        }
    }

    func select(_ chat: Chat) {
        selectedChatID = chat.id
        Task {
            await service.send(.fetchMessages(chatID: chat.id, before: nil))
            await service.send(.markRead(chatID: chat.id))
        }
    }

    func sendMessage(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let selectedChatID, !clean.isEmpty else { return }
        Task { await service.send(.sendMessage(chatID: selectedChatID, text: clean)) }
    }

    private func apply(_ event: ChatEvent) {
        switch event {
        case let .connectionChanged(state):
            connection = state
        case let .chatsLoaded(newChats):
            chats = newChats.sorted(by: chatOrder)
        case let .messagesLoaded(chatID, newMessages):
            messages[chatID] = newMessages
        case let .messageAdded(message):
            messages[message.chatID, default: []].append(message)
        case let .messageUpdated(message):
            guard let index = messages[message.chatID]?.firstIndex(where: { $0.id == message.id }) else { return }
            messages[message.chatID]?[index] = message
        case let .chatUpdated(chat):
            if let index = chats.firstIndex(where: { $0.id == chat.id }) {
                chats[index] = chat
            } else {
                chats.append(chat)
            }
            chats.sort(by: chatOrder)
        }
    }

    private func chatOrder(_ lhs: Chat, _ rhs: Chat) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        return lhs.lastActivity > rhs.lastActivity
    }
}

