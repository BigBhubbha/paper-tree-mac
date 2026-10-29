// Shows, places, sizes, and closes the explanation card, and runs the requests behind it.
import AppKit
import SwiftUI

@MainActor
final class CardController {
    private let state = AppState.shared
    private let model: CardModel
    private let panel: CardPanel
    private let host: NSHostingView<ExplanationCardView>

    private var current: CapturedSelection?
    private var anchorPoint: NSPoint = .zero
    private var placeBelow = true
    private var lastSize: CGSize = .zero
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
        var sizeHandler: (CGSize) -> Void = { _ in }
        let hosting = NSHostingView(rootView: ExplanationCardView(model: cardModel, onSize: { sizeHandler($0) }))
        hosting.sizingOptions = []
        hosting.frame = cardPanel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        cardPanel.contentView = hosting

        panel = cardPanel
        model = cardModel
        host = hosting

        sizeHandler = { [weak self] size in
            Task { @MainActor in self?.applySize(size) }
        }
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
        placeBelow = true
        lastSize = CGSize(width: ExplanationCardView.width, height: 200)
        layout(size: lastSize)

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
    /// this local one covers clicks on our own windows such as the buddy.
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

        let client = ExplainClient(endpoint: state.endpoint, token: state.clientToken, configured: state.endpointIsConfigured)
        task = Task { [weak self] in
            do {
                let text = try await client.explain(text: sel.text, context: sel.context, mode: mode)
                guard !Task.isCancelled else { return }
                self?.model.phase = .loaded(text)
            } catch let err as ExplainError {
                guard !Task.isCancelled else { return }
                self?.model.phase = .failed(err)
            } catch {
                guard !Task.isCancelled else { return }
                self?.model.phase = .failed(ExplainError(title: "Something went wrong.", detail: error.localizedDescription))
            }
            guard let self else { return }
            self.state.mood = .idle
            self.state.refreshMood()
        }
    }

    // MARK: Layout

    private func applySize(_ size: CGSize) {
        guard size.height > 1, abs(size.height - lastSize.height) > 0.5 || abs(size.width - lastSize.width) > 0.5 else { return }
        lastSize = size
        layout(size: size)
    }

    private func layout(size: CGSize) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) ?? NSScreen.main ?? NSScreen.screens.first
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w = size.width
        // Never taller than the screen; the explanation area scrolls instead of clipping.
        let h = min(size.height, vf.height - 16)
        let gap: CGFloat = 10

        var x = anchorPoint.x - 40
        x = min(max(x, vf.minX + 8), vf.maxX - w - 8)

        var y: CGFloat
        let topOfSelection = current.map { $0.preciseRect && $0.rect.height <= 60 ? $0.rect.maxY : anchorPoint.y + 26 } ?? anchorPoint.y + 26
        if placeBelow && anchorPoint.y - gap - h < vf.minY + 8 {
            placeBelow = false
        }
        if placeBelow {
            y = anchorPoint.y - gap - h
        } else {
            y = topOfSelection + gap
            if y + h > vf.maxY - 8 { y = max(vf.minY + 8, vf.maxY - 8 - h) }
        }
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        panel.invalidateShadow()
    }
}
