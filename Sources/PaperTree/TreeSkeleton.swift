// The living structure of a tree. The paper branches laid out in TreeArt become chains of nodes;
// then the crown fills in by space colonization (Runions et al., 2007): points scattered in the
// crown pull the nearest twig toward them until every point is reached. Limb thickness follows the
// pipe model (a limb is as thick as the twigs it carries), so trunks swell and twigs stay fine.
// Foliage, needles, polyps and pods are laid out here once; the painter only poses and paints them.
import SwiftUI

extension SeededRandom {
    /// A normal draw (mean 0, spread 1), for paint that bleeds by a natural amount.
    mutating func gauss() -> Double {
        let u = max(1e-9, next()), v = next()
        return sqrt(-2 * log(u)) * cos(2 * .pi * v)
    }
}

/// Watercolor shapes: a polygon deformed again and again, stacked in many nearly clear layers
/// (Tyler Hobbs' method). Every layer differs in its fine edge, so edges bloom softly like real paint.
enum Wash {
    static func deform(_ pts: [CGPoint], rounds: Int, amount: CGFloat, rnd: inout SeededRandom) -> [CGPoint] {
        var cur = pts
        for _ in 0..<rounds {
            var next: [CGPoint] = []
            next.reserveCapacity(cur.count * 2)
            for i in cur.indices {
                let a = cur[i], c = cur[(i + 1) % cur.count]
                next.append(a)
                let len = hypot(c.x - a.x, c.y - a.y)
                next.append(CGPoint(x: (a.x + c.x) / 2 + CGFloat(rnd.gauss()) * len * amount,
                                    y: (a.y + c.y) / 2 + CGFloat(rnd.gauss()) * len * amount))
            }
            cur = next
        }
        return cur
    }

    static func polygon(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    /// A blot about the size of a unit circle (scale it when you paint it).
    static func blob(sides: Int = 9, layers: Int, squash: CGFloat = 1, rnd: inout SeededRandom) -> [Path] {
        var base: [CGPoint] = (0..<sides).map { i in
            let a = Double(i) / Double(sides) * 2 * .pi + rnd.range(-0.2, 0.2)
            let r = rnd.cg(0.82, 1.08)
            return CGPoint(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r * squash)
        }
        base = deform(base, rounds: 2, amount: 0.3, rnd: &rnd)
        return (0..<layers).map { _ in polygon(deform(base, rounds: 2, amount: 0.36, rnd: &rnd)) }
    }

    /// Layers for a given outline (a conifer tier, a coral fan), in the outline's own coordinates.
    static func layers(of outline: [CGPoint], count: Int, amount: CGFloat, rnd: inout SeededRandom) -> [Path] {
        let base = deform(outline, rounds: 1, amount: amount, rnd: &rnd)
        return (0..<count).map { _ in polygon(deform(base, rounds: 2, amount: amount * 1.4, rnd: &rnd)) }
    }
}

extension TreeGeometry {
    struct Node {
        var p: CGPoint
        var parent: Int
        /// The paper (by order added) this wood belongs to.
        var owner: Int
        /// 0...1 along the paper's own branch; above 1 for the fine growth that fills the crown.
        var along: CGFloat
        var r: CGFloat = 0.5
        /// How much it bends in the wind: thin twigs a lot, the trunk not at all.
        var flex: CGFloat = 0
        var phase: Double = 0
    }
    struct Chain { var ids: [Int]; var side: Bool }
    enum ClumpKind { case leaves, polyp, orb }
    struct Dab { var p: CGPoint; var angle: Double; var len: CGFloat; var tint: Double }
    struct Clump {
        /// 1 is full foliage; less where a paper card sits, so its page stays readable.
        var thin: CGFloat = 1
        var node: Int
        var offset: CGPoint
        var rx: CGFloat
        var ry: CGFloat
        /// 0 = in shadow, 1 = lit (light comes from the upper left, as on a plate).
        var light: Double
        var kind: ClumpKind
        var layers: [Path]
        var dabs: [Dab]
        var front: Bool
        var phase: Double
    }
    /// One leaf on a twig: where it sits relative to its node, which way it points, and its color.
    struct Leaf {
        var node: Int
        var offset: CGPoint
        var angle: Double
        var length: CGFloat
        /// -1 dark to 1 light, and -1 cool to 1 warm: small shifts so a crown isn't one flat color.
        var value: Double
        var hue: Double
        var phase: Double
        /// Behind the branches.
        var back: Bool
        /// Under a paper card: drawn faint so the page stays readable.
        var dim = false
    }
    struct Strand { var node: Int; var length: CGFloat; var lean: CGFloat; var phase: Double; var leaves: Int; var tint: Double }
    struct Tier { var node: Int; var offset: CGPoint; var layers: [Path]; var half: CGFloat; var height: CGFloat; var light: Double }

