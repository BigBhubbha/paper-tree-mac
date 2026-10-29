// Reading the highlighted text of whatever app you are in, through the macOS Accessibility API.
import AppKit
import ApplicationServices

/// A highlight we captured, ready to explain.
struct CapturedSelection {
    var text: String
    var context: String
    /// Where the highlight is, in Cocoa screen coordinates (origin bottom-left of the primary display).
    var rect: NSRect
    /// True when the rect came from the app itself, false when it was guessed from the mouse.
    var preciseRect: Bool
    var appPID: pid_t
    var appName: String
    var capturedAt: Date
    var source: Source

    enum Source { case accessibility, copyFallback }
}

enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system "Paper Tree would like to control this computer" prompt (once per launch at most).
    @discardableResult
    static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Chromium and Electron apps build their accessibility tree only when asked.
    /// Setting AXManualAccessibility is the documented, low-impact way to ask.
    private static var nudgedPIDs = Set<pid_t>()
    static func nudgeAccessibilityTree(pid: pid_t) {
        guard !nudgedPIDs.contains(pid) else { return }
        nudgedPIDs.insert(pid)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    // MARK: Reading the selection

    struct AXSelection: Sendable {
        var text: String
        var context: String
        var axRect: CGRect?   // top-left-origin global coordinates, as AX reports them
    }

    /// Looks for selected text in the focused element, then in the element under the mouse and its parents.
    static func readSelection(pid: pid_t, mouseAt: CGPoint?) -> AXSelection? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.35)

        var candidates: [AXUIElement] = []
        if let focused: AXUIElement = copyElement(appElement, kAXFocusedUIElementAttribute) {
            candidates.append(focused)
        }
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.35)
        if let focused: AXUIElement = copyElement(systemWide, kAXFocusedUIElementAttribute) {
            candidates.append(focused)
        }
        if let p = mouseAt {
            var hit: AXUIElement?
            if AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(p.y), &hit) == .success, var el = hit {
                // Walk up a few levels: web views often put the selection on an ancestor.
                for _ in 0..<6 {
                    candidates.append(el)
                    guard let parent: AXUIElement = copyElement(el, kAXParentAttribute) else { break }
                    el = parent
                }
            }
        }

        for el in candidates {
            AXUIElementSetMessagingTimeout(el, 0.35)
            guard let raw: String = copyValue(el, kAXSelectedTextAttribute) else { continue }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            var rect: CGRect?
            var context = ""
            if let range = selectedRange(el) {
                rect = bounds(el, range: range)
                context = surroundingText(el, range: range)
            }
            return AXSelection(text: text, context: context, axRect: rect)
        }
        return nil
    }

    private static func selectedRange(_ el: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        let axValue = v as! AXValue
        var range = CFRange()
        guard AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range), range.length > 0 else { return nil }
        return range
    }

    private static func bounds(_ el: AXUIElement, range: CFRange) -> CGRect? {
        var r = range
        guard let param = AXValueCreate(.cfRange, &r) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, param, &value) == .success,
              let v = value, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        let axValue = v as! AXValue
        var rect = CGRect.zero
        guard AXValueGetType(axValue) == .cgRect, AXValueGetValue(axValue, .cgRect, &rect) else { return nil }
        return rect
    }

    /// Up to about 300 characters on each side of the highlight, to help the explanation.
    private static func surroundingText(_ el: AXUIElement, range: CFRange) -> String {
        let pad = 300
        var total = range.location + range.length + pad
        if let n: Int = copyValue(el, kAXNumberOfCharactersAttribute) { total = n }
        let start = max(0, range.location - pad)
        let end = min(total, range.location + range.length + pad)
        guard end > start else { return "" }
        var r = CFRange(location: start, length: end - start)
        guard let param = AXValueCreate(.cfRange, &r) else { return "" }
        var value: CFTypeRef?
        if AXUIElementCopyParameterizedAttributeValue(el, kAXStringForRangeParameterizedAttribute as CFString, param, &value) == .success,
           let s = value as? String {
            return s
        }
        return ""
    }

    // MARK: Small typed helpers

    private static func copyElement(_ el: AXUIElement, _ attr: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    private static func copyValue<T>(_ el: AXUIElement, _ attr: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success else { return nil }
        return value as? T
    }

    // MARK: Coordinates

    /// AX uses a top-left origin on the primary display; AppKit uses bottom-left.
    static func cocoaRect(fromAX r: CGRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    static func axPoint(fromCocoa p: NSPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: primaryHeight - p.y)
    }

    /// Rejects empty, giant, or off-screen rects that some apps report.
    static func isPlausible(_ r: NSRect) -> Bool {
        guard r.width >= 1, r.height >= 1, r.width < 5000, r.height < 3000 else { return false }
        return NSScreen.screens.contains { $0.frame.intersects(r) }
    }
}
