import AppKit
import SwiftUI

@main
struct NotchChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Text("NotchChat")
                .font(.headline)

            Divider()

            Button("Quit NotchChat") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(nsImage: MenuBarArtwork.image)
                .renderingMode(.original)
                .accessibilityLabel("NotchChat")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("NotchChat")
                    .font(.title2.bold())
                Text("A focused messaging surface built for the MacBook notch.")
                    .foregroundStyle(.secondary)
                Text("Backend: demo service")
                    .font(.caption.monospaced())
            }
            .padding(24)
            .frame(width: 360)
        }
    }
}

@MainActor
private enum MenuBarArtwork {
    static let image: NSImage = {
        let fallback = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: "NotchChat")!
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return fallback }
        image.size = NSSize(width: 20, height: 20)
        image.isTemplate = false
        return image
    }()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?
    private var store: ChatStore?
    private var authStore: TelegramAuthStore?
    private var telegramService: TelegramChatService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let service = TelegramChatService()
        telegramService = service
        let store = ChatStore(service: service)
        let authStore = TelegramAuthStore(service: service)
        self.store = store
        self.authStore = authStore
        panelController = NotchPanelController(store: store, auth: authStore)
        panelController?.show()
        authStore.start()
        store.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