    static func resample(_ pts: [CGPoint], step: CGFloat) -> [CGPoint] {
        guard pts.count > 1 else { return pts }
        let total = pathLength(pts)
        let n = max(2, Int((total / step).rounded()))
        var out: [CGPoint] = []
        for k in 0...n { out.append(point(on: pts, atLength: total * CGFloat(k) / CGFloat(n))) }
        // Two passes of smoothing so the limb curves instead of kinking at the layout points.
        for _ in 0..<2 where out.count > 2 {
            var s = out
            for i in 1..<(out.count - 1) {
                s[i] = CGPoint(x: (out[i - 1].x + out[i].x * 2 + out[i + 1].x) / 4, y: (out[i - 1].y + out[i].y * 2 + out[i + 1].y) / 4)
            }
            out = s
        }
        return out
    }

    static func point(on pts: [CGPoint], atLength d: CGFloat) -> CGPoint {
        var left = d
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let l = hypot(b.x - a.x, b.y - a.y)
            if left <= l || i == pts.count - 1 {
                let t = l > 0 ? min(1, left / l) : 0
                return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            left -= l
        }
        return pts.last!
    }

    func nearestNode(to p: CGPoint) -> Int {
        var best = 0, bd = CGFloat.greatestFiniteMagnitude
        for (i, n) in nodes.enumerated() {
            let d = (n.p.x - p.x) * (n.p.x - p.x) + (n.p.y - p.y) * (n.p.y - p.y)
            if d < bd { bd = d; best = i }
        }
        return best
    }

