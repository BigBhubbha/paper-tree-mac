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
            default: return RGB(0x7F9C6B)
            }
        }
    }
    static func barkRGB(_ s: Species) -> RGB {
        switch s {
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
        guard dt >= 0, dt < duration else { return nil }
        return (tree.papers.count - 1, CGFloat(dt / duration))
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

    var body: some View {
        Canvas { ctx, size in
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
        var rnd = SeededRandom(tree.seed, "ink")
        ground(&ctx, rnd: &rnd)
        if tree.papers.isEmpty || g.nodes.isEmpty { seed(&ctx); return }

        if species == .coral { fan(&ctx) }
        if species == .oak || species == .willow {
            for c in g.clumps where c.kind == .leaves { leafMass(&ctx, c, pass: .shadow) }
            for c in g.clumps where c.kind == .leaves && !c.front { leafMass(&ctx, c, pass: .body) }
        }
        for gh in g.ghosts { ghost(&ctx, gh, rnd: &rnd) }

        if species == .flytrap {
            rosette(&ctx, rnd: &rnd)
            for chain in g.chains { petiole(&ctx, chain) }
        } else {
            woods(&ctx)
            if species != .coral { roots(&ctx, rnd: &rnd) }
        }

        switch species {
        case .oak, .willow:
            if species == .willow { for s in g.strands { strand(&ctx, s) } }
            for c in g.clumps where c.kind == .leaves && c.front { leafMass(&ctx, c, pass: .body) }
            for c in g.clumps where c.kind == .leaves { leafMass(&ctx, c, pass: .detail) }
        case .conifer:
            for t in g.tiers { tier(&ctx, t) }
            sprays(&ctx)
        case .alien:
            for c in g.clumps { orb(&ctx, c) }
        case .coral:
            for c in g.clumps { polyp(&ctx, c) }
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

    private func leafMass(_ ctx: inout GraphicsContext, _ c: TreeGeometry.Clump, pass: Pass) {
        guard pose.vis[c.node] > 0 else { return }
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
        let L = leaf
        for k in 1...s.leaves {
            let t = CGFloat(k) / CGFloat(s.leaves + 1)
            let u = 1 - t
            let q = CGPoint(x: u * u * p.x + 2 * u * t * ctrl.x + t * t * end.x, y: u * u * p.y + 2 * u * t * ctrl.y + t * t * end.y)
            let side: Double = k % 2 == 0 ? 1 : -1
            let tint = (s.tint + Double(k) * 0.13).truncatingRemainder(dividingBy: 1)
            let path = Pen.leaf(at: q, angle: .pi / 2 + side * 0.6, length: max(4, g.crownRadius * 0.24) * (0.7 + 0.3 * u), width: 0.28)
            ctx.fill(path, with: .color(L.shade.mix(L.lit, tint).color(0.85)))
        }
    }

    // MARK: Conifer

    private func tier(_ ctx: inout GraphicsContext, _ t: TreeGeometry.Tier) {
        guard pose.vis[t.node] > 0 else { return }
        let a = pose.p[t.node]
        let L = leaf
        let body = L.mix(L.lit, t.light * 0.45)
        let tr = CGAffineTransform(translationX: a.x, y: a.y)
        for l in t.layers { ctx.fill(l.applying(tr), with: .color(body.color(0.24))) }
        if let edge = t.layers.first {
            let e = edge.applying(tr)
            ctx.stroke(e, with: .color(L.shade.color(0.45)), lineWidth: lw * 0.6)
            if fine {
                var gctx = ctx
                gctx.blendMode = .multiply
                gctx.opacity = 0.3
                gctx.fill(e, with: .tiledImage(Grain.image, origin: .zero, sourceRect: CGRect(x: 0, y: 0, width: 1, height: 1), scale: 1))
            }
        }
        // Needle chevrons in rows, lighter where the light falls.
        var rnd = SeededRandom(tree.seed &+ UInt64(t.node), "needles")
        var chev = Path()
        let scale = max(0.5, g.height / 300)
        let rows = max(1, Int(t.height / (8 * scale)))
        let top = a.y + (t.layers.first?.boundingRect.minY ?? 0)
        for r in 0..<rows {
            let y = top + (CGFloat(r) + 0.9) * t.height / CGFloat(rows + 1)
            let w = t.half * ((y - top) / max(1, t.height)) * 0.85
            var x = a.x - w
            while x < a.x + w {
                chev.move(to: CGPoint(x: x - 2.4 * scale, y: y + 2.6 * scale))
                chev.addLine(to: CGPoint(x: x, y: y))
                chev.addLine(to: CGPoint(x: x + 2.4 * scale, y: y + 2.6 * scale))
                x += 6.5 * scale + rnd.cg(0, 2)
            }
        }
        ctx.stroke(chev, with: .color(L.lit.color(0.42)), lineWidth: lw * 0.55)
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
        let glowR = c.rx * 2.8 * s
        ctx.fill(Path(ellipseIn: CGRect(x: o.x - glowR, y: o.y - glowR, width: glowR * 2, height: glowR * 2)),
                 with: .radialGradient(Gradient(colors: [L.lit.color(0.42), L.lit.color(0)]), center: o, startRadius: 0, endRadius: glowR))
        for l in c.layers { ctx.fill(layer(l, at: o, rx: c.rx * s, ry: c.ry * s), with: .color(L.mix(RGB(0x7B5BA6), 0.25).color(0.2))) }
        let core = Path(ellipseIn: CGRect(x: o.x - c.rx * 0.32 * s, y: o.y - c.ry * 0.4 * s, width: c.rx * 0.64 * s, height: c.ry * 0.8 * s))
        ctx.fill(core, with: .color(RGB(0xF3E7B8).color(0.8)))
        if let edge = c.layers.first {
            ctx.stroke(layer(edge, at: o, rx: c.rx * s, ry: c.ry * s), with: .color(PlantInk.ink.opacity(0.5)), lineWidth: lw * 0.6)
        }
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
        if fine, let e = g.fanLayers.first {
            var gctx = ctx
            gctx.blendMode = .multiply
            gctx.opacity = 0.16
            gctx.fill(e.applying(tr), with: .tiledImage(Grain.image, origin: .zero, sourceRect: CGRect(x: 0, y: 0, width: 1, height: 1), scale: 1))
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
