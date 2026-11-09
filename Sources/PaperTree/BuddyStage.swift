// The flask buddy as a little actor on each setup page: it waves hello, wears a mortarboard,
// juggles books, knocks on a padlock, presses the Option key, peers at a highlight through a
// magnifier, carries a paper to a sapling, flips the Research switch and celebrates.
// Everything is drawn in code and driven by keyframes over a looping clock; a real action
// (a tap, a highlight) bumps `pulse`, and the buddy answers with a spring hop.
import SwiftUI

enum BuddyAct: String, CaseIterable {
    case wave, school, ponder, juggle, scroll, knock, tap, peer, carry, flip, celebrate

    /// One loop of the act, in seconds.
    var loop: Double {
        switch self {
        case .wave: return 3.2
        case .school: return 3.0
        case .ponder: return 3.6
        case .juggle: return 1.8
        case .scroll: return 3.4
        case .knock: return 2.4
        case .tap: return 3.0
        case .peer: return 3.8
        case .carry: return 4.6
        case .flip: return 2.8
        case .celebrate: return 1.6
        }
    }

    /// The single frame shown when Reduce Motion is on: the moment that says the most.
    var restTime: Double {
        switch self {
        case .wave: return 0.9
        case .tap: return 1.35
        case .peer: return 2.3
        case .carry: return 1.3
        case .flip: return 1.2
        case .celebrate: return 0.4
        case .knock: return 0.62
        default: return 1.0
        }
    }
}

struct BuddyStage: View {
    var act: BuddyAct
    var research = false
    /// Permission page: the padlock opens once macOS lets us in.
    var granted = false
    /// Bump to make the buddy react to something the person really did.
    var pulse = 0
    /// A fixed moment, for snapshots and animation frames.
    var time: Double? = nil

    /// Set by the snapshot renderer to draw every buddy at one moment.
    static var frozenTime: Double? = nil

    @State private var start = Date()
    @State private var pulseAt = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fixed = time ?? Self.frozenTime
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || fixed != nil)) { tl in
            let t: Double = fixed ?? (reduceMotion ? act.restTime : tl.date.timeIntervalSince(start))
            let since: Double = (fixed != nil || reduceMotion) ? 99 : tl.date.timeIntervalSince(pulseAt)
            Canvas { ctx, size in
                var scene = BuddyScene(act: act, t: t, since: since, research: research, granted: granted, size: size)
                scene.draw(&ctx)
            }
        }
        .onChange(of: pulse) { _ in pulseAt = Date() }
        .onChange(of: act) { _ in start = Date() }
        .accessibilityElement()
        .accessibilityLabel("The flask buddy, \(act.rawValue)")
    }
}

// MARK: - Keyframes

enum Keys {
    static func smooth(_ x: Double) -> Double { let t = max(0, min(1, x)); return t * t * (3 - 2 * t) }
    /// Values at times, eased between; held before the first and after the last.
    static func at(_ t: Double, _ keys: [(Double, Double)]) -> Double {
        guard let first = keys.first else { return 0 }
        if t <= first.0 { return first.1 }
        for i in 1..<keys.count where t <= keys[i].0 {
            let a = keys[i - 1], b = keys[i]
            let f = smooth((t - a.0) / max(0.0001, b.0 - a.0))
            return a.1 + (b.1 - a.1) * f
        }
        return keys.last!.1
    }
    /// A hop: up and down once over `d` seconds, starting at `t0`.
    static func hop(_ t: Double, at t0: Double, d: Double, height: Double) -> Double {
        let u = (t - t0) / d
        guard u > 0, u < 1 else { return 0 }
        return -sin(u * .pi) * height
    }
    /// A spring answer to a real action: a quick hop that rings down.
    static func springHop(_ since: Double) -> Double {
        guard since < 1.4 else { return 0 }
        return -abs(sin(since * 8.5)) * 22 * exp(-since * 3.2)
    }
}

// MARK: - The scene

struct BuddyScene {
    var act: BuddyAct
    var t: Double
    var since: Double
    var research: Bool
    var granted: Bool
    var size: CGSize

    private var u: CGFloat { min(size.width / 230, size.height / 250) }
    private var groundY: CGFloat { size.height - 22 * u }
    private var lp: Double { t.truncatingRemainder(dividingBy: act.loop) }

    /// Where the buddy is and how it holds itself, plus its two hands (in buddy units, 0...100).
    struct Pose {
        var x: CGFloat
        var lift: CGFloat = 0
        var tilt: Double = 0
        var squash: CGFloat = 0
        var mood: BuddyMood = .idle
        var goggles = false
        var left = CGPoint(x: 18, y: 86)
        var right = CGPoint(x: 82, y: 86)
        var scale: CGFloat = 1
    }

