// The explanation card: a clean note card that opens beside your highlight, in the same style
// as the card on the Paper Tree website. A short answer, a thin rule, then a mini glossary.
// CardController measures this view's real height and sizes the window to match, so nothing clips.
import AppKit
import SwiftUI

@MainActor
final class CardModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case loaded(Explanation)
        case failed(title: String, detail: String, canOpenSettings: Bool)
    }

    @Published var selection: String = ""
    @Published var mode: ExplainMode = .plain
    @Published var phase: Phase = .loading
    @Published var specimen: Int = 1
    @Published var copied = false

    var onMode: (ExplainMode) -> Void = { _ in }
    var onRetry: () -> Void = {}
    var onClose: () -> Void = {}
    var onSettings: () -> Void = {}

    var isLoading: Bool { if case .loading = phase { return true } else { return false } }
    var explanation: Explanation? { if case .loaded(let e) = phase { return e } else { return nil } }
}

/// Colors lifted from the website's card.
enum CardInk {
    static let paper = Color(hex: 0xFFFEFA)
    static let border = Color(hex: 0x2B2822)
    static let text = Color(hex: 0x26231D)
    static let muted = Color(hex: 0x5F584B)
    static let faint = Color(hex: 0x8A8272)
    static let rule = Color(hex: 0xE6DFCF)
    static let chip = Color(hex: 0xD4CCBA)
}

/// The whole card. `scrollBodyHeight` is nil when everything fits; otherwise the answer and
/// glossary scroll inside a box of that height while the header and buttons stay put.
struct ExplanationCardView: View {
    @ObservedObject var model: CardModel
    var scrollBodyHeight: CGFloat? = nil

    static let width: CGFloat = 440
    static let corner: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(model: model)
            quote.padding(.top, 6)
            Group {
                if let h = scrollBodyHeight {
                    ScrollView(.vertical, showsIndicators: true) {
                        CardBody(model: model).padding(.trailing, 8)
                    }
                    .frame(height: h)
                } else {
                    CardBody(model: model)
                }
            }
            .padding(.top, 10)
            CardFooter(model: model).padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 12)
        .frame(width: ExplanationCardView.width, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: ExplanationCardView.corner, style: .continuous).fill(CardInk.paper))
        .overlay(RoundedRectangle(cornerRadius: ExplanationCardView.corner, style: .continuous)
            .strokeBorder(CardInk.border.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: ExplanationCardView.corner, style: .continuous))
    }

    /// One quiet line showing what you highlighted.
    private var quote: some View {
        Text("\u{201C}" + model.selection.replacingOccurrences(of: "\n", with: " ") + "\u{201D}")
            .font(.ui(12))
            .foregroundColor(CardInk.faint)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(model.selection)
    }
}

private struct CardHeader: View {
    @ObservedObject var model: CardModel

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Sprout().stroke(Palette.green, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 15, height: 15)
            Text("Paper Tree")
                .font(.uiBold(13.5))
                .foregroundColor(CardInk.text)
            Spacer(minLength: 8)
            Text(model.mode.label)
                .font(.ui(12))
                .foregroundColor(CardInk.faint)
            Button(action: model.onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(CardInk.faint)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
            .accessibilityLabel("Close")
        }
    }
}

/// The answer plus the glossary. Measured on its own too, so the card knows how much can scroll.
struct CardBody: View {
    @ObservedObject var model: CardModel

