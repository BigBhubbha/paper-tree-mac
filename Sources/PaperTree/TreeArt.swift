// Drawing the trees. Every tree is laid out from its own seed and its papers, then drawn in ink
// and watercolor wash in the style of its species. Nothing here is an image file: it is all strokes.
//
// Layout: each paper is a branch. The first paper is the leader at the top of the trunk; later
// papers grow as limbs off the trunk, or off the branch of the paper they build on. Suggestions
// are pencil branches sprouting from the paper they came from.
import SwiftUI

// MARK: Randomness you can repeat

struct SeededRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    init(_ seed: UInt64, _ salt: String) {
        var h: UInt64 = 1469598103934665603
        for b in salt.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        self.init(seed ^ h)
    }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
    mutating func cg(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat(range(Double(a), Double(b))) }
    mutating func sign() -> CGFloat { next() < 0.5 ? -1 : 1 }
}

// MARK: Palette for plants

enum PlantInk {
    static func tone(_ name: String) -> Color {
        switch name {
        case "moss": return Color(hex: 0x5E7A3A)
        case "olive": return Color(hex: 0x8A8A3E)
        case "rust": return Color(hex: 0xB5653A)
        case "plum": return Color(hex: 0x7D4E6E)
        case "teal": return Color(hex: 0x3E8C86)
        case "ochre": return Color(hex: 0xC79A3A)
        default: return Color(hex: 0x7F9C6B) // sage
        }
    }
    static func bark(_ s: Species, tone: Color) -> Color {
        switch s {
        case .alien: return Color(hex: 0x56656B)
        case .coral: return tone
        case .flytrap: return Color(hex: 0x6F8A45)
        case .conifer: return Color(hex: 0x5E4632)
        default: return Color(hex: 0x6E553F)
        }
    }
    static let ink = Color(hex: 0x24211B)
    static let pencil = Color(hex: 0x8F887B)
}

// MARK: Geometry

struct TreeGeometry {
    struct Limb {
        var points: [CGPoint]
        var w0: CGFloat
        var w1: CGFloat
        var depth: Int
    }
    struct Tip { var id: String; var point: CGPoint; var angle: Double }
    struct Ghost { var id: String; var from: CGPoint; var control: CGPoint; var to: CGPoint }

    var limbs: [Limb] = []
    var twigs: [Limb] = []
    var tips: [Tip] = []
    var ghosts: [Ghost] = []
    var base: CGPoint = .zero
    var height: CGFloat = 0
    var growth: CGFloat = 0     // 0 = seed, 1 = enormous
    var cardSize = CGSize(width: 40, height: 52)

    /// How tall the tree is, as a share of the space, for a number of papers: a sapling at one, huge by twenty.
    static func growth(papers n: Int) -> CGFloat {
        n == 0 ? 0 : CGFloat(1 - exp(-Double(n) / 6.5))
    }

    static func make(_ tree: PaperTreeData, in size: CGSize) -> TreeGeometry {
        var g = TreeGeometry()
        var rnd = SeededRandom(tree.seed, "layout")
        let species = tree.look.species
        let n = tree.papers.count
        let stage = growth(papers: n)
        g.growth = stage
        let ground: CGFloat = max(22, size.height * 0.07)
        g.base = CGPoint(x: size.width * 0.5 + rnd.cg(-0.03, 0.03) * size.width, y: size.height - ground)
        let usable = size.height - ground - size.height * 0.06
        g.height = usable * (0.24 + 0.74 * stage)
        let card = max(20, min(58, min(size.width, size.height) * 0.075)) * (0.75 + 0.25 * stage)
        g.cardSize = CGSize(width: card, height: card * 1.3)
        guard n > 0 else { return g }

        let H = g.height
        let twist = CGFloat(tree.look.twist)
        let fromBase = species == .flytrap || species == .coral

        // The trunk (or, for a flytrap or coral, nothing but a crown at the base).
        var trunk: [CGPoint] = []
        if !fromBase {
            let steps = 9
            let sway: CGFloat = species == .alien ? (0.06 + 0.1 * twist) * H : 0.025 * H
            let phase = rnd.range(0, .pi * 2)
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let bend = sin(Double(t) * .pi * (species == .alien ? 2.2 : 1.1) + phase)
                let x = g.base.x + CGFloat(bend) * sway * t + rnd.cg(-1.5, 1.5)
                trunk.append(CGPoint(x: x, y: g.base.y - H * t))
            }
            let baseW = (species == .conifer ? 7 : 9) + (species == .conifer ? 20 : 34) * stage
            g.limbs.append(Limb(points: trunk, w0: baseW, w1: max(1.6, baseW * 0.14), depth: 0))
        }

        // Papers, oldest first. Roots grow from the trunk (or the crown); others from their parent.
        let papers = tree.papers.sorted { $0.addedAt < $1.addedAt }
        let ids = Set(papers.map(\.id))
        let roots = papers.filter { $0.parentId == nil || !ids.contains($0.parentId!) }
        var tipOf: [String: TreeGeometry.Tip] = [:]
        var lengthOf: [String: CGFloat] = [:]

