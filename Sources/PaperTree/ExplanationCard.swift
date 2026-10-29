// The explanation card: a taped specimen slip that appears beside your highlight.
import AppKit
import SwiftUI

@MainActor
final class CardModel: ObservableObject {
    enum Phase {
        case loading
        case loaded(String)
        case failed(ExplainError)
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
    var explanation: String? { if case .loaded(let s) = phase { return s } else { return nil } }
}

private struct CardSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct BodyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// A specimen slip from the field journal: taped down, a red margin rule, the highlighted
/// term as its title, and the explanation in book type. It grows to fit the answer and
/// scrolls only past `maxBodyHeight`, so text is never clipped.
struct ExplanationCardView: View {
    @ObservedObject var model: CardModel
    var onSize: (CGSize) -> Void

    static let width: CGFloat = 480
    /// Tallest the explanation area gets before it scrolls.
    static let maxBodyHeight: CGFloat = 340

    @State private var bodyHeight: CGFloat = 0

    private let marginX: CGFloat = 26   // left edge of the writing area, right of the red margin rule

    var body: some View {
        card
            .frame(width: ExplanationCardView.width)
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { g in Color.clear.preference(key: CardSizeKey.self, value: g.size) })
            .onPreferenceChange(CardSizeKey.self) { size in onSize(size) }
    }

    private var card: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                header
                title.padding(.top, 10)
                DoubleRule().padding(.top, 12)
                content.padding(.top, 14)
                footer.padding(.top, 16)
            }
            .padding(.leading, marginX + 14)
            .padding(.trailing, 22)
            .padding(.top, 22)
            .padding(.bottom, 16)
            .background(
                ZStack(alignment: .topLeading) {
                    PaperSheet(corner: 4, graph: true)
                    // Notebook margin rule.
                    Rectangle()
                        .fill(Palette.red.opacity(0.38))
                        .frame(width: 1)
                        .padding(.leading, marginX)
                        .padding(.vertical, 1)
                    // A faint deckle along the bottom edge.
                    DeckleEdge()
                        .fill(Palette.ink.opacity(0.05))
                        .frame(height: 5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            )
            .padding(.top, 9)

            // Two strips of tape holding the slip down.
            HStack {
                Tape().frame(width: 62, height: 18).rotationEffect(.degrees(-6))
                Spacer()
                Tape().frame(width: 62, height: 18).rotationEffect(.degrees(5))
            }
            .padding(.horizontal, 30)
            .allowsHitTesting(false)
        }
    }

    // MARK: Header and title

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Sprout().stroke(Palette.green, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 13, height: 13)
            Text(String(format: "PT-%04d", model.specimen))
                .font(.typewriter(11))
                .foregroundColor(Palette.red)
            Text("·").font(.typewriter(11)).foregroundColor(Palette.ink3)
            Text(model.mode.label.lowercased())
                .font(.typewriter(11))
                .foregroundColor(Palette.ink3)
            Spacer(minLength: 8)
            Button(action: model.onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Palette.ink2)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Palette.paper.opacity(0.9)))
                    .overlay(Circle().strokeBorder(Palette.ink.opacity(0.18), lineWidth: 0.75))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
            .accessibilityLabel("Close")
        }
    }

    private var title: some View {
        Text(model.selection)
            .font(.fellItalic(21))
            .foregroundColor(Palette.ink)
            .lineSpacing(1)
            .lineLimit(3)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3)
            .background(
                // Highlighter swipe under the term, slightly uneven like a real marker.
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.marker.opacity(0.55))
                    .padding(.top, 9)
                    .rotationEffect(.degrees(-0.5))
            )
            .help(model.selection)
    }

    // MARK: Body

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            HStack(alignment: .center, spacing: 14) {
                BuddyView(mood: .thinking, researchMode: true)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reading closely...")
                        .font(.hand(17))
                        .foregroundColor(Palette.red)
                    Text("Turning this into plain words.")
                        .font(.ui(12.5))
                        .foregroundColor(Palette.ink3)
                    PencilLines().frame(height: 18).padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading explanation")

        case .loaded(let text):
            ScrollView(.vertical, showsIndicators: bodyHeight > ExplanationCardView.maxBodyHeight) {
                Text(text)
                    .font(.text(16.5))
                    .foregroundColor(Palette.ink)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.trailing, bodyHeight > ExplanationCardView.maxBodyHeight ? 10 : 0)
                    .padding(.bottom, 2)
                    .background(GeometryReader { g in Color.clear.preference(key: BodyHeightKey.self, value: g.size.height) })
            }
            .frame(height: max(1, min(bodyHeight, ExplanationCardView.maxBodyHeight)))
            .onPreferenceChange(BodyHeightKey.self) { h in bodyHeight = ceil(h) }

        case .failed(let err):
            VStack(alignment: .leading, spacing: 6) {
                Text(err.title)
                    .font(.hand(18))
                    .foregroundColor(Palette.red)
                    .rotationEffect(.degrees(-0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Text(err.detail)
                    .font(.ui(13))
                    .foregroundColor(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button("Try again", action: model.onRetry).buttonStyle(StampButtonStyle(compact: true))
                    if err.canOpenSettings {
                        Button("Open Settings", action: model.onSettings).buttonStyle(InkLinkButtonStyle())
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                modeTab("Plain", .plain)
                modeTab("Simpler", .simpler)
                modeTab("More detail", .detail)
            }
            .background(RoundedRectangle(cornerRadius: 3).fill(Palette.paper2))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ink.opacity(0.55), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .disabled(model.isLoading)

            Spacer(minLength: 6)

            if let text = model.explanation {
                Button(model.copied ? "Copied" : "Copy") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(text, forType: .string)
                    model.copied = true
                }
                .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
            }
        }
        .opacity(model.isLoading ? 0.55 : 1)
    }

    private func modeTab(_ title: String, _ mode: ExplainMode) -> some View {
        let selected = model.mode == mode
        return Button { if !selected { model.onMode(mode) } } label: {
            Text(title)
                .font(selected ? .uiBold(12.5) : .ui(12.5))
                .foregroundColor(selected ? Palette.paper2 : Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Palette.ink : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Thin-thick double rule, like the head of a lab notebook page.
private struct DoubleRule: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().fill(Palette.ink.opacity(0.75)).frame(height: 1.2)
            Rectangle().fill(Palette.ink.opacity(0.35)).frame(height: 0.6)
        }
    }
}

/// A slightly torn paper edge along the bottom of the slip.
private struct DeckleEdge: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        var x = r.minX
        var i = 0
        while x < r.maxX {
            let y = r.minY + r.height * CGFloat([0.2, 0.7, 0.4, 0.9, 0.3, 0.6][i % 6])
            p.addLine(to: CGPoint(x: x, y: y))
            x += 7; i += 1
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Translucent paper tape.
private struct Tape: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xEADFB8).opacity(0.78))
            .overlay(Rectangle().strokeBorder(Color(hex: 0xBFAF7E).opacity(0.35), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
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