    var body: some View {
        switch model.phase {
        case .loading:
            HStack(alignment: .center, spacing: 12) {
                BuddyView(mood: .thinking, researchMode: true)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reading closely...")
                        .font(.ui(14))
                        .foregroundColor(CardInk.muted)
                    PencilLines().frame(width: 200, height: 18)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading explanation")

        case .loaded(let e):
            VStack(alignment: .leading, spacing: 0) {
                Text(e.text)
                    .font(.ui(15.5))
                    .foregroundColor(CardInk.text)
                    .lineSpacing(3.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if !e.terms.isEmpty {
                    Rectangle().fill(CardInk.rule).frame(height: 1).padding(.top, 12)
                    Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 5) {
                        ForEach(e.terms, id: \.self) { t in
                            GridRow {
                                // Short terms set the column width; long ones wrap at 150 pt.
                                Group {
                                    if t.term.count <= 20 {
                                        Text(t.term).fixedSize()
                                    } else {
                                        Text(t.term).frame(width: 150, alignment: .leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .font(.uiBold(13))
                                .foregroundColor(CardInk.text)
                                Text(t.meaning)
                                    .font(.ui(13))
                                    .foregroundColor(CardInk.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .padding(.top, 9)
                }
            }

        case .failed(let title, let detail, let canOpenSettings):
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.uiBold(14))
                    .foregroundColor(Palette.red)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.ui(13))
                    .foregroundColor(CardInk.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Try again", action: model.onRetry).buttonStyle(ChipButtonStyle(selected: true))
                    if canOpenSettings {
                        Button("Open Settings", action: model.onSettings).buttonStyle(ChipButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

private struct CardFooter: View {
    @ObservedObject var model: CardModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach([ExplainMode.plain, .simpler, .detail], id: \.self) { mode in
                Button(mode == .plain ? "Plain" : mode.label) {
                    if model.mode != mode || model.explanation == nil { model.onMode(mode) }
                }
                .buttonStyle(ChipButtonStyle(selected: model.mode == mode))
                .disabled(model.isLoading)
            }
            Spacer(minLength: 6)
            if let e = model.explanation {
                Button(model.copied ? "Copied" : "Copy") {
                    var text = e.text
                    if !e.terms.isEmpty {
                        text += "\n\n" + e.terms.map { "\($0.term): \($0.meaning)" }.joined(separator: "\n")
                    }
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(text, forType: .string)
                    model.copied = true
                }
                .buttonStyle(ChipButtonStyle(quiet: true))
            }
        }
        .opacity(model.isLoading ? 0.6 : 1)
    }
}

/// Small outlined button like the website card's "Simpler" and "More detail".
struct ChipButtonStyle: ButtonStyle {
    var selected = false
    var quiet = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(12))
            .foregroundColor(selected ? Color(hex: 0xFBF8EF) : (quiet ? CardInk.faint : Color(hex: 0x3A362E)))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(selected ? Palette.green : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(selected ? Palette.green : CardInk.chip.opacity(quiet ? 0 : 1), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// The little sprout logo mark.
struct Sprout: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h))
        p.addLine(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.38))
        // left leaf
        p.move(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.55))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.05, y: r.minY + h * 0.3), control: CGPoint(x: r.minX + w * 0.1, y: r.minY + h * 0.62))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.55), control: CGPoint(x: r.minX + w * 0.42, y: r.minY + h * 0.22))
        // right leaf
        p.move(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.4))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.95, y: r.minY + h * 0.05), control: CGPoint(x: r.minX + w * 0.6, y: r.minY + h * 0.02))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.4), control: CGPoint(x: r.minX + w * 0.92, y: r.minY + h * 0.42))
        return p
    }
}

/// Pencil lines being "written" while we wait.
private struct PencilLines: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<2 {
                    let progress = CGFloat((sin(t * 1.6 + Double(i) * 1.3) * 0.5 + 0.5))
                    let y = CGFloat(i) * 9 + 3
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width * (0.35 + 0.6 * progress) * (i == 1 ? 0.7 : 1), y: y))
                    ctx.stroke(p, with: .color(Palette.pencil.opacity(0.55)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
    }
}

/// Card window. It can take keyboard focus (for Esc) without activating Paper Tree.
final class CardPanel: FloatingPanel {
    var onEscape: (() -> Void)?

    override func cancelOperation(_ sender: Any?) { onEscape?() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}