        for (j, p) in roots.enumerated() {
            if !fromBase && j == 0 {
                // The first paper sits at the very top: the trunk is its branch.
                let top = trunk.last!
                let angle = atan2(Double(top.y - trunk[trunk.count - 2].y), Double(top.x - trunk[trunk.count - 2].x))
                tipOf[p.id] = Tip(id: p.id, point: top, angle: angle)
                lengthOf[p.id] = H * 0.4
                continue
            }
            let k = fromBase ? roots.count : max(1, roots.count - 1)
            let jj = fromBase ? j : j - 1
            var start: CGPoint
            var angleFromUp: Double
            var length: CGFloat
            let side: CGFloat = jj % 2 == 0 ? -1 : 1
            if fromBase {
                let spread = species == .flytrap ? 1.25 : 1.05
                let u = k == 1 ? 0.0 : (Double(jj) / Double(k - 1) - 0.5) * 2 // -1...1
                angleFromUp = u * spread + rnd.range(-0.08, 0.08)
                start = CGPoint(x: g.base.x + CGFloat(u) * 6, y: g.base.y - 2)
                length = H * CGFloat(species == .flytrap ? (1.0 - 0.38 * abs(u)) : (0.92 - 0.3 * abs(u))) * rnd.cg(0.88, 1.04)
            } else {
                let t = k == 1 ? 0.55 : 0.3 + 0.58 * Double(jj) / Double(k - 1)
                start = point(on: trunk, at: CGFloat(t))
                switch species {
                case .conifer:
                    angleFromUp = Double(side) * rnd.range(1.25, 1.45)
                    length = H * CGFloat(0.5 * (1 - t) + 0.1)
                case .willow:
                    angleFromUp = Double(side) * rnd.range(0.7, 1.0)
                    length = H * CGFloat(0.42 - 0.12 * t)
                case .alien:
                    angleFromUp = Double(side) * rnd.range(0.55, 1.15)
                    length = H * CGFloat(0.46 - 0.16 * t)
                default:
                    angleFromUp = Double(side) * rnd.range(0.75, 1.15)
                    length = H * CGFloat(0.5 - 0.2 * t)
                }
                length *= rnd.cg(0.85, 1.1)
            }
            let (limb, tip) = TreeGeometry.grow(from: start, angleFromUp: angleFromUp, length: length,
                                   width: max(2.4, (fromBase ? 5 : 4) + 14 * stage * (fromBase ? 0.6 : 1) * CGFloat(1 - Double(jj) / Double(max(k, 1)) * 0.4)),
                                   species: species, twist: twist, droop: CGFloat(tree.look.droop), rnd: &rnd, depth: 1)
            g.limbs.append(limb)
            tipOf[p.id] = Tip(id: p.id, point: tip.point, angle: tip.angle)
            lengthOf[p.id] = length
        }

        // Children: branch off the parent's tip, alternating sides.
        var childCount: [String: Int] = [:]
        var pending = papers.filter { tipOf[$0.id] == nil }
        var guardLoops = 0
        while !pending.isEmpty && guardLoops < 10 {
            guardLoops += 1
            for p in pending {
                guard let parentId = p.parentId, let parent = tipOf[parentId] else { continue }
                let c = childCount[parentId, default: 0]
                childCount[parentId] = c + 1
                let side: Double = c % 2 == 0 ? 1 : -1
                let parentUp = parent.angle + .pi / 2 // angle from straight up
                let a = parentUp + side * rnd.range(0.4, 0.75)
                let len = (lengthOf[parentId] ?? H * 0.3) * rnd.cg(0.55, 0.7)
                let back = (lengthOf[parentId] ?? H * 0.3) * 0.22
                let start = CGPoint(x: parent.point.x - CGFloat(cos(parent.angle)) * back,
                                    y: parent.point.y - CGFloat(sin(parent.angle)) * back)
                let (limb, tip) = TreeGeometry.grow(from: start, angleFromUp: a, length: len, width: max(1.8, 3 + 6 * stage),
                                       species: species, twist: twist, droop: CGFloat(tree.look.droop), rnd: &rnd, depth: 2)
                g.limbs.append(limb)
                tipOf[p.id] = Tip(id: p.id, point: tip.point, angle: tip.angle)
                lengthOf[p.id] = len
            }
            pending = pending.filter { tipOf[$0.id] == nil }
        }
        g.tips = papers.compactMap { tipOf[$0.id] }

        // Small twigs for fullness: more as the tree grows.
        var twigRnd = SeededRandom(tree.seed, "twigs")
        let perLimb = species == .coral ? 3 : 2
        for limb in g.limbs where limb.points.count > 3 {
            let count = Int((CGFloat(perLimb) * (0.5 + stage)).rounded())
            for _ in 0..<count {
                let t = twigRnd.cg(0.35, 0.85)
                let at = point(on: limb.points, at: t)
                let dir = direction(on: limb.points, at: t)
                let a = atan2(Double(dir.dy), Double(dir.dx)) + .pi / 2 + Double(twigRnd.sign()) * twigRnd.range(0.5, 0.9)
                let len = pathLength(limb.points) * twigRnd.cg(0.16, 0.3)
                let (twig, _) = TreeGeometry.grow(from: at, angleFromUp: a, length: len, width: max(1, limb.w1 * 1.2),
                                                  species: species, twist: twist, droop: CGFloat(tree.look.droop), rnd: &twigRnd, depth: 3)
                g.twigs.append(twig)
            }
        }

