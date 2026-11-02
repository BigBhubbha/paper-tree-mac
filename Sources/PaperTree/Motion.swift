// One family of motion for the whole app, so everything moves alike. Springs (not timed curves)
// throughout, as Apple recommends: they keep their speed when interrupted, so a pill that is
// opening can turn around and close without a jolt. Opening has a little give; closing has none.
// With Reduce Motion on, movement becomes a short crossfade and nothing sways or grows.
import AppKit
import SwiftUI

enum Motion {
    /// The island growing out of the notch: quick, with a little give.
    static let open = Animation.spring(response: 0.5, dampingFraction: 0.76)
    /// Tucking back into the notch: quicker, no bounce.
    static let close = Animation.spring(response: 0.34, dampingFraction: 0.94)
    /// Presses, toggles, small state changes.
    static let snappy = Animation.spring(response: 0.26, dampingFraction: 0.82)
    /// Turning a page in setup, or moving between grove pages.
    static let page = Animation.spring(response: 0.46, dampingFraction: 0.88)
    /// Things that land, like a stamp.
    static let land = Animation.spring(response: 0.4, dampingFraction: 0.62)

    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// The animation to use, or a plain crossfade under Reduce Motion.
    static func pick(_ a: Animation) -> Animation { reduced ? .easeInOut(duration: 0.18) : a }
}

/// Fades in through a soft blur and a hair of scale, anchored at the top (content arriving in the island).
struct BlurRise: ViewModifier {
    var amount: CGFloat
    func body(content: Content) -> some View {
        content
            .blur(radius: 7 * amount)
            .scaleEffect(1 - 0.035 * amount, anchor: .top)
            .opacity(Double(1 - amount))
    }
}

/// A page turning: it slides a little, swings on its spine, and fades.
struct PageTurn: ViewModifier {
    var amount: CGFloat     // -1 (gone left) ... 0 (here) ... 1 (waiting right)
    func body(content: Content) -> some View {
        content
            .offset(x: 46 * amount)
            .rotation3DEffect(.degrees(Double(-9 * amount)), axis: (x: 0, y: 1, z: 0),
                              anchor: amount > 0 ? .leading : .trailing, perspective: 0.5)
            .opacity(Double(1 - min(1, abs(amount) * 1.15)))
    }
}

extension AnyTransition {
    static var islandContent: AnyTransition {
        if Motion.reduced { return .opacity.animation(.easeInOut(duration: 0.18)) }
        return .asymmetric(
            insertion: .modifier(active: BlurRise(amount: 1), identity: BlurRise(amount: 0)).animation(Motion.open.delay(0.09)),
            removal: .opacity.animation(.easeOut(duration: 0.12)))
    }

    static func pageTurn(forward: Bool) -> AnyTransition {
        if Motion.reduced { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: PageTurn(amount: forward ? 1 : -1), identity: PageTurn(amount: 0)),
            removal: .modifier(active: PageTurn(amount: forward ? -1 : 1), identity: PageTurn(amount: 0)))
    }

    /// A tree's own page opening out of its sheet in the grove.
    static var zoomIn: AnyTransition {
        if Motion.reduced { return .opacity }
        return .asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity),
                           removal: .scale(scale: 1.03).combined(with: .opacity))
    }
}

/// Lifts a touch on hover and sinks on press: for sheets, slips, and cards you can click.
struct HoverLift: ViewModifier {
    var amount: CGFloat = 1
    @State private var hover = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(hover && !Motion.reduced ? 1 + 0.012 * amount : 1)
            .shadow(color: Palette.ink.opacity(hover ? 0.16 : 0), radius: hover ? 8 : 0, x: 0, y: hover ? 4 : 0)
            .onHover { h in withAnimation(Motion.snappy) { hover = h } }
    }
}

extension View {
    func hoverLift(_ amount: CGFloat = 1) -> some View { modifier(HoverLift(amount: amount)) }

    /// Rises into place a beat after the page opens; `order` staggers a page's parts.
    func entrance(_ order: Int) -> some View { modifier(Entrance(order: order)) }
}

struct Entrance: ViewModifier {
    var order: Int
    @State private var shown = false
    func body(content: Content) -> some View {
        let here = shown || Snapshots.isRendering
        return content
            .opacity(here ? 1 : 0)
            .offset(y: here || Motion.reduced ? 0 : 10)
            .onAppear {
                guard !shown else { return }
                withAnimation(Motion.pick(Motion.page).delay(Motion.reduced ? 0 : 0.05 + Double(order) * 0.06)) { shown = true }
            }
    }
}

/// Text that writes itself in: letters ink in from left to right with a soft leading edge.
/// The full text is always laid out (the unwritten part is clear), so the card's size never jumps.
struct WritingText: View {
    var text: String
    var start: Date?

    static func rate(_ count: Int) -> Double { max(80, Double(count) / 1.1) }
    static func duration(_ count: Int) -> Double { Double(count) / rate(count) }

    var body: some View {
        if let start, !Motion.reduced, !Snapshots.isRendering, Date().timeIntervalSince(start) < Self.duration(text.count) + 0.3 {
            TimelineView(.animation(minimumInterval: 1.0 / 45)) { tl in
                let shown = tl.date.timeIntervalSince(start) * Self.rate(text.count)
                Text(Self.inked(text, shown: shown))
            }
        } else {
            Text(text)
        }
    }

    static func inked(_ text: String, shown: Double) -> AttributedString {
        let chars = Array(text)
        let ramp = 7.0
        let full = max(0, min(chars.count, Int(shown - ramp)))
        var out = AttributedString(String(chars[0..<full]))
        let rampEnd = max(full, min(chars.count, Int(shown.rounded(.up))))
        for i in full..<rampEnd {
            var a = AttributedString(String(chars[i]))
            a.foregroundColor = CardInk.text.opacity(max(0, min(1, (shown - Double(i)) / ramp)))
            out += a
        }
        if rampEnd < chars.count {
            var rest = AttributedString(String(chars[rampEnd...]))
            rest.foregroundColor = .clear
            out += rest
        }
        return out
    }
}

/// Fades something in once the text before it has finished writing.
struct FadeInAfter: ViewModifier {
    var start: Date?
    var delay: Double
    func body(content: Content) -> some View {
        if let start, !Motion.reduced, !Snapshots.isRendering, Date().timeIntervalSince(start) < delay + 0.5 {
            TimelineView(.animation(minimumInterval: 1.0 / 45)) { tl in
                let t = max(0, min(1, (tl.date.timeIntervalSince(start) - delay) / 0.35))
                content.opacity(t).offset(y: CGFloat(1 - t) * 6)
            }
        } else {
            content
        }
    }
}
