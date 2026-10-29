// Watches the mouse across all apps (only while research mode is on):
// you drag, double-click, or triple-click to highlight text, and a moment after you let go
// we read the highlight and open the explanation card next to it. No extra click needed.
// We only listen to mouse clicks here; we never record keystrokes.
import AppKit
import Combine

@MainActor
final class SelectionMonitor {
    private let state = AppState.shared
    private let card: CardController
    private var monitors: [Any] = []
    private var bag = Set<AnyCancellable>()

    private var downPoint: NSPoint = .zero
    private var dragged = false
    private var captureTask: Task<Void, Never>?

    /// The last highlight we explained, so letting go on the same text again does not re-fire.
    private var lastExplained: String?
    private var lastExplainedAt = Date.distantPast
    /// Wait this long after mouse up, so the app finishes selecting (and a triple-click can land).
    private let debounce: UInt64 = 350_000_000
    private let minCharacters = 2
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
                if !on { self.captureTask?.cancel(); self.lastExplained = nil }
                if on { ExplainClient.warmUp(endpoint: self.state.endpoint) }
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
        /// Cmd, Control, or Option held: the user is doing something else (Cmd-click links, etc.).
        var commandLike: Bool
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
            let f = e.modifierFlags
            commandLike = f.contains(.command) || f.contains(.control) || f.contains(.option)
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

        guard e.kind == .leftDown, state.researchMode else { return }
        // A new gesture replaces any highlight we were still waiting on.
        captureTask?.cancel()
        downPoint = p
        dragged = false
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
        guard !e.commandLike else { return }

        let p = e.location
        let moved = dragged || hypot(p.x - downPoint.x, p.y - downPoint.y) > 4

        // Only selecting gestures: a drag, a double or triple click, or a shift-click.
        let selecting = moved || e.clickCount >= 2 || e.shift
        guard selecting else { return }

        // Open the connection now, while we wait for the app to finish selecting.
        ExplainClient.warmUp(endpoint: state.endpoint)

        let down = downPoint
        let clicks = e.clickCount
        captureTask?.cancel()
        captureTask = Task { [weak self] in
            await self?.capture(down: down, up: p, clickCount: clicks, dragged: moved)
        }
    }

    // MARK: Capturing the highlight

    private func capture(down: NSPoint, up: NSPoint, clickCount: Int, dragged: Bool) async {
        // Debounce: give the app a moment to finish its selection (and a triple-click time to land).
        try? await Task.sleep(nanoseconds: debounce)
        guard !Task.isCancelled,
              state.researchMode,
              !NSEvent.modifierFlags.contains(.command),
              NSEvent.pressedMouseButtons & 1 == 0,      // still dragging: wait for the real mouse up
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

        guard !Task.isCancelled, let sel = selection else { return }
        let text = sel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= minCharacters else { return }
        // Same highlight as the one just explained: leave the card alone.
        if text == lastExplained && (card.isVisible || Date().timeIntervalSince(lastExplainedAt) < 8) { return }
        lastExplained = text
        lastExplainedAt = Date()
        // show() cancels any explanation still loading for an older highlight.
        card.show(for: sel, clickedAt: up)
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
}
