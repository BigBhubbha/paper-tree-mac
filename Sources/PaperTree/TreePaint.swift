// Painting a tree. Wood is filled, tapered and shaded (light from the upper left, like a plate);
// leaves are stacked watercolor washes with a few crisp leaf dabs and touches of ink on top.
// Everything is posed per frame: twigs sway in a slow wind, and a newly added paper's branch
// extends, its leaves unfurl, and its front page settles on the tip.
import AppKit
import SwiftUI

// MARK: Colour you can mix

struct RGB {
    var r: Double, g: Double, b: Double
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    func mix(_ o: RGB, _ t: Double) -> RGB {
        let t = max(0, min(1, t))
        return RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }
    func color(_ a: Double = 1) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var lit: RGB { mix(RGB(0xF4E9B0), 0.42) }
    var shade: RGB { mix(RGB(0x1F3138), 0.48) }
}

extension PlantInk {
    static func leafRGB(_ s: Species, toneName: String) -> RGB {
        if s == .cactus { return RGB(0x6F9A57) }
        if s == .mushroom && ["sage", "moss", "olive"].contains(toneName) { return RGB(0xB5533A) }
        if s == .kelp && ["sage", "moss"].contains(toneName) { return RGB(0x8A7A3A) }
        if s == .crystal && ["sage", "moss", "olive"].contains(toneName) { return RGB(0x8FC7D8) }
        if s == .dendrite && toneName == "sage" { return RGB(0x8C78C8) }
        switch s {
        case .flytrap: return RGB(0x95B23E)
        case .coral: return RGB(0xE58066)
        case .conifer: return RGB(0x2F5E4F)
        default:
            switch toneName {
            case "moss": return RGB(0x5E7A3A)
            case "olive": return RGB(0x8A8A3E)
            case "rust": return RGB(0xB5653A)
            case "plum": return RGB(0x7D4E6E)
            case "teal": return RGB(0x3E8C86)
            case "ochre": return RGB(0xC79A3A)
            case "violet": return RGB(0x8C78C8)
            case "gold": return RGB(0xD4A940)
            case "ice": return RGB(0x8FC7D8)
            default: return RGB(0x7F9C6B)
            }
        }
    }
    static func barkRGB(_ s: Species) -> RGB {
        switch s {
        case .kelp: return RGB(0x8A6F2E)
        case .dendrite: return RGB(0x5B4E86)
        case .crystal: return RGB(0x4E5D6C)
        case .herb: return RGB(0x6F8F45)
        case .cactus: return RGB(0x5F8A4E)
        case .fern: return RGB(0x6E5A3A)
        case .mushroom: return RGB(0xE9DDC4)
        case .alien: return RGB(0x56656B)
        case .coral: return RGB(0xD9694F)
        case .flytrap: return RGB(0x7C9A3A)
        case .conifer: return RGB(0x5E4632)
        case .willow: return RGB(0x6B5A45)
        case .oak: return RGB(0x6E553F)
        }
    }
}

/// Paper grain, laid over washes so they granulate like pigment settling into paper.
enum Grain {
    static let image: Image = {
        let w = 96
        var bytes = [UInt8](repeating: 0, count: w * w * 4)
        var rnd = SeededRandom(7, "grain")
        for i in 0..<(w * w) {
            let v = rnd.next()
            bytes[i * 4 + 3] = UInt8(min(255, v * v * v * 210))
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let made: CGImage? = bytes.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: w, height: w, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        if let made { return Image(decorative: made, scale: 2) }
        return Image(systemName: "circle")
    }()
}

extension Pen {
    /// A filled limb: a ribbon around the centre line, `radii` wide at each point, rounded at the end.
    static func ribbon(_ pts: [CGPoint], _ radii: [CGFloat]) -> Path {
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in pts.indices {
            let a = pts[max(0, i - 1)], b = pts[min(pts.count - 1, i + 1)]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(0.001, hypot(dx, dy))
            let nx = -dy / len, ny = dx / len
            let w = radii[i]
            left.append(CGPoint(x: pts[i].x + nx * w, y: pts[i].y + ny * w))
            right.append(CGPoint(x: pts[i].x - nx * w, y: pts[i].y - ny * w))
        }
        var p = Path()
        addSmooth(&p, left, move: true)
        let end = pts[pts.count - 1]
        p.addQuadCurve(to: right[right.count - 1], control: CGPoint(x: end.x + (end.x - pts[max(0, pts.count - 2)].x) * 0.6,
                                                                       y: end.y + (end.y - pts[max(0, pts.count - 2)].y) * 0.6))
        addSmooth(&p, right.reversed(), move: false)
        p.closeSubpath()
        return p
    }

    static func addSmooth(_ p: inout Path, _ pts: [CGPoint], move: Bool) {
        guard let first = pts.first else { return }
        if move { p.move(to: first) } else { p.addLine(to: first) }
        if pts.count == 2 { p.addLine(to: pts[1]); return }
        guard pts.count > 2 else { return }
        for i in 1..<(pts.count - 1) {
            p.addQuadCurve(to: CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2), control: pts[i])
        }
        p.addLine(to: pts[pts.count - 1])
    }

    /// An almond leaf from `base`, pointing along `angle`.
    static func leaf(at base: CGPoint, angle: Double, length: CGFloat, width: CGFloat = 0.36) -> Path {
        let c = CGFloat(cos(angle)), s = CGFloat(sin(angle))
        let tip = CGPoint(x: base.x + c * length, y: base.y + s * length)
        let mid = CGPoint(x: base.x + c * length * 0.45, y: base.y + s * length * 0.45)
        let w = length * width
        var p = Path()
        p.move(to: base)
        p.addQuadCurve(to: tip, control: CGPoint(x: mid.x - s * w, y: mid.y + c * w))
        p.addQuadCurve(to: base, control: CGPoint(x: mid.x + s * w, y: mid.y - c * w))
        p.closeSubpath()
        return p
    }
}

// MARK: Motion

/// What is growing right now: the newest paper, for a short while after it is added.
enum TreeGrowth {
    static let duration: TimeInterval = 2.8

    static func current(_ tree: PaperTreeData, at now: Date) -> (owner: Int, progress: CGFloat)? {
        guard let newest = tree.papers.max(by: { $0.addedAt < $1.addedAt }) else { return nil }
        let dt = now.timeIntervalSince(newest.addedAt)
        // A paper stamped a moment in the future (a clock nudge, or a rendered sequence) waits as a bud.
        guard dt > -2, dt < duration else { return nil }
        return (tree.papers.count - 1, CGFloat(max(0, dt) / duration))
    }

    static func easeOut(_ t: CGFloat) -> CGFloat { let u = 1 - max(0, min(1, t)); return 1 - u * u * u }
    /// A damped spring from 0 to 1 (a little overshoot, then rest), for things that land.
    static func spring(_ t: CGFloat) -> CGFloat {
        let x = Double(max(0, min(1, t)))
        return CGFloat(1 - exp(-5.2 * x) * cos(7.8 * x))
    }
}

/// Snapshots freeze the clock so renders repeat exactly.
@MainActor
enum TreeClock {
    static var frozen: Date?
    /// When pencil branches start drawing themselves (nil: the moment a tree comes into view).
    static var sketchStart: Date?
}

extension TreeGeometry {
    struct Pose {
        var p: [CGPoint]
        var vis: [CGFloat]
        var time: Double
        var wind: CGFloat
        var owner: Int
        var progress: CGFloat

        /// Wood of the growing paper starts thin and fills out.
        func radiusScale(_ o: Int) -> CGFloat { o == owner && progress < 1 ? 0.35 + 0.65 * TreeGrowth.easeOut(progress / 0.8) : 1 }
        /// Leaves of the growing paper unfurl after the branch has reached out.
        func leafScale(_ o: Int) -> CGFloat {
            guard o == owner && progress < 1 else { return 1 }
            return max(0, TreeGrowth.spring((progress - 0.5) / 0.42))
        }
    }

    func pose(time: Double, wind: CGFloat, growing: (owner: Int, progress: CGFloat)?) -> Pose {
        var P = [CGPoint](repeating: .zero, count: nodes.count)
        var A = [Double](repeating: 0, count: nodes.count)
        var V = [CGFloat](repeating: 1, count: nodes.count)
        let owner = growing?.owner ?? -1
        let prog = growing?.progress ?? 1
        let ext = TreeGrowth.easeOut(prog / 0.6)
        for i in nodes.indices {
            let n = nodes[i]
            guard n.parent >= 0 else {
                P[i] = n.p
                if n.owner == owner && prog < 1 { V[i] = prog > 0 ? 1 : 0 }
                continue
            }
            let par = n.parent
            let sway = wind == 0 ? 0 : Double(wind) * Double(n.flex) * (0.0044 * sin(time * 1.25 + n.phase) + 0.0028 * sin(time * 0.47 + n.phase * 0.6 + 1.7))
            let a = A[par] + sway
            A[i] = a
            let vx = n.p.x - nodes[par].p.x, vy = n.p.y - nodes[par].p.y
            let c = CGFloat(cos(a)), s = CGFloat(sin(a))
            var v = CGPoint(x: vx * c - vy * s, y: vx * s + vy * c)
            var f: CGFloat = 1
            if n.owner == owner && prog < 1 {
                if n.along <= 1 {
                    let pa = nodes[par].owner == owner && nodes[par].along <= 1 ? nodes[par].along : 0
                    f = max(0, min(1, (ext - pa) / max(0.0001, n.along - pa)))
                } else {
                    f = max(0, min(1, (prog - (0.42 + 0.4 * (n.along - 1))) / 0.08))
                }
            }
            if V[par] < 1 { f = 0 }
            v = CGPoint(x: v.x * f, y: v.y * f)
            V[i] = f
            P[i] = CGPoint(x: P[par].x + v.x, y: P[par].y + v.y)
        }
        return Pose(p: P, vis: V, time: time, wind: wind, owner: owner, progress: prog)
    }
}

// MARK: The drawing

struct TreeDrawing: View {
    var tree: PaperTreeData
    var geometry: TreeGeometry
    /// Smaller trees in the grove skip the finest detail.
    var detail: CGFloat = 1
    var pose: TreeGeometry.Pose? = nil
    /// How far each pencil branch has drawn itself, 0...1 (missing means drawn).
    var sketch: [String: CGFloat] = [:]
    /// Drawing coordinates to the view: the camera (fit, zoom and pan).
    var camera: CGAffineTransform = .identity

    var body: some View {
        Canvas { ctx, size in
            ctx.concatenate(camera)
            let painter = TreePainter(tree: tree, g: geometry,
                                      pose: pose ?? geometry.pose(time: 0, wind: 0, growing: nil),
                                      detail: detail, sketch: sketch)
            painter.paint(&ctx, size)
        }
    }
}

