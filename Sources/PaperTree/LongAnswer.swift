// The long-form answer field for the "about you" questions: a strip of ruled field-journal paper
// with a red margin line, written on in Kalam in blue-black fountain pen ink. The rules sit under
// each written line, so it reads like a notebook page you are filling in by hand.
import AppKit
import SwiftUI

/// Shared measurements, so the live field and its drawn stand-in (for snapshots) line up the same.
enum JournalInk {
    static let size: CGFloat = 17
    static var font: NSFont { NSFont(name: Typeface.hand, size: size) ?? .systemFont(ofSize: size) }
    /// The font's own line height, and the pitch of the rules (a little roomier than the font).
    static let natural: CGFloat = NSLayoutManager().defaultLineHeight(for: font)
    static let pitch: CGFloat = max(28, ceil(natural) + 3)
    static var lineSpacing: CGFloat { pitch - natural }
    /// Space above the first line inside the field.
    static let inset: CGFloat = 4
    /// How far below the top of a line its baseline sits, measured once from a real layout.
    static let baseline: CGFloat = {
        let storage = NSTextStorage(string: "Ag", attributes: attributes(color: .black))
        let lm = NSLayoutManager()
        let tc = NSTextContainer(size: NSSize(width: 400, height: 400))
        tc.lineFragmentPadding = 0
        lm.addTextContainer(tc)
        storage.addLayoutManager(lm)
        lm.ensureLayout(for: tc)
        guard lm.numberOfGlyphs > 0 else { return font.ascender }
        let frag = lm.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
        return frag.minY + lm.location(forGlyphAt: 0).y
    }()
    /// Where rule `k` (0 = under the first line) is drawn, from the top of the field.
    static func rule(_ k: Int) -> CGFloat { inset + baseline + CGFloat(k) * pitch + 4 }
    static func height(lines: Int) -> CGFloat { inset + CGFloat(lines) * pitch + 6 }

    static let inkColor = Color(hex: 0x23314A)
    static let ruleColor = Color(hex: 0x7F97A8).opacity(0.5)
    static let marginColor = Palette.red.opacity(0.42)

    static func attributes(color: NSColor) -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        return [.font: font, .foregroundColor: color, .paragraphStyle: para]
    }
}

/// A question's answer, written long-hand. Live, it's a real text view; while rendering snapshots
/// it's drawn with plain SwiftUI so the PNGs show the same page.
struct LongAnswerField: View {
    @Binding var text: String
    var placeholder: String
    var lines: Int = 4
    var accessibilityName: String
    var focusOnAppear = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // The red margin line of a notebook page, a touch wobbly, as if ruled by hand.
            MarginRule()
                .stroke(JournalInk.marginColor, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(width: 2)
                .padding(.trailing, 12)
            Group {
                if Snapshots.isRendering {
                    drawn
                } else {
                    JournalTextView(text: $text, placeholder: placeholder, accessibilityName: accessibilityName,
                                    focusOnAppear: focusOnAppear)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: JournalInk.height(lines: lines))
    }

    private var drawn: some View {
        ZStack(alignment: .topLeading) {
            JournalRules(lines: lines)
                .stroke(JournalInk.ruleColor, lineWidth: 0.8)
            Text(text.isEmpty ? placeholder : text)
                .font(.hand(JournalInk.size))
                .foregroundColor(text.isEmpty ? Palette.pencil.opacity(0.85) : JournalInk.inkColor)
                .lineSpacing(JournalInk.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, JournalInk.inset)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

/// The blue rules of the page, one under each line.
struct JournalRules: Shape {
    var lines: Int
    func path(in r: CGRect) -> Path {
        var p = Path()
        var k = 0
        while true {
            let y = r.minY + JournalInk.rule(k)
            if y > r.maxY - 1 || k > 40 { break }
            p.move(to: CGPoint(x: r.minX, y: y))
            p.addLine(to: CGPoint(x: r.maxX, y: y))
            k += 1
        }
        return p
    }
}

private struct MarginRule: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX + 0.6, y: r.maxY), control: CGPoint(x: r.midX - 0.9, y: r.midY))
        return p
    }
}

