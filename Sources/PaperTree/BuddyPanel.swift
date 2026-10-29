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
    /// Fallback size before we know the screen; the real size comes from the menu bar height.
    static let defaultSize = NSSize(width: 24, height: 24)
    /// Current buddy size: a square exactly as tall as the menu bar strip.
    private(set) var size = BuddyController.defaultSize

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
    var onCheckForUpdates: (() -> Void)?

    override init() {
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: BuddyController.defaultSize))
        super.init()
        // Sit above the menu bar so the buddy can rest in it, beside the notch.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)

        let root = NSView(frame: NSRect(origin: .zero, size: BuddyController.defaultSize))
        root.autoresizingMask = [.width, .height]
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
            checkForUpdates: { [weak self] in
                self?.keepFocusAfterClose = true
                self?.popover.performClose(nil)
                self?.onCheckForUpdates?()
            },
            quit: { NSApp.terminate(nil) }))

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.placeOnScreen() }
        }
        // Menu bar height can differ per display and Space (for example after plugging in a monitor).
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
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

    /// Height of the menu bar strip on this screen, in points.
    /// Notch Macs report it as the top safe area inset (about 37 pt); other displays show it as the
    /// gap between frame and visibleFrame (about 24 pt). If the menu bar auto-hides, fall back to the
    /// system status bar thickness.
    static func menuBarHeight(of screen: NSScreen) -> CGFloat {
        let notch = screen.safeAreaInsets.top
        let gap = screen.frame.maxY - screen.visibleFrame.maxY
        var h = max(notch, gap)
        if h < 18 || h > 60 { h = max(NSStatusBar.system.thickness, 22) }
        return floor(h)
    }

    /// The strip the buddy lives in: full width of the screen, menu bar height, flush with the top.
    func menuBarStrip(of screen: NSScreen) -> NSRect {
        let h = BuddyController.menuBarHeight(of: screen)
        let f = screen.frame
        return NSRect(x: f.minX, y: f.maxY - h, width: f.width, height: h)
    }

    /// The camera housing, if this screen has one. The buddy would be hidden behind it, so it never rests there.
    private func notchGap(of screen: NSScreen) -> ClosedRange<CGFloat>? {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea,
              right.minX > left.maxX else { return nil }
        return left.maxX...right.minX
    }

    /// Keeps the buddy's left edge inside the strip and out from under the notch.
    private func clampedX(_ x: CGFloat, in strip: NSRect, screen: NSScreen) -> CGFloat {
        let w = size.width
        var x = min(max(x, strip.minX + 2), strip.maxX - w - 2)
        if let gap = notchGap(of: screen), x + w > gap.lowerBound, x < gap.upperBound {
            let toLeft = gap.lowerBound - w - 2
            let toRight = gap.upperBound + 2
            x = (x + w / 2) < (gap.lowerBound + gap.upperBound) / 2 ? toLeft : toRight
        }
        return x
    }

    func placeOnScreen() {
        guard let screen = homeScreen else { return }
        let strip = menuBarStrip(of: screen)
        // A square as tall as the menu bar, with 1 pt of air top and bottom so the glow never touches the tabs.
        let side = max(strip.height - 2, 16)
        size = NSSize(width: side, height: side)
        let w = size.width
        var centerX: CGFloat
        if state.buddyCenterXFraction >= 0 && state.buddyCenterXFraction <= 1 {
            centerX = strip.minX + CGFloat(state.buddyCenterXFraction) * strip.width
        } else if let gap = notchGap(of: screen) {
            // Default: rest just left of the notch, where the app menus end.
            centerX = gap.lowerBound - w / 2 - 6
        } else {
            centerX = strip.midX
        }
        let x = clampedX(centerX - w / 2, in: strip, screen: screen)
        // Bottom edge sits 1 pt above the bottom of the menu bar; it never hangs below it.
        let frame = NSRect(x: x, y: strip.minY + 1, width: w, height: side)
        panel.setFrame(frame, display: true)
    }

    func resetPosition() {
        state.buddyCenterXFraction = -1
        placeOnScreen()
    }

    /// Dragging is sideways only, inside the menu bar strip. The buddy can pass over the notch while you drag
    /// and settles beside it when you let go.
    private func moveBy(_ dx: CGFloat) {
        guard let screen = homeScreen else { return }
        let strip = menuBarStrip(of: screen)
        let x = min(max(panel.frame.origin.x + dx, strip.minX + 2), strip.maxX - size.width - 2)
        panel.setFrameOrigin(NSPoint(x: x, y: strip.minY + 1))
        if popover.isShown { popover.performClose(nil) }
    }

    private func savePosition() {
        guard let screen = homeScreen else { return }
        let strip = menuBarStrip(of: screen)
        let x = clampedX(panel.frame.origin.x, in: strip, screen: screen)
        panel.setFrameOrigin(NSPoint(x: x, y: strip.minY + 1))
        state.buddyCenterXFraction = Double((panel.frame.midX - strip.minX) / strip.width)
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
        BuddyView(mood: state.mood, researchMode: state.researchMode, compact: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
