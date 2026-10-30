// Single tap of the right Option key: read the highlighted text (a paper's title), look it up in
// Semantic Scholar through the Paper Tree server, and open the island half way to choose a tree.
import AppKit

@MainActor
final class PaperAdder {
    private let state = AppState.shared
    private let store = TreeStore.shared
    private let island: IslandController
    private var task: Task<Void, Never>?

    init(island: IslandController) { self.island = island }

    func singleTap() {
        task?.cancel()
        task = Task { await run() }
    }

    private func run() async {
        let trusted = Accessibility.isTrusted
        if trusted != state.accessibilityGranted { state.accessibilityGranted = trusted }
        guard trusted else {
            island.note("Paper Tree needs Accessibility to read your highlight")
            return
        }
        guard let raw = await captureSelection(), !Task.isCancelled else {
            island.note("Highlight a paper's title first, then tap right Option")
            return
        }
        let title = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"\u{201C}\u{201D}")))
        guard title.count >= 4 else {
            island.note("Highlight a paper's whole title, then tap right Option")
            return
        }
        guard title.count <= 400 else {
            island.note("That's a lot of text. Highlight just the title")
            return
        }
        island.openAdding(AddRequest(highlighted: title))
        do {
            let result = try await PaperLookup.find(title)
            guard !Task.isCancelled, island.model.adding?.highlighted == title else { return }
            if result.candidates.isEmpty {
                island.model.adding?.lookup = .notFound("I couldn't find that title in Semantic Scholar, OpenAlex, or Crossref.")
            } else {
                island.model.adding?.lookup = .found(Array(result.candidates.prefix(8)), confident: result.confident)
            }
        } catch let e as TreeClient.ServerError {
            guard !Task.isCancelled, island.model.adding?.highlighted == title else { return }
            island.model.adding?.lookup = .notFound(e.status == 404 ? "I couldn't find that title in Semantic Scholar, OpenAlex, or Crossref." : e.message)
        } catch {
            guard !Task.isCancelled, island.model.adding?.highlighted == title else { return }
            island.model.adding?.lookup = .notFound("I couldn't reach the paper databases.")
        }
    }

    /// The highlighted text in the app in front: our own text views (like the setup practice) directly,
    /// other apps through Accessibility, and, for apps that hide their text, a quick copy that puts the
    /// clipboard back (if "Grab stubborn text" is on).
    private func captureSelection() async -> String? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        if front.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            for window in NSApp.windows where window.isVisible {
                if let tv = window.firstResponder as? NSTextView, tv.selectedRange().length > 0 {
                    return (tv.string as NSString).substring(with: tv.selectedRange())
                }
            }
            return nil
        }
        let pid = front.processIdentifier
        let mouse = Accessibility.axPoint(fromCocoa: NSEvent.mouseLocation)
        let ax = await Task.detached(priority: .userInitiated) {
            Accessibility.readSelection(pid: pid, mouseAt: mouse)
        }.value
        if let text = ax?.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
        if state.copyFallbackEnabled { return await CopyFallback.grabSelectedText() }
        return nil
    }
}