        // Suggestions: a pencil branch out of the paper they bounce off.
        for s in tree.suggestions {
            var r = SeededRandom(tree.seed, s.id)
            let from = tipOf[s.fromPaperId] ?? g.tips.last ?? Tip(id: "", point: CGPoint(x: g.base.x, y: g.base.y - H), angle: -.pi / 2)
            let up = from.angle + .pi / 2
            let a = up + Double(r.sign()) * r.range(0.55, 1.0)
            let len = max(g.cardSize.height * 1.4, H * r.cg(0.2, 0.3))
            let to = CGPoint(x: from.point.x + CGFloat(sin(a)) * len, y: from.point.y - CGFloat(cos(a)) * len)
            let mid = CGPoint(x: (from.point.x + to.x) / 2, y: (from.point.y + to.y) / 2)
            let control = CGPoint(x: mid.x + r.cg(-0.2, 0.2) * len, y: mid.y - r.cg(0.05, 0.25) * len)
            g.ghosts.append(Ghost(id: s.id, from: from.point, control: control, to: to))
        }
        g.fit(in: size)
        return g
    }

    /// Shrinks the whole drawing about its base (and slides it sideways) so every branch, leaf
    /// cloud, paper and pencil branch stays on the sheet. Big trees get denser, not cut off.
    private mutating func fit(in size: CGSize) {
        let pad = max(8, cardSize.width * 0.25)
        let leaf = cardSize.height * 1.15   // foliage and the card that hangs off a tip
        var minX = base.x, maxX = base.x, minY = base.y
        func take(_ p: CGPoint, _ r: CGFloat) {
            minX = min(minX, p.x - r); maxX = max(maxX, p.x + r); minY = min(minY, p.y - r)
        }
        for l in limbs { for p in l.points { take(p, l.w0) } }
        for l in twigs { for p in l.points { take(p, leaf * 0.5) } }
        for t in tips { take(t.point, leaf) }
        for gh in ghosts { take(gh.to, cardSize.height * 0.9); take(gh.control, 0) }
        let availW = size.width - pad * 2, availH = base.y - pad
        let s = min(1, availW / max(1, maxX - minX), availH / max(1, base.y - minY))
        let left = base.x + (minX - base.x) * s, right = base.x + (maxX - base.x) * s
        var dx: CGFloat = 0
        if left < pad { dx = pad - left } else if right > size.width - pad { dx = size.width - pad - right }
        guard s < 0.999 || abs(dx) > 0.5 else { return }
        let b = base
        func m(_ p: CGPoint) -> CGPoint { CGPoint(x: b.x + (p.x - b.x) * s + dx, y: b.y + (p.y - b.y) * s) }
        func ml(_ l: Limb) -> Limb { Limb(points: l.points.map(m), w0: l.w0 * s, w1: l.w1 * s, depth: l.depth) }
        limbs = limbs.map(ml)
        twigs = twigs.map(ml)
        tips = tips.map { Tip(id: $0.id, point: m($0.point), angle: $0.angle) }
        ghosts = ghosts.map { Ghost(id: $0.id, from: m($0.from), control: m($0.control), to: m($0.to)) }
        base = CGPoint(x: base.x + dx, y: base.y)
        height *= s
        let c = max(0.7, s.squareRoot())
        cardSize = CGSize(width: cardSize.width * c, height: cardSize.height * c)
    }

    /// One branch: a gently bending curve from `start`, with species habits (droop, curl, kinks).
    static func grow(from start: CGPoint, angleFromUp: Double, length: CGFloat, width: CGFloat, species: Species,
                     twist: CGFloat, droop: CGFloat, rnd: inout SeededRandom, depth: Int) -> (Limb, Tip) {
        var pts: [CGPoint] = [start]
        let steps = 8
        var a = angleFromUp
        var p = start
        let seg = length / CGFloat(steps)
        let curl = species == .alien ? Double(twist) * 0.16 * (angleFromUp >= 0 ? 1 : -1) : 0
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            switch species {
            case .willow: a += (angleFromUp >= 0 ? 1 : -1) * (0.05 + 0.12 * Double(droop)) * t * 2.2
            case .conifer: a += (angleFromUp >= 0 ? 1 : -1) * 0.025
            case .oak: a += rnd.range(-0.22, 0.22)
            case .alien: a += curl * (1 + t * 2)
            case .flytrap: a += (angleFromUp >= 0 ? 1 : -1) * 0.03
            case .coral: a += rnd.range(-0.12, 0.12)
            }
            p = CGPoint(x: p.x + CGFloat(sin(a)) * seg + rnd.cg(-0.6, 0.6), y: p.y - CGFloat(cos(a)) * seg + rnd.cg(-0.6, 0.6))
            pts.append(p)
        }
        let last = pts[pts.count - 1], prev = pts[pts.count - 2]
        let tipAngle = atan2(Double(last.y - prev.y), Double(last.x - prev.x))
        let limb = Limb(points: pts, w0: width, w1: max(0.9, width * (species == .coral ? 0.55 : 0.25)), depth: depth)
        return (limb, Tip(id: "", point: last, angle: tipAngle))
    }

    static func point(on pts: [CGPoint], at t: CGFloat) -> CGPoint {
        guard pts.count > 1 else { return pts.first ?? .zero }
        let f = max(0, min(1, t)) * CGFloat(pts.count - 1)
        let i = min(pts.count - 2, Int(f))
        let r = f - CGFloat(i)
        return CGPoint(x: pts[i].x + (pts[i + 1].x - pts[i].x) * r, y: pts[i].y + (pts[i + 1].y - pts[i].y) * r)
    }

    static func direction(on pts: [CGPoint], at t: CGFloat) -> CGVector {
        guard pts.count > 1 else { return CGVector(dx: 0, dy: -1) }
        let f = max(0, min(1, t)) * CGFloat(pts.count - 1)
        let i = min(pts.count - 2, Int(f))
        return CGVector(dx: pts[i + 1].x - pts[i].x, dy: pts[i + 1].y - pts[i].y)
    }

    static func pathLength(_ pts: [CGPoint]) -> CGFloat {
        zip(pts, pts.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }
}

