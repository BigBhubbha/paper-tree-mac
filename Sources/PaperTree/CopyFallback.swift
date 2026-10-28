// Fallback for apps that do not share highlighted text through Accessibility
// (some PDF viewers, canvas-based apps, some Chrome pages).
// We press Cmd+C for you, read the text, then put your clipboard back exactly as it was.
import AppKit
import Carbon.HIToolbox

@MainActor
enum CopyFallback {
    /// Pasteboards larger than this are left alone so we never stall on a big image copy.
    private static let maxSnapshotBytes = 25 * 1024 * 1024

    private struct Snapshot {
        var items: [[(NSPasteboard.PasteboardType, Data)]]
        var tooBig: Bool
    }

    private static func snapshot(_ pb: NSPasteboard) -> Snapshot {
        var total = 0
        var items: [[(NSPasteboard.PasteboardType, Data)]] = []
        for item in pb.pasteboardItems ?? [] {
            var entries: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                guard let data = item.data(forType: type) else { continue }
                total += data.count
                if total > maxSnapshotBytes { return Snapshot(items: [], tooBig: true) }
                entries.append((type, data))
            }
            items.append(entries)
        }
        return Snapshot(items: items, tooBig: false)
    }

    private static func restore(_ snap: Snapshot, to pb: NSPasteboard) {
        pb.clearContents()
        let restored: [NSPasteboardItem] = snap.items.map { entries in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pb.writeObjects(restored) }
    }

    /// Returns the selected text of the frontmost app, or nil if nothing was copied.
    static func grabSelectedText() async -> String? {
        let pb = NSPasteboard.general
        let snap = snapshot(pb)
        if snap.tooBig { return nil }
        let before = pb.changeCount

        // Wait until the physical modifier keys are up, so we send a clean Cmd+C.
        for _ in 0..<10 {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if !flags.contains(.maskShift) && !flags.contains(.maskAlternate) && !flags.contains(.maskControl) { break }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_C)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return nil }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // Give the app up to about 400 ms to put the text on the pasteboard.
        var changed = false
        for _ in 0..<16 {
            try? await Task.sleep(nanoseconds: 25_000_000)
            if pb.changeCount != before { changed = true; break }
        }
        guard changed else { return nil }

        // Some apps write in two steps; let them finish.
        try? await Task.sleep(nanoseconds: 30_000_000)
        let text = pb.string(forType: .string)
        restore(snap, to: pb)

        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