    static let shoulderL = CGPoint(x: 26, y: 72)
    static let shoulderR = CGPoint(x: 74, y: 72)

    /// A hand at an angle from straight down (positive swings outward and up) and a reach.
    static func hand(_ right: Bool, angle: Double, reach: CGFloat = 25) -> CGPoint {
        let s = right ? shoulderR : shoulderL
        let side: CGFloat = right ? 1 : -1
        return CGPoint(x: s.x + side * CGFloat(sin(angle)) * reach, y: s.y + CGFloat(cos(angle)) * reach)
    }

    mutating func draw(_ ctx: inout GraphicsContext) {
        let pose = makePose()
        drawBackProps(&ctx, pose)
        drawBuddy(&ctx, pose)
        drawFrontProps(&ctx, pose)
    }

    // MARK: Choreography

    private func makePose() -> Pose {
        let w = size.width
        var p = Pose(x: w * 0.55)
        let k = lp
        switch act {
        case .wave:
            p.lift = CGFloat(Keys.hop(k, at: 0, d: 0.5, height: 14))
            let waving = k < 2.1
            let a = waving ? 2.5 + 0.42 * sin(k * 9) : Keys.at(k, [(2.1, 2.5), (2.6, 0.45)])
            p.right = Self.hand(true, angle: a)
            p.left = Self.hand(false, angle: 0.35)
            p.tilt = 0.06 * sin(k * 2.2)
        case .school:
            p.right = Self.hand(true, angle: 2.35 + 0.16 * sin(k * 7), reach: 20)
            p.left = Self.hand(false, angle: 0.4)
            p.tilt = Keys.at(k, [(0, -0.05), (1.5, 0.08), (3, -0.05)])
        case .ponder:
            p.mood = .thinking
            p.tilt = Keys.at(k, [(0, -0.13), (1.4, -0.13), (1.9, 0.13), (3.2, 0.13), (3.6, -0.13)])
            p.right = Self.hand(true, angle: 2.75, reach: 19)
            p.left = Self.hand(false, angle: 0.3)
        case .juggle:
            let f = k / act.loop * 2 * .pi
            p.right = Self.hand(true, angle: 1.7 + 0.35 * sin(f * 2), reach: 20)
            p.left = Self.hand(false, angle: 1.7 + 0.35 * sin(f * 2 + .pi), reach: 20)
            p.lift = CGFloat(-abs(sin(f * 2)) * 2)
        case .scroll:
            let half = scrollHalf
            p.left = CGPoint(x: 50 - half, y: 66)
            p.right = CGPoint(x: 50 + half, y: 66)
            p.tilt = 0.04 * sin(k * 1.8)
        case .knock:
            p.x = w * 0.36
            if granted {
                p.lift = CGFloat(Keys.hop(k, at: 0.1, d: 0.6, height: 16))
                p.right = Self.hand(true, angle: 2.8)
                p.left = Self.hand(false, angle: 2.8)
            } else {
                p.mood = .needsAccess
                let knock = min(Keys.hop(k, at: 0.35, d: 0.26, height: 1), Keys.hop(k, at: 0.75, d: 0.26, height: 1)) // 0 down to -1
                let reach = 28 + CGFloat(-knock) * 10
                p.right = Self.hand(true, angle: 1.5, reach: reach)
                p.left = Self.hand(false, angle: 0.35)
                p.tilt = 0.08 * (-knock)
            }
        case .tap:
            // Leans over, presses the key once, bounces as the island opens.
            p.x = w * 0.66
            let reachDown = Keys.at(k, [(0.3, 0), (1.0, 1), (1.25, 1.12), (1.5, 1), (2.4, 0)])
            p.tilt = -0.32 * reachDown
            p.left = Self.hand(false, angle: Keys.at(k, [(0, 1.2), (1.0, 1.5), (1.25, 1.65), (1.5, 1.5), (2.4, 1.2)]), reach: 24 + 12 * CGFloat(reachDown))
            p.right = Self.hand(true, angle: 0.5)
            p.lift = CGFloat(Keys.hop(k, at: 1.35, d: 0.45, height: 12))
            p.squash = CGFloat(Keys.hop(k, at: 1.15, d: 0.2, height: -0.08))
        case .peer:
            p.x = w * 0.72
            p.tilt = Keys.at(k, [(0, 0), (0.6, -0.2), (3.2, -0.2), (3.8, 0)])
            p.mood = k > 1.45 ? .noticed : .idle
            p.left = Self.hand(false, angle: 2.0, reach: 27)
            p.right = Self.hand(true, angle: 0.45)
            p.lift = CGFloat(Keys.hop(k, at: 1.45, d: 0.35, height: 7))
        case .carry:
            let walk = Keys.at(k, [(0, 0), (2.2, 1), (3.4, 1), (4.4, 0)])
            p.x = w * (0.2 + 0.36 * CGFloat(walk))
            let walking = (k < 2.2) || (k > 3.4 && k < 4.4)
            p.lift = walking ? CGFloat(-abs(sin(k * 9)) * 3.5) : CGFloat(Keys.hop(k, at: 2.75, d: 0.45, height: 12))
            p.tilt = walking ? 0.07 * sin(k * 9) : 0
            let holding = k < 2.3
            p.left = holding ? CGPoint(x: 34, y: 8) : Self.hand(false, angle: Keys.at(k, [(2.3, 2.9), (3.4, 0.35)]))
            p.right = holding ? CGPoint(x: 66, y: 8) : Self.hand(true, angle: Keys.at(k, [(2.3, 2.9), (3.4, 0.35)]))
        case .flip:
            p.x = w * 0.68
            let flick = max(-Keys.hop(k, at: 0.45, d: 0.22, height: 1), -Keys.hop(k, at: 0.8, d: 0.22, height: 1))
            p.left = Self.hand(false, angle: 1.45 + 0.35 * flick, reach: 34)
            p.right = Self.hand(true, angle: 0.4)
            p.goggles = switchOn
            p.lift = CGFloat(Keys.hop(k, at: 1.1, d: 0.4, height: 10))
        case .celebrate:
            p.lift = CGFloat(-abs(sin(k / act.loop * 2 * .pi)) * 22)
            p.squash = p.lift > -2 ? 0.06 : -0.03
            p.right = Self.hand(true, angle: 2.75 + 0.2 * sin(k * 10))
            p.left = Self.hand(false, angle: 2.75 + 0.2 * sin(k * 10 + 1))
            p.tilt = 0.08 * sin(k * 4)
        }
        p.lift += CGFloat(Keys.springHop(since))
        if since < 1.2 && act != .knock { p.mood = .noticed }
        return p
    }