// MARK: Pen work

enum Pen {
    /// A smooth path through points (midpoint curves), the way a hand draws a line.
    static func smooth(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        if pts.count == 2 { p.addLine(to: pts[1]); return p }
        for i in 1..<(pts.count - 1) {
            let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            p.addQuadCurve(to: mid, control: pts[i])
        }
        p.addLine(to: pts[pts.count - 1])
        return p
    }

    /// The outline of a branch that tapers from w0 to w1, with a slightly uneven edge.
    static func taper(_ pts: [CGPoint], _ w0: CGFloat, _ w1: CGFloat, rnd: inout SeededRandom) -> (Path, [CGPoint], [CGPoint]) {
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in pts.indices {
            let a = pts[max(0, i - 1)], b = pts[min(pts.count - 1, i + 1)]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(0.001, hypot(dx, dy))
            let nx = -dy / len, ny = dx / len
            let t = CGFloat(i) / CGFloat(max(1, pts.count - 1))
            let w = (w0 + (w1 - w0) * pow(t, 0.8)) / 2 * rnd.cg(0.93, 1.07)
            left.append(CGPoint(x: pts[i].x + nx * w, y: pts[i].y + ny * w))
            right.append(CGPoint(x: pts[i].x - nx * w, y: pts[i].y - ny * w))
        }
        var path = smooth(left)
        let back = smooth(right.reversed())
        path.addPath(back)
        var shape = Path()
        shape.move(to: left[0])
        for pt in left.dropFirst() { shape.addLine(to: pt) }
        for pt in right.reversed() { shape.addLine(to: pt) }
        shape.closeSubpath()
        return (shape, left, right)
    }

