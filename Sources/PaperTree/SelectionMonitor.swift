// Watches the mouse across all apps (only while research mode is on):
//   1. You drag or double-click to highlight text. On mouse up we read the highlight.
//   2. You click on that highlight. We open the explanation card next to it.
// We only listen to mouse clicks; we never record keystrokes.
import AppKit
import Combine

@MainActor
final class SelectionMonitor {
    private let state = AppState.shared
    private let card: CardController
    private var monitors: [Any] = []
    private var bag = Set<AnyCancellable>()

    private var pending: CapturedSelection?
    private var downPoint: NSPoint = .zero
    private var dragged = false
    private var armed = false
    private var captureTask: Task<Void, Never>?
    private var noticeTimer: Task<Void, Never>?

    /// How long a highlight stays "clickable" after you make it.
    private let selectionLifetime: TimeInterval = 60
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    init(card: CardController) {
        self.card = card
    }

    func start() {
        stop()
        // Monitor callbacks arrive on the main thread; we hop onto the main actor explicitly
        // (in order) so this compiles cleanly whatever concurrency annotations the SDK uses.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .leftMouseDragged, .leftMouseUp], handler: { [weak self] e in
            let info = MouseInfo(e)
            Task { @MainActor in self?.handle(info) }
        }) { monitors.append(m) }

        state.$researchMode.removeDuplicates().sink { [weak self] on in
            Task { @MainActor in
                guard let self else { return }
                if !on { self.clearPending() }
                self.state.refreshMood()
            }
        }.store(in: &bag)
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        bag.removeAll()
    }

    // MARK: Events

    /// The parts of an NSEvent we need, copied out so they can cross to the main actor safely.
    struct MouseInfo: Sendable {
        enum Kind: Sendable { case leftDown, rightDown, dragged, leftUp, other }
        var kind: Kind
        var clickCount: Int
        var shift: Bool
        /// Screen location (Cocoa coordinates) at the moment the event arrived.
        var location: NSPoint

        init(_ e: NSEvent) {
            location = NSEvent.mouseLocation
            switch e.type {
            case .leftMouseDown: kind = .leftDown
            case .rightMouseDown: kind = .rightDown
            case .leftMouseDragged: kind = .dragged
            case .leftMouseUp: kind = .leftUp
            default: kind = .other
            }
            clickCount = (e.type == .leftMouseDown || e.type == .leftMouseUp) ? e.clickCount : 0
            shift = e.modifierFlags.contains(.shift)
        }
    }

    private func handle(_ e: MouseInfo) {
        switch e.kind {
        case .leftDown, .rightDown: mouseDown(e)
        case .dragged: mouseDragged(e)
        case .leftUp: mouseUp(e)
        case .other: break
        }
    }

    private func mouseDown(_ e: MouseInfo) {
        let p = e.location
        // Global events never land on our own windows, so any click here is "outside" the card.
        if card.isVisible && !card.frame.contains(p) { card.close() }

        guard e.kind == .leftDown, state.researchMode else { armed = false; return }
        downPoint = p
        dragged = false
        armed = false

        if let sel = pending,
           e.clickCount == 1,
           !e.shift,
           Date().timeIntervalSince(sel.capturedAt) < selectionLifetime,
           hitArea(for: sel).contains(p),
           NSWorkspace.shared.frontmostApplication?.processIdentifier == sel.appPID {
            armed = true
        }
    }

    private func mouseDragged(_ e: MouseInfo) {
        guard state.researchMode, !dragged else { return }
        let p = e.location
        if hypot(p.x - downPoint.x, p.y - downPoint.y) > 4 { dragged = true }
    }

    private func mouseUp(_ e: MouseInfo) {
        guard state.researchMode else { return }
        let trusted = Accessibility.isTrusted
        if trusted != state.accessibilityGranted { state.accessibilityGranted = trusted }
        guard trusted else { state.refreshMood(); return }

        let p = e.location
        let moved = dragged || hypot(p.x - downPoint.x, p.y - downPoint.y) > 4

        // Step 2: a plain click on the highlight you just made.
        if armed && !moved, let sel = pending {
            armed = false
            clearPending()
            card.show(for: sel, clickedAt: p)
            return
        }
        armed = false

        // Step 1: was this a selecting gesture? Drag, double or triple click, or shift-click.
        let selecting = moved || e.clickCount >= 2 || e.shift
        guard selecting else { clearPending(); return }

        let down = downPoint
        let clicks = e.clickCount
        captureTask?.cancel()
        captureTask = Task { [weak self] in
            await self?.capture(down: down, up: p, clickCount: clicks, dragged: moved)
        }
    }

    // MARK: Capturing the highlight

    private func capture(down: NSPoint, up: NSPoint, clickCount: Int, dragged: Bool) async {
        // Give the app a moment to finish updating its selection.
        try? await Task.sleep(nanoseconds: 90_000_000)
        guard !Task.isCancelled,
              let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ownPID else { return }
        let pid = front.processIdentifier
        Accessibility.nudgeAccessibilityTree(pid: pid)

        let axMouse = Accessibility.axPoint(fromCocoa: up)
        let ax = await Task.detached(priority: .userInitiated) {
            Accessibility.readSelection(pid: pid, mouseAt: axMouse)
        }.value
        guard !Task.isCancelled else { return }

        let guessed = guessedRect(down: down, up: up, dragged: dragged)
        var selection: CapturedSelection?

        if let ax {
            var rect = guessed
            var precise = false
            if let r = ax.axRect {
                let cocoa = Accessibility.cocoaRect(fromAX: r)
                // Trust the app's rect only if it is sane and near where the mouse let go.
                if Accessibility.isPlausible(cocoa) && cocoa.insetBy(dx: -60, dy: -60).contains(up) {
                    rect = cocoa
                    precise = true
                }
            }
            selection = CapturedSelection(text: ax.text, context: ax.context, rect: rect, preciseRect: precise,
                                          appPID: pid, appName: front.localizedName ?? "", capturedAt: Date(),
                                          source: .accessibility)
        } else if state.copyFallbackEnabled, dragged || clickCount >= 2 {
            if let text = await CopyFallback.grabSelectedText(), !Task.isCancelled {
                selection = CapturedSelection(text: text, context: "", rect: guessed, preciseRect: false,
                                              appPID: pid, appName: front.localizedName ?? "", capturedAt: Date(),
                                              source: .copyFallback)
            }
        }

        guard !Task.isCancelled else { return }
        guard let sel = selection, sel.text.count >= 1 else { clearPending(); return }
        pending = sel
        state.refreshMood(noticed: true)

        // Calm the buddy down again if the highlight is never clicked.
        noticeTimer?.cancel()
        noticeTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.selectionLifetime ?? 60) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.clearPending()
        }
    }

    /// When the app does not tell us where the highlight is, estimate it from the mouse path.
    private func guessedRect(down: NSPoint, up: NSPoint, dragged: Bool) -> NSRect {
        if !dragged {
            return NSRect(x: up.x - 60, y: up.y - 12, width: 120, height: 24)
        }
        let minY = min(down.y, up.y) - 12
        let maxY = max(down.y, up.y) + 12
        var minX = min(down.x, up.x)
        var maxX = max(down.x, up.x)
        if maxY - minY > 40 {
            // Multi-line: the highlight runs the full width of the lines in between.
            minX -= 260
            maxX += 260
        }
        return NSRect(x: minX - 6, y: minY, width: (maxX - minX) + 12, height: maxY - minY)
    }

    private func hitArea(for sel: CapturedSelection) -> NSRect {
        sel.rect.insetBy(dx: sel.preciseRect ? -4 : -8, dy: sel.preciseRect ? -4 : -6)
    }

    private func clearPending() {
        pending = nil
        noticeTimer?.cancel()
        noticeTimer = nil
        if state.mood == .noticed { state.mood = .idle }
        state.refreshMood()
    }
}
