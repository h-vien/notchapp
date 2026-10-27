import Foundation

@MainActor
final class TelegramAuthStore: ObservableObject {
    @Published private(set) var step: TelegramAuthStep = .checkingSession
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSubmitting = false

    private let service: any TelegramAuthenticating
    private var task: Task<Void, Never>?

    init(service: any TelegramAuthenticating) {
        self.service = service
    }

    var isReady: Bool { step == .ready }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, service] in
            for await event in service.authEvents {
                guard let self else { return }
                isSubmitting = false
                switch event {
                case let .step(step): self.step = step; errorMessage = nil
                case let .error(message): errorMessage = message
                }
            }
        }
    }

    func submitCredentials(apiID: String, apiHash: String) {
        guard let id = Int(apiID), id > 0, !apiHash.isEmpty else {
            errorMessage = "Enter a valid API ID and API hash."
            return
        }
        submit { await $0.submitCredentials(TelegramCredentials(apiID: id, apiHash: apiHash)) }
    }

    func submit(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { errorMessage = "This field is required."; return }
        switch step {
        case .phoneNumber: submit { await $0.submitPhoneNumber(clean) }
        case .emailAddress: submit { await $0.submitEmailAddress(clean) }
        case .emailCode: submit { await $0.submitEmailCode(clean) }
        case .code: submit { await $0.submitCode(clean) }
        case .password: submit { await $0.submitPassword(value) }
        default: break
        }
    }

    private func submit(_ operation: @escaping @Sendable (any TelegramAuthenticating) async -> Void) {
        errorMessage = nil
        isSubmitting = true
        Task { [service] in await operation(service) }
    }
}