    mutating func buildSkeleton(_ tree: PaperTreeData) {
        let real = tree.look.species
        let species = real.family
        let st = tree.structure
        var rnd = SeededRandom(st?.seed ?? tree.seed, "skeleton")
        let H = max(height, 24)
        let D = max(2.4, H / 34)
        let fromBase = real.fromBase
        var rootTarget: [Int: CGFloat] = [:]
        /// The width each node was laid out with, for plants whose arms stay thick (cactus).
        var laid: [Int: CGFloat] = [:]

        // 1. The paper branches become chains of nodes.
        for limb in limbs + twigs {
            let pts = Self.resample(limb.points, step: D)
            guard pts.count > 1 else { continue }
            let isRoot = limb.depth == 0 || (fromBase && limb.depth == 1) || nodes.isEmpty
            var parent: Int
            if isRoot {
                nodes.append(Node(p: pts[0], parent: -1, owner: limb.owner, along: 0))
                parent = nodes.count - 1
                rootTarget[parent] = max(1, limb.w0 / 2 * (species == .coral ? 0.55 : 1))
                if limb.depth == 0 { trunkNodes.append(parent) }
            } else {
                parent = nearestNode(to: pts[0])
            }
            let total = CGFloat(pts.count - 1)
            if isRoot { laid[parent] = limb.w0 / 2 }
            for k in 1..<pts.count {
                nodes.append(Node(p: pts[k], parent: parent, owner: limb.owner, along: CGFloat(k) / total))
                parent = nodes.count - 1
                let f = CGFloat(k) / total
                laid[parent] = (limb.w0 + (limb.w1 - limb.w0) * f) / 2
                if limb.depth == 0 { trunkNodes.append(parent) }
            }
            if limb.depth == 3 { twigEnds.append(parent) }
        }
        guard !nodes.isEmpty else { return }
        for i in tips.indices { tips[i].node = nearestNode(to: tips[i].point) }
        for i in ghosts.indices { ghosts[i].node = nearestNode(to: ghosts[i].from) }

        // 2. The crown fills in.
        let vigor = CGFloat(tree.look.recipe?.density ?? tree.look.vigor)
        let R = max(cardSize.height * 0.85, H * 0.15) * (0.85 + 0.3 * vigor)
        crownRadius = R
        var att: [CGPoint] = []
        let floorY = base.y - H * (species == .coral ? 0.1 : st?.crown == .weeping ? 0.08 : 0.28)
        func scatter(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ n: Int) {
            for _ in 0..<n {
                let a = rnd.range(0, 2 * .pi), d = CGFloat(sqrt(rnd.next()))
                let p = CGPoint(x: c.x + CGFloat(cos(a)) * d * rx, y: c.y + CGFloat(sin(a)) * d * ry)
                if p.y < floorY { att.append(p) }
            }
        }
        var bias = CGVector(dx: 0, dy: 0)
        var swirl = 0.0
        var step = D
        // The crown: one envelope over all the paper tips (and the top of the trunk), plus a cloud
        // around each tip so every paper sits in leaves.
        var hull = tips.reduce(CGRect.null) { $0.union(CGRect(origin: $1.point, size: .zero)) }
        if let top = trunkNodes.last { hull = hull.union(CGRect(origin: nodes[top].p, size: .zero)) }
        if hull.isNull { hull = CGRect(x: base.x, y: base.y - H, width: 0, height: 0) }
        let shapedCrown = st != nil && (species == .oak || species == .willow) && !fromBase
        if shapedCrown, let sh = st {
            // The recipe's crown shape sets the envelope the crown grows into.
            for e in scaffoldEnds { hull = hull.union(CGRect(origin: e, size: .zero)) }
            let density = tree.look.recipe?.density ?? 0.5
            let dens = 0.55 + 0.9 * (sh.crown == .columnar ? max(density, 0.7) : density)
            let n = Int(Double(140 + 10 * tips.count + 8 * scaffoldEnds.count) * dens)
            let W = hull.width / 2, Hh = hull.height / 2
            switch sh.crown {
            case .round:
                scatter(CGPoint(x: hull.midX, y: hull.midY - R * 0.25), W + R * 0.95, Hh + R * 0.85, n)
                bias = CGVector(dx: 0, dy: -0.15)
            case .columnar:
                // A full column from low on the trunk to above the top.
                let top = min(hull.minY, base.y - H) - R * 0.5, low = base.y - H * 0.22
                scatter(CGPoint(x: (hull.midX + base.x) / 2, y: (top + low) / 2), max(W, R * 0.55) + R * 0.4, (low - top) / 2, n)
                bias = CGVector(dx: 0, dy: -0.2)
            case .vase:
                // Narrow low down, wide at the top.
                let top = hull.minY - R * 0.9, bottom = max(hull.maxY, base.y - H * 0.45)
                var made = 0, tries = 0
                while made < n && tries < n * 6 {
                    tries += 1
                    let y = top + CGFloat(rnd.next()) * (bottom - top)
                    let v = 1 - (y - top) / max(1, bottom - top)
                    let half = (W + R * 0.9) * (0.3 + 0.7 * v)
                    let p = CGPoint(x: hull.midX + CGFloat(rnd.range(-1, 1)) * half, y: y)
                    if p.y < floorY { att.append(p); made += 1 }
                }
                bias = CGVector(dx: 0, dy: -0.25)
            case .spreading:
                scatter(CGPoint(x: hull.midX, y: hull.midY - R * 0.15), W + R * 1.35, Hh * 0.75 + R * 0.45, n)
                bias = CGVector(dx: 0, dy: -0.04)
            case .weeping:
                // Curtains: the crown reaches far down toward the ground.
                scatter(CGPoint(x: hull.midX, y: hull.midY + R * 0.5), W + R * 1.05, Hh + R * 1.3, n)
                bias = CGVector(dx: 0, dy: 0.45)
            case .windswept:
                scatter(CGPoint(x: hull.midX + CGFloat(sh.side) * R * 0.7, y: hull.midY - R * 0.1), W + R * 1.15, Hh * 0.7 + R * 0.5, n)
                bias = CGVector(dx: CGFloat(sh.side) * 0.38, dy: -0.04)
            }
            for t in tips { scatter(CGPoint(x: t.point.x, y: t.point.y - R * 0.15), R * 1.0, R * 0.75, 10) }
            step = D * 1.3
        } else {
        switch species {
        case .oak:
            // Fewer crown points and a longer reach: an open crown of distinct limbs, not a thicket.
            scatter(CGPoint(x: hull.midX, y: hull.midY - R * 0.25), hull.width / 2 + R * 0.95, hull.height / 2 + R * 0.85, 170 + 12 * tips.count)
            for t in tips { scatter(CGPoint(x: t.point.x, y: t.point.y - R * 0.2), R * 1.1, R * 0.8, 12) }
            bias = CGVector(dx: 0, dy: -0.15)
            step = D * 1.3
        case .willow:
            scatter(CGPoint(x: hull.midX, y: hull.midY - R * 0.2), hull.width / 2 + R * 0.9, hull.height / 2 + R * 0.5, 90 + 7 * tips.count)
            for t in tips { scatter(CGPoint(x: t.point.x, y: t.point.y - R * 0.05), R * 1.05, R * 0.6, 7) }
            bias = CGVector(dx: 0, dy: 0.2)
            step = D * 1.3
        case .alien:
            for t in tips { scatter(t.point, R * 1.0, R * 1.0, 22) }
            swirl = 0.42
            step = D * 1.2
        case .coral:
            let reach = tips.map { hypot($0.point.x - base.x, $0.point.y - base.y) }.max() ?? H
            for _ in 0..<(150 + 20 * tips.count) {
                let a = rnd.range(-1.3, 1.3), d = reach * CGFloat(0.22 + 0.85 * sqrt(rnd.next()))
                let p = CGPoint(x: base.x + CGFloat(sin(a)) * d, y: base.y - CGFloat(cos(a)) * d * 0.95)
                if p.y < floorY { att.append(p) }
            }
            bias = CGVector(dx: 0, dy: -0.1)
            step = D * 0.8
        default:
            break
        }
        }
        if att.count > 640 { att = Array(att.prefix(640)) }
        let open = species == .oak || species == .willow
        if !att.isEmpty { colonize(&att, step: step, influence: R * 1.3, kill: step * (species == .oak ? 2.4 : open ? 2.9 : 1.7), bias: bias, swirl: swirl, maxNodes: 1200) }

        // 3. Pull new nodes a little toward their parent: softer branching angles.
        let before = nodes.map(\.p)
        for i in nodes.indices where nodes[i].along > 1 && nodes[i].parent >= 0 {
            let q = before[nodes[i].parent]
            nodes[i].p = CGPoint(x: before[i].x + (q.x - before[i].x) * 0.35, y: before[i].y + (q.y - before[i].y) * 0.35)
        }

        // 4. Thickness by the pipe model, scaled so every root keeps its laid-out width.
        var kids = [[Int]](repeating: [], count: nodes.count)
        for i in nodes.indices where nodes[i].parent >= 0 { kids[nodes[i].parent].append(i) }
        var raw = [CGFloat](repeating: 1, count: nodes.count)
        let n: CGFloat = 2.0
        for i in nodes.indices.reversed() where !kids[i].isEmpty {
            raw[i] = pow(kids[i].reduce(CGFloat(0)) { $0 + pow(raw[$1], n) }, 1 / n)
        }
        let minR = max(0.45, H / 560)
        var root = [Int](repeating: 0, count: nodes.count)
        for i in nodes.indices { root[i] = nodes[i].parent < 0 ? i : root[nodes[i].parent] }
        for i in nodes.indices {
            let rt = root[i]
            let target = rootTarget[rt] ?? 2
            let top = max(raw[rt], 1.0001)
            var r: CGFloat
            if top < 1.6 {
                r = target
            } else {
                let k = log(max(target / minR, 1.01)) / log(top)
                r = minR * pow(raw[i], k)
            }
            if nodes[i].along <= 1 { r *= 1 - 0.3 * nodes[i].along }
            nodes[i].r = max(minR, r)
            if real == .cactus, let w = laid[i] { nodes[i].r = max(minR, w) }
        }
        let maxR = nodes.map(\.r).max() ?? 1
        maxRadius = maxR
        for i in nodes.indices {
            nodes[i].flex = pow(max(0, 1 - nodes[i].r / maxR), 1.5)
            nodes[i].phase = Double(nodes[i].p.x) * 0.017 + rnd.range(0, 0.6)
        }

        // 5. Chains: follow the thickest child; every other child starts a chain of its own.
        var stack: [Chain] = nodes.indices.filter { nodes[$0].parent < 0 }.map { Chain(ids: [$0], side: false) }
        while var chain = stack.popLast() {
            var cur = chain.ids.last!
            while true {
                let ks = kids[cur].sorted { nodes[$0].r > nodes[$1].r }
                guard let main = ks.first else { break }
                for k in ks.dropFirst() { stack.append(Chain(ids: [cur, k], side: true)) }
                chain.ids.append(main)
                cur = main
            }
            chains.append(chain)
        }
        chains.sort { nodes[$0.ids[min(1, $0.ids.count - 1)]].r > nodes[$1.ids[min(1, $1.ids.count - 1)]].r }

        // 6. Leaves, needles, polyps, pods.
        let terminals = nodes.indices.filter { kids[$0].isEmpty }
        var fr = SeededRandom(st?.seed ?? tree.seed, "foliage")
        let pts = terminals.map { nodes[$0].p }
        let box = pts.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }.insetBy(dx: -1, dy: -1)
        func lightAt(_ p: CGPoint) -> Double {
            let u = Double((p.x - box.midX) / max(1, box.width / 2)), v = Double((p.y - box.midY) / max(1, box.height / 2))
            return max(0, min(1, 0.55 - 0.32 * u - 0.38 * v))
        }
        func dabs(_ count: Int) -> [Dab] {
            (0..<count).map { _ in
                let a = fr.range(0, 2 * .pi)
                let rr = CGFloat(fr.range(0.45, 1.0))
                return Dab(p: CGPoint(x: CGFloat(cos(a)) * rr, y: CGFloat(sin(a)) * rr),
                           angle: a + fr.range(-0.7, 0.7),
                           len: fr.cg(0.2, 0.34),
                           tint: max(0, min(1, 0.5 + 0.5 * cos(a - 3.93) + fr.range(-0.2, 0.2))))
            }
        }
        func grouped(_ cell: CGFloat) -> [(Int, CGPoint, Int)] {
            var groups: [String: [Int]] = [:]
            for t in terminals {
                let p = nodes[t].p
                groups["\(Int(floor(p.x / cell))),\(Int(floor(p.y / cell)))", default: []].append(t)
            }
            return groups.keys.sorted().map { key in
                let ids = groups[key]!
                let mean = CGPoint(x: ids.reduce(0) { $0 + nodes[$1].p.x } / CGFloat(ids.count),
                                   y: ids.reduce(0) { $0 + nodes[$1].p.y } / CGFloat(ids.count))
                let anchor = ids.min { hypot(nodes[$0].p.x - mean.x, nodes[$0].p.y - mean.y) < hypot(nodes[$1].p.x - mean.x, nodes[$1].p.y - mean.y) }!
                return (anchor, mean, ids.count)
            }
        }

