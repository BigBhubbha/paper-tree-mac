// The flask buddy, drawn entirely in code on a 100 x 100 canvas.
// The same geometry is mirrored in design-previews/buddy.svg.
import SwiftUI

struct BuddyView: View {
    var mood: BuddyMood
    var researchMode: Bool
    /// Pause the idle animation (used for static renders and reduced motion).
    var animated: Bool = true
    /// Menu bar size: the halo is pulled in so the whole buddy, glow included, fits inside its square.
    var compact: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mood: BuddyMood, researchMode: Bool, animated: Bool = true, compact: Bool = false) {
        self.mood = mood
        self.researchMode = researchMode
        self.animated = animated
        self.compact = compact
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated || reduceMotion)) { timeline in
            let t = (animated && !reduceMotion) ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, size in
                ctx.scaleBy(x: size.width / 100, y: size.height / 100)
                BuddyArt.draw(in: &ctx, t: t, mood: mood, research: researchMode, compact: compact)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(researchMode ? "Paper Tree buddy, research mode on" : "Paper Tree buddy")
    }
}

enum BuddyArt {
    // Flask geometry (unit space 100 x 100).
    static var bodyPath: Path {
        var p = Path()
        p.move(to: CGPoint(x: 41, y: 21))
        p.addLine(to: CGPoint(x: 41, y: 42))
        p.addLine(to: CGPoint(x: 21.5, y: 77))
        p.addQuadCurve(to: CGPoint(x: 29, y: 90), control: CGPoint(x: 16, y: 90))
        p.addLine(to: CGPoint(x: 71, y: 90))
        p.addQuadCurve(to: CGPoint(x: 78.5, y: 77), control: CGPoint(x: 84, y: 90))
        p.addLine(to: CGPoint(x: 59, y: 42))
        p.addLine(to: CGPoint(x: 59, y: 21))
        p.closeSubpath()
        return p
    }

    static var rimPath: Path {
        Path(roundedRect: CGRect(x: 37, y: 15, width: 26, height: 7), cornerRadius: 3.5)
    }

    static let eyeY: CGFloat = 70
    static let eyeL: CGFloat = 41.5
    static let eyeR: CGFloat = 58.5

