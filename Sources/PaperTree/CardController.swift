// Shows, places, sizes, and closes the explanation card, and runs the requests behind it.
import AppKit
import SwiftUI
import Combine

@MainActor
final class CardController {
    private let state = AppState.shared
    private let model: CardModel
    private let panel: CardPanel
    private let host: NSHostingView<CardRoot>
    /// Off-screen copies of the card used only to measure real text height.
    private let cardMeasurer: NSHostingController<ExplanationCardView>
    private let bodyMeasurer: NSHostingController<CardBody>
    private var bag = Set<AnyCancellable>()
    private var resizeScheduled = false

    private var current: CapturedSelection?
    private var anchorPoint: NSPoint = .zero
    private var task: Task<Void, Never>?
    private var outsideClickMonitor: Any?
    /// Bumped on every show, so a fade-out that finishes late never hides a newer card.
    private var generation = 0

    var onOpenSettings: (() -> Void)?

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    init() {
        let cardPanel = CardPanel(contentRect: NSRect(x: 0, y: 0, width: ExplanationCardView.width, height: 200))
        cardPanel.allowsKey = true
        cardPanel.becomesKeyOnlyIfNeeded = false
        cardPanel.hasShadow = true
        cardPanel.level = .popUpMenu

        let cardModel = CardModel()
        let hosting = NSHostingView(rootView: CardRoot(model: cardModel, scrollBodyHeight: nil))
        hosting.sizingOptions = []
        hosting.frame = cardPanel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        cardPanel.contentView = hosting

        panel = cardPanel
        model = cardModel
        host = hosting
        cardMeasurer = NSHostingController(rootView: ExplanationCardView(model: cardModel))
        bodyMeasurer = NSHostingController(rootView: CardBody(model: cardModel))

        // Any change (answer arrives, mode switch, error) re-measures and re-sizes the window.
        model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.scheduleResize() }
        }.store(in: &bag)

        panel.onEscape = { [weak self] in self?.close() }

        model.onClose = { [weak self] in self?.close() }
        model.onMode = { [weak self] mode in self?.request(mode: mode) }
        model.onRetry = { [weak self] in self?.request(mode: self?.model.mode ?? .plain) }
        model.onSettings = { [weak self] in self?.close(); self?.onOpenSettings?() }
    }

    // MARK: Show and hide

    func show(for selection: CapturedSelection, clickedAt click: NSPoint) {
        task?.cancel()
        generation += 1
        current = selection
        model.selection = selection.text
        model.copied = false
        model.specimen = state.nextSpecimenNumber()

        // Line the card up under the line you clicked; flip above if there is no room below.
        let r = selection.rect
        anchorPoint = NSPoint(x: click.x, y: r.minY)
        if selection.preciseRect {
            // Use the clicked line, not the whole multi-line block, when the highlight is tall.
            anchorPoint.y = r.height > 60 ? click.y - 12 : r.minY
        } else {
            anchorPoint.y = click.y - 14
        }
        resize()

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 1
        }
        installOutsideClickMonitor()
        request(mode: .plain)
    }

    func close() {
        task?.cancel()
        task = nil
        removeOutsideClickMonitor()
        guard panel.isVisible else { return }
        let closingGeneration = generation
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == closingGeneration else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        })
        if state.mood == .thinking { state.mood = .idle; state.refreshMood() }
    }

    /// Click-outside to close. The selection monitor also routes outside clicks here,
    /// this local one covers clicks on our own windows such as the island.
    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let clickedWindow = event.windowNumber
            Task { @MainActor in
                guard let self else { return }
                if clickedWindow != self.panel.windowNumber { self.close() }
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
    }

    // MARK: Requests

    private func request(mode: ExplainMode) {
        guard let sel = current else { return }
        task?.cancel()
        model.mode = mode
        model.copied = false
        model.phase = .loading
        state.mood = .thinking

        let client = ExplainClient(endpoint: state.endpoint, token: state.clientToken, configured: state.endpointIsConfigured,
                                   profile: state.profilePayload)
        task = Task { [weak self] in
            do {
                let explanation = try await client.explain(text: sel.text, context: sel.context, mode: mode)
                guard !Task.isCancelled else { return }
                self?.model.phase = .loaded(explanation)
            } catch let err as ExplainError {
                guard !Task.isCancelled else { return }
                self?.model.phase = .failed(title: err.title, detail: err.detail, canOpenSettings: err.canOpenSettings)
            } catch {
                guard !Task.isCancelled else { return }
                self?.model.phase = .failed(title: "Something went wrong.", detail: error.localizedDescription, canOpenSettings: false)
            }
            guard let self else { return }
            self.state.mood = .idle
            self.state.refreshMood()
        }
    }

    // MARK: Layout

    private func scheduleResize() {
        guard !resizeScheduled else { return }
        resizeScheduled = true
        // objectWillChange fires before the new value lands, so measure on the next turn.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.resizeScheduled = false
            if self.panel.isVisible { self.resize() }
        }
    }

    /// Measures the card's real height at its fixed width, then sizes the window to match.
    /// Only past 80% of the screen height does the answer area scroll.
    private func resize() {
        let width = ExplanationCardView.width
        let probe = CGSize(width: width, height: 100_000)

        cardMeasurer.rootView = ExplanationCardView(model: model)
        let full = ceil(cardMeasurer.sizeThatFits(in: probe).height)

        let vf = screenForAnchor()?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let cap = floor(vf.height * 0.8)

        var height = full
        var scroll: CGFloat? = nil
        if full > cap {
            bodyMeasurer.rootView = CardBody(model: model)
            let bodyHeight = ceil(bodyMeasurer.sizeThatFits(in: CGSize(width: width - 32, height: 100_000)).height)
            let chrome = full - bodyHeight
            scroll = max(80, cap - chrome)
            height = chrome + (scroll ?? 0)
        }
        host.rootView = CardRoot(model: model, scrollBodyHeight: scroll)
        layout(size: CGSize(width: width, height: height + 1))
    }

    private func screenForAnchor() -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func layout(size: CGSize) {
        let vf = screenForAnchor()?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w = size.width
        let h = min(size.height, vf.height - 16)
        let gap: CGFloat = 10

        var x = anchorPoint.x - 40
        x = min(max(x, vf.minX + 8), vf.maxX - w - 8)

        // Prefer below the highlight; flip above if it would run off the bottom; clamp on screen.
        let topOfSelection = current.map { $0.preciseRect && $0.rect.height <= 60 ? $0.rect.maxY : anchorPoint.y + 26 } ?? anchorPoint.y + 26
        var y: CGFloat
        if anchorPoint.y - gap - h >= vf.minY + 8 {
            y = anchorPoint.y - gap - h
        } else if topOfSelection + gap + h <= vf.maxY - 8 {
            y = topOfSelection + gap
        } else {
            y = max(vf.minY + 8, vf.maxY - 8 - h)
        }
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        panel.invalidateShadow()
    }
}

/// What the window hosts: the card pinned to the top of the window.
struct CardRoot: View {
    @ObservedObject var model: CardModel
    var scrollBodyHeight: CGFloat?

    var body: some View {
        ExplanationCardView(model: model, scrollBodyHeight: scrollBodyHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