        switch real {
        case .oak, .willow:
            let willow = species == .willow
            let cell = R * (willow ? 0.6 : 0.78)
            for (k, (anchor, mean, count)) in grouped(cell).enumerated() {
                let rx = min(cell * 1.45, max(cell * 0.62, cell * (0.72 + 0.14 * CGFloat(count).squareRoot())))
                clumps.append(Clump(node: anchor, offset: CGPoint(x: mean.x - nodes[anchor].p.x, y: mean.y - nodes[anchor].p.y),
                                    rx: rx, ry: rx * (willow ? 0.55 : 0.8), light: lightAt(mean), kind: .leaves,
                                    layers: Wash.blob(layers: 5, squash: 1, rnd: &fr), dabs: dabs(willow ? 6 : 14),
                                    front: k % 4 != 0, phase: fr.range(0, 6)))
            }
            // Willows, and any tree with a weeping crown, let strands fall from the branch ends.
            if willow || st?.crown == .weeping {
                let stride = max(1, terminals.count / (willow ? 26 : 30))
                for (k, t) in terminals.enumerated() where k % stride == 0 {
                    let p = nodes[t].p
                    let len = min(base.y - 6 - p.y, R * fr.cg(1.0, 2.2) * (0.6 + CGFloat(tree.look.droopValue)))
                    guard len > R * 0.3 else { continue }
                    strands.append(Strand(node: t, length: len, lean: fr.cg(-0.12, 0.12), phase: fr.range(0, 6),
                                          leaves: max(4, Int(len / (D * 1.3))), tint: fr.range(0, 1)))
                }
            }
        case .alien:
            for (k, t) in terminals.enumerated() where k % 2 == 0 || tips.contains(where: { $0.node == t }) {
                let rx = R * fr.cg(0.18, 0.36)
                clumps.append(Clump(node: t, offset: .zero, rx: rx, ry: rx * 1.18, light: lightAt(nodes[t].p), kind: .orb,
                                    layers: Wash.blob(layers: 4, rnd: &fr), dabs: [], front: true, phase: fr.range(0, 6)))
            }
        case .dendrite:
            // Synaptic boutons on the ends of the finest branches.
            for t in terminals {
                let rx = max(1.1, R * 0.05) * fr.cg(0.8, 1.3)
                clumps.append(Clump(node: t, offset: .zero, rx: rx, ry: rx, light: lightAt(nodes[t].p), kind: .polyp,
                                    layers: [], dabs: [], front: true, phase: fr.range(0, 6)))
            }
        case .coral:
            for t in terminals {
                let rx = max(1.3, R * 0.075) * fr.cg(0.8, 1.35)
                clumps.append(Clump(node: t, offset: .zero, rx: rx, ry: rx, light: lightAt(nodes[t].p), kind: .polyp,
                                    layers: [], dabs: [], front: true, phase: fr.range(0, 6)))
            }
            // The sea-fan wash behind the branches.
            let reach = max(box.height, H * 0.5)
            var outline: [CGPoint] = []
            for i in 0...14 {
                let a = -1.25 + 2.5 * Double(i) / 14
                let d = reach * CGFloat(1.0 - 0.1 * abs(a)) * fr.cg(0.94, 1.04)
                outline.append(CGPoint(x: CGFloat(sin(a)) * d * 1.05, y: -CGFloat(cos(a)) * d))
            }
            outline.append(CGPoint(x: 0, y: -reach * 0.06))
            fanLayers = Wash.layers(of: outline, count: 5, amount: 0.05, rnd: &fr)
        case .conifer:
            guard let top = trunkNodes.last.map({ nodes[$0].p }) else { break }
            let bottom = base.y - H * 0.1
            let span = max(10, bottom - top.y)
            let count = 4 + Int((5 * growth).rounded())
            let maxHalf = max(H * 0.34, 14)
            for k in stride(from: count - 1, through: 0, by: -1) {
                let t0 = CGFloat(k) / CGFloat(count)
                let yTop = top.y - 5 + span * t0 * 0.88
                let yBot = top.y + span * min(1, (CGFloat(k) + 1.5) / CGFloat(count))
                let half = maxHalf * ((yBot - top.y) / span) * fr.cg(0.9, 1.05) + 4
                let anchor = trunkNodes.min { abs(nodes[$0].p.y - yTop) < abs(nodes[$1].p.y - yTop) }!
                let a = nodes[anchor].p
                let h = yBot - yTop
                var outline: [CGPoint] = [CGPoint(x: 0, y: yTop - a.y)]
                outline.append(CGPoint(x: -half * 0.45, y: yTop - a.y + h * 0.55))
                let teeth = max(4, Int(half / max(4, H / 60)))
                for i in 0...teeth {
                    let x = -half + CGFloat(i) * half * 2 / CGFloat(teeth)
                    outline.append(CGPoint(x: x, y: yBot - a.y + fr.cg(-1, 2)))
                    if i < teeth { outline.append(CGPoint(x: x + half / CGFloat(teeth), y: yBot - a.y - h * 0.16)) }
                }
                outline.append(CGPoint(x: half * 0.45, y: yTop - a.y + h * 0.55))
                tiers.append(Tier(node: anchor, offset: .zero, layers: Wash.layers(of: outline, count: 4, amount: 0.035, rnd: &fr),
                                  half: half, height: h, light: Double(0.25 + 0.55 * (1 - t0))))
            }
        default:
            break
        }
        clumps.sort { ($0.front ? 1 : 0, nodes[$0.node].p.y) < ($1.front ? 1 : 0, nodes[$1.node].p.y) }
        switch real {
        case .oak: growLeaves(.oak, kids: kids, rnd: &fr, light: lightAt, habit: tree.look.habit, structure: st)
        case .willow: growLeaves(.willow, kids: kids, rnd: &fr, light: lightAt, habit: tree.look.habit, structure: st)
        case .crystal: growLeaves(.crystal, kids: kids, rnd: &fr, light: lightAt, habit: tree.look.habit, structure: st)
        case .herb: growLeaves(.herb, kids: kids, rnd: &fr, light: lightAt, habit: tree.look.habit, structure: st)
        case .kelp: growLeaves(.kelp, kids: kids, rnd: &fr, light: lightAt, habit: tree.look.habit, structure: st)
        default: break
        }
        groundLayers = Wash.blob(sides: 11, layers: 4, squash: 1, rnd: &fr)
    }

