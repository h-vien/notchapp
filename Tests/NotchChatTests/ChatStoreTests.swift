import XCTest
import AppKit
@testable import NotchChat

@MainActor
final class ChatStoreTests: XCTestCase {
    func testDemoServiceLoadsChatsAndSendsMessage() async throws {
        let store = ChatStore(service: DemoChatService())
        store.start()
        try await Task.sleep(for: .milliseconds(700))

        XCTAssertEqual(store.connection, .online)
        XCTAssertFalse(store.chats.isEmpty)
        let firstUnpinnedIndex = store.chats.firstIndex(where: { !$0.isPinned }) ?? store.chats.endIndex
        XCTAssertTrue(store.chats[..<firstUnpinnedIndex].allSatisfy(\.isPinned))
        XCTAssertTrue(store.chats[firstUnpinnedIndex...].allSatisfy { !$0.isPinned })

        let chat = try XCTUnwrap(store.chats.first)
        store.select(chat)
        try await Task.sleep(for: .milliseconds(100))
        let originalCount = store.selectedMessages.count

        store.sendMessage("Hello from the notch")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.selectedMessages.count, originalCount + 1)
        XCTAssertEqual(store.selectedMessages.last?.text, "Hello from the notch")
        XCTAssertEqual(store.selectedChat?.unreadCount, 0)
    }

    func testScreenGeometryReservesHardwareNotch() {
        let geometry = ScreenGeometry(
            frame: NSRect(x: 0, y: 0, width: 1_512, height: 982),
            safeAreaTop: 32,
            auxiliaryLeft: NSRect(x: 0, y: 950, width: 650, height: 32),
            auxiliaryRight: NSRect(x: 862, y: 950, width: 650, height: 32)
        )

        XCTAssertEqual(geometry.topOcclusionHeight, 32)
        XCTAssertEqual(geometry.notchWidth, 212)
    }

    func testScreenGeometryDoesNotPadExternalDisplay() {
        let geometry = ScreenGeometry(
            frame: NSRect(x: 0, y: 0, width: 1_920, height: 1_080),
            safeAreaTop: 0,
            auxiliaryLeft: nil,
            auxiliaryRight: nil
        )

        XCTAssertEqual(geometry.topOcclusionHeight, 0)
        XCTAssertEqual(geometry.notchWidth, 0)
    }
}