/// The live field: an NSTextView that draws its own rules under the text, so they always sit
/// under the written lines, even as the field scrolls.
struct JournalTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var accessibilityName: String
    var focusOnAppear = false

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.verticalScrollElasticity = .none

        let storage = NSTextStorage()
        let lm = NSLayoutManager()
        storage.addLayoutManager(lm)
        let tc = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        tc.widthTracksTextView = true
        tc.lineFragmentPadding = 0
        lm.addTextContainer(tc)

        let tv = RuledTextView(frame: .zero, textContainer: tc)
        tv.placeholder = placeholder
        tv.focusOnAppear = focusOnAppear
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = true
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainerInset = NSSize(width: 0, height: JournalInk.inset)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.font = JournalInk.font
        tv.textColor = NSColor(JournalInk.inkColor)
        tv.insertionPointColor = NSColor(JournalInk.inkColor)
        let attrs = JournalInk.attributes(color: NSColor(JournalInk.inkColor))
        tv.defaultParagraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        tv.typingAttributes = attrs
        tv.selectedTextAttributes = [.backgroundColor: NSColor(Palette.marker).withAlphaComponent(0.7)]
        tv.string = text
        storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
        tv.delegate = context.coordinator
        tv.setAccessibilityLabel(accessibilityName)
        tv.setAccessibilityPlaceholderValue(placeholder)

        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let tv = scroll.documentView as? RuledTextView else { return }
        // Keep the page at least as tall as the field, so the rules run to the bottom.
        let h = scroll.contentSize.height
        if tv.minSize.height != h { tv.minSize = NSSize(width: 0, height: h); tv.sizeToFit() }
        if tv.string != text {
            tv.string = text
            tv.textStorage?.setAttributes(JournalInk.attributes(color: NSColor(JournalInk.inkColor)),
                                          range: NSRange(location: 0, length: tv.textStorage?.length ?? 0))
            tv.needsDisplay = true
        }
        if tv.placeholder != placeholder { tv.placeholder = placeholder; tv.needsDisplay = true }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
            tv.needsDisplay = true
        }

        /// A few sentences at most, so the answer stays an answer.
        func textView(_ tv: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            guard let replacement = replacementString else { return true }
            let current = tv.string as NSString
            let after = current.length - range.length + (replacement as NSString).length
            return after <= ReaderProfile.maxAnswer || (replacement as NSString).length < range.length
        }

        /// Tab moves on to the next control (the Next button), the way a form would.
        func textView(_ tv: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertTab(_:)) { tv.window?.selectNextKeyView(nil); return true }
            if selector == #selector(NSResponder.insertBacktab(_:)) { tv.window?.selectPreviousKeyView(nil); return true }
            return false
        }
    }
}

final class RuledTextView: NSTextView {
    var placeholder = ""
    var focusOnAppear = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard focusOnAppear, let window else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window === window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        needsDisplay = true
        return ok
    }

    override func draw(_ dirtyRect: NSRect) {
        // The rules first, under the ink.
        let rules = NSBezierPath()
        var k = 0
        while true {
            let y = JournalInk.rule(k)
            if y > bounds.maxY - 1 || k > 200 { break }
            if y >= dirtyRect.minY - 2 && y <= dirtyRect.maxY + 2 {
                rules.move(to: NSPoint(x: bounds.minX, y: y))
                rules.line(to: NSPoint(x: bounds.maxX, y: y))
            }
            k += 1
        }
        rules.lineWidth = 0.8
        NSColor(JournalInk.ruleColor).setStroke()
        rules.stroke()

        if string.isEmpty && !placeholder.isEmpty {
            let attrs = JournalInk.attributes(color: NSColor(Palette.pencil).withAlphaComponent(0.85))
            NSAttributedString(string: placeholder, attributes: attrs)
                .draw(with: NSRect(x: textContainerOrigin.x, y: textContainerOrigin.y,
                                   width: bounds.width - textContainerOrigin.x, height: bounds.height),
                      options: [.usesLineFragmentOrigin])
        }
        super.draw(dirtyRect)
    }
}