    /// Leaves one by one along the twigs, with Poisson-disc spacing: a new leaf only goes where no
    /// other leaf's center is closer than most of a leaf length, so there are gaps to see through.
    enum LeafPlan { case oak, willow, crystal, herb, kelp }

    private mutating func growLeaves(_ plan: LeafPlan, kids: [[Int]], rnd fr: inout SeededRandom, light: (CGPoint) -> Double, habit: TreeHabit, structure: TreeStructure?) {
        let willow = plan == .willow
        let size: CGFloat
        let spacing: CGFloat
        let cap: Int
        switch plan {
        case .oak: size = 0.08; spacing = 0.74; cap = 520
        case .willow: size = 0.055; spacing = 0.7; cap = 320
        case .crystal: size = 0.075; spacing = 1.0; cap = 240
        case .herb: size = 0.06; spacing = 0.85; cap = 260
        case .kelp: size = 0.17; spacing = 0.5; cap = 140
        }
        // A recipe sets the leaf size and the gap between leaves. The gap never closes: leaf centers
        // stay most of a leaf apart, so every leaf reads on its own.
        let sized = structure.map { size * CGFloat(0.62 + 0.8 * ($0.crown == .columnar ? max($0.leafSize, 0.5) : $0.leafSize)) } ?? size
        let L = max(6, min(plan == .kelp ? 70 : 46, height * CGFloat(sized)))
        leafSize = L
        let minD: CGFloat
        if let sh = structure, plan != .kelp {
            minD = L * max(spacing, 0.86) * CGFloat(0.95 + 0.75 * sh.leafGap)
        } else {
            minD = L * spacing * CGFloat(habit.spacingScale)
        }
        let leafCap = Int(Double(cap) * habit.countScale)
        var grid: [Int64: [CGPoint]] = [:]
        func key(_ x: Int, _ y: Int) -> Int64 { (Int64(x) << 32) | Int64(UInt32(bitPattern: Int32(truncatingIfNeeded: y))) }
        func cell(_ p: CGPoint) -> (Int, Int) { (Int(floor(p.x / minD)), Int(floor(p.y / minD))) }
        func free(_ p: CGPoint) -> Bool {
            let (cx, cy) = cell(p)
            for dx in -1...1 { for dy in -1...1 {
                for q in grid[key(cx + dx, cy + dy)] ?? [] where hypot(q.x - p.x, q.y - p.y) < minD { return false }
            } }
            return true
        }
        func put(_ p: CGPoint) { let (cx, cy) = cell(p); grid[key(cx, cy), default: []].append(p) }

        let trunk = Set(trunkNodes)
        // Herbs and kelp have no fine crown growth: leaves go all along their stems.
        let along = plan == .herb || plan == .kelp
        let twig = along ? .greatestFiniteMagnitude : maxRadius * (willow ? 0.55 : 0.5)
        let groundLine = base.y - height * 0.07
        var order = nodes.indices.filter { nodes[$0].parent >= 0 && nodes[$0].r <= twig && !trunk.contains($0) && nodes[$0].p.y < groundLine }
        // Branch ends first, so every twig tip gets its leaf before the spaces fill in.
        order.sort { (kids[$0].isEmpty ? 0 : 1, $0) < (kids[$1].isEmpty ? 0 : 1, $1) }
        for i in order {
            if leaves.count >= leafCap { break }
            let p = nodes[i].p, q = nodes[nodes[i].parent].p
            let dir = atan2(Double(p.y - q.y), Double(p.x - q.x))
            let side: Double = i % 2 == 0 ? 1 : -1
            var tries: [(Double, CGFloat)] = []
            if kids[i].isEmpty { tries.append((fr.range(-0.2, 0.2), 1)) }
            for t in [CGFloat(0.3), 0.7] {
                tries.append((side * fr.range(0.55, 1.0), t))
                tries.append((-side * fr.range(0.55, 1.0), t))
            }
            for (da, t) in tries {
                let at = CGPoint(x: q.x + (p.x - q.x) * t, y: q.y + (p.y - q.y) * t)
                var a = dir + da
                if willow {
                    // Willow leaves hang: lean every leaf most of the way toward straight down.
                    let vx = cos(a) * 0.45, vy = sin(a) * 0.45 + 0.55
                    a = atan2(vy, vx)
                } else if plan == .kelp {
                    // Kelp blades float: they stream upward from the stipe.
                    let vx = cos(a) * 0.5, vy = sin(a) * 0.5 - 0.6
                    a = atan2(vy, vx)
                } else if plan == .crystal || plan == .herb {
                    // Shards and herb leaves angle up and out, never down.
                    if sin(a) > -0.1 { a = atan2(-abs(sin(a)) - 0.35, cos(a)) }
                } else if sin(a) > 0.6 {
                    a -= 0.5 * (cos(a) >= 0 ? 1 : -1)      // oak leaves don't point at the ground
                }
                let len = L * fr.cg(0.82, 1.15)
                let c = CGPoint(x: at.x + CGFloat(cos(a)) * len * 0.55, y: at.y + CGFloat(sin(a)) * len * 0.55)
                guard free(c) else { continue }
                put(c)
                let lit = light(c) * 2 - 1
                leaves.append(Leaf(node: i, offset: CGPoint(x: at.x - p.x, y: at.y - p.y), angle: a, length: len,
                                   value: max(-1, min(1, lit * 0.7 + fr.range(-0.35, 0.35))), hue: fr.range(-1, 1),
                                   phase: fr.range(0, 6.28), back: fr.next() < 0.28))
            }
        }
        // Willow strands carry their own leaves; fewer of them, spaced to the leaf size.
        for k in strands.indices { strands[k].leaves = max(3, Int(strands[k].length / (L * 0.78))) }
    }