    static func draw(in ctx: inout GraphicsContext, t: Double, mood: BuddyMood, research: Bool, compact: Bool = false) {
        let thinking = mood == .thinking
        let noticed = mood == .noticed

        // 1. Halo: pink to lilac, brighter and wider in research mode.
        let pulse = research ? (sin(t * 2.4) * 0.5 + 0.5) : 0
        // Compact (menu bar): the glow stays inside the 100 x 100 square so nothing spills below the bar.
        let haloCY: CGFloat = compact ? 52 : 56
        let haloR: CGFloat = compact ? (research ? 44 + CGFloat(pulse) * 2 : 40) : (research ? 47 + CGFloat(pulse) * 2 : 42)
        let haloAlpha = research ? 0.95 : 0.7
        let halo = Path(ellipseIn: CGRect(x: 50 - haloR, y: haloCY - haloR, width: haloR * 2, height: haloR * 2))
        ctx.fill(halo, with: .radialGradient(
            Gradient(stops: [
                .init(color: Palette.haloPink.opacity(haloAlpha), location: 0.0),
                .init(color: Palette.haloPink.opacity(haloAlpha * 0.85), location: 0.45),
                .init(color: Palette.haloLilac.opacity(haloAlpha * 0.55), location: 0.75),
                .init(color: Palette.haloLilac.opacity(0), location: 1.0),
            ]),
            center: CGPoint(x: 50, y: haloCY), startRadius: 0, endRadius: haloR))

        // 2. Idle bob. A little hop when a highlight is noticed.
        let bob = CGFloat(sin(t * 2.1)) * (compact ? 1.0 : 1.6) + (noticed ? CGFloat(-abs(sin(t * 6))) * 2.2 : 0)
        var c = ctx
        c.translateBy(x: 0, y: bob)

        // Soft ground shadow (does not bob).
        ctx.fill(Path(ellipseIn: CGRect(x: 30, y: compact ? 92 : 91.5, width: 40, height: compact ? 3.5 : 4)),
                 with: .color(Palette.mintLine.opacity(0.18)))

        let body = bodyPath

        // 3. Glass.
        c.fill(body, with: .linearGradient(
            Gradient(colors: [Palette.mintGlass, Palette.mintLight]),
            startPoint: CGPoint(x: 30, y: 25), endPoint: CGPoint(x: 70, y: 90)))

        // 4. Liquid with a gentle wave, clipped to the glass.
        var liquid = c
        liquid.clip(to: body)
        let level: CGFloat = 57
        var wave = Path()
        wave.move(to: CGPoint(x: 0, y: level))
        var x: CGFloat = 0
        while x <= 100 {
            let y = level + CGFloat(sin(Double(x) / 7.0 + t * 2.6)) * 1.4
            wave.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        wave.addLine(to: CGPoint(x: 100, y: 100))
        wave.addLine(to: CGPoint(x: 0, y: 100))
        wave.closeSubpath()
        liquid.fill(wave, with: .linearGradient(
            Gradient(colors: [Palette.mint, Palette.mintDeep]),
            startPoint: CGPoint(x: 50, y: level), endPoint: CGPoint(x: 50, y: 92)))

        // 5. Bubbles rising from the liquid, up the neck, and out of the top.
        let count = thinking ? 7 : 3
        let speed = thinking ? 0.55 : 0.16
        for i in 0..<count {
            let phase = (t * speed + Double(i) / Double(count)).truncatingRemainder(dividingBy: 1)
            let y = CGFloat(80 - phase * 82)                 // 80 down to -2
            let r = CGFloat(1.4 + Double((i * 7) % 5) * 0.3) * (thinking ? 1.15 : 1)
            let insideNeck = y < 42
            let sway = CGFloat(sin(phase * .pi * 3 + Double(i) * 1.7)) * (insideNeck ? 3.2 : 9)
            let bx = 50 + sway
            let fade = phase > 0.82 ? max(0, 1 - (phase - 0.82) / 0.18) : min(1, phase / 0.08)
            let bubble = Path(ellipseIn: CGRect(x: bx - r, y: y - r, width: r * 2, height: r * 2))
            c.fill(bubble, with: .color(.white.opacity(0.85 * fade)))
            c.stroke(bubble, with: .color(Palette.mintLine.opacity(0.55 * fade)), lineWidth: 0.6)
        }

        // 6. Glass outline and rim.
        c.stroke(body, with: .color(Palette.mintLine), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        c.fill(rimPath, with: .color(Palette.mintLight))
        c.stroke(rimPath, with: .color(Palette.mintLine), lineWidth: 2.0)

        // 7. Sheen on the glass.
        var sheen = Path()
        sheen.move(to: CGPoint(x: 29, y: 78))
        sheen.addLine(to: CGPoint(x: 36.5, y: 64))
        c.stroke(sheen, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: 44, y: 26, width: 2.4, height: 9)), with: .color(.white.opacity(0.7)))

        // 8. Blush.
        for cx in [CGFloat(32.5), CGFloat(67.5)] {
            c.fill(Path(ellipseIn: CGRect(x: cx - 4.2, y: 76.5, width: 8.4, height: 4.4)),
                   with: .color(Palette.blush.opacity(0.75)))
        }

        // 9. Goggles in research mode (drawn under the eyes so the eyes show through).
        if research {
            let frame = Color(hex: 0x37414A)
            var strap = Path()
            strap.move(to: CGPoint(x: 24.5, y: eyeY - 1))
            strap.addLine(to: CGPoint(x: 75.5, y: eyeY - 1))
            c.stroke(strap, with: .color(frame.opacity(0.9)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            for ex in [eyeL, eyeR] {
                let lens = Path(ellipseIn: CGRect(x: ex - 7.6, y: eyeY - 7.6, width: 15.2, height: 15.2))
                c.fill(lens, with: .color(Color(hex: 0xE4F6FF).opacity(0.75)))
                c.stroke(lens, with: .color(frame), lineWidth: 2.4)
                // Little glint on each lens, upper left.
                var glint = Path()
                glint.move(to: CGPoint(x: ex - 4.7, y: eyeY - 1.7))
                glint.addQuadCurve(to: CGPoint(x: ex - 1.7, y: eyeY - 4.7), control: CGPoint(x: ex - 3.9, y: eyeY - 3.9))
                c.stroke(glint, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }

        // 10. Face.
        let eyeColor: Color = research ? Palette.mintLine : .white
        switch mood {
        case .noticed:
            for ex in [eyeL, eyeR] {
                let eye = Path(ellipseIn: CGRect(x: ex - 2.8, y: eyeY - 3.2, width: 5.6, height: 6.4))
                c.fill(eye, with: .color(Color(hex: 0x24493A)))
                c.fill(Path(ellipseIn: CGRect(x: ex - 1.4, y: eyeY - 2.4, width: 1.8, height: 1.8)), with: .color(.white))
            }
            // tiny "o" of surprise
            c.stroke(Path(ellipseIn: CGRect(x: 48.4, y: 76.5, width: 3.2, height: 3.2)), with: .color(Color(hex: 0x24493A)), lineWidth: 1.3)
        case .needsAccess:
            for ex in [eyeL, eyeR] {
                var line = Path()
                line.move(to: CGPoint(x: ex - 3.6, y: eyeY))
                line.addLine(to: CGPoint(x: ex + 3.6, y: eyeY))
                c.stroke(line, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            }
        case .idle, .thinking:
            for ex in [eyeL, eyeR] {
                var caret = Path()
                caret.move(to: CGPoint(x: ex - 4.2, y: eyeY + 2.2))
                caret.addLine(to: CGPoint(x: ex, y: eyeY - 2.4))
                caret.addLine(to: CGPoint(x: ex + 4.2, y: eyeY + 2.2))
                if !research {
                    c.stroke(caret, with: .color(Palette.mintLine.opacity(0.35)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round))
                }
                c.stroke(caret, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            }
        }

        // 11. Permission badge.
        if mood == .needsAccess {
            let badge = Path(ellipseIn: CGRect(x: 70, y: 14, width: 14, height: 14))
            ctx.fill(badge, with: .color(Palette.red))
            ctx.stroke(badge, with: .color(.white), lineWidth: 1.5)
            ctx.draw(Text("!").font(.system(size: 10, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: 77, y: 21))
        }
    }
}
