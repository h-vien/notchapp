import AppKit
import SwiftUI

@MainActor
final class NotchPanelController: NSObject, ObservableObject, NSWindowDelegate {
    private let notchlessHoverSize = NSSize(width: 148, height: 12)
    private let expandedContentSize = NSSize(width: 310, height: 340)
    private var panel: NotchPanel!
    private var hostingView: HoverTrackingHostingView<NotchPanelView>!
    private let store: ChatStore
    private let auth: TelegramAuthStore
    private var hoverCollapseTask: Task<Void, Never>?

    @Published var isExpanded = false {
        didSet { updatePanel(animated: true) }
    }

    init(store: ChatStore, auth: TelegramAuthStore) {
        self.store = store
        self.auth = auth
        super.init()
        let geometry = ScreenGeometry(screen: NSScreen.main)
        let root = NotchPanelView(store: store, auth: auth, isExpanded: Binding(
            get: { [weak self] in self?.isExpanded ?? false },
            set: { [weak self] in self?.isExpanded = $0 }
        ), topOcclusionHeight: geometry.topOcclusionHeight)
        hostingView = HoverTrackingHostingView(rootView: root)
        hostingView.onHoverChanged = { [weak self] isInside in
            self?.handleHover(isInside)
        }
        panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: Self.compactPanelSize(geometry: geometry, fallback: notchlessHoverSize)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.becomesKeyOnlyIfNeeded = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        updatePanel(animated: false)
    }

    func show() {
        let geometry = ScreenGeometry(screen: targetScreen)
        positionPanel(size: Self.compactPanelSize(geometry: geometry, fallback: notchlessHoverSize))
        panel.orderFrontRegardless()
    }

    private func updatePanel(animated: Bool) {
        guard panel != nil else { return }
        let geometry = ScreenGeometry(screen: targetScreen)
        hostingView.rootView = NotchPanelView(store: store, auth: auth, isExpanded: Binding(
            get: { [weak self] in self?.isExpanded ?? false },
            set: { [weak self] in self?.isExpanded = $0 }
        ), topOcclusionHeight: geometry.topOcclusionHeight)
        let size = isExpanded
            ? Self.expandedPanelSize(content: expandedContentSize, geometry: geometry)
            : Self.compactPanelSize(geometry: geometry, fallback: notchlessHoverSize)
        let frame = targetFrame(size: size)
        if isExpanded {
            panel.orderFrontRegardless()
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = isExpanded ? 0.34 : 0.26
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.25, 1)
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                guard let self, !self.isExpanded else { return }
                self.panel.resignKey()
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func positionPanel(size: NSSize) {
        panel.setFrame(targetFrame(size: size), display: true)
    }

    private func targetFrame(size: NSSize) -> NSRect {
        let screen = targetScreen
        let frame = screen?.frame ?? .zero
        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private var targetScreen: NSScreen? { panel?.screen ?? NSScreen.main }

    private static func compactPanelSize(geometry: ScreenGeometry, fallback: NSSize) -> NSSize {
        guard geometry.notchWidth > 0, geometry.topOcclusionHeight > 0 else { return fallback }
        return NSSize(width: geometry.notchWidth, height: geometry.topOcclusionHeight)
    }

    private static func expandedPanelSize(content: NSSize, geometry: ScreenGeometry) -> NSSize {
        NSSize(
            width: max(content.width, geometry.notchWidth + 16),
            height: content.height + geometry.topOcclusionHeight
        )
    }

    func windowDidResignKey(_ notification: Notification) {
        guard isExpanded else { return }
        isExpanded = false
    }

    private func handleHover(_ isInside: Bool) {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = nil

        if isInside {
            guard !isExpanded else { return }
            isExpanded = true
            return
        }

        hoverCollapseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled, let self, self.isExpanded else { return }
            self.isExpanded = false
        }
    }
}

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        }
        super.sendEvent(event)
    }
}

private final class HoverTrackingHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }
}

struct ScreenGeometry {
    let topOcclusionHeight: CGFloat
    let notchWidth: CGFloat

    init(screen: NSScreen?) {
        self.init(
            frame: screen?.frame ?? .zero,
            safeAreaTop: screen?.safeAreaInsets.top ?? 0,
            auxiliaryLeft: screen?.auxiliaryTopLeftArea,
            auxiliaryRight: screen?.auxiliaryTopRightArea
        )
    }

    init(
        frame: NSRect,
        safeAreaTop: CGFloat,
        auxiliaryLeft left: NSRect?,
        auxiliaryRight right: NSRect?
    ) {
        guard let left, let right else {
            topOcclusionHeight = 0
            notchWidth = 0
            return
        }

        let gap = max(0, right.minX - left.maxX)
        guard gap > 0 else {
            topOcclusionHeight = 0
            notchWidth = 0
            return
        }

        notchWidth = gap
        topOcclusionHeight = min(80, max(safeAreaTop, min(left.height, right.height)))
    }
}

