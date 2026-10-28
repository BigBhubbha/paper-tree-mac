// The always-on-top, see-through panel that holds the buddy at the top of the screen.
import AppKit
import SwiftUI
import Combine

/// Borderless, non-activating, transparent panel. Never steals focus from the app you are reading in.
class FloatingPanel: NSPanel {
    var allowsKey = false

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    /// Let the buddy sit over the menu bar instead of being pushed below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Receives the mouse for the whole buddy panel: a tiny drag moves it sideways, a click opens the popover.
final class BuddyHitView: NSView {
    var onClick: (() -> Void)?
    var onDrag: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?

    private var downPoint: NSPoint = .zero
    private var lastPoint: NSPoint = .zero
    private var dragging = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }

    override func mouseDown(with event: NSEvent) {
        downPoint = NSEvent.mouseLocation
        lastPoint = downPoint
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        if !dragging && abs(p.x - downPoint.x) > 3 { dragging = true; NSCursor.closedHand.push() }
        if dragging { onDrag?(p.x - lastPoint.x) }
        lastPoint = p
    }

    override func mouseUp(with event: NSEvent) {
        if dragging {
            NSCursor.pop()
            dragging = false
            onDragEnd?()
        } else {
            onClick?()
        }
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}

@MainActor
final class BuddyController: NSObject, NSPopoverDelegate {
    static let size = NSSize(width: 58, height: 58)

    private let state = AppState.shared
    let panel: FloatingPanel
    private let hitView = BuddyHitView()
    private let popover = NSPopover()
    private var bag = Set<AnyCancellable>()
    /// The app you were reading in before the popover opened; we hand focus back to it on close.
    private var previousApp: NSRunningApplication?
    /// Set when a popover action opens one of our own windows, so focus should stay with us.
    var keepFocusAfterClose = false

    var onOpenSettings: (() -> Void)?
    var onRequestAccess: (() -> Void)?

    override init() {
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: BuddyController.size))
        super.init()
        // Sit above the menu bar so the buddy can rest in it, beside the notch.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)

        let root = NSView(frame: NSRect(origin: .zero, size: BuddyController.size))
        let host = NSHostingView(rootView: BuddyHost(state: state))
        host.frame = root.bounds
        host.autoresizingMask = [.width, .height]
        hitView.frame = root.bounds
        hitView.autoresizingMask = [.width, .height]
        root.addSubview(host)
        root.addSubview(hitView)
        panel.contentView = root

        hitView.toolTip = "Paper Tree. Click for research mode, drag to move."
        hitView.onClick = { [weak self] in self?.togglePopover() }
        hitView.onDrag = { [weak self] dx in self?.moveBy(dx) }
        hitView.onDragEnd = { [weak self] in self?.savePosition() }

        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .aqua)
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: BuddyPopoverView(
            state: state,
            openSettings: { [weak self] in
                self?.keepFocusAfterClose = true
                self?.popover.performClose(nil)
                self?.onOpenSettings?()
            },
            requestAccess: { [weak self] in
                self?.keepFocusAfterClose = true
                self?.popover.performClose(nil)
                self?.onRequestAccess?()
            },
            quit: { NSApp.terminate(nil) }))

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.placeOnScreen() }
        }

        state.$showBuddy.removeDuplicates().sink { [weak self] show in
            Task { @MainActor in self?.setVisible(show) }
        }.store(in: &bag)
    }

    // MARK: Placement

    /// The built-in display (the one with the notch) if there is one, else the primary display.
    var homeScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first
    }

    func placeOnScreen() {
        guard let screen = homeScreen else { return }
        let f = screen.frame
        let w = BuddyController.size.width
        var centerX: CGFloat
        if state.buddyCenterXFraction >= 0 && state.buddyCenterXFraction <= 1 {
            centerX = f.minX + CGFloat(state.buddyCenterXFraction) * f.width
        } else if let left = screen.auxiliaryTopLeftArea, screen.safeAreaInsets.top > 0 {
            // Default: rest just left of the notch, where the app menus end.
            centerX = left.maxX - w / 2 - 6
        } else {
            centerX = f.midX
        }
        centerX = min(max(centerX, f.minX + w / 2 + 4), f.maxX - w / 2 - 4)
        // Top of the panel touches the top of the screen; the flask hangs into the menu bar.
        let origin = NSPoint(x: centerX - w / 2, y: f.maxY - BuddyController.size.height + 4)
        panel.setFrameOrigin(origin)
    }

    func resetPosition() {
        state.buddyCenterXFraction = -1
        placeOnScreen()
    }

    private func moveBy(_ dx: CGFloat) {
        guard let screen = homeScreen else { return }
        var frame = panel.frame
        frame.origin.x = min(max(frame.origin.x + dx, screen.frame.minX + 2), screen.frame.maxX - frame.width - 2)
        panel.setFrameOrigin(frame.origin)
        if popover.isShown { popover.performClose(nil) }
    }

    private func savePosition() {
        guard let screen = homeScreen else { return }
        state.buddyCenterXFraction = Double((panel.frame.midX - screen.frame.minX) / screen.frame.width)
    }

    func setVisible(_ visible: Bool) {
        if visible {
            placeOnScreen()
            panel.orderFrontRegardless()
        } else {
            popover.performClose(nil)
            panel.orderOut(nil)
        }
    }

    // MARK: Popover

    func togglePopover() {
        if popover.isShown { popover.performClose(nil); return }
        state.accessibilityGranted = Accessibility.isTrusted
        // The popover needs our app active so its controls respond and it closes on outside clicks.
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        keepFocusAfterClose = false
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: hitView.bounds, of: hitView, preferredEdge: .minY)
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            guard !self.keepFocusAfterClose else { return }
            // Only give focus back if none of our own windows (Settings, Welcome) is showing.
            let ownWindowVisible = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
            if !ownWindowVisible { _ = self.previousApp?.activate(options: []) }
            self.previousApp = nil
        }
    }

    /// Screen rect of the buddy, used to keep explanation cards from covering it.
    var frameOnScreen: NSRect { panel.frame }
}

/// Feeds live state into the drawing.
private struct BuddyHost: View {
    @ObservedObject var state: AppState
    var body: some View {
        BuddyView(mood: state.mood, researchMode: state.researchMode)
            .frame(width: BuddyController.size.width, height: BuddyController.size.height)
    }
}