struct TreePainter {
    var tree: PaperTreeData
    var g: TreeGeometry
    var pose: TreeGeometry.Pose
    var detail: CGFloat
    var sketch: [String: CGFloat]

    private var species: Species { tree.look.species }
    private var leaf: RGB { PlantInk.leafRGB(species, toneName: tree.look.leafTone) }
    private var bark: RGB { PlantInk.barkRGB(species) }
    private var lw: CGFloat { max(0.7, min(1.4, g.height / 260)) }
    private var fine: Bool { detail >= 1 }

    func paint(_ ctx: inout GraphicsContext, _ size: CGSize) {
        paintPlant(&ctx, size)
        leaderLines(&ctx)
    }

    /// Thin ink lines from a branch tip to its paper when the paper had to move aside to make room.
    private func leaderLines(_ ctx: inout GraphicsContext) {
        for t in g.tips where g.leaders.contains(t.id) && t.node < pose.p.count && pose.vis[t.node] > 0 {
            guard let c = g.cardCenters[t.id] else { continue }
            let p = pose.p[t.node]
            let card = CGPoint(x: c.x + p.x - t.point.x, y: c.y + p.y - t.point.y)
            var line = Path()
            line.move(to: p)
            line.addQuadCurve(to: card, control: CGPoint(x: (p.x + card.x) / 2, y: min(p.y, card.y) - 6))
            ctx.stroke(line, with: .color(PlantInk.ink.opacity(0.45)), style: StrokeStyle(lineWidth: lw * 0.6, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 1.6, width: 3.2, height: 3.2)), with: .color(PlantInk.ink.opacity(0.6)))
        }
    }

    private var hasLeafList: Bool { [.oak, .willow, .crystal, .herb, .kelp].contains(species) }

    private func paintPlant(_ ctx: inout GraphicsContext, _ size: CGSize) {
        var rnd = SeededRandom(tree.seed, "ink")
        if species == .mushroom { mycelium(&ctx) }
        ground(&ctx, rnd: &rnd)
        if tree.papers.isEmpty || g.nodes.isEmpty { seed(&ctx); return }

        if species == .coral { fan(&ctx) }
        if species == .kelp { water(&ctx) }
        if hasLeafList {
            for lf in g.leaves where lf.back { leafShape(&ctx, lf) }
        }
        for gh in g.ghosts { ghost(&ctx, gh, rnd: &rnd) }

        // The body: stems, stalks, columns or wood.
        switch species {
        case .flytrap:
            rosette(&ctx, rnd: &rnd)
            for chain in g.chains { petiole(&ctx, chain) }
        case .herb:
            for chain in g.chains { stem(&ctx, chain, color: RGB(0x6F8F45), widen: 1) }
        case .kelp:
            holdfast(&ctx)
            for chain in g.chains { stem(&ctx, chain, color: RGB(0x8A6F2E), widen: 1.1) }
        case .fern:
            for (k, chain) in g.chains.enumerated() { frond(&ctx, chain, index: k) }
        case .mushroom:
            for chain in g.chains { stalk(&ctx, chain) }
        case .cactus:
            cactusBody(&ctx)
        case .dendrite:
            axon(&ctx)
            woods(&ctx)
            soma(&ctx)
        default:
            woods(&ctx)
            if species != .coral { roots(&ctx, rnd: &rnd) }
        }
        if species == .crystal { circuit(&ctx) }

        // What grows on it.
        switch species {
        case .oak, .willow, .crystal, .herb, .kelp:
            if species == .willow { for s in g.strands { strand(&ctx, s) } }
            for lf in g.leaves where !lf.back { leafShape(&ctx, lf) }
            if species == .kelp { bladders(&ctx) }
        case .conifer:
            for t in g.tiers { tier(&ctx, t) }
            sprays(&ctx)
        case .alien:
            for c in g.clumps { orb(&ctx, c) }
        case .coral:
            for c in g.clumps { polyp(&ctx, c) }
        case .dendrite:
            spines(&ctx)
            for c in g.clumps { bouton(&ctx, c) }
        case .mushroom:
            caps(&ctx)
        case .cactus:
            break
        case .fern:
            fiddleheads(&ctx)
        case .flytrap:
            let big = max(g.cardSize.height * 0.95, g.height * 0.2)
            for (k, t) in g.twigEnds.enumerated() where pose.vis[t] > 0 {
                trap(&ctx, node: t, size: max(10, big * 0.42), open: 0.12 + 0.03 * CGFloat(sin(pose.time * 0.9 + Double(k))), mouth: false)
            }
            for t in g.tips where t.node < pose.vis.count && pose.vis[t.node] > 0 {
                let o = g.nodes[t.node].owner
                let unfurl = pose.leafScale(o)
                trap(&ctx, node: t.node, size: big * (0.35 + 0.65 * unfurl),
                     open: 0.14 + 0.5 * unfurl + 0.03 * CGFloat(sin(pose.time * 0.7 + Double(o))), mouth: true)
            }
        }
        if tree.look.tendrils == true { tendrils(&ctx) }
        blooms(&ctx)
    }

    // MARK: Ground and seed

    private func ground(_ ctx: inout GraphicsContext, rnd: inout SeededRandom) {
        let y = g.base.y
        let half = max(60, g.height * 0.55 + 40)
        let earth = RGB(0xA08B66)
        for layer in g.groundLayers {
            ctx.fill(layer.applying(CGAffineTransform(translationX: g.base.x, y: y + 5).scaledBy(x: half, y: max(5, half * 0.07))),
                     with: .color(earth.color(0.11)))
        }
        var pts: [CGPoint] = []
        var x = g.base.x - half * 0.92
        while x <= g.base.x + half * 0.92 {
            pts.append(CGPoint(x: x, y: y + rnd.cg(-1, 1)))
            x += 14
        }
        Pen.ink(&ctx, Pen.smooth(pts), color: PlantInk.ink.opacity(0.55), width: lw * 0.8)
        var grass = Path()
        for _ in 0..<Int(half / 7) {
            let gx = g.base.x + rnd.cg(-half * 0.9, half * 0.9)
            let h = rnd.cg(3, 9)
            grass.move(to: CGPoint(x: gx, y: y))
            grass.addQuadCurve(to: CGPoint(x: gx + rnd.cg(-3, 3), y: y - h), control: CGPoint(x: gx + rnd.cg(-1, 1), y: y - h * 0.5))
        }
        ctx.stroke(grass, with: .color(RGB(0x5D7A3E).color(0.55)), lineWidth: lw * 0.7)
    }

    private func seed(_ ctx: inout GraphicsContext) {
        let c = CGPoint(x: g.base.x, y: g.base.y + 8)
        let seed = Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 4.5, width: 14, height: 9))
        ctx.fill(seed, with: .color(RGB(0x8B6B47).color(0.55)))
        Pen.ink(&ctx, seed, color: PlantInk.ink, width: lw)
        var sprout = Path()
        sprout.move(to: CGPoint(x: c.x, y: c.y - 5))
        sprout.addQuadCurve(to: CGPoint(x: c.x + 3, y: c.y - 30), control: CGPoint(x: c.x - 6, y: c.y - 18))
        ctx.stroke(sprout, with: .color(PlantInk.pencil), style: StrokeStyle(lineWidth: lw, lineCap: .round, dash: [3, 4]))
    }

    // MARK: Wood

    private func points(_ chain: TreeGeometry.Chain) -> ([CGPoint], [CGFloat]) {
        var pts: [CGPoint] = [], rr: [CGFloat] = []
        for (k, id) in chain.ids.enumerated() {
            let v = pose.vis[id]
            if k > 0 && v <= 0 { break }
            let rid = (k == 0 && chain.side && chain.ids.count > 1) ? chain.ids[1] : id
            let n = g.nodes[rid]
            pts.append(pose.p[id])
            rr.append(n.r * pose.radiusScale(n.owner) * (k == 0 && chain.side ? 1.15 : 1))
            if v < 1 && k > 0 { break }
        }
        return (pts, rr)
    }

    /// All the wood as one silhouette: every limb's ink outline first, then every fill on top, so
    /// only the outside edge of the whole tree is inked (no seams where limbs join).
    private func woods(_ ctx: inout GraphicsContext) {
        var limbs: [(Path, [CGPoint], [CGFloat])] = []
        for chain in g.chains {
            let (pts, rr) = points(chain)
            guard pts.count >= 2 else { continue }
            limbs.append((Pen.ribbon(pts, rr), pts, rr))
        }
        for (shape, _, rr) in limbs {
            let thick = rr.max() ?? 1
            ctx.stroke(shape, with: .color(PlantInk.ink.opacity(thick > 2.5 ? 0.6 : 0.42)), lineWidth: lw * (thick > 2.5 ? 1.3 : 0.8))
        }
        for (shape, _, _) in limbs { ctx.fill(shape, with: .color(bark.color(1))) }
        for (_, pts, rr) in limbs where (rr.max() ?? 0) > 1.1 {
            // The lit side: a narrower, lighter ribbon nudged toward the light.
            let lit = Pen.ribbon(zip(pts, rr).map { CGPoint(x: $0.x - $1 * 0.34, y: $0.y - $1 * 0.16) }, rr.map { $0 * 0.4 })
            ctx.fill(lit, with: .color(bark.lit.color(0.42)))
        }
        if fine {
            for (k, (_, pts, rr)) in limbs.enumerated() { barkDetail(&ctx, pts, rr, index: k) }
        }
    }

    private func barkDetail(_ ctx: inout GraphicsContext, _ pts: [CGPoint], _ rr: [CGFloat], index: Int) {
        let thick = rr.max() ?? 1
        guard thick > 3, pts.count > 3 else { return }
        var rnd = SeededRandom(tree.seed &+ UInt64(index), "bark")
        switch species {
        case .coral:
            var pits = Path()
            for i in stride(from: 1, to: pts.count, by: 2) {
                let r = max(0.7, min(2, rr[i] * 0.22))
                pits.addEllipse(in: CGRect(x: pts[i].x - r + rnd.cg(-1, 1), y: pts[i].y - r + rnd.cg(-1, 1), width: r * 2, height: r * 2))
            }
            ctx.fill(pits, with: .color(RGB(0xFBE3D6).color(0.85)))
        case .dendrite, .herb, .kelp, .crystal, .cactus, .mushroom, .fern:
            break
        case .alien:
            // Faint glowing freckles along the wood.
            var dots = Path()
            for i in stride(from: 2, to: pts.count - 1, by: 2) {
                let r = max(0.6, rr[i] * 0.09)
                let u = rnd.cg(-0.5, 0.5) * rr[i]
                dots.addEllipse(in: CGRect(x: pts[i].x + u - r, y: pts[i].y - r, width: r * 2, height: r * 2))
            }
            ctx.fill(dots, with: .color(RGB(0xB8F0E4).color(0.55)))
        default:
            // Bark: long wavy ridges running with the grain, darker on the shadow side.
            var ridges = Path()
            let count = Int(Double(pts.count) * (species == .conifer ? 0.6 : 0.9))
            for _ in 0..<count {
                let i = Int(rnd.next() * Double(pts.count - 3))
                let u = rnd.cg(-0.6, 0.65)
                func at(_ j: Int) -> CGPoint {
                    let a = pts[max(0, j - 1)], b = pts[min(pts.count - 1, j + 1)]
                    let len = max(0.001, hypot(b.x - a.x, b.y - a.y))
                    return CGPoint(x: pts[j].x - (b.y - a.y) / len * rr[j] * u, y: pts[j].y + (b.x - a.x) / len * rr[j] * u)
                }
                let s = at(i), e = at(min(pts.count - 1, i + 2 + Int(rnd.next() * 2)))
                ridges.move(to: s)
                ridges.addQuadCurve(to: e, control: CGPoint(x: (s.x + e.x) / 2 + rnd.cg(-1.2, 1.2), y: (s.y + e.y) / 2 + rnd.cg(-1.2, 1.2)))
            }
            ctx.stroke(ridges, with: .color(PlantInk.ink.opacity(0.28)), style: StrokeStyle(lineWidth: lw * 0.5, lineCap: .round))
        }
    }

    private func roots(_ ctx: inout GraphicsContext, rnd: inout SeededRandom) {
        guard let root = g.nodes.first else { return }
        let w = max(3, root.r)
        for side in [-1.0, 1.0, -0.45, 0.55] {
            let s = CGFloat(side)
            let pts = [CGPoint(x: g.base.x + s * w * 0.3, y: g.base.y - w * 0.5),
                       CGPoint(x: g.base.x + s * w * 0.9, y: g.base.y - 1),
                       CGPoint(x: g.base.x + s * w * rnd.cg(1.5, 2.2), y: g.base.y + rnd.cg(1, 3))]
            let shape = Pen.ribbon(pts, [w * 0.45, w * 0.25, 0.4])
            ctx.fill(shape, with: .color(bark.color(0.9)))
            ctx.stroke(shape, with: .color(PlantInk.ink.opacity(0.45)), lineWidth: lw * 0.5)
        }
    }

    // MARK: Leaves

    private enum Pass { case shadow, body, detail }

    private func center(_ c: TreeGeometry.Clump) -> CGPoint {
        let p = pose.p[c.node]
        return CGPoint(x: p.x + c.offset.x, y: p.y + c.offset.y)
    }

    private func layer(_ path: Path, at c: CGPoint, rx: CGFloat, ry: CGFloat, rotate: CGFloat = 0) -> Path {
        path.applying(CGAffineTransform(translationX: c.x, y: c.y).rotated(by: rotate).scaledBy(x: rx, y: ry))
    }

    private func leafMass(_ base: inout GraphicsContext, _ c: TreeGeometry.Clump, pass: Pass) {
        guard pose.vis[c.node] > 0 else { return }
        var ctx = base
        ctx.opacity = c.thin
        let s = pose.leafScale(g.nodes[c.node].owner)
        guard s > 0.01 else { return }
        let unfurl = (1 - min(1, s)) * 0.9
        let o = center(c)
        let rx = c.rx * s, ry = c.ry * s
        let L = leaf
        switch pass {
        case .shadow:
            let at = CGPoint(x: o.x + rx * 0.1, y: o.y + ry * 0.16)
            for l in c.layers { ctx.fill(layer(l, at: at, rx: rx * 1.05, ry: ry * 1.05, rotate: unfurl), with: .color(L.shade.color(0.12))) }
        case .body:
            let body = L.mix(L.lit, c.light * 0.55)
            for l in c.layers { ctx.fill(layer(l, at: o, rx: rx * 0.94, ry: ry * 0.94, rotate: unfurl), with: .color(body.color(0.15))) }
            if c.light > 0.3 {
                let hl = CGPoint(x: o.x - rx * 0.22, y: o.y - ry * 0.28)
                for l in c.layers.prefix(3) { ctx.fill(layer(l, at: hl, rx: rx * 0.55, ry: ry * 0.5, rotate: unfurl), with: .color(L.lit.color(0.13 * c.light))) }
            }
            if let edge = c.layers.first {
                let e = layer(edge, at: o, rx: rx * 0.94, ry: ry * 0.94, rotate: unfurl)
                ctx.stroke(e, with: .color(L.shade.color(0.2)), lineWidth: lw * 0.55)
                if fine {
                    var gctx = ctx
                    gctx.blendMode = .multiply
                    gctx.opacity = 0.3
                    gctx.fill(e, with: .tiledImage(Grain.image, origin: .zero, sourceRect: CGRect(x: 0, y: 0, width: 1, height: 1), scale: 1))
                }
            }
        case .detail:
            let count = fine ? c.dabs.count : c.dabs.count / 3
            let sway = CGFloat(sin(pose.time * 1.6 + c.phase)) * 0.12 * pose.wind
            for d in c.dabs.prefix(count) {
                let base = CGPoint(x: o.x + d.p.x * rx * 0.9, y: o.y + d.p.y * ry * 0.9)
                let path = Pen.leaf(at: base, angle: d.angle + Double(sway) + Double(unfurl), length: d.len * c.rx * s)
                let col = L.shade.mix(L.lit, d.tint).mix(RGB(0xC9B04A), d.tint > 0.8 ? 0.15 : 0)
                ctx.fill(path, with: .color(col.color(0.78)))
                if fine && d.tint < 0.35 { ctx.stroke(path, with: .color(PlantInk.ink.opacity(0.25)), lineWidth: lw * 0.4) }
            }
            if fine, let edge = c.layers.last, c.front {
                let e = layer(edge, at: o, rx: rx * 0.94, ry: ry * 0.94, rotate: unfurl)
                ctx.stroke(e.trimmedPath(from: 0.05, to: 0.32), with: .color(PlantInk.ink.opacity(0.32)), lineWidth: lw * 0.55)
            }
        }
    }

    // MARK: Single leaves

    /// An oak leaf one unit long, pointing along +x from its stalk: rounded lobes, a little uneven.
    static let oakUnit: Path = {
        var top: [CGPoint] = [], bottom: [CGPoint] = []
        let n = 30
        for i in 0...n {
            let x = CGFloat(i) / CGFloat(n)
            let env = 0.3 * CGFloat(pow(sin(Double.pi * min(1, Double(x) * 1.04)), 0.8)) * (1 - 0.25 * x)
            let lobeA = 0.58 + 0.42 * CGFloat(pow(abs(sin(Double(x) * .pi * 3.2 + 0.35)), 0.6))
            let lobeB = 0.58 + 0.42 * CGFloat(pow(abs(sin(Double(x) * .pi * 3.2 + 0.85)), 0.6))
            top.append(CGPoint(x: x, y: -env * lobeA))
            bottom.append(CGPoint(x: x, y: env * lobeB))
        }
        var p = Path()
        p.move(to: .zero)
        for q in top { p.addLine(to: q) }
        for q in bottom.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        return p
    }()

    /// A willow leaf: long, narrow and pointed at both ends.
    static let lanceUnit: Path = {
        var p = Path()
        p.move(to: .zero)
        p.addCurve(to: CGPoint(x: 1, y: 0), control1: CGPoint(x: 0.25, y: -0.16), control2: CGPoint(x: 0.7, y: -0.1))
        p.addCurve(to: .zero, control1: CGPoint(x: 0.7, y: 0.1), control2: CGPoint(x: 0.25, y: 0.16))
        p.closeSubpath()
        return p
    }()

    /// The leaf's color: the tree's green (or plum, or rust) moved a little lighter or darker, warmer or cooler.
    private func tone(value: Double, hue: Double) -> RGB {
        let L = leaf
        let v = max(-1, min(1, value))
        var c = v >= 0 ? L.mix(L.lit, v * 0.75) : L.mix(L.shade, -v * 0.75)
        c = hue >= 0 ? c.mix(RGB(0xC9A94A), hue * 0.16) : c.mix(RGB(0x4F6C8E), -hue * 0.14)
        return c
    }

    private func drawLeaf(_ ctx: inout GraphicsContext, unit: Path, at base: CGPoint, angle: Double, length: CGFloat, color: RGB, alpha: Double) {
        guard length > 0.5 else { return }
        let t = CGAffineTransform(translationX: base.x, y: base.y).rotated(by: CGFloat(angle)).scaledBy(x: length, y: length)
        let shape = unit.applying(t)
        ctx.fill(shape, with: .color(color.color(0.96 * alpha)))
        // The half away from the light, a shade darker, so each leaf has a fold.
        var half = Path()
        half.move(to: CGPoint(x: 0.02, y: 0))
        half.addLine(to: CGPoint(x: 0.98, y: 0))
        half.addLine(to: CGPoint(x: 0.98, y: 0.4))
        half.addLine(to: CGPoint(x: 0.02, y: 0.4))
        half.closeSubpath()
        var folded = ctx
        folded.clip(to: shape)
        folded.fill(half.applying(t), with: .color(color.shade.color(0.28 * alpha)))
        ctx.stroke(shape, with: .color(PlantInk.ink.opacity(0.55 * alpha)), lineWidth: max(0.35, lw * 0.5))
        var rib = Path()
        rib.move(to: CGPoint(x: -0.14, y: 0.02))
        rib.addQuadCurve(to: CGPoint(x: 0.88, y: 0), control: CGPoint(x: 0.4, y: -0.03))
        ctx.stroke(rib.applying(t), with: .color(color.shade.shade.color(0.75 * alpha)), lineWidth: max(0.3, lw * 0.42))
    }

    private func leafShape(_ ctx: inout GraphicsContext, _ lf: TreeGeometry.Leaf) {
        guard lf.node < pose.p.count, pose.vis[lf.node] > 0 else { return }
        let s = pose.leafScale(g.nodes[lf.node].owner)
        guard s > 0.01 else { return }
        let p = pose.p[lf.node]
        let flex = Double(g.nodes[lf.node].flex)
        let flutter = sin(pose.time * 1.7 + lf.phase) * 0.12 * Double(pose.wind) * (0.4 + flex)
        let unit = leafUnit
        // Unfurling: a new leaf turns into place as it grows.
        let turn = Double(1 - min(1, s)) * 0.9
        if species == .crystal {
            shard(&ctx, at: CGPoint(x: p.x + lf.offset.x, y: p.y + lf.offset.y), angle: lf.angle + flutter * 0.4 + turn,
                  length: lf.length * s, value: lf.value - (lf.back ? 0.45 : 0), alpha: lf.dim ? 0.3 : 1)
            return
        }
        drawLeaf(&ctx, unit: unit, at: CGPoint(x: p.x + lf.offset.x, y: p.y + lf.offset.y), angle: lf.angle + flutter + turn,
                 length: lf.length * s, color: tone(value: lf.value - (lf.back ? 0.45 : 0), hue: lf.hue), alpha: lf.dim ? 0.3 : 1)
    }

    private func strand(_ ctx: inout GraphicsContext, _ s: TreeGeometry.Strand) {
        guard pose.vis[s.node] > 0 else { return }
        let sc = pose.leafScale(g.nodes[s.node].owner)
        guard sc > 0.01 else { return }
        let p = pose.p[s.node]
        let len = s.length * sc
        let sway = CGFloat(sin(pose.time * 1.1 + s.phase)) * len * 0.07 * pose.wind
        let end = CGPoint(x: p.x + s.lean * len + sway, y: p.y + len)
        let ctrl = CGPoint(x: p.x + s.lean * len * 0.3 + sway * 0.25, y: p.y + len * 0.35)
        var stem = Path()
        stem.move(to: p)
        stem.addQuadCurve(to: end, control: ctrl)
        ctx.stroke(stem, with: .color(leaf.shade.color(0.5)), lineWidth: lw * 0.5)
        var r = SeededRandom(tree.seed &+ UInt64(s.node), "strand")
        for k in 1...s.leaves {
            let t = CGFloat(k) / CGFloat(s.leaves + 1)
            let u = 1 - t
            let q = CGPoint(x: u * u * p.x + 2 * u * t * ctrl.x + t * t * end.x, y: u * u * p.y + 2 * u * t * ctrl.y + t * t * end.y)
            let d = CGPoint(x: 2 * u * (ctrl.x - p.x) + 2 * t * (end.x - ctrl.x), y: 2 * u * (ctrl.y - p.y) + 2 * t * (end.y - ctrl.y))
            let along = atan2(Double(d.y), Double(d.x))
            let side: Double = k % 2 == 0 ? 1 : -1
            let flutter = sin(pose.time * 1.9 + s.phase + Double(k)) * 0.1 * Double(pose.wind)
            let value = (s.tint * 2 - 1) * 0.4 + r.range(-0.35, 0.35) - 0.3 * Double(t)
            drawLeaf(&ctx, unit: Self.lanceUnit, at: q, angle: along + side * 0.5 + flutter,
                     length: g.leafSize * (0.95 - 0.25 * t) * sc, color: tone(value: value, hue: r.range(-1, 1)), alpha: 1)
        }
    }

    // MARK: Conifer

    private func tier(_ ctx: inout GraphicsContext, _ t: TreeGeometry.Tier) {
        guard pose.vis[t.node] > 0 else { return }
        let a = pose.p[t.node]
        let L = leaf
        let tr = CGAffineTransform(translationX: a.x, y: a.y)
        // Only a faint silhouette; the tier is really its boughs and their needles.
        if let edge = t.layers.first { ctx.fill(edge.applying(tr), with: .color(L.mix(L.lit, t.light * 0.4).color(0.1))) }
        var rnd = SeededRandom(tree.seed &+ UInt64(t.node), "needles")
        let top = a.y + (t.layers.first?.boundingRect.minY ?? 0)
        let nl = max(4, g.height / 34)                  // needle length
        let boughs = max(2, min(4, Int(t.height / (nl * 2.2))))
        for side in [-1.0, 1.0] {
            for j in 0..<boughs {
                let f = (CGFloat(j) + 0.6) / CGFloat(boughs)
                let root = CGPoint(x: a.x, y: top + t.height * (0.12 + 0.7 * f))
                let reach = t.half * (0.35 + 0.65 * f) * rnd.cg(0.85, 1.05)
                let sway = CGFloat(sin(pose.time * 1.2 + Double(t.node) + Double(j))) * reach * 0.03 * pose.wind
                let end = CGPoint(x: root.x + CGFloat(side) * reach, y: root.y + t.height * 0.22 + sway)
                let ctrl = CGPoint(x: root.x + CGFloat(side) * reach * 0.55, y: root.y - t.height * 0.04)
                var bough = Path()
                bough.move(to: root)
                bough.addQuadCurve(to: end, control: ctrl)
                ctx.stroke(bough, with: .color(bark.color(0.85)), lineWidth: max(0.5, lw * 0.75))
                // Needle sprays: little fans along the bough, each its own shade of green.
                let tufts = max(2, Int(reach / (nl * 0.95)))
                for k in 1...tufts {
                    let u = CGFloat(k) / CGFloat(tufts)
                    let w = 1 - u
                    let q = CGPoint(x: w * w * root.x + 2 * w * u * ctrl.x + u * u * end.x, y: w * w * root.y + 2 * w * u * ctrl.y + u * u * end.y)
                    let d = CGPoint(x: 2 * w * (ctrl.x - root.x) + 2 * u * (end.x - ctrl.x), y: 2 * w * (ctrl.y - root.y) + 2 * u * (end.y - ctrl.y))
                    let along = atan2(Double(d.y), Double(d.x))
                    var fan = Path()
                    for n in 0..<7 {
                        let off = (Double(n) - 3) / 3 * 1.05
                        let ang = along + off + (n % 2 == 0 ? 0.15 : -0.15)
                        let len = nl * (1 - 0.25 * CGFloat(abs(off))) * rnd.cg(0.85, 1.1)
                        fan.move(to: q)
                        fan.addLine(to: CGPoint(x: q.x + CGFloat(cos(ang)) * len, y: q.y + CGFloat(sin(ang)) * len))
                    }
                    let value = t.light * 1.4 - 0.6 + rnd.range(-0.35, 0.35) - Double(u) * 0.15
                    ctx.stroke(fan, with: .color(tone(value: value, hue: rnd.range(-1, 1)).color(0.95)),
                               style: StrokeStyle(lineWidth: max(0.5, lw * 0.7), lineCap: .round))
                }
            }
        }
    }

    private func sprays(_ ctx: inout GraphicsContext) {
        // Short needle sprays along the paper branches, so they read as boughs, not sticks.
        let L = leaf
        var needles = Path()
        let len = max(3, g.height / 70)
        for chain in g.chains where chain.ids.count > 2 {
            for (k, id) in chain.ids.enumerated() where k % 2 == 1 && pose.vis[id] >= 1 && g.nodes[id].along <= 1 && !g.trunkNodes.contains(id) {
                let p = pose.p[id]
                needles.move(to: p); needles.addLine(to: CGPoint(x: p.x - len * 0.6, y: p.y + len))
                needles.move(to: p); needles.addLine(to: CGPoint(x: p.x + len * 0.6, y: p.y + len))
                needles.move(to: p); needles.addLine(to: CGPoint(x: p.x, y: p.y + len * 1.2))
            }
        }
        ctx.stroke(needles, with: .color(L.shade.color(0.85)), lineWidth: lw * 0.75)
    }

    // MARK: Alien and coral

    private func orb(_ ctx: inout GraphicsContext, _ c: TreeGeometry.Clump) {
        guard pose.vis[c.node] > 0 else { return }
        let s = pose.leafScale(g.nodes[c.node].owner) * (1 + 0.05 * CGFloat(sin(pose.time * 1.6 + c.phase)) * pose.wind)
        guard s > 0.01 else { return }
        let o = center(c)
        let L = leaf
        let glowR = c.rx * 2.6 * s
        ctx.fill(Path(ellipseIn: CGRect(x: o.x - glowR, y: o.y - glowR, width: glowR * 2, height: glowR * 2)),
                 with: .radialGradient(Gradient(colors: [RGB(0xBFF2E2).color(0.38), RGB(0xBFF2E2).color(0)]), center: o, startRadius: 0, endRadius: glowR))
        // A smooth seed pod: teal-lit on top, violet underneath, a pale seed showing through.
        let rx = c.rx * s * 0.85, ry = c.ry * s * 0.95
        let pod = Path(ellipseIn: CGRect(x: o.x - rx, y: o.y - ry, width: rx * 2, height: ry * 2))
        let top = L.mix(RGB(0x7FD6C2), 0.55), under = L.mix(RGB(0x6A4C93), 0.6)
        ctx.fill(pod, with: .linearGradient(Gradient(colors: [top.lit.color(0.95), under.color(0.95)]),
                                            startPoint: CGPoint(x: o.x - rx * 0.5, y: o.y - ry), endPoint: CGPoint(x: o.x + rx * 0.4, y: o.y + ry)))
        let seed = Path(ellipseIn: CGRect(x: o.x - rx * 0.36, y: o.y - ry * 0.3, width: rx * 0.72, height: ry * 0.66))
        ctx.fill(seed, with: .radialGradient(Gradient(colors: [RGB(0xFFF4C8).color(0.95), RGB(0xF3D98A).color(0.4)]),
                                             center: CGPoint(x: o.x, y: o.y + ry * 0.03), startRadius: 0, endRadius: rx * 0.4))
        var shine = Path()
        shine.addArc(center: o, radius: min(rx, ry) * 0.78, startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
        ctx.stroke(shine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: lw * 0.9, lineCap: .round))
        ctx.stroke(pod, with: .color(PlantInk.ink.opacity(0.5)), lineWidth: lw * 0.6)
    }

    private func polyp(_ ctx: inout GraphicsContext, _ c: TreeGeometry.Clump) {
        guard pose.vis[c.node] > 0 else { return }
        let s = pose.leafScale(g.nodes[c.node].owner) * (1 + 0.08 * CGFloat(sin(pose.time * 1.3 + c.phase)) * pose.wind)
        guard s > 0.01 else { return }
        let o = center(c)
        let r = c.rx * s
        let L = leaf
        let knob = Path(ellipseIn: CGRect(x: o.x - r, y: o.y - r, width: r * 2, height: r * 2))
        ctx.fill(knob, with: .color(L.mix(L.lit, c.light * 0.5).color(0.9)))
        if fine {
            var ten = Path()
            for k in 0..<6 {
                let a = Double(k) / 6 * 2 * .pi + c.phase
                ten.move(to: CGPoint(x: o.x + CGFloat(cos(a)) * r, y: o.y + CGFloat(sin(a)) * r))
                ten.addLine(to: CGPoint(x: o.x + CGFloat(cos(a)) * r * 1.8, y: o.y + CGFloat(sin(a)) * r * 1.8))
            }
            ctx.stroke(ten, with: .color(L.color(0.6)), lineWidth: lw * 0.45)
        }
        ctx.stroke(knob, with: .color(PlantInk.ink.opacity(0.45)), lineWidth: lw * 0.45)
        ctx.fill(Path(ellipseIn: CGRect(x: o.x - r * 0.35, y: o.y - r * 0.35, width: r * 0.7, height: r * 0.7)), with: .color(RGB(0xFBE3D6).color(0.95)))
    }

    private func fan(_ ctx: inout GraphicsContext) {
        guard let root = g.nodes.first else { return }
        let prog: CGFloat = pose.owner == 0 && pose.progress < 1 ? TreeGrowth.easeOut(pose.progress) : 1
        let tr = CGAffineTransform(translationX: root.p.x, y: g.base.y).scaledBy(x: prog, y: prog)
        for l in g.fanLayers { ctx.fill(l.applying(tr), with: .color(leaf.color(0.06))) }
        if let e = g.fanLayers.first {
            ctx.stroke(e.applying(tr), with: .color(leaf.shade.color(0.12)), lineWidth: lw * 1.4)
        }
    }

    // MARK: Flytrap

    private func rosette(_ ctx: inout GraphicsContext, rnd: inout SeededRandom) {
        let L = leaf
        let scale = max(0.5, g.height / 300)
        for i in 0..<9 {
            let a = -.pi + Double(i) / 8 * .pi
            let len = rnd.cg(18, 30) * scale
            let path = Pen.leaf(at: g.base, angle: a, length: len * 1.3, width: 0.32)
            ctx.fill(path, with: .color(L.mix(L.lit, Double(i % 3) * 0.2).color(0.7)))
            ctx.stroke(path, with: .color(PlantInk.ink.opacity(0.4)), lineWidth: lw * 0.5)
        }
    }

    /// A flytrap leaf stalk: winged, widest near the end, with a midrib.
    private func petiole(_ ctx: inout GraphicsContext, _ chain: TreeGeometry.Chain) {
        let (pts, rr) = points(chain)
        guard pts.count >= 2 else { return }
        let L = leaf
        let n = CGFloat(max(1, pts.count - 1))
        let wing = pts.indices.map { i -> CGFloat in
            let t = CGFloat(i) / n
            return max(0.6, (rr.first ?? 2) * (0.5 + 1.5 * CGFloat(sin(Double(t) * .pi * 0.85))))
        }
        let shape = Pen.ribbon(pts, wing)
        ctx.fill(shape, with: .color(L.color(0.55)))
        let lit = Pen.ribbon(pts.enumerated().map { CGPoint(x: $1.x - wing[$0] * 0.25, y: $1.y - wing[$0] * 0.2) }, wing.map { $0 * 0.45 })
        ctx.fill(lit, with: .color(L.lit.color(0.45)))
        ctx.stroke(shape, with: .color(PlantInk.ink.opacity(0.45)), lineWidth: lw * 0.55)
        var rib = Path()
        Pen.addSmooth(&rib, pts, move: true)
        ctx.stroke(rib, with: .color(L.shade.color(0.6)), lineWidth: lw * 0.5)
    }

    /// Two hinged lobes with long teeth; open ones are red inside.
    private func trap(_ ctx: inout GraphicsContext, node: Int, size: CGFloat, open spread: CGFloat, mouth: Bool) {
        let n = g.nodes[node]
        let p = pose.p[node]
        let q = n.parent >= 0 ? pose.p[n.parent] : CGPoint(x: p.x, y: p.y + 1)
        let angle = atan2(Double(p.y - q.y), Double(p.x - q.x))
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(angle + .pi / 2))
        let w = size * 0.8, h = size * 0.65
        let L = leaf
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let tipPt = CGPoint(x: s * w * spread, y: -h)
            var lobe = Path()
            lobe.move(to: .zero)
            lobe.addQuadCurve(to: tipPt, control: CGPoint(x: s * w * (spread + 0.55), y: -h * 0.25))
            lobe.addQuadCurve(to: .zero, control: CGPoint(x: s * w * spread * 0.2, y: -h * 0.65))
            c.fill(lobe, with: .color(L.color(0.8)))
            c.fill(lobe, with: .linearGradient(Gradient(colors: [L.lit.color(0.5), L.color(0)]),
                                               startPoint: CGPoint(x: s * w * 0.6, y: -h * 0.2), endPoint: CGPoint(x: 0, y: -h * 0.6)))
            if mouth {
                var m = Path()
                m.move(to: CGPoint(x: s * w * spread * 0.1, y: -h * 0.2))
                m.addQuadCurve(to: CGPoint(x: tipPt.x * 0.92, y: tipPt.y * 0.92), control: CGPoint(x: s * w * (spread + 0.25), y: -h * 0.35))
                m.addQuadCurve(to: CGPoint(x: s * w * spread * 0.1, y: -h * 0.2), control: CGPoint(x: s * w * spread * 0.25, y: -h * 0.62))
                c.fill(m, with: .radialGradient(Gradient(colors: [RGB(0x8E1F2B).color(0.95), PlantInk.trapMouth.opacity(0.7)]),
                                                center: CGPoint(x: s * w * spread * 0.3, y: -h * 0.45), startRadius: 0, endRadius: h * 0.6))
            } else {
                c.fill(lobe, with: .color(PlantInk.trapMouth.opacity(0.2)))
            }
            c.stroke(lobe, with: .color(PlantInk.ink.opacity(0.8)), lineWidth: lw * 0.75)
            var teeth = Path()
            for k in 1..<10 {
                let t = CGFloat(k) / 10
                let rim = CGPoint(x: s * w * spread * 0.2 * (1 - t) + tipPt.x * t, y: -h * 0.65 * (1 - t) * (1 - t) + tipPt.y * t)
                teeth.move(to: rim)
                teeth.addQuadCurve(to: CGPoint(x: rim.x - s * size * 0.12, y: rim.y - size * 0.17), control: CGPoint(x: rim.x - s * size * 0.02, y: rim.y - size * 0.1))
            }
            c.stroke(teeth, with: .color(PlantInk.ink.opacity(0.7)), style: StrokeStyle(lineWidth: lw * 0.55, lineCap: .round))
        }
    }

    // MARK: Pencil branches

    private func ghost(_ ctx: inout GraphicsContext, _ gh: TreeGeometry.Ghost, rnd: inout SeededRandom) {
        let t = sketch[gh.id] ?? 1
        guard t > 0 else { return }
        let from = gh.node < pose.p.count ? pose.p[gh.node] : gh.from
        let dx = from.x - gh.from.x, dy = from.y - gh.from.y
        for pass in 0..<3 {
            var p = Path()
            let j = CGFloat(pass) * 0.9
            p.move(to: CGPoint(x: from.x + rnd.cg(-j, j), y: from.y + rnd.cg(-j, j)))
            p.addQuadCurve(to: CGPoint(x: gh.to.x + dx + rnd.cg(-j, j), y: gh.to.y + dy + rnd.cg(-j, j)),
                           control: CGPoint(x: gh.control.x + dx + rnd.cg(-3, 3), y: gh.control.y + dy + rnd.cg(-3, 3)))
            // The first pass draws on; the softer passes follow a beat behind, like going over a line.
            let reach = max(0, min(1, t * 1.25 - CGFloat(pass) * 0.12))
            guard reach > 0 else { continue }
            ctx.stroke(p.trimmedPath(from: 0, to: reach), with: .color(PlantInk.pencil.opacity(pass == 0 ? 0.75 : 0.3)),
                       style: StrokeStyle(lineWidth: lw * (pass == 0 ? 1 : 0.6), lineCap: .round, dash: pass == 0 ? [5, 3, 1, 3] : []))
        }
    }
}