    /// Strokes a path twice, a hair apart, so it reads as ink rather than vector.
    static func ink(_ ctx: inout GraphicsContext, _ path: Path, color: Color, width: CGFloat, rough: CGFloat = 0.6) {
        ctx.stroke(path, with: .color(color.opacity(0.92)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        var copy = ctx
        copy.translateBy(x: rough * 0.7, y: -rough * 0.5)
        copy.stroke(path, with: .color(color.opacity(0.35)), style: StrokeStyle(lineWidth: max(0.5, width * 0.55), lineCap: .round, lineJoin: .round))
    }

    /// A scalloped leaf mass: a circle with soft bumps, like a pen-drawn canopy.
    static func cloud(center c: CGPoint, radius r: CGFloat, bumps: Int, rnd: inout SeededRandom) -> Path {
        var pts: [CGPoint] = []
        let phase = rnd.range(0, .pi * 2)
        let total = bumps * 4
        for i in 0...total {
            let t = Double(i) / Double(total) * .pi * 2 + phase
            let bump = 1 + 0.12 * abs(sin(Double(bumps) * (t - phase) / 2))
            let rr = r * CGFloat(bump) * rnd.cg(0.97, 1.03)
            pts.append(CGPoint(x: c.x + CGFloat(cos(t)) * rr, y: c.y + CGFloat(sin(t)) * rr * 0.86))
        }
        var p = smooth(pts)
        p.closeSubpath()
        return p
    }
}

// MARK: The drawing

struct TreeDrawing: View {
    var tree: PaperTreeData
    var geometry: TreeGeometry
    /// Smaller trees in the grove skip the finest detail.
    var detail: CGFloat = 1

    var body: some View {
        Canvas { ctx, size in
            draw(&ctx, size)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let g = geometry
        let tone = PlantInk.tone(tree.look.leafTone)
        let bark = PlantInk.bark(tree.look.species, tone: tone)
        var rnd = SeededRandom(tree.seed, "ink")
        let lw: CGFloat = max(0.7, min(1.4, g.height / 260))

        drawGround(&ctx, size, rnd: &rnd, lw: lw)
        if tree.papers.isEmpty { drawSeed(&ctx, g, lw: lw); return }

        // Back leaves first, so limbs sit in front of some of them.
        if tree.look.species == .oak || tree.look.species == .conifer { foliage(&ctx, g, tone: tone, back: true, rnd: &rnd, lw: lw) }

        // Ghost branches sit behind the real ones.
        for ghost in g.ghosts { drawGhost(&ctx, ghost, lw: lw, rnd: &rnd) }

        for limb in g.limbs + g.twigs { drawLimb(&ctx, limb, bark: bark, lw: lw, rnd: &rnd) }
        if tree.look.species != .flytrap && tree.look.species != .coral { drawRoots(&ctx, g, bark: bark, lw: lw, rnd: &rnd) }

        foliage(&ctx, g, tone: tone, back: false, rnd: &rnd, lw: lw)
    }

    // MARK: Ground, seed

    private func drawGround(_ ctx: inout GraphicsContext, _ size: CGSize, rnd: inout SeededRandom, lw: CGFloat) {
        let y = geometry.base.y
        let half = max(60, geometry.height * 0.55 + 40)
        var pts: [CGPoint] = []
        var x = geometry.base.x - half
        while x <= geometry.base.x + half {
            pts.append(CGPoint(x: x, y: y + rnd.cg(-1.2, 1.2)))
            x += 14
        }
        Pen.ink(&ctx, Pen.smooth(pts), color: PlantInk.ink.opacity(0.7), width: lw * 0.9)
        // Soil hatching under the line.
        var hatch = Path()
        var hx = geometry.base.x - half * 0.8
        while hx < geometry.base.x + half * 0.8 {
            let len = rnd.cg(4, 9)
            hatch.move(to: CGPoint(x: hx, y: y + 4 + rnd.cg(0, 3)))
            hatch.addLine(to: CGPoint(x: hx - len * 0.6, y: y + 4 + len))
            hx += rnd.cg(7, 13)
        }
        ctx.stroke(hatch, with: .color(PlantInk.ink.opacity(0.25)), lineWidth: lw * 0.6)
        // Grass ticks.
        var grass = Path()
        for _ in 0..<Int(half / 9) {
            let gx = geometry.base.x + rnd.cg(-half, half)
            let h = rnd.cg(3, 8)
            grass.move(to: CGPoint(x: gx, y: y))
            grass.addLine(to: CGPoint(x: gx + rnd.cg(-2, 2), y: y - h))
        }
        ctx.stroke(grass, with: .color(Color(hex: 0x506B39).opacity(0.55)), lineWidth: lw * 0.7)
    }

    private func drawSeed(_ ctx: inout GraphicsContext, _ g: TreeGeometry, lw: CGFloat) {
        let c = CGPoint(x: g.base.x, y: g.base.y + 10)
        let seed = Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 4.5, width: 14, height: 9))
        ctx.fill(seed, with: .color(Color(hex: 0x8B6B47).opacity(0.5)))
        Pen.ink(&ctx, seed, color: PlantInk.ink, width: lw)
        var dash = Path()
        dash.move(to: CGPoint(x: c.x, y: c.y - 6))
        dash.addQuadCurve(to: CGPoint(x: c.x + 4, y: c.y - 34), control: CGPoint(x: c.x - 6, y: c.y - 20))
        ctx.stroke(dash, with: .color(PlantInk.pencil), style: StrokeStyle(lineWidth: lw, lineCap: .round, dash: [3, 4]))
    }

    // MARK: Wood

    private func drawLimb(_ ctx: inout GraphicsContext, _ limb: TreeGeometry.Limb, bark: Color, lw: CGFloat, rnd: inout SeededRandom) {
        let (shape, _, right) = Pen.taper(limb.points, limb.w0, limb.w1, rnd: &rnd)
        ctx.fill(shape, with: .color(bark.opacity(tree.look.species == .alien ? 0.35 : 0.5)))
        Pen.ink(&ctx, shape, color: PlantInk.ink, width: lw * (limb.depth == 0 ? 1.2 : 1))
        // Hatching along the shadow side of thicker wood.
        guard limb.w0 > 6 else { return }
        var hatch = Path()
        for i in stride(from: 0, to: right.count - 1, by: 1) {
            let a = right[i], b = limb.points[i]
            for k in 0..<2 {
                let f = CGFloat(k) * 0.5 + rnd.cg(0.05, 0.25)
                let s = CGPoint(x: a.x + (b.x - a.x) * 0.1, y: a.y + (b.y - a.y) * 0.1 + f * 6)
                let e = CGPoint(x: a.x + (b.x - a.x) * 0.45, y: a.y + (b.y - a.y) * 0.45 + f * 6 - 3)
                hatch.move(to: s); hatch.addLine(to: e)
            }
        }
        ctx.stroke(hatch, with: .color(PlantInk.ink.opacity(0.3)), lineWidth: lw * 0.55)
        if tree.look.species == .alien || tree.look.species == .coral {
            // Suckers or polyps: small rings along the wood.
            var dots = Path()
            for i in stride(from: 1, to: limb.points.count - 1, by: 2) {
                let p = limb.points[i]
                let r = max(1.2, limb.w0 * 0.1)
                dots.addEllipse(in: CGRect(x: p.x - r + rnd.cg(-2, 2), y: p.y - r, width: r * 2, height: r * 2))
            }
            ctx.stroke(dots, with: .color(PlantInk.ink.opacity(0.5)), lineWidth: lw * 0.6)
        }
    }

    private func drawRoots(_ ctx: inout GraphicsContext, _ g: TreeGeometry, bark: Color, lw: CGFloat, rnd: inout SeededRandom) {
        let w = max(8, (g.limbs.first?.w0 ?? 10))
        for side in [-1.0, 1.0, -0.4, 0.5] {
            var p = Path()
            let s = CGPoint(x: g.base.x + CGFloat(side) * w * 0.25, y: g.base.y - w * 0.3)
            p.move(to: s)
            p.addQuadCurve(to: CGPoint(x: g.base.x + CGFloat(side) * w * rnd.cg(1.0, 1.6), y: g.base.y + rnd.cg(1, 4)),
                           control: CGPoint(x: g.base.x + CGFloat(side) * w * 0.7, y: g.base.y - 1))
            Pen.ink(&ctx, p, color: PlantInk.ink.opacity(0.85), width: lw)
        }
    }

    // MARK: Leaves, traps, pods

    private func foliage(_ ctx: inout GraphicsContext, _ g: TreeGeometry, tone: Color, back: Bool, rnd: inout SeededRandom, lw: CGFloat) {
        let ends = g.limbs.map { $0.points.last! } + g.twigs.map { $0.points.last! }
        let scale = max(0.5, g.height / 300)
        switch tree.look.species {
        case .oak:
            for (i, e) in ends.enumerated() where (i % 2 == 0) == back || !back {
                let r = rnd.cg(14, 26) * scale * CGFloat(0.8 + tree.look.vigor * 0.5)
                let c = CGPoint(x: e.x + rnd.cg(-r * 0.4, r * 0.4), y: e.y + rnd.cg(-r * 0.5, r * 0.2))
                let cloud = Pen.cloud(center: c, radius: r, bumps: 7 + i % 3, rnd: &rnd)
                ctx.fill(cloud, with: .color(tone.opacity(back ? 0.28 : 0.42)))
                if !back {
                    Pen.ink(&ctx, cloud.trimmedPath(from: 0.08, to: 0.86), color: PlantInk.ink.opacity(0.75), width: lw * 0.85)
                    leafTicks(&ctx, c, r, tone: tone, rnd: &rnd, lw: lw)
                }
            }
        case .willow:
            guard !back else { return }
            for e in ends {
                let strands = Int(4 + 6 * tree.look.vigor)
                for _ in 0..<strands {
                    let s = CGPoint(x: e.x + rnd.cg(-18, 18) * scale, y: e.y + rnd.cg(-6, 6))
                    let len = rnd.cg(40, 110) * scale * CGFloat(0.6 + tree.look.droop)
                    var p = Path()
                    p.move(to: s)
                    let end = CGPoint(x: s.x + rnd.cg(-10, 10), y: min(g.base.y - 4, s.y + len))
                    p.addQuadCurve(to: end, control: CGPoint(x: s.x + rnd.cg(-14, 14), y: s.y + len * 0.3))
                    ctx.stroke(p, with: .color(PlantInk.ink.opacity(0.55)), lineWidth: lw * 0.6)
                    // Little leaves along the strand.
                    var leaves = Path()
                    for k in 1..<7 {
                        let t = CGFloat(k) / 7
                        let pt = CGPoint(x: s.x + (end.x - s.x) * t, y: s.y + (end.y - s.y) * t)
                        leaves.move(to: pt)
                        leaves.addLine(to: CGPoint(x: pt.x + (k % 2 == 0 ? 4 : -4), y: pt.y + 4))
                    }
                    ctx.stroke(leaves, with: .color(tone.opacity(0.9)), lineWidth: lw * 1.1)
                }
            }
        case .conifer:
            for limb in g.limbs + g.twigs {
                let pts = limb.points
                if back {
                    // A dark wash tier hanging from each limb.
                    guard limb.depth == 1, let first = pts.first, let last = pts.last else { continue }
                    var tier = Path()
                    tier.move(to: first)
                    tier.addLine(to: last)
                    tier.addLine(to: CGPoint(x: (first.x + last.x) / 2, y: max(first.y, last.y) + 18 * scale))
                    tier.closeSubpath()
                    ctx.fill(tier, with: .color(tone.opacity(0.3)))
                    continue
                }
                var needles = Path()
                for i in 1..<pts.count {
                    let a = pts[i - 1], b = pts[i]
                    for k in 0..<3 {
                        let t = CGFloat(k) / 3
                        let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                        let l = 6 * scale
                        needles.move(to: p); needles.addLine(to: CGPoint(x: p.x - l * 0.5, y: p.y + l))
                        needles.move(to: p); needles.addLine(to: CGPoint(x: p.x + l * 0.5, y: p.y + l))
                    }
                }
                ctx.stroke(needles, with: .color(tone.opacity(0.85)), lineWidth: lw * 0.8)
            }
        case .flytrap:
            guard !back else { return }
            // A rosette of small leaves at the base.
            for i in 0..<9 {
                let a = Double(i) / 9 * .pi - .pi
                let len = rnd.cg(18, 30) * scale
                var leaf = Path()
                let s = g.base
                let e = CGPoint(x: s.x + CGFloat(cos(a)) * len * 1.4, y: s.y + CGFloat(sin(a)) * len * 0.5)
                leaf.move(to: s)
                leaf.addQuadCurve(to: e, control: CGPoint(x: (s.x + e.x) / 2, y: min(s.y, e.y) - 8))
                leaf.addQuadCurve(to: s, control: CGPoint(x: (s.x + e.x) / 2, y: max(s.y, e.y) + 2))
                ctx.fill(leaf, with: .color(tone.opacity(0.35)))
                Pen.ink(&ctx, leaf, color: PlantInk.ink.opacity(0.7), width: lw * 0.8)
            }
            // A trap at every paper (big and open) and every twig (small and shut).
            for tip in g.tips { trap(&ctx, at: tip.point, angle: tip.angle, size: g.cardSize.height * 0.95, open: true, tone: tone, lw: lw, rnd: &rnd) }
            for t in g.twigs { let p = t.points; trap(&ctx, at: p.last!, angle: atan2(Double(p.last!.y - p[p.count - 2].y), Double(p.last!.x - p[p.count - 2].x)), size: 14 * scale, open: false, tone: tone, lw: lw, rnd: &rnd) }
        case .alien:
            guard !back else { return }
            for (i, e) in ends.enumerated() {
                let r = rnd.cg(6, 13) * scale * CGFloat(0.8 + tree.look.vigor * 0.6)
                let c = CGPoint(x: e.x + rnd.cg(-4, 4), y: e.y + rnd.cg(-4, 4))
                let pod = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 1.25, width: r * 2, height: r * 2.5))
                ctx.fill(pod, with: .color(tone.opacity(0.45)))
                Pen.ink(&ctx, pod, color: PlantInk.ink.opacity(0.8), width: lw * 0.9)
                // Concentric pencil rings around the pod, and its seeds.
                let ring = Path(ellipseIn: CGRect(x: c.x - r * 1.6, y: c.y - r * 1.9, width: r * 3.2, height: r * 3.8))
                ctx.stroke(ring, with: .color(tone.opacity(0.35)), style: StrokeStyle(lineWidth: lw * 0.6, dash: [2, 3]))
                var seeds = Path()
                for k in 0..<3 { seeds.addEllipse(in: CGRect(x: c.x - 1.5 + CGFloat(k - 1) * r * 0.45, y: c.y - 1.5 + CGFloat(k % 2) * 3, width: 3, height: 3)) }
                ctx.fill(seeds, with: .color(Color(hex: 0xC79A3A).opacity(0.9)))
                if i % 3 == 0 {
                    // A curling tendril.
                    var curl: [CGPoint] = []
                    for k in 0..<22 {
                        let t = Double(k) / 21
                        let rr = Double(r) * 2.2 * (1 - t)
                        let a = t * .pi * 3.2
                        curl.append(CGPoint(x: c.x + r * 1.4 + CGFloat(cos(a) * rr), y: c.y - r * 1.5 + CGFloat(sin(a) * rr)))
                    }
                    ctx.stroke(Pen.smooth(curl), with: .color(PlantInk.ink.opacity(0.6)), lineWidth: lw * 0.7)
                }
            }
        case .coral:
            guard !back else { return }
            for e in ends {
                let r = rnd.cg(3.5, 6.5) * scale
                let knob = Path(ellipseIn: CGRect(x: e.x - r, y: e.y - r, width: r * 2, height: r * 2))
                ctx.fill(knob, with: .color(tone.opacity(0.75)))
                Pen.ink(&ctx, knob, color: PlantInk.ink.opacity(0.8), width: lw * 0.8)
                var polyps = Path()
                for k in 0..<6 {
                    let a = Double(k) / 6 * .pi * 2
                    let p = CGPoint(x: e.x + CGFloat(cos(a)) * r * 1.9, y: e.y + CGFloat(sin(a)) * r * 1.9)
                    polyps.move(to: CGPoint(x: e.x + CGFloat(cos(a)) * r, y: e.y + CGFloat(sin(a)) * r))
                    polyps.addLine(to: p)
                }
                ctx.stroke(polyps, with: .color(tone.opacity(0.8)), lineWidth: lw * 0.6)
            }
        }
    }

    private func leafTicks(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat, tone: Color, rnd: inout SeededRandom, lw: CGFloat) {
        var ticks = Path()
        for _ in 0..<Int(5 + r / 4) {
            let p = CGPoint(x: c.x + rnd.cg(-r * 0.7, r * 0.7), y: c.y + rnd.cg(-r * 0.6, r * 0.6))
            ticks.move(to: p)
            ticks.addQuadCurve(to: CGPoint(x: p.x + 4, y: p.y - 2), control: CGPoint(x: p.x + 2, y: p.y + 2))
        }
        ctx.stroke(ticks, with: .color(PlantInk.ink.opacity(0.4)), lineWidth: lw * 0.6)
    }

    /// Two hinged lobes with teeth, like a Venus flytrap. Open ones hold a paper between the jaws.
    private func trap(_ ctx: inout GraphicsContext, at p: CGPoint, angle: Double, size: CGFloat, open: Bool,
                      tone: Color, lw: CGFloat, rnd: inout SeededRandom) {
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(angle + .pi / 2))
        let w = size * 0.8, h = size * 0.65
        let spread: CGFloat = open ? 0.62 : 0.12
        for side in [-1.0, 1.0] {
            var lobe = Path()
            lobe.move(to: .zero)
            let s = CGFloat(side)
            let tipPt = CGPoint(x: s * w * spread, y: -h)
            lobe.addQuadCurve(to: tipPt, control: CGPoint(x: s * w * (spread + 0.55), y: -h * 0.25))
            lobe.addQuadCurve(to: .zero, control: CGPoint(x: s * w * spread * 0.2, y: -h * 0.65))
            c.fill(lobe, with: .color(tone.opacity(0.55)))
            c.fill(lobe, with: .color(Color(hex: 0xB2432C).opacity(open ? 0.25 : 0.12)))
            Pen.ink(&c, lobe, color: PlantInk.ink, width: lw * 0.9)
            // Teeth along the rim.
            var teeth = Path()
            for k in 1..<9 {
                let t = CGFloat(k) / 9
                let rim = CGPoint(x: s * w * spread * 0.2 * (1 - t) + tipPt.x * t, y: -h * 0.65 * (1 - t) * (1 - t) + tipPt.y * t)
                teeth.move(to: rim)
                teeth.addLine(to: CGPoint(x: rim.x - s * size * 0.08, y: rim.y - size * 0.09))
            }
            c.stroke(teeth, with: .color(PlantInk.ink.opacity(0.75)), lineWidth: lw * 0.6)
        }
    }

    // MARK: Pencil branches

    private func drawGhost(_ ctx: inout GraphicsContext, _ ghost: TreeGeometry.Ghost, lw: CGFloat, rnd: inout SeededRandom) {
        for pass in 0..<3 {
            var p = Path()
            let j = CGFloat(pass) * 0.9
            p.move(to: CGPoint(x: ghost.from.x + rnd.cg(-j, j), y: ghost.from.y + rnd.cg(-j, j)))
            p.addQuadCurve(to: CGPoint(x: ghost.to.x + rnd.cg(-j, j), y: ghost.to.y + rnd.cg(-j, j)),
                           control: CGPoint(x: ghost.control.x + rnd.cg(-3, 3), y: ghost.control.y + rnd.cg(-3, 3)))
            ctx.stroke(p, with: .color(PlantInk.pencil.opacity(pass == 0 ? 0.75 : 0.3)),
                       style: StrokeStyle(lineWidth: lw * (pass == 0 ? 1 : 0.6), lineCap: .round, dash: pass == 0 ? [5, 3, 1, 3] : []))
        }
    }
}

