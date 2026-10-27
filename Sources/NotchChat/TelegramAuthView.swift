import SwiftUI

struct TelegramAuthView: View {
    @ObservedObject var auth: TelegramAuthStore
    @State private var apiID = ""
    @State private var apiHash = ""
    @State private var value = ""
    @FocusState private var focusedField: Field?

    private enum Field { case apiID, apiHash, value }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchTheme.text)
                Text(instruction)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            form

            if let error = auth.errorMessage {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.48, blue: 0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if auth.step != .checkingSession, case .unavailable = auth.step {} else {
                Button(action: submit) {
                    HStack(spacing: 7) {
                        if auth.isSubmitting { ProgressView().controlSize(.small) }
                        Text(buttonTitle)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(NotchTheme.telegram, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(auth.isSubmitting || !canSubmit)
                .opacity(canSubmit ? 1 : 0.45)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .onChange(of: auth.step) {
            value = ""
            focusFirstField()
        }
    }

    @ViewBuilder
    private var form: some View {
        switch auth.step {
        case .checkingSession:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Checking the encrypted local session…")
                    .font(.system(size: 11))
                    .foregroundStyle(NotchTheme.secondary)
            }
        case .credentials:
            VStack(spacing: 9) {
                authField("API ID", text: $apiID, secure: false, field: .apiID)
                authField("API hash", text: $apiHash, secure: true, field: .apiHash)
                Link(destination: URL(string: "https://my.telegram.org/apps")!) {
                    Label("Create credentials at my.telegram.org", systemImage: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchTheme.telegram)
                }
            }
        case .phoneNumber:
            authField("+84…", text: $value, secure: false, field: .value)
        case .emailAddress:
            authField("Email address", text: $value, secure: false, field: .value)
        case .emailCode:
            authField("Email code", text: $value, secure: false, field: .value)
        case .code:
            authField("Telegram code", text: $value, secure: false, field: .value)
        case .password:
            authField("Two-step verification password", text: $value, secure: true, field: .value)
        case .unavailable:
            Label("Rebuild the app to bundle TDLib.", systemImage: "shippingbox")
                .font(.system(size: 11))
                .foregroundStyle(NotchTheme.secondary)
        case .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    private func authField(_ placeholder: String, text: Binding<String>, secure: Bool, field: Field) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(NotchTheme.text)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(NotchTheme.raised, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .focused($focusedField, equals: field)
        .simultaneousGesture(TapGesture().onEnded {
            NSApp.activate(ignoringOtherApps: true)
            focusedField = field
        })
        .onSubmit(submit)
    }

    private var title: String {
        switch auth.step {
        case .checkingSession: "Connecting"
        case .credentials: "Telegram API"
        case .phoneNumber: "Your phone number"
        case .emailAddress: "Recovery email"
        case .emailCode: "Check your email"
        case .code: "Check Telegram"
        case .password: "Two-step verification"
        case .ready: "Connected"
        case .unavailable: "TDLib unavailable"
        }
    }

    private var instruction: String {
        switch auth.step {
        case .checkingSession: "Looking for a previously authorized Telegram session."
        case .credentials: "Enter the API credentials for your own Telegram application. They are stored in the macOS Keychain."
        case .phoneNumber: "Use international format, including the country code."
        case .emailAddress: "Telegram requires an email address to continue authorization."
        case .emailCode: "Enter the code Telegram sent to your email."
        case .code: "Enter the login code sent inside your Telegram app."
        case let .password(hint): hint.isEmpty ? "Enter your Telegram two-step verification password." : "Password hint: \(hint)"
        case .ready: "Your account is connected."
        case let .unavailable(message): message
        }
    }

    private var buttonTitle: String {
        auth.step == .credentials ? "Continue" : "Verify"
    }

    private var canSubmit: Bool {
        switch auth.step {
        case .credentials: !apiID.isEmpty && !apiHash.isEmpty
        case .phoneNumber, .emailAddress, .emailCode, .code, .password: !value.isEmpty
        default: false
        }
    }

    private func submit() {
        guard canSubmit else { return }
        if auth.step == .credentials {
            auth.submitCredentials(apiID: apiID, apiHash: apiHash)
        } else {
            auth.submit(value)
        }
    }

    private func focusFirstField() {
        DispatchQueue.main.async {
            guard NSApp.isActive else { return }
            focusedField = auth.step == .credentials ? .apiID : .value
        }
    }
}

