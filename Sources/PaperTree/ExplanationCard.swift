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

struct ExplanationCardView: View {
    @ObservedObject var model: CardModel
    var onSize: (CGSize) -> Void

    static let width: CGFloat = 360

    var body: some View {
        card
            .frame(width: ExplanationCardView.width)
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { g in Color.clear.preference(key: CardSizeKey.self, value: g.size) })
            .onPreferenceChange(CardSizeKey.self) { size in onSize(size) }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Strip of tape holding the slip to the page.
            HStack { Spacer(); Tape().frame(width: 74, height: 18).rotationEffect(.degrees(-3)); Spacer() }
                .frame(height: 20)
                .padding(.bottom, -9)
                .zIndex(2)

            VStack(alignment: .leading, spacing: 0) {
                header
                Rectangle().fill(Palette.rule).frame(height: 1).padding(.top, 9)
                highlight.padding(.top, 11)
                content.padding(.top, 10)
                footer.padding(.top, 14)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .background(PaperSheet(corner: 5))
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 7) {
            Sprout().stroke(Palette.green, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 14, height: 14)
            Text("Paper Tree")
                .font(.fell(17))
                .foregroundColor(Palette.ink)
            Spacer()
            Text(model.mode.label)
                .font(.typewriter(10.5))
                .foregroundColor(Palette.ink3)
            Button(action: model.onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Palette.ink3)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
            .accessibilityLabel("Close")
        }
    }

    private var highlight: some View {
        Text(model.selection)
            .font(.textItalic(14))
            .foregroundColor(Palette.ink)
            .lineLimit(2)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.marker.opacity(0.85))
                    .rotationEffect(.degrees(-0.6))
            )
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            HStack(alignment: .center, spacing: 12) {
                BuddyView(mood: .thinking, researchMode: true)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reading closely...")
                        .font(.hand(16))
                        .foregroundColor(Palette.red)
                    Text("Turning this into plain words.")
                        .font(.ui(12))
                        .foregroundColor(Palette.ink3)
                    PencilLines().frame(height: 18).padding(.top, 4)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading explanation")

        case .loaded(let text):
            Text(text)
                .font(.text(15.5))
                .foregroundColor(Palette.ink)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

        case .failed(let err):
            VStack(alignment: .leading, spacing: 6) {
                Text(err.title)
                    .font(.hand(17))
                    .foregroundColor(Palette.red)
                    .rotationEffect(.degrees(-0.8))
                Text(err.detail)
                    .font(.ui(12.5))
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

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Simpler") { model.onMode(.simpler) }
                .buttonStyle(StampButtonStyle(compact: true, quiet: model.mode != .simpler))
                .disabled(model.isLoading)
            Button("More detail") { model.onMode(.detail) }
                .buttonStyle(StampButtonStyle(compact: true, quiet: model.mode != .detail))
                .disabled(model.isLoading)
            if let text = model.explanation {
                Button(model.copied ? "Copied" : "Copy") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(text, forType: .string)
                    model.copied = true
                }
                .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
                .padding(.leading, 2)
            }
            Spacer(minLength: 4)
            Text(String(format: "No. %04d", model.specimen))
                .font(.typewriter(10))
                .foregroundColor(Palette.ink3)
        }
        .opacity(model.isLoading ? 0.55 : 1)
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