// MARK: Paper tips

/// A paper's front page at the end of its branch: the real page 1 when we have it, else a drawn title page.
struct PaperTipCard: View {
    var paper: Paper
    var image: NSImage?
    var size: CGSize
    var tilt: Double

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height).clipped()
            } else {
                DrawnTitlePage(paper: paper, size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color(hex: 0xFCFAF3))
        .overlay(Rectangle().strokeBorder(PlantInk.ink.opacity(0.55), lineWidth: 0.6))
        .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0.5, y: 1.5)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(hex: 0xE8DDB4).opacity(0.8)).frame(width: size.width * 0.45, height: max(4, size.height * 0.09))
                .rotationEffect(.degrees(-tilt * 2)).offset(y: -size.height * 0.03)
        }
        .rotationEffect(.degrees(tilt))
    }
}

/// A title page drawn from what we know: venue, title, authors, a few ruled lines of "text".
struct DrawnTitlePage: View {
    var paper: Paper
    var size: CGSize

    var body: some View {
        let s = size.width / 60
        VStack(alignment: .center, spacing: 2.5 * s) {
            if !paper.venue.isEmpty || paper.year != nil {
                Text([paper.venue, paper.year.map(String.init) ?? ""].filter { !$0.isEmpty }.joined(separator: ", "))
                    .font(.custom(Typeface.text, size: max(3, 3.6 * s))).foregroundColor(PlantInk.ink.opacity(0.6))
                    .lineLimit(1)
            }
            Text(paper.title)
                .font(.custom(Typeface.textMedium, size: max(4, 6.2 * s)))
                .foregroundColor(PlantInk.ink)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
            if !paper.shortAuthors.isEmpty {
                Text(paper.shortAuthors).font(.custom(Typeface.textItalic, size: max(3, 4 * s))).foregroundColor(PlantInk.ink.opacity(0.7))
                    .lineLimit(1)
            }
            VStack(spacing: 1.6 * s) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle().fill(PlantInk.ink.opacity(0.18)).frame(height: 0.7)
                        .padding(.trailing, i == 5 ? size.width * 0.3 : 0)
                }
            }
            .padding(.top, 1.5 * s)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4 * s)
        .padding(.top, 5 * s)
        .frame(width: size.width, height: size.height)
    }
}

/// A suggestion's ghost page: a pencil outline with the title, not quite there yet.
struct GhostTipCard: View {
    var paper: Paper
    var size: CGSize

    var body: some View {
        let s = size.width / 60
        VStack(spacing: 2 * s) {
            Text(paper.title)
                .font(.custom(Typeface.hand, size: max(4, 6 * s)))
                .foregroundColor(PlantInk.pencil)
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            Text("suggested").font(.custom(Typeface.type, size: max(3, 4 * s))).foregroundColor(PlantInk.pencil.opacity(0.9))
        }
        .padding(4 * s)
        .frame(width: size.width, height: size.height)
        .background(Color(hex: 0xFCFAF3).opacity(0.45))
        .overlay(Rectangle().stroke(PlantInk.pencil, style: StrokeStyle(lineWidth: 0.9, dash: [3, 2])))
        .rotationEffect(.degrees(-3))
    }
}