    /// Space colonization: each crown point pulls its nearest node; nodes step toward the average pull;
    /// points that a node reaches are used up.
    private mutating func colonize(_ att: inout [CGPoint], step: CGFloat, influence: CGFloat, kill: CGFloat,
                                   bias: CGVector, swirl: Double, maxNodes: Int) {
        let iterations = 36
        let di2 = influence * influence, dk2 = kill * kill
        var grownFrom = [Int: [CGPoint]]()
        for it in 0..<iterations {
            if att.isEmpty || nodes.count >= maxNodes { break }
            var sum = [CGVector](repeating: .zero, count: nodes.count)
            var hit = [Bool](repeating: false, count: nodes.count)
            var keep: [CGPoint] = []
            keep.reserveCapacity(att.count)
            for a in att {
                var best = -1, bd = di2, killed = false
                for j in nodes.indices {
                    let dx = a.x - nodes[j].p.x, dy = a.y - nodes[j].p.y
                    let d2 = dx * dx + dy * dy
                    if d2 < dk2 { killed = true; break }
                    if d2 < bd { bd = d2; best = j }
                }
                if killed { continue }
                keep.append(a)
                if best >= 0 {
                    let d = max(0.0001, bd.squareRoot())
                    sum[best].dx += (a.x - nodes[best].p.x) / d
                    sum[best].dy += (a.y - nodes[best].p.y) / d
                    hit[best] = true
                }
            }
            att = keep
            var grew = false
            let count = nodes.count
            for j in 0..<count where hit[j] {
                var v = CGVector(dx: sum[j].dx + bias.dx, dy: sum[j].dy + bias.dy)
                if swirl != 0 {
                    let s = swirl * (nodes[j].owner % 2 == 0 ? 1 : -1)
                    v = CGVector(dx: v.dx * CGFloat(cos(s)) - v.dy * CGFloat(sin(s)), dy: v.dx * CGFloat(sin(s)) + v.dy * CGFloat(cos(s)))
                }
                let len = hypot(v.dx, v.dy)
                guard len > 0.0001 else { continue }
                let p = CGPoint(x: nodes[j].p.x + v.dx / len * step, y: nodes[j].p.y + v.dy / len * step)
                // A node pulled two ways at once would sprout the same twig again and again.
                if let prior = grownFrom[j], prior.contains(where: { hypot($0.x - p.x, $0.y - p.y) < step * 0.5 }) { continue }
                grownFrom[j, default: []].append(p)
                nodes.append(Node(p: p, parent: j, owner: nodes[j].owner, along: 1 + CGFloat(it) / CGFloat(iterations)))
                grew = true
                if nodes.count >= maxNodes { break }
            }
            if !grew { break }
        }
    }
}

/// Built trees, kept so a tree is grown once per size and not on every frame.
final class TreeGeometryCache: @unchecked Sendable {
    static let shared = TreeGeometryCache()
    private let lock = NSLock()
    private var store: [Int: TreeGeometry] = [:]
    private var order: [Int] = []

    func geometry(_ tree: PaperTreeData, in size: CGSize) -> TreeGeometry {
        var h = Hasher()
        h.combine(tree)
        h.combine(Int(size.width.rounded()))
        h.combine(Int(size.height.rounded()))
        let key = h.finalize()
        lock.lock()
        if let g = store[key] { lock.unlock(); return g }
        lock.unlock()
        let g = TreeGeometry.make(tree, in: size)
        lock.lock()
        store[key] = g
        order.append(key)
        if order.count > 60 { store[order.removeFirst()] = nil }
        lock.unlock()
        return g
    }
}

extension TreeGeometry {
    static func cached(_ tree: PaperTreeData, in size: CGSize) -> TreeGeometry {
        TreeGeometryCache.shared.geometry(tree, in: size)
    }
}