// MARK: - The newer plants: kelp, dendrite, crystal, herb, cactus, fern, mushroom; blooms and tendrils

extension TreePainter {
    /// The leaf for this plant: the AI's pick for leafy trees, the plant's own otherwise.
    var leafUnit: Path {
        switch species {
        case .kelp: return Self.kelpUnit
        case .crystal: return Self.shardUnit
        case .oak, .willow, .herb:
            switch tree.look.leafShape ?? "" {
            case "lobed": return Self.oakUnit
            case "lance": return Self.lanceUnit
            case "oval": return Self.ovalUnit
            case "heart": return Self.heartUnit
            case "fan": return Self.fanUnit
            default: return species == .willow ? Self.lanceUnit : species == .herb ? Self.ovalUnit : Self.oakUnit
            }
        default: return Self.oakUnit
        }
    }

    static let ovalUnit: Path = {
        var p = Path()
        p.move(to: .zero)
        p.addCurve(to: CGPoint(x: 1, y: 0), control1: CGPoint(x: 0.12, y: -0.36), control2: CGPoint(x: 0.78, y: -0.3))
        p.addCurve(to: .zero, control1: CGPoint(x: 0.78, y: 0.3), control2: CGPoint(x: 0.12, y: 0.36))
        p.closeSubpath()
        return p
    }()