    private var scrollHalf: CGFloat { CGFloat(Keys.at(lp, [(0, 9), (0.4, 9), (1.4, 30), (2.2, 30), (3.0, 9)])) }
    private var switchOn: Bool { research || (lp > 0.85 && lp < 2.3) }

    // MARK: Drawing the buddy

    private func transform(_ p: Pose) -> CGAffineTransform {
        let s = u * 1.28 * p.scale
        return CGAffineTransform(translationX: p.x, y: groundY + p.lift * u)
            .rotated(by: CGFloat(p.tilt))
            .scaledBy(x: s * (1 + p.squash), y: s * (1 - p.squash))
            .translatedBy(x: -50, y: -91)
    }

    private func drawBuddy(_ ctx: inout GraphicsContext, _ p: Pose) {
        // Shadow on the ground shrinks as it jumps.
        let lift = max(0, -p.lift)
        let sw = 46 * u * max(0.5, 1 - lift / 60)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - sw / 2, y: groundY - 3 * u, width: sw, height: 6 * u)), with: .color(Palette.ink.opacity(0.08)))
        var c = ctx
        c.concatenate(transform(p))
        BuddyArt.draw(in: &c, t: t, mood: p.mood, research: research || p.goggles)
        arm(&c, from: Self.shoulderL, to: p.left, bend: -1)
        arm(&c, from: Self.shoulderR, to: p.right, bend: 1)
        hand(&c, p.left)
        hand(&c, p.right)
        heldProps(&c, p)
    }

    private func arm(_ c: inout GraphicsContext, from s: CGPoint, to h: CGPoint, bend: CGFloat) {
        var a = Path()
        a.move(to: s)
        let mid = CGPoint(x: (s.x + h.x) / 2 + bend * 4, y: (s.y + h.y) / 2 + 3)
        a.addQuadCurve(to: h, control: mid)
        c.stroke(a, with: .color(Palette.flaskLine), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    }

    private func hand(_ c: inout GraphicsContext, _ h: CGPoint) {
        let r: CGFloat = 3.1
        let dot = Path(ellipseIn: CGRect(x: h.x - r, y: h.y - r, width: r * 2, height: r * 2))
        c.fill(dot, with: .color(Palette.flaskGlass))
        c.stroke(dot, with: .color(Palette.flaskLine), lineWidth: 1.6)
    }

    // MARK: Props

    private func heldProps(_ c: inout GraphicsContext, _ p: Pose) {
        let k = lp
        switch act {
        case .school:
            // Mortarboard on the rim, tassel swinging; a pencil in hand.
            var board = Path()
            board.move(to: CGPoint(x: 50, y: 6)); board.addLine(to: CGPoint(x: 70, y: 11))
            board.addLine(to: CGPoint(x: 50, y: 16)); board.addLine(to: CGPoint(x: 30, y: 11)); board.closeSubpath()
            c.fill(Path(roundedRect: CGRect(x: 40, y: 11, width: 20, height: 7), cornerRadius: 1.5), with: .color(Color(hex: 0x2F3440)))
            c.fill(board, with: .color(Color(hex: 0x3A4050)))
            c.stroke(board, with: .color(Palette.ink), lineWidth: 1)
            var tassel = Path()
            tassel.move(to: CGPoint(x: 50, y: 11))
            let swing = CGFloat(sin(t * 3)) * 4
            tassel.addQuadCurve(to: CGPoint(x: 66 + swing, y: 24), control: CGPoint(x: 64, y: 10))
            c.stroke(tassel, with: .color(Color(hex: 0xE8B53A)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            pencil(&c, at: p.right, angle: -0.9)
        case .ponder:
            pencil(&c, at: p.right, angle: -1.2)
        case .juggle:
            let colors: [UInt32] = [0xC8423B, 0x3E8C86, 0xE8B53A]
            for i in 0..<3 {
                let f = (k / act.loop + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let x = 50 + CGFloat(cos(f * 2 * .pi)) * 30
                let y = 30 - CGFloat(abs(sin(f * 2 * .pi))) * 34
                book(&c, at: CGPoint(x: x, y: y), angle: f * 6, color: RGB(colors[i]))
            }
        case .scroll:
            let half = scrollHalf
            let r = CGRect(x: 50 - half, y: 58, width: half * 2, height: 17)
            c.fill(Path(r), with: .color(Color(hex: 0xFBF6E6)))
            c.stroke(Path(r), with: .color(Palette.ink.opacity(0.7)), lineWidth: 0.9)
            var lines = Path()
            var y: CGFloat = 62
            while y < 73 { lines.move(to: CGPoint(x: r.minX + 3, y: y)); lines.addLine(to: CGPoint(x: r.maxX - 3, y: y)); y += 3.4 }
            c.stroke(lines, with: .color(Palette.ink.opacity(0.35)), lineWidth: 0.7)
            for x in [r.minX, r.maxX] {
                let roll = Path(roundedRect: CGRect(x: x - 2.5, y: 55, width: 5, height: 23), cornerRadius: 2.5)
                c.fill(roll, with: .color(Color(hex: 0xEFE3C2)))
                c.stroke(roll, with: .color(Palette.ink.opacity(0.7)), lineWidth: 0.9)
            }
        case .peer:
            // A magnifier held out toward the highlighted word.
            let h = p.left
            let lens = CGPoint(x: h.x - 13, y: h.y - 9)
            var handle = Path(); handle.move(to: h); handle.addLine(to: CGPoint(x: lens.x + 5, y: lens.y + 4))
            c.stroke(handle, with: .color(Color(hex: 0x6B4F33)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            let ring = Path(ellipseIn: CGRect(x: lens.x - 9, y: lens.y - 9, width: 18, height: 18))
            c.fill(ring, with: .color(Color(hex: 0xE4F6FF).opacity(0.55)))
            c.stroke(ring, with: .color(Palette.ink.opacity(0.85)), lineWidth: 1.8)
            var glint = Path(); glint.addArc(center: lens, radius: 5.5, startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
            c.stroke(glint, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        case .carry where k < 2.3:
            paperSheet(&c, center: CGPoint(x: 50, y: 0), w: 30, h: 22, tilt: 0.05 * sin(k * 9))
        default:
            break
        }
    }

    private func drawBackProps(_ ctx: inout GraphicsContext, _ p: Pose) {
        let k = lp
        let w = size.width
        // A pencil ground line, like the edge of the bench.
        var ground = Path()
        ground.move(to: CGPoint(x: 10 * u, y: groundY + 1))
        ground.addQuadCurve(to: CGPoint(x: w - 10 * u, y: groundY), control: CGPoint(x: w / 2, y: groundY + 3))
        ctx.stroke(ground, with: .color(Palette.pencil.opacity(0.55)), style: StrokeStyle(lineWidth: 1, lineCap: .round))

        switch act {
        case .knock:
            padlock(&ctx, at: CGPoint(x: w * 0.83, y: groundY - 66 * u), open: granted)
            if !granted && (abs(k - 0.48) < 0.25 || abs(k - 0.88) < 0.25) {
                label(&ctx, "knock", at: CGPoint(x: w * 0.8, y: groundY - 100 * u), color: Palette.pencil)
            }
        case .tap:
            let pressed = k > 1.05 && k < 1.45
            optionKey(&ctx, at: CGPoint(x: w * 0.19, y: groundY), pressed: pressed)
            // The island grows out of the top edge once the key goes down.
            let open = Keys.at(k, [(1.15, 0), (1.6, 1), (2.6, 1), (2.95, 0)])
            island(&ctx, open: CGFloat(open))
        case .peer:
            textScrap(&ctx, at: CGPoint(x: w * 0.04, y: groundY - 142 * u), k: k)
        case .carry:
            let grown = CGFloat(Keys.at(k, [(2.4, 0), (2.9, 1), (4.3, 1), (4.6, 0)]))
            sapling(&ctx, at: CGPoint(x: w * 0.86, y: groundY), grown: grown)
            if k >= 2.3 && k < 4.3 {
                // The paper, set down on the sapling's tip.
                let drop = CGFloat(Keys.smooth((k - 2.3) / 0.5))
                let from = CGPoint(x: p.x, y: groundY - 112 * u)
                let to = CGPoint(x: w * 0.86 + 10 * u, y: groundY - 88 * u)
                var c = ctx
                c.translateBy(x: from.x + (to.x - from.x) * drop, y: from.y + (to.y - from.y) * drop)
                c.scaleBy(x: u * (1 - 0.35 * drop), y: u * (1 - 0.35 * drop))
                paperSheet(&c, center: .zero, w: 30, h: 22, tilt: Double(drop) * -0.25)
            }
        case .flip:
            toggle(&ctx, at: CGPoint(x: w * 0.2, y: groundY), on: switchOn, k: k)
            if !research, abs(k - 0.56) < 0.2 || abs(k - 0.91) < 0.2 {
                label(&ctx, "tap", at: CGPoint(x: w * 0.2, y: groundY - 112 * u), color: Palette.pencil)
            }
        default:
            break
        }
    }

    private func drawFrontProps(_ ctx: inout GraphicsContext, _ p: Pose) {
        let k = lp
        let head = CGPoint(x: p.x, y: groundY + p.lift * u - 112 * u)
        switch act {
        case .wave where k > 0.25 && k < 2.5:
            label(&ctx, "hello!", at: CGPoint(x: head.x + 46 * u, y: head.y - 4 * u), color: Palette.red, size: 18)
        case .ponder:
            for i in 0..<3 {
                let f = (t * 0.45 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let a = 1 - f
                ctx.draw(Text("?").font(.fell(14 + 8 * CGFloat(f))).foregroundColor(Palette.ink.opacity(a * 0.8)),
                         at: CGPoint(x: head.x + (CGFloat(i) - 1) * 18 * u + CGFloat(sin(f * 6 + Double(i))) * 5 * u, y: head.y - CGFloat(f) * 40 * u))
            }
        case .peer where k > 1.8 && k < 3.5:
            // A little explanation card pops up beside the word.
            let a = Keys.smooth((k - 1.8) / 0.3) * (1 - Keys.smooth((k - 3.2) / 0.3))
            let r = CGRect(x: size.width * 0.04 + 52 * u, y: groundY - 180 * u, width: 92 * u, height: 34 * u)
            var c = ctx
            c.opacity = a
            c.fill(Path(roundedRect: r, cornerRadius: 4 * u), with: .color(Color(hex: 0xFFFDF6)))
            c.stroke(Path(roundedRect: r, cornerRadius: 4 * u), with: .color(Palette.ink.opacity(0.6)), lineWidth: 0.9)
            var lines = Path()
            for j in 0..<3 {
                let y = r.minY + (9 + CGFloat(j) * 8) * u
                lines.move(to: CGPoint(x: r.minX + 7 * u, y: y)); lines.addLine(to: CGPoint(x: r.maxX - (j == 2 ? 30 : 8) * u, y: y))
            }
            c.stroke(lines, with: .color(Palette.ink.opacity(0.45)), lineWidth: 1.1)
        case .flip where research || switchOn:
            for i in 0..<4 {
                let a = Double(i) / 4 * 2 * .pi + t * 1.5
                let r = 58 * u + CGFloat(sin(t * 3 + Double(i))) * 4 * u
                sparkle(&ctx, at: CGPoint(x: head.x + CGFloat(cos(a)) * r, y: head.y + 40 * u + CGFloat(sin(a)) * r * 0.8), s: 4 * u)
            }
        case .knock where granted:
            for i in 0..<3 {
                sparkle(&ctx, at: CGPoint(x: size.width * 0.82 + CGFloat(i - 1) * 18 * u, y: groundY - 100 * u - CGFloat(i % 2) * 10 * u), s: 4 * u)
            }
        default:
            break
        }
    }

    // MARK: Prop pieces

    private func label(_ ctx: inout GraphicsContext, _ s: String, at p: CGPoint, color: Color, size: CGFloat = 15) {
        ctx.draw(Text(s).font(.hand(size * max(0.8, u))).foregroundColor(color), at: p)
    }

    private func pencil(_ c: inout GraphicsContext, at h: CGPoint, angle: Double) {
        var g = c
        g.translateBy(x: h.x, y: h.y)
        g.rotate(by: .radians(angle))
        g.fill(Path(CGRect(x: -2, y: -16, width: 4, height: 18)), with: .color(Color(hex: 0xE8B53A)))
        var tip = Path(); tip.move(to: CGPoint(x: -2, y: -16)); tip.addLine(to: CGPoint(x: 0, y: -22)); tip.addLine(to: CGPoint(x: 2, y: -16)); tip.closeSubpath()
        g.fill(tip, with: .color(Color(hex: 0xEAD7B0)))
        g.stroke(Path(CGRect(x: -2, y: -16, width: 4, height: 18)), with: .color(Palette.ink.opacity(0.7)), lineWidth: 0.7)
        g.fill(Path(CGRect(x: -2, y: 1, width: 4, height: 3)), with: .color(Color(hex: 0xE89AB0)))
    }

    private func book(_ c: inout GraphicsContext, at p: CGPoint, angle: Double, color: RGB) {
        var g = c
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(angle))
        let r = CGRect(x: -6, y: -4.5, width: 12, height: 9)
        g.fill(Path(roundedRect: r, cornerRadius: 1), with: .color(color.color()))
        g.fill(Path(CGRect(x: -6, y: -4.5, width: 2.2, height: 9)), with: .color(color.shade.color()))
        g.stroke(Path(roundedRect: r, cornerRadius: 1), with: .color(Palette.ink.opacity(0.7)), lineWidth: 0.8)
    }

    private func paperSheet(_ c: inout GraphicsContext, center: CGPoint, w: CGFloat, h: CGFloat, tilt: Double) {
        var g = c
        g.translateBy(x: center.x, y: center.y)
        g.rotate(by: .radians(tilt))
        let r = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        g.fill(Path(r), with: .color(Color(hex: 0xFFFDF6)))
        g.stroke(Path(r), with: .color(Palette.ink.opacity(0.75)), lineWidth: 0.9)
        var lines = Path()
        lines.move(to: CGPoint(x: r.minX + 4, y: r.minY + 5)); lines.addLine(to: CGPoint(x: r.maxX - 9, y: r.minY + 5))
        for j in 0..<3 {
            let y = r.minY + 10 + CGFloat(j) * 3.6
            lines.move(to: CGPoint(x: r.minX + 4, y: y)); lines.addLine(to: CGPoint(x: r.maxX - 4, y: y))
        }
        g.stroke(lines, with: .color(Palette.ink.opacity(0.4)), lineWidth: 0.8)
    }

    private func optionKey(_ ctx: inout GraphicsContext, at base: CGPoint, pressed: Bool) {
        let kw = 70 * u, kh = 44 * u
        let down: CGFloat = pressed ? 4 * u : 0
        let body = CGRect(x: base.x - kw / 2, y: base.y - kh, width: kw, height: kh)
        ctx.fill(Path(roundedRect: body.offsetBy(dx: 0, dy: 3 * u), cornerRadius: 7 * u), with: .color(Palette.ink.opacity(0.25)))
        let top = body.offsetBy(dx: 0, dy: down)
        ctx.fill(Path(roundedRect: top, cornerRadius: 7 * u), with: .color(Color(hex: 0xFBF8EE)))
        ctx.stroke(Path(roundedRect: top, cornerRadius: 7 * u), with: .color(Palette.ink.opacity(0.8)), lineWidth: 1.2)
        ctx.draw(Text("\u{2325}").font(.system(size: 15 * u)).foregroundColor(Palette.ink), at: CGPoint(x: top.maxX - 13 * u, y: top.minY + 12 * u))
        ctx.draw(Text("option").font(.typewriter(10 * u)).foregroundColor(Palette.ink2), at: CGPoint(x: top.midX, y: top.maxY - 11 * u))
        ctx.draw(Text("right").font(.hand(12 * u)).foregroundColor(Palette.red), at: CGPoint(x: top.midX, y: top.minY - 10 * u))
    }

    private func island(_ ctx: inout GraphicsContext, open: CGFloat) {
        let w = (46 + 110 * open) * u, h = (13 + 34 * open) * u
        // A pencil sketch of the top of a screen, so the island has somewhere to hang from.
        let top = groundY - 206 * u
        let screen = CGRect(x: size.width * 0.12, y: top, width: size.width * 0.76, height: 58 * u)
        var bezel = Path()
        bezel.move(to: CGPoint(x: screen.minX, y: screen.maxY))
        bezel.addLine(to: CGPoint(x: screen.minX, y: screen.minY + 6 * u))
        bezel.addQuadCurve(to: CGPoint(x: screen.minX + 6 * u, y: screen.minY), control: CGPoint(x: screen.minX, y: screen.minY))
        bezel.addLine(to: CGPoint(x: screen.maxX - 6 * u, y: screen.minY))
        bezel.addQuadCurve(to: CGPoint(x: screen.maxX, y: screen.minY + 6 * u), control: CGPoint(x: screen.maxX, y: screen.minY))
        bezel.addLine(to: CGPoint(x: screen.maxX, y: screen.maxY))
        ctx.stroke(bezel, with: .color(Palette.ink.opacity(0.4)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [5 * u, 3 * u]))
        label(&ctx, "your screen", at: CGPoint(x: screen.maxX - 26 * u, y: screen.minY - 8 * u), color: Palette.pencil)
        let r = CGRect(x: size.width / 2 - w / 2, y: top, width: w, height: h)
        ctx.fill(Path(roundedRect: r, cornerRadius: min(h / 2, 10 * u)), with: .color(.black))
        if open > 0.6 {
            var c = ctx
            c.opacity = Double((open - 0.6) / 0.4)
            // Three tiny trees inside the island.
            for i in 0..<3 {
                let x = r.minX + r.width * (0.3 + 0.2 * CGFloat(i))
                var stem = Path(); stem.move(to: CGPoint(x: x, y: r.maxY - 8 * u)); stem.addLine(to: CGPoint(x: x, y: r.maxY - 20 * u))
                c.stroke(stem, with: .color(Color(hex: 0xC9B48A)), lineWidth: 1.2)
                c.fill(Path(ellipseIn: CGRect(x: x - 6 * u, y: r.maxY - 30 * u, width: 12 * u, height: 12 * u)), with: .color(Palette.flaskLiquid.opacity(0.9)))
            }
        }
    }

    private func textScrap(_ ctx: inout GraphicsContext, at o: CGPoint, k: Double) {
        let r = CGRect(x: o.x, y: o.y, width: 82 * u, height: 124 * u)
        ctx.fill(Path(r), with: .color(Color(hex: 0xFFFDF6)))
        ctx.stroke(Path(r), with: .color(Palette.ink.opacity(0.35)), lineWidth: 0.8)
        // The sweep of a highlighter over one phrase.
        let hl = CGFloat(Keys.at(k, [(0.4, 0), (1.4, 1), (3.5, 1), (3.8, 0)]))
        let marked = r.minY + 96 * u
        ctx.fill(Path(CGRect(x: r.minX + 10 * u, y: marked - 5 * u, width: 52 * u * hl, height: 10 * u)), with: .color(Palette.marker.opacity(0.85)))
        var lines = Path()
        for j in 0..<7 {
            let y = r.minY + (16 + CGFloat(j) * 16) * u
            lines.move(to: CGPoint(x: r.minX + 10 * u, y: y))
            lines.addLine(to: CGPoint(x: r.maxX - (j % 3 == 2 ? 26 : 10) * u, y: y))
        }
        ctx.stroke(lines, with: .color(Palette.ink.opacity(0.55)), lineWidth: 1.3)
    }

    private func sapling(_ ctx: inout GraphicsContext, at base: CGPoint, grown: CGFloat) {
        let h = (70 + 18 * grown) * u
        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: CGPoint(x: base.x + 6 * u, y: base.y - h), control: CGPoint(x: base.x - 8 * u, y: base.y - h * 0.5))
        ctx.stroke(stem, with: .color(Color(hex: 0x6E553F)), style: StrokeStyle(lineWidth: 3 * u, lineCap: .round))
        let leaves: [(CGFloat, Double, CGFloat)] = [(0.45, -2.4, 1), (0.62, -0.7, 1), (0.8, -2.2, 0.9), (0.95, -0.9, grown)]
        for (f, a, s) in leaves where s > 0.02 {
            let p = CGPoint(x: base.x - 2 * u + 6 * u * f, y: base.y - h * f)
            let path = Pen.leaf(at: p, angle: a, length: 22 * u * s, width: 0.4)
            ctx.fill(path, with: .color(Color(hex: 0x7F9C6B)))
            ctx.stroke(path, with: .color(Palette.ink.opacity(0.6)), lineWidth: 0.8)
        }
        // Mound of earth.
        var mound = Path()
        mound.move(to: CGPoint(x: base.x - 24 * u, y: base.y))
        mound.addQuadCurve(to: CGPoint(x: base.x + 24 * u, y: base.y), control: CGPoint(x: base.x, y: base.y - 12 * u))
        ctx.fill(mound, with: .color(Color(hex: 0xA08B66).opacity(0.5)))
    }

    private func padlock(_ ctx: inout GraphicsContext, at c: CGPoint, open: Bool) {
        let w = 36 * u, h = 30 * u
        let body = CGRect(x: c.x - w / 2, y: c.y, width: w, height: h)
        var shackle = Path()
        let lift: CGFloat = open ? 10 * u : 0
        shackle.move(to: CGPoint(x: body.minX + 7 * u, y: body.minY))
        shackle.addLine(to: CGPoint(x: body.minX + 7 * u, y: body.minY - 10 * u - lift))
        shackle.addArc(center: CGPoint(x: c.x, y: body.minY - 10 * u - lift), radius: w / 2 - 7 * u, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        shackle.addLine(to: CGPoint(x: body.maxX - 7 * u, y: body.minY - (open ? lift - 2 * u : 0)))
        ctx.stroke(shackle, with: .color(Color(hex: 0x8A8F96)), style: StrokeStyle(lineWidth: 4 * u, lineCap: .round))
        ctx.fill(Path(roundedRect: body, cornerRadius: 4 * u), with: .color(open ? Palette.green.opacity(0.85) : Color(hex: 0xC79A3A)))
        ctx.stroke(Path(roundedRect: body, cornerRadius: 4 * u), with: .color(Palette.ink.opacity(0.8)), lineWidth: 1.1)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3 * u, y: body.minY + 9 * u, width: 6 * u, height: 6 * u)), with: .color(Palette.ink.opacity(0.8)))
    }

    private func toggle(_ ctx: inout GraphicsContext, at base: CGPoint, on: Bool, k: Double) {
        var post = Path(); post.move(to: base); post.addLine(to: CGPoint(x: base.x, y: base.y - 60 * u))
        ctx.stroke(post, with: .color(Color(hex: 0x6E553F)), style: StrokeStyle(lineWidth: 3 * u, lineCap: .round))
        let plate = CGRect(x: base.x - 26 * u, y: base.y - 96 * u, width: 52 * u, height: 38 * u)
        ctx.fill(Path(roundedRect: plate, cornerRadius: 5 * u), with: .color(Color(hex: 0xFBF8EE)))
        ctx.stroke(Path(roundedRect: plate, cornerRadius: 5 * u), with: .color(Palette.ink.opacity(0.8)), lineWidth: 1.1)
        let track = CGRect(x: plate.minX + 8 * u, y: plate.midY - 8 * u, width: 36 * u, height: 16 * u)
        ctx.fill(Path(roundedRect: track, cornerRadius: 8 * u), with: .color(on ? Palette.green : Palette.pencil.opacity(0.35)))
        ctx.stroke(Path(roundedRect: track, cornerRadius: 8 * u), with: .color(Palette.ink.opacity(0.6)), lineWidth: 0.9)
        let x = on ? track.maxX - 8 * u : track.minX + 8 * u
        let knob = Path(ellipseIn: CGRect(x: x - 7 * u, y: track.midY - 7 * u, width: 14 * u, height: 14 * u))
        ctx.fill(knob, with: .color(.white))
        ctx.stroke(knob, with: .color(Palette.ink.opacity(0.7)), lineWidth: 0.9)
        ctx.draw(Text("research").font(.typewriter(9 * u)).foregroundColor(Palette.ink2), at: CGPoint(x: plate.midX, y: plate.minY - 8 * u))
    }

    private func sparkle(_ ctx: inout GraphicsContext, at p: CGPoint, s: CGFloat) {
        var star = Path()
        star.move(to: CGPoint(x: p.x, y: p.y - s * 2)); star.addLine(to: CGPoint(x: p.x, y: p.y + s * 2))
        star.move(to: CGPoint(x: p.x - s * 2, y: p.y)); star.addLine(to: CGPoint(x: p.x + s * 2, y: p.y))
        ctx.stroke(star, with: .color(Color(hex: 0xE8B53A)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }
}