    static let heartUnit: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0.08, y: 0))
        p.addCurve(to: CGPoint(x: 1, y: 0), control1: CGPoint(x: -0.12, y: -0.62), control2: CGPoint(x: 0.62, y: -0.42))
        p.addCurve(to: CGPoint(x: 0.08, y: 0), control1: CGPoint(x: 0.62, y: 0.42), control2: CGPoint(x: -0.12, y: 0.62))
        p.closeSubpath()
        return p
    }()

    /// A ginkgo fan.
    static let fanUnit: Path = {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: 0.7, y: -0.5))
        p.addQuadCurve(to: CGPoint(x: 0.92, y: -0.04), control: CGPoint(x: 1.02, y: -0.32))
        p.addLine(to: CGPoint(x: 0.8, y: 0))
        p.addLine(to: CGPoint(x: 0.92, y: 0.04))
        p.addQuadCurve(to: CGPoint(x: 0.7, y: 0.5), control: CGPoint(x: 1.02, y: 0.32))
        p.closeSubpath()
        return p
    }()

    /// A long kelp blade with a ruffled edge.
    static let kelpUnit: Path = {
        var top: [CGPoint] = [], bottom: [CGPoint] = []
        let n = 40
        for i in 0...n {
            let x = CGFloat(i) / CGFloat(n)
            let env = 0.12 * CGFloat(sin(Double.pi * pow(Double(x), 0.65)))
            let ruffle = 1 + 0.2 * CGFloat(sin(Double(x) * 34))
            top.append(CGPoint(x: x, y: -env * ruffle))
            bottom.append(CGPoint(x: x, y: env * (2 - ruffle)))
        }
        var p = Path()
        p.move(to: .zero)
        for q in top { p.addLine(to: q) }
        for q in bottom.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        return p
    }()

    /// A crystal: a long hexagonal prism, pointed at both ends.
    static let shardUnit: Path = {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: 0.16, y: -0.15))
        p.addLine(to: CGPoint(x: 0.8, y: -0.15))
        p.addLine(to: CGPoint(x: 1, y: 0))
        p.addLine(to: CGPoint(x: 0.8, y: 0.15))
        p.addLine(to: CGPoint(x: 0.16, y: 0.15))
        p.closeSubpath()
        return p
    }()

    func shard(_ ctx: inout GraphicsContext, at base: CGPoint, angle: Double, length: CGFloat, value: Double, alpha: Double) {
        guard length > 0.5 else { return }
        let t = CGAffineTransform(translationX: base.x, y: base.y).rotated(by: CGFloat(angle)).scaledBy(x: length, y: length)
        let shape = Self.shardUnit.applying(t)
        let c = tone(value: value, hue: 0)
        ctx.fill(shape, with: .color(c.color(0.55 * alpha)))
        // The lit facet, the ridge, and a glint.
        var facet = Path()
        facet.move(to: .zero); facet.addLine(to: CGPoint(x: 0.16, y: -0.15)); facet.addLine(to: CGPoint(x: 0.8, y: -0.15))
        facet.addLine(to: CGPoint(x: 1, y: 0)); facet.closeSubpath()
        ctx.fill(facet.applying(t), with: .color(c.lit.lit.color(0.55 * alpha)))
        var ridge = Path()
        ridge.move(to: .zero); ridge.addLine(to: CGPoint(x: 1, y: 0))
        ctx.stroke(ridge.applying(t), with: .color(c.shade.color(0.6 * alpha)), lineWidth: max(0.3, lw * 0.4))
        var glint = Path()
        glint.move(to: CGPoint(x: 0.3, y: -0.08)); glint.addLine(to: CGPoint(x: 0.55, y: -0.08))
        ctx.stroke(glint.applying(t), with: .color(.white.opacity(0.85 * alpha)), style: StrokeStyle(lineWidth: max(0.4, lw * 0.6), lineCap: .round))
        ctx.stroke(shape, with: .color(PlantInk.ink.opacity(0.6 * alpha)), lineWidth: max(0.35, lw * 0.5))
    }

    // MARK: Stems and stalks

    func stem(_ ctx: inout GraphicsContext, _ chain: TreeGeometry.Chain, color: RGB, widen: CGFloat) {
        let (pts, rr) = points(chain)
        guard pts.count >= 2 else { return }
        let shape = Pen.ribbon(pts, rr.map { max(0.5, $0 * 0.55 * widen) })
        ctx.fill(shape, with: .color(color.color(0.95)))
        let lit = Pen.ribbon(pts.map { CGPoint(x: $0.x - 0.5, y: $0.y - 0.3) }, rr.map { max(0.2, $0 * 0.18 * widen) })
        ctx.fill(lit, with: .color(color.lit.color(0.55)))
        ctx.stroke(shape, with: .color(PlantInk.ink.opacity(0.5)), lineWidth: lw * 0.55)
    }

    /// Faint water lines and a few bubbles behind a kelp forest.
    func water(_ ctx: inout GraphicsContext) {
        var rnd = SeededRandom(tree.seed, "water")
        let top = g.base.y - g.height * 1.08
        let half = max(60, g.height * 0.6)
        var lines = Path()
        for k in 0..<5 {
            let y = top + CGFloat(k) * g.height * 0.2 + rnd.cg(-6, 6)
            var x = g.base.x - half * rnd.cg(0.6, 0.95)
            let end = g.base.x + half * rnd.cg(0.6, 0.95)
            lines.move(to: CGPoint(x: x, y: y))
            while x < end {
                x += 10
                lines.addLine(to: CGPoint(x: x, y: y + CGFloat(sin(Double(x) * 0.07 + pose.time * 0.6)) * 1.6))
            }
        }
        ctx.stroke(lines, with: .color(RGB(0x5E9AA0).color(0.16)), style: StrokeStyle(lineWidth: lw * 0.7, lineCap: .round, dash: [14, 6, 4, 6]))
        for k in 0..<10 {
            let rise = (pose.time * 0.05 + Double(k) * 0.1).truncatingRemainder(dividingBy: 1)
            let x = g.base.x + rnd.cg(-half, half) * 0.8
            let y = g.base.y - CGFloat(rise) * g.height * 1.05
            let r = rnd.cg(1.2, 2.6)
            ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(RGB(0x5E9AA0).color(0.35 * (1 - rise))), lineWidth: lw * 0.5)
        }
    }

    func holdfast(_ ctx: inout GraphicsContext) {
        var rnd = SeededRandom(tree.seed, "holdfast")
        var p = Path()
        let w = max(8, g.height * 0.06)
        for _ in 0..<9 {
            let s = CGPoint(x: g.base.x + rnd.cg(-w * 0.3, w * 0.3), y: g.base.y - 2)
            let e = CGPoint(x: g.base.x + rnd.cg(-w, w), y: g.base.y + rnd.cg(1, 4))
            p.move(to: s)
            p.addQuadCurve(to: e, control: CGPoint(x: (s.x + e.x) / 2 + rnd.cg(-4, 4), y: s.y - rnd.cg(0, 4)))
        }
        ctx.stroke(p, with: .color(RGB(0x6B5424).color(0.85)), style: StrokeStyle(lineWidth: lw * 1.1, lineCap: .round))
    }

    /// Gas floats at the base of kelp blades.
    func bladders(_ ctx: inout GraphicsContext) {
        for (k, lf) in g.leaves.enumerated() where k % 2 == 0 && !lf.back && lf.node < pose.p.count && pose.vis[lf.node] > 0 {
            let s = pose.leafScale(g.nodes[lf.node].owner)
            guard s > 0.2 else { continue }
            let p = pose.p[lf.node]
            let r = max(1.2, lf.length * 0.05) * s
            let c = CGPoint(x: p.x + lf.offset.x, y: p.y + lf.offset.y)
            let ball = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 1.15, width: r * 2, height: r * 2.3))
            ctx.fill(ball, with: .color(RGB(0xB49A45).color(0.95)))
            ctx.stroke(ball, with: .color(PlantInk.ink.opacity(0.55)), lineWidth: lw * 0.45)
        }
    }

    /// A fern frond: a curved stalk with paired leaflets that shrink toward the tip.
    func frond(_ ctx: inout GraphicsContext, _ chain: TreeGeometry.Chain, index: Int) {
        let (pts, _) = points(chain)
        guard pts.count >= 3 else { return }
        let owner = g.nodes[chain.ids[min(1, chain.ids.count - 1)]].owner
        let grow = pose.leafScale(owner)
        var rib = Path()
        Pen.addSmooth(&rib, pts, move: true)
        ctx.stroke(rib, with: .color(RGB(0x5E5134).color(0.9)), style: StrokeStyle(lineWidth: max(0.6, lw * (chain.side ? 0.7 : 1.1)), lineCap: .round))
        let L = max(4, g.height * (chain.side ? 0.045 : 0.07))
        let n = pts.count
        var rnd = SeededRandom(tree.seed &+ UInt64(index), "pinnae")
        var leaflets = Path(), shade = Path()
        for k in 1..<(n - 1) {
            let t = CGFloat(k) / CGFloat(n - 1)
            guard t > 0.12 else { continue }
            let a = pts[k - 1], b = pts[k + 1]
            let along = atan2(Double(b.y - a.y), Double(b.x - a.x))
            let len = L * (1 - 0.8 * t) * (0.55 + 0.45 * CGFloat(min(1, t * 4))) * grow
            guard len > 0.8 else { continue }
            for side in [-1.0, 1.0] {
                let ang = along + side * (1.05 - 0.25 * Double(t)) + rnd.range(-0.06, 0.06)
                let tr = CGAffineTransform(translationX: pts[k].x, y: pts[k].y).rotated(by: CGFloat(ang)).scaledBy(x: len, y: len * 1.2)
                if side < 0 { leaflets.addPath(Self.lanceUnit.applying(tr)) } else { shade.addPath(Self.lanceUnit.applying(tr)) }
            }
        }
        ctx.fill(shade, with: .color(leaf.mix(leaf.shade, 0.2).color(0.92)))
        ctx.fill(leaflets, with: .color(leaf.mix(leaf.lit, 0.15).color(0.92)))
        if fine {
            ctx.stroke(leaflets, with: .color(PlantInk.ink.opacity(0.35)), lineWidth: lw * 0.35)
            ctx.stroke(shade, with: .color(PlantInk.ink.opacity(0.35)), lineWidth: lw * 0.35)
        }
    }

    /// Young fronds still coiled, at the foot of the fern.
    func fiddleheads(_ ctx: inout GraphicsContext) {
        var rnd = SeededRandom(tree.seed, "fiddle")
        let r = max(3, g.height * 0.028)
        for k in 0..<3 {
            let x = g.base.x + CGFloat(k - 1) * r * 3.4 + rnd.cg(-r, r)
            let h = r * rnd.cg(2.2, 3.6)
            let top = CGPoint(x: x + r * 0.6, y: g.base.y - h)
            var stalk = Path()
            stalk.move(to: CGPoint(x: x, y: g.base.y))
            stalk.addQuadCurve(to: top, control: CGPoint(x: x - r * 0.4, y: g.base.y - h * 0.5))
            var coil = Path()
            coil.move(to: top)
            let nod = CGFloat(sin(pose.time * 0.8 + Double(k))) * 0.15 * pose.wind
            for j in 1...26 {
                let a = Double(j) * 0.36 + Double(nod)
                let rr = r * CGFloat(1 - Double(j) / 30)
                coil.addLine(to: CGPoint(x: top.x - r + CGFloat(cos(a)) * rr, y: top.y + CGFloat(sin(a)) * rr * -1))
            }
            ctx.stroke(stalk, with: .color(leaf.shade.color(0.9)), style: StrokeStyle(lineWidth: lw * 1.1, lineCap: .round))
            ctx.stroke(coil, with: .color(leaf.color(0.95)), style: StrokeStyle(lineWidth: lw * 1.3, lineCap: .round))
        }
    }

    // MARK: Mushroom

    func mycelium(_ ctx: inout GraphicsContext) {
        var rnd = SeededRandom(tree.seed, "mycelium")
        var p = Path()
        let half = max(50, g.height * 0.5)
        for _ in 0..<14 {
            var q = CGPoint(x: g.base.x + rnd.cg(-8, 8), y: g.base.y + 3)
            p.move(to: q)
            let dir = rnd.range(-1.4, 1.4)
            for _ in 0..<7 {
                let a = dir + rnd.range(-0.5, 0.5)
                q = CGPoint(x: q.x + CGFloat(sin(a)) * half * 0.12, y: q.y + abs(CGFloat(cos(a))) * half * 0.025 + 0.6)
                p.addLine(to: q)
            }
        }
        ctx.stroke(p, with: .color(RGB(0xBFB49A).color(0.7)), style: StrokeStyle(lineWidth: lw * 0.45, lineCap: .round))
    }

    func stalk(_ ctx: inout GraphicsContext, _ chain: TreeGeometry.Chain) {
        let (pts, rr) = points(chain)
        guard pts.count >= 2 else { return }
        let body = Pen.ribbon(pts, rr.map { max(1, $0 * 0.9) })
        ctx.fill(body, with: .color(RGB(0xEFE5CF).color(0.98)))
        let shade = Pen.ribbon(pts.map { CGPoint(x: $0.x + 0.6, y: $0.y) }, rr.map { max(0.4, $0 * 0.35) })
        ctx.fill(shade, with: .color(RGB(0xCDBE9C).color(0.6)))
        ctx.stroke(body, with: .color(PlantInk.ink.opacity(0.55)), lineWidth: lw * 0.6)
    }

    func caps(_ ctx: inout GraphicsContext) {
        let L = leaf
        for (k, chain) in g.chains.enumerated() {
            let (pts, rr) = points(chain)
            guard pts.count >= 2, let end = pts.last else { continue }
            let owner = g.nodes[chain.ids[min(1, chain.ids.count - 1)]].owner
            let s = pose.leafScale(owner)
            guard s > 0.02 else { continue }
            let prev = pts[pts.count - 2]
            let up = atan2(Double(end.y - prev.y), Double(end.x - prev.x)) + .pi / 2
            let w = max((rr.first ?? 3) * 3.4, chain.side ? g.cardSize.width * 0.45 : g.cardSize.width * 0.85) * s
            var c = ctx
            c.translateBy(x: end.x, y: end.y)
            c.rotate(by: .radians(up))
            let h = w * 0.62
            var dome = Path()
            dome.move(to: CGPoint(x: -w, y: 0))
            dome.addCurve(to: CGPoint(x: w, y: 0), control1: CGPoint(x: -w * 0.95, y: -h * 1.35), control2: CGPoint(x: w * 0.95, y: -h * 1.35))
            dome.addQuadCurve(to: CGPoint(x: -w, y: 0), control: CGPoint(x: 0, y: h * 0.28))
            var gills = Path()
            for j in 0..<9 {
                let x = -w * 0.8 + w * 1.6 * CGFloat(j) / 8
                gills.move(to: CGPoint(x: x * 0.3, y: h * 0.12)); gills.addLine(to: CGPoint(x: x, y: h * 0.06))
            }
            c.fill(dome, with: .linearGradient(Gradient(colors: [L.lit.color(0.98), L.color(0.98), L.shade.color(0.98)]),
                                               startPoint: CGPoint(x: -w * 0.5, y: -h), endPoint: CGPoint(x: w * 0.6, y: 0)))
            c.stroke(gills, with: .color(PlantInk.ink.opacity(0.35)), lineWidth: lw * 0.4)
            var rnd = SeededRandom(tree.seed &+ UInt64(k), "spots")
            for _ in 0..<5 {
                let x = rnd.cg(-0.6, 0.6) * w, y = -rnd.cg(0.25, 0.85) * h
                let r = w * rnd.cg(0.06, 0.11)
                c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.8, width: r * 2, height: r * 1.6)), with: .color(RGB(0xFBF4E2).color(0.92)))
            }
            c.stroke(dome, with: .color(PlantInk.ink.opacity(0.7)), lineWidth: lw * 0.7)
        }
        // A few small ones in the moss.
        var rnd = SeededRandom(tree.seed, "buttons")
        for k in 0..<4 {
            let x = g.base.x + CGFloat(k % 2 == 0 ? -1 : 1) * rnd.cg(14, 40) * max(0.6, g.height / 300)
            let w = rnd.cg(4, 8) * max(0.6, g.height / 300)
            let top = CGPoint(x: x, y: g.base.y - w * 1.4)
            var st = Path(); st.move(to: CGPoint(x: x, y: g.base.y)); st.addLine(to: top)
            ctx.stroke(st, with: .color(RGB(0xE9DDC4)), style: StrokeStyle(lineWidth: w * 0.45, lineCap: .round))
            var dome = Path()
            dome.move(to: CGPoint(x: x - w, y: top.y))
            dome.addQuadCurve(to: CGPoint(x: x + w, y: top.y), control: CGPoint(x: x, y: top.y - w * 1.3))
            dome.closeSubpath()
            ctx.fill(dome, with: .color(leaf.color(0.95)))
            ctx.stroke(dome, with: .color(PlantInk.ink.opacity(0.6)), lineWidth: lw * 0.5)
        }
    }

    // MARK: Cactus

    func cactusBody(_ ctx: inout GraphicsContext) {
        let L = leaf
        var limbs: [(Path, [CGPoint], [CGFloat])] = []
        for chain in g.chains {
            let (pts, rr) = points(chain)
            guard pts.count >= 2 else { continue }
            var shape = Pen.ribbon(pts, rr)
            if let e = pts.last, let r = rr.last { shape.addEllipse(in: CGRect(x: e.x - r, y: e.y - r, width: r * 2, height: r * 2)) }
            limbs.append((shape, pts, rr))
        }
        for (shape, _, _) in limbs { ctx.stroke(shape, with: .color(PlantInk.ink.opacity(0.65)), lineWidth: lw * 1.3) }
        for (shape, pts, rr) in limbs {
            ctx.fill(shape, with: .color(L.color(1)))
            let lit = Pen.ribbon(pts.enumerated().map { CGPoint(x: $1.x - rr[$0] * 0.35, y: $1.y) }, rr.map { $0 * 0.35 })
            ctx.fill(lit, with: .color(L.lit.color(0.5)))
        }
        // Ribs and spines.
        var ribs = Path(), spines = Path()
        for (_, pts, rr) in limbs where pts.count > 2 {
            for u in [-0.62, -0.2, 0.25, 0.66] as [CGFloat] {
                var line: [CGPoint] = []
                for i in pts.indices {
                    let a = pts[max(0, i - 1)], b = pts[min(pts.count - 1, i + 1)]
                    let len = max(0.001, hypot(b.x - a.x, b.y - a.y))
                    line.append(CGPoint(x: pts[i].x - (b.y - a.y) / len * rr[i] * u, y: pts[i].y + (b.x - a.x) / len * rr[i] * u))
                }
                Pen.addSmooth(&ribs, line, move: true)
                if fine {
                    for i in stride(from: 1, to: line.count, by: 2) {
                        let q = line[i]
                        let sp = max(1.2, rr[i] * 0.22)
                        for a in [-2.4, -1.57, -0.7] {
                            spines.move(to: q)
                            spines.addLine(to: CGPoint(x: q.x + CGFloat(cos(a)) * sp, y: q.y + CGFloat(sin(a)) * sp))
                        }
                    }
                }
            }
        }
        ctx.stroke(ribs, with: .color(L.shade.color(0.55)), lineWidth: lw * 0.6)
        ctx.stroke(spines, with: .color(RGB(0xF3EAD0).color(0.95)), lineWidth: lw * 0.45)
        ctx.stroke(spines, with: .color(PlantInk.ink.opacity(0.25)), lineWidth: lw * 0.2)
    }

    // MARK: Dendrite (a neuron)

    func soma(_ ctx: inout GraphicsContext) {
        let r = max(6, g.height * 0.07)
        let c = CGPoint(x: g.base.x, y: g.base.y - r * 0.7)
        var body = Path()
        for i in 0...24 {
            let a = Double(i) / 24 * 2 * .pi
            let k = 1 + 0.12 * sin(a * 3 + 0.5) + 0.05 * sin(pose.time * 1.2 + a)
            let p = CGPoint(x: c.x + CGFloat(cos(a) * k) * r * 1.15, y: c.y + CGFloat(sin(a) * k) * r * 0.9)
            if i == 0 { body.move(to: p) } else { body.addLine(to: p) }
        }
        body.closeSubpath()
        ctx.fill(body, with: .radialGradient(Gradient(colors: [leaf.lit.color(0.98), leaf.color(0.95), bark.color(0.95)]),
                                             center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.4))
        ctx.stroke(body, with: .color(PlantInk.ink.opacity(0.6)), lineWidth: lw * 0.8)
        let nr = r * 0.38
        let nucleus = Path(ellipseIn: CGRect(x: c.x - nr, y: c.y - nr * 0.9, width: nr * 2, height: nr * 1.8))
        ctx.fill(nucleus, with: .color(bark.color(0.7)))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - nr * 0.3, y: c.y - nr * 0.3, width: nr * 0.6, height: nr * 0.6)), with: .color(RGB(0xF2C14E).color(0.9)))
    }

    /// The axon, wrapped in myelin, running down into the ground.
    func axon(_ ctx: inout GraphicsContext) {
        let len = max(14, g.height * 0.16)
        var line = Path()
        line.move(to: g.base)
        line.addQuadCurve(to: CGPoint(x: g.base.x + len * 0.3, y: g.base.y + len), control: CGPoint(x: g.base.x - len * 0.2, y: g.base.y + len * 0.5))
        ctx.stroke(line, with: .color(bark.color(0.8)), style: StrokeStyle(lineWidth: lw * 1.2, lineCap: .round))
        for k in 0..<3 {
            let t = 0.25 + 0.25 * Double(k)
            let x = g.base.x + CGFloat(-0.2 * 2 * (1 - t) * t + 0.3 * t * t) * len
            let y = g.base.y + CGFloat(t) * len
            let sheath = Path(roundedRect: CGRect(x: x - 2.4 * lw, y: y - len * 0.08, width: 4.8 * lw, height: len * 0.16), cornerRadius: 2.4 * lw)
            ctx.fill(sheath, with: .color(RGB(0xF3E8D2).color(0.95)))
            ctx.stroke(sheath, with: .color(PlantInk.ink.opacity(0.45)), lineWidth: lw * 0.45)
        }
    }

    /// Dendritic spines along the fine branches, and signals running out along the big ones.
    func spines(_ ctx: inout GraphicsContext) {
        var p = Path()
        let maxR = g.nodes.map(\.r).max() ?? 1
        let len = max(1.5, g.height / 110)
        for (i, n) in g.nodes.enumerated() where i % 2 == 0 && n.parent >= 0 && n.r < maxR * 0.35 && pose.vis[i] >= 1 {
            let q = pose.p[i], o = pose.p[n.parent]
            let a = atan2(Double(q.y - o.y), Double(q.x - o.x)) + (i % 4 == 0 ? 1.4 : -1.4)
            let e = CGPoint(x: q.x + CGFloat(cos(a)) * len, y: q.y + CGFloat(sin(a)) * len)
            p.move(to: q); p.addLine(to: e)
            p.addEllipse(in: CGRect(x: e.x - len * 0.3, y: e.y - len * 0.3, width: len * 0.6, height: len * 0.6))
        }
        ctx.stroke(p, with: .color(bark.color(0.75)), lineWidth: lw * 0.4)
        // Signals: bright sparks travelling up the main dendrites.
        for (k, chain) in g.chains.prefix(8).enumerated() where chain.ids.count > 6 {
            let (pts, _) = points(chain)
            guard pts.count > 3 else { continue }
            let f = (pose.time * 0.22 + Double(k) * 0.37).truncatingRemainder(dividingBy: 1)
            let q = pts[min(pts.count - 1, Int(f * Double(pts.count - 1)))]
            let r = max(2, g.height / 120)
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - r * 2.5, y: q.y - r * 2.5, width: r * 5, height: r * 5)),
                     with: .radialGradient(Gradient(colors: [RGB(0xFFE7A0).color(0.8), RGB(0xFFE7A0).color(0)]), center: q, startRadius: 0, endRadius: r * 2.5))
        }
    }

    func bouton(_ ctx: inout GraphicsContext, _ c: TreeGeometry.Clump) {
        guard pose.vis[c.node] > 0 else { return }
        let s = pose.leafScale(g.nodes[c.node].owner)
        guard s > 0.01 else { return }
        let o = center(c)
        let r = c.rx * s
        let glow = 0.25 + 0.25 * sin(pose.time * 2 + c.phase) * Double(pose.wind)
        ctx.fill(Path(ellipseIn: CGRect(x: o.x - r * 3, y: o.y - r * 3, width: r * 6, height: r * 6)),
                 with: .radialGradient(Gradient(colors: [RGB(0xF2C14E).color(glow), RGB(0xF2C14E).color(0)]), center: o, startRadius: 0, endRadius: r * 3))
        let knob = Path(ellipseIn: CGRect(x: o.x - r, y: o.y - r, width: r * 2, height: r * 2))
        ctx.fill(knob, with: .color(leaf.lit.color(0.95)))
        ctx.stroke(knob, with: .color(PlantInk.ink.opacity(0.5)), lineWidth: lw * 0.45)
    }

    // MARK: Crystal circuit veins

    func circuit(_ ctx: inout GraphicsContext) {
        let maxR = g.nodes.map(\.r).max() ?? 1
        var traces = Path(), pads = Path()
        for chain in g.chains {
            let (pts, rr) = points(chain)
            guard pts.count > 4, (rr.max() ?? 0) > maxR * 0.22 else { continue }
            // A trace that runs in straight runs and 45 degree jogs, like a circuit board.
            var line: [CGPoint] = [pts[0]]
            for i in stride(from: 3, to: pts.count, by: 3) {
                let a = line.last!, b = pts[i]
                let dx = b.x - a.x, dy = b.y - a.y
                let m = min(abs(dx), abs(dy))
                line.append(CGPoint(x: a.x + (dx >= 0 ? m : -m), y: a.y + (dy >= 0 ? m : -m)))
                line.append(b)
            }
            traces.move(to: line[0])
            for q in line.dropFirst() { traces.addLine(to: q) }
            for (k, q) in line.enumerated() where k % 4 == 2 {
                let r = max(0.8, lw * 1.1)
                pads.addEllipse(in: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2))
            }
        }
        ctx.stroke(traces, with: .color(RGB(0xE3C46A).color(0.85)), style: StrokeStyle(lineWidth: max(0.5, lw * 0.6), lineCap: .round, lineJoin: .round))
        ctx.fill(pads, with: .color(RGB(0xF3DE96)))
        ctx.stroke(pads, with: .color(PlantInk.ink.opacity(0.5)), lineWidth: lw * 0.35)
    }

    // MARK: Tendrils

    func tendrils(_ ctx: inout GraphicsContext) {
        guard [.oak, .willow, .crystal, .herb, .alien, .coral, .dendrite, .conifer].contains(species) else { return }
        var isParent = [Bool](repeating: false, count: g.nodes.count)
        for n in g.nodes where n.parent >= 0 { isParent[n.parent] = true }
        let ends = g.nodes.indices.filter { !isParent[$0] && g.nodes[$0].parent >= 0 }
        guard !ends.isEmpty else { return }
        let stride = max(1, ends.count / 14)
        let r = max(3, g.height * 0.022)
        var p = Path()
        for (k, i) in ends.enumerated() where k % stride == 0 && pose.vis[i] >= 1 {
            let q = pose.p[i], o = pose.p[g.nodes[i].parent]
            var a = atan2(Double(q.y - o.y), Double(q.x - o.x))
            var at = q
            p.move(to: at)
            let turn = (k % 2 == 0 ? 1.0 : -1.0)
            let sway = sin(pose.time * 1.1 + Double(k)) * 0.04 * Double(pose.wind)
            for j in 0..<22 {
                let seg = r * CGFloat(0.55 - 0.018 * Double(j))
                a += turn * (0.12 + 0.03 * Double(j)) + sway
                at = CGPoint(x: at.x + CGFloat(cos(a)) * seg, y: at.y + CGFloat(sin(a)) * seg)
                p.addLine(to: at)
            }
        }
        ctx.stroke(p, with: .color(leaf.shade.color(0.85)), style: StrokeStyle(lineWidth: max(0.5, lw * 0.6), lineCap: .round, lineJoin: .round))
    }

    // MARK: Flowers, berries, fruit

    func bloomRGB(_ name: String?) -> RGB {
        switch name ?? "" {
        case "white": return RGB(0xF6F1E4)
        case "red": return RGB(0xC8423B)
        case "gold": return RGB(0xE8B53A)
        case "violet": return RGB(0x9B7BC8)
        case "blue": return RGB(0x6E93D6)
        default: return RGB(0xE89AB0)
        }
    }

    func blooms(_ ctx: inout GraphicsContext) {
        guard let kind = tree.look.bloom, kind != "none", ![.mushroom, .kelp, .dendrite].contains(species) else { return }
        let color = bloomRGB(tree.look.bloomTone)
        var spots: [(Int, CGPoint)] = []
        if species == .cactus {
            for chain in g.chains where chain.ids.count > 3 {
                let (pts, rr) = points(chain)
                guard pts.count > 3, let e = pts.last, let r = rr.last else { continue }
                spots.append((chain.ids[min(chain.ids.count - 1, pts.count - 1)], CGPoint(x: e.x - r * 0.4, y: e.y - r * 0.9)))
            }
        } else {
            var isParent = [Bool](repeating: false, count: g.nodes.count)
            for n in g.nodes where n.parent >= 0 { isParent[n.parent] = true }
            let ends = g.nodes.indices.filter { !isParent[$0] && g.nodes[$0].parent >= 0 }
            let stride = max(1, ends.count / 26)
            let card = g.cardSize
            for (k, i) in ends.enumerated() where k % stride == 0 {
                let rest = g.nodes[i].p
                if g.cardCenters.values.contains(where: { abs($0.x - rest.x) < card.width * 0.6 && abs($0.y - rest.y) < card.height * 0.6 }) { continue }
                spots.append((i, pose.p[i]))
            }
        }
        let size = max(2.6, g.height * 0.02)
        for (k, (i, at)) in spots.enumerated() where i < pose.vis.count && pose.vis[i] >= 1 {
            let s = pose.leafScale(g.nodes[i].owner)
            guard s > 0.05 else { continue }
            let r = size * s
            switch kind {
            case "berry":
                for j in 0..<3 {
                    let a = Double(j) * 2.1 + Double(k)
                    let c = CGPoint(x: at.x + CGFloat(cos(a)) * r * 0.8, y: at.y + r * 0.9 + CGFloat(sin(a)) * r * 0.5)
                    let b = Path(ellipseIn: CGRect(x: c.x - r * 0.62, y: c.y - r * 0.62, width: r * 1.24, height: r * 1.24))
                    ctx.fill(b, with: .color(color.color(0.98)))
                    ctx.stroke(b, with: .color(PlantInk.ink.opacity(0.55)), lineWidth: lw * 0.4)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.3, y: c.y - r * 0.35, width: r * 0.25, height: r * 0.25)), with: .color(.white.opacity(0.8)))
                }
            case "fruit":
                let c = CGPoint(x: at.x, y: at.y + r * 1.6)
                var st = Path(); st.move(to: at); st.addLine(to: CGPoint(x: c.x, y: c.y - r * 1.1))
                ctx.stroke(st, with: .color(bark.color(0.9)), lineWidth: lw * 0.6)
                let f = Path(ellipseIn: CGRect(x: c.x - r * 1.25, y: c.y - r * 1.15, width: r * 2.5, height: r * 2.4))
                ctx.fill(f, with: .radialGradient(Gradient(colors: [color.lit.color(1), color.color(1), color.shade.color(1)]),
                                                  center: CGPoint(x: c.x - r * 0.4, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.9))
                ctx.stroke(f, with: .color(PlantInk.ink.opacity(0.6)), lineWidth: lw * 0.5)
            default:
                var petals = Path()
                let spin = Double(k) * 0.7 + sin(pose.time * 0.8 + Double(k)) * 0.05 * Double(pose.wind)
                for j in 0..<5 {
                    let a = spin + Double(j) / 5 * 2 * .pi
                    let tr = CGAffineTransform(translationX: at.x, y: at.y).rotated(by: CGFloat(a))
                    petals.addPath(Path(ellipseIn: CGRect(x: r * 0.15, y: -r * 0.42, width: r * 1.05, height: r * 0.84)).applying(tr))
                }
                ctx.fill(petals, with: .color(color.color(0.97)))
                ctx.stroke(petals, with: .color(color.shade.color(0.7)), lineWidth: lw * 0.4)
                ctx.fill(Path(ellipseIn: CGRect(x: at.x - r * 0.3, y: at.y - r * 0.3, width: r * 0.6, height: r * 0.6)), with: .color(RGB(0xE8B53A)))
            }
        }
    }
}
