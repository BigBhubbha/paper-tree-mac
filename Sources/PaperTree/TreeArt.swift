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
        case .coral: return Color(hex: 0xD9694F)
        case .flytrap: return Color(hex: 0x7C9A3A)
        case .conifer: return Color(hex: 0x5E4632)
        default: return Color(hex: 0x6E553F)
        }
    }

    /// Three species keep their own colour whatever the topics say, so they read at a glance even
    /// as thumbnails: a flytrap is lime with red mouths, coral is coral, a conifer is dark spruce.
    static func leaf(_ s: Species, toneName: String) -> Color {
        switch s {
        case .flytrap: return Color(hex: 0x95B23E)
        case .coral: return Color(hex: 0xE58066)
        case .conifer: return Color(hex: 0x2F5E4F)
        default: return tone(toneName)
        }
    }
    static let trapMouth = Color(hex: 0xB82A36)
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
        var owner: Int = 0
    }
    struct Tip { var id: String; var point: CGPoint; var angle: Double; var node: Int = 0 }
    struct Ghost { var id: String; var from: CGPoint; var control: CGPoint; var to: CGPoint; var node: Int = 0 }

    var limbs: [Limb] = []
    var twigs: [Limb] = []
    var tips: [Tip] = []
    var ghosts: [Ghost] = []
    var base: CGPoint = .zero
    var height: CGFloat = 0
    var growth: CGFloat = 0     // 0 = seed, 1 = enormous
    var cardSize = CGSize(width: 40, height: 52)

    // The living structure (TreeSkeleton.swift).
    var nodes: [Node] = []
    var chains: [Chain] = []
    var clumps: [Clump] = []
    var strands: [Strand] = []
    var tiers: [Tier] = []
    var trunkNodes: [Int] = []
    var twigEnds: [Int] = []
    /// Ends of structural limbs that carry no paper (recipe trees): the crown grows over them too.
    var scaffoldEnds: [CGPoint] = []
    var fanLayers: [Path] = []
    var groundLayers: [Path] = []
    var crownRadius: CGFloat = 20
    /// Individual leaves (oak and willow), spaced so they rarely touch, and their usual length.
    var leaves: [Leaf] = []
    var leafSize: CGFloat = 8
    var maxRadius: CGFloat = 1

    // Where the cards sit once they've been spaced out (TreeLayout.swift), in drawing coordinates.
    var cardCenters: [String: CGPoint] = [:]
    /// Paper cards pushed away from their tip, which get a thin leader line back to it.
    var leaders: Set<String> = []
    /// Everything that gets drawn: wood, leaves, ground and cards. The camera fits this.
    var contentBounds: CGRect = .zero

    /// How tall the tree is, as a share of the space, for a number of papers: a sapling at one, huge by twenty.
    static func growth(papers n: Int) -> CGFloat {
        n == 0 ? 0 : CGFloat(1 - exp(-Double(n) / 6.5))
    }

    static func make(_ tree: PaperTreeData, in size: CGSize) -> TreeGeometry {
        var g = TreeGeometry()
        // A tree with a recipe has its own structure, seeded from its id, seed, crown and trunk.
        let st = tree.structure
        var rnd = SeededRandom(st?.seed ?? tree.seed, "layout")
        // The plant body, and the skeleton it grows on (new plants borrow one of the six).
        let real = tree.look.species
        let species = real.family
        let n = tree.papers.count
        let stage = growth(papers: n)
        g.growth = stage
        let ground: CGFloat = max(22, size.height * 0.07)
        g.base = CGPoint(x: size.width * 0.5 + rnd.cg(-0.03, 0.03) * size.width, y: size.height - ground)
        let usable = size.height - ground - size.height * 0.06
        let habit = tree.look.habit
        // Only woody, single-crowned plants take a crown and trunk shape (a cactus, conifer or
        // a plant that grows from its base keeps its own build).
        let shaped: TreeStructure? = (st != nil && !real.fromBase && real != .cactus && species != .conifer) ? st : nil
        var crownTall: CGFloat = 1
        switch shaped?.crown {
        case .columnar?: crownTall = 1.14
        case .spreading?: crownTall = 0.84
        case .windswept?: crownTall = 0.9
        case .vase?: crownTall = 1.05
        default: break
        }
        g.height = usable * (0.24 + 0.74 * stage) * CGFloat(habit.heightScale) * crownTall
        let card = max(20, min(58, min(size.width, size.height) * 0.075)) * (0.75 + 0.25 * stage)
        g.cardSize = CGSize(width: card, height: card * 1.3)
        guard n > 0 else { return g }

        let H = g.height
        let twist = CGFloat(tree.look.twistValue)
        let droop = CGFloat(tree.look.droopValue)
        let girth = CGFloat(habit.girthScale)
        let sag = habit.sag
        // Wobble: how much a trunk or branch wanders, from the recipe's twist (1 at the middle).
        let wobble = 0.4 + 1.2 * habit.twist
        let fromBase = real.fromBase
        let side0 = shaped?.side ?? 1
        // Weeping crowns hang; windswept ones are pushed downwind.
        let crownSag = sag + (shaped?.crown == .weeping ? 0.13 : 0)
        let push = shaped?.crown == .windswept ? side0 * 0.045 : 0
        let angleK = shaped.map { 0.7 + 0.6 * $0.angle } ?? 1

        // The trunk (or, for a flytrap or coral, nothing but a crown at the base).
        var trunk: [CGPoint] = []
        if !fromBase {
            let steps = 9
            let gnarled = shaped?.trunk == .gnarled
            let sway: CGFloat = (species == .alien ? (0.06 + 0.1 * twist) * H : 0.025 * H * CGFloat(wobble)) * (gnarled ? 2.4 : 1)
            let phase = rnd.range(0, .pi * 2)
            // A lean: strong for a leaning trunk, gentle under a windswept crown; it eases back near the top.
            let lean: CGFloat = shaped?.trunk == .leaning ? CGFloat(side0) * 0.34 : shaped?.crown == .windswept ? CGFloat(side0) * 0.16 : 0
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let bend = sin(Double(t) * .pi * (species == .alien ? 2.2 : gnarled ? 2.7 : 1.1) + phase)
                var x = g.base.x + CGFloat(bend) * sway * t + rnd.cg(-1.5, 1.5) + lean * H * (t - 0.4 * t * t)
                if gnarled && i > 0 && i < steps { x += rnd.cg(-0.014, 0.014) * H }
                trunk.append(CGPoint(x: x, y: g.base.y - H * t))
            }
            // A forked trunk: above the fork the main leader swings to one side and a second leader
            // goes the other way.
            var fork: (CGPoint, CGFloat)? = nil
            if shaped?.trunk == .forked {
                let f = rnd.cg(0.36, 0.52)
                for i in trunk.indices {
                    let t = CGFloat(i) / CGFloat(steps)
                    if t > f { trunk[i].x += CGFloat(side0) * 0.3 * (t - f) * H }
                }
                fork = (point(on: trunk, at: f), f)
            }
            if real == .cactus {
                // A saguaro column: thick, hardly tapering, rounded at the top.
                let baseW = (14 + 30 * stage) * girth
                g.limbs.append(Limb(points: trunk, w0: baseW, w1: baseW * 0.82, depth: 0))
            } else {
                let baseW = ((species == .conifer ? 7 : 9) + (species == .conifer ? 20 : 34) * stage) * girth * (gnarled ? 1.15 : 1)
                g.limbs.append(Limb(points: trunk, w0: baseW, w1: max(1.6, baseW * 0.14), depth: 0))
                if let fk = fork {
                    let (fp, f) = fk
                    let (leader, tip) = TreeGeometry.grow(from: fp, angleFromUp: -side0 * rnd.range(0.32, 0.48), length: H * (1 - f) * rnd.cg(0.85, 1.0),
                                                          width: baseW * 0.55, species: real, twist: twist, droop: droop, rnd: &rnd, depth: 1,
                                                          sag: crownSag * 0.5, wobble: wobble, push: push)
                    g.limbs.append(leader)
                    g.scaffoldEnds.append(tip.point)
                }
                if shaped?.trunk == .multi {
                    // Two or three stems from the ground, like a coppiced tree.
                    let extra = rnd.next() < 0.5 ? 1 : 2
                    for e in 0..<extra {
                        let sd: Double = e == 0 ? -side0 : side0
                        let start = CGPoint(x: g.base.x + CGFloat(sd) * rnd.cg(4, 9), y: g.base.y)
                        let (stem, tip) = TreeGeometry.grow(from: start, angleFromUp: sd * rnd.range(0.2, 0.36), length: H * rnd.cg(0.62, 0.86),
                                                            width: baseW * 0.62, species: real, twist: twist, droop: droop, rnd: &rnd, depth: 0,
                                                            sag: 0, wobble: wobble, push: push)
                        g.limbs.append(stem)
                        g.scaffoldEnds.append(tip.point)
                    }
                }
            }
        }

        // Papers, oldest first. Roots grow from the trunk (or the crown); others from their parent.
        let papers = tree.papers.sorted { $0.addedAt < $1.addedAt }
        let ids = Set(papers.map(\.id))
        let roots = papers.filter { $0.parentId == nil || !ids.contains($0.parentId!) }
        var order: [String: Int] = [:]
        for (i, p) in papers.enumerated() where order[p.id] == nil { order[p.id] = i }
        if let first = roots.first, let k = g.limbs.firstIndex(where: { $0.depth == 0 }) { g.limbs[k].owner = order[first.id] ?? 0 }
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
                let spread: Double
                switch real {
                case .kelp: spread = 0.62
                case .mushroom: spread = 0.95
                case .fern: spread = 1.2
                case .herb: spread = 1.0
                case .flytrap: spread = 1.25
                default: spread = 1.05
                }
                let u = k == 1 ? 0.0 : (Double(jj) / Double(k - 1) - 0.5) * 2 // -1...1
                angleFromUp = min(1.5, spread * habit.spreadScale) * u + rnd.range(-0.08, 0.08)
                start = CGPoint(x: g.base.x + CGFloat(u) * 6, y: g.base.y - 2)
                length = H * CGFloat(species == .flytrap ? (1.0 - 0.38 * abs(u)) : (0.92 - 0.3 * abs(u))) * rnd.cg(0.88, 1.04)
                if real == .mushroom { length *= CGFloat(0.55 + 0.4 * (1 - abs(u))) * rnd.cg(0.8, 1.1) }
                if real == .kelp { length *= rnd.cg(0.85, 1.12) }
            } else if let sh = shaped {
                let (lo, hi) = Self.attach(sh.crown)
                let t = k == 1 ? (lo + hi) / 2 : lo + (hi - lo) * Double(jj) / Double(k - 1) + rnd.range(-0.04, 0.04)
                start = point(on: trunk, at: CGFloat(t))
                let downwind = sh.crown == .windswept && rnd.next() < 0.75
                let sd: Double = downwind ? sh.side : Double(side)
                (angleFromUp, length) = Self.crownBranch(sh.crown, t: t, side: sd, H: H, angleK: angleK, rnd: &rnd)
                if sh.crown == .windswept && sd != sh.side { length *= 0.55 }
            } else {
                let t = real == .cactus ? (k == 1 ? 0.4 : 0.22 + 0.4 * Double(jj) / Double(k - 1))
                                        : (k == 1 ? 0.55 : 0.3 + 0.58 * Double(jj) / Double(k - 1))
                start = point(on: trunk, at: CGFloat(t))
                switch real == .cactus ? Species.cactus : species {
                case .cactus:
                    // Arms come out sideways, then turn up.
                    angleFromUp = Double(side) * rnd.range(1.45, 1.57)
                    length = H * CGFloat(0.5 - 0.18 * t)
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
                // Reach out wider than a real tree would, so papers have room between them.
                if species != .conifer && real != .crystal { angleFromUp = max(-1.5, min(1.5, angleFromUp * 1.18)); length *= 1.1 }
                // The recipe opens the crown out or draws it in (a cactus keeps its sideways arms).
                if real != .cactus { angleFromUp = max(-1.55, min(1.55, angleFromUp * habit.spreadScale)) }
            }
            let (limb, tip) = TreeGeometry.grow(from: start, angleFromUp: angleFromUp, length: length,
                                   width: max(2.4, (fromBase ? 5 : 4) + 14 * stage * (fromBase ? 0.6 : 1) * CGFloat(1 - Double(jj) / Double(max(k, 1)) * 0.4)) * (real == .cactus ? 1.9 : real == .mushroom ? 1.5 : 1) * (0.5 + 0.5 * girth),
                                   species: real, twist: twist, droop: droop, rnd: &rnd, depth: 1, sag: crownSag, wobble: wobble, push: push)
            var owned = limb
            owned.owner = order[p.id] ?? 0
            g.limbs.append(owned)
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
                let a = parentUp + side * rnd.range(0.4, 0.75) * habit.spreadScale
                let len = (lengthOf[parentId] ?? H * 0.3) * rnd.cg(0.55, 0.7)
                let back = (lengthOf[parentId] ?? H * 0.3) * 0.22
                let start = CGPoint(x: parent.point.x - CGFloat(cos(parent.angle)) * back,
                                    y: parent.point.y - CGFloat(sin(parent.angle)) * back)
                let (limb, tip) = TreeGeometry.grow(from: start, angleFromUp: a, length: len, width: max(1.8, 3 + 6 * stage) * (real == .cactus ? 2.2 : 1) * (0.5 + 0.5 * girth),
                                       species: real, twist: twist, droop: droop, rnd: &rnd, depth: 2, sag: crownSag, wobble: wobble, push: push)
                var owned = limb
                owned.owner = order[p.id] ?? 0
                g.limbs.append(owned)
                tipOf[p.id] = Tip(id: p.id, point: tip.point, angle: tip.angle)
                lengthOf[p.id] = len
            }
            pending = pending.filter { tipOf[$0.id] == nil }
        }
        g.tips = papers.compactMap { tipOf[$0.id] }

        // Recipe trees: structural limbs that carry no paper, then side branches of a few orders.
        if let sh = shaped, trunk.count > 2 {
            var sr = SeededRandom(sh.seed, "scaffold")
            let (lo, hi) = Self.attach(sh.crown)
            // A column needs many short limbs all the way up, or it reads as a bare pole.
            let limbs = sh.crown == .columnar ? max(sh.count, 0.8) * 1.5 : sh.count
            let count = Int(((1 + 6 * limbs) * Double(0.45 + 0.55 * stage)).rounded())
            let owner = g.limbs.first(where: { $0.depth == 0 })?.owner ?? 0
            for q in 0..<count {
                let t = lo + (hi - lo) * (Double(q) + sr.range(0.1, 0.9)) / Double(max(count, 1))
                let sd: Double = sh.crown == .windswept ? (sr.next() < 0.8 ? sh.side : -sh.side) : (q % 2 == 0 ? -side0 : side0)
                var (a, len) = Self.crownBranch(sh.crown, t: t, side: sd, H: H, angleK: angleK, rnd: &sr)
                len *= sr.cg(0.7, 0.95)
                if sh.crown == .windswept && sd != sh.side { len *= 0.5 }
                a += sr.range(-0.1, 0.1)
                let w = max(2, (3 + 10 * stage) * (0.5 + 0.5 * girth))
                var (limb, tip) = TreeGeometry.grow(from: point(on: trunk, at: CGFloat(t)), angleFromUp: a, length: len, width: w,
                                                    species: real, twist: twist, droop: droop, rnd: &sr, depth: 1, sag: crownSag, wobble: wobble, push: push)
                limb.owner = owner
                g.limbs.append(limb)
                g.scaffoldEnds.append(tip.point)
            }
            // A column also carries short leafy spurs straight off the trunk, all the way up.
            if sh.crown == .columnar {
                var cr = SeededRandom(sh.seed, "spurs")
                let spurs = Int((8 + 10 * stage).rounded())
                for q in 0..<spurs {
                    let t = 0.24 + 0.72 * (Double(q) + cr.range(0.2, 0.8)) / Double(spurs)
                    let sd: Double = q % 2 == 0 ? 1 : -1
                    var (spur, _) = TreeGeometry.grow(from: point(on: trunk, at: CGFloat(t)), angleFromUp: sd * cr.range(0.45, 0.8),
                                                      length: H * cr.cg(0.07, 0.13) * CGFloat(1.1 - 0.4 * t), width: max(1, 2 + 3 * stage),
                                                      species: real, twist: twist, droop: droop, rnd: &cr, depth: 3, sag: 0, wobble: wobble, push: push)
                    spur.owner = owner
                    g.twigs.append(spur)
                }
            }
            // Side branches: one to four per limb, and on deep recipes their own side shoots.
            var fr = SeededRandom(sh.seed, "forks")
            let per = Int((1 + 3 * (sh.crown == .columnar ? max(sh.depth, 0.5) : sh.depth)).rounded())
            // Weeping side shoots arch over and hang like curtains.
            let forkSag = sh.crown == .weeping ? crownSag + 0.12 : crownSag
            let structural = g.limbs.filter { $0.depth >= 1 && $0.points.count > 3 }
            for limb in structural {
                let L = pathLength(limb.points)
                for f in 0..<per {
                    let t = fr.cg(0.3, 0.88)
                    let at = point(on: limb.points, at: t)
                    let d = direction(on: limb.points, at: t)
                    let sd: Double = f % 2 == 0 ? 1 : -1
                    let a = atan2(Double(d.dy), Double(d.dx)) + .pi / 2 + sd * fr.range(0.45, 0.85) * angleK
                    let len = L * fr.cg(0.28, 0.48)
                    var (twig, tip) = TreeGeometry.grow(from: at, angleFromUp: a, length: len, width: max(1, limb.w0 * 0.42),
                                                        species: real, twist: twist, droop: droop, rnd: &fr, depth: 3, sag: forkSag, wobble: wobble, push: push)
                    twig.owner = limb.owner
                    g.twigs.append(twig)
                    if sh.depth > 0.55 {
                        for s2 in [-1.0, 1.0] where fr.next() < 0.4 + 0.6 * (sh.depth - 0.55) / 0.45 {
                            let d2 = direction(on: twig.points, at: 0.7)
                            let a2 = atan2(Double(d2.dy), Double(d2.dx)) + .pi / 2 + s2 * fr.range(0.4, 0.75)
                            var (sub, _) = TreeGeometry.grow(from: point(on: twig.points, at: 0.7), angleFromUp: a2, length: len * fr.cg(0.35, 0.55),
                                                             width: max(0.8, twig.w1), species: real, twist: twist, droop: droop, rnd: &fr, depth: 3,
                                                             sag: forkSag, wobble: wobble, push: push)
                            sub.owner = limb.owner
                            g.twigs.append(sub)
                        }
                    }
                    _ = tip
                }
            }
        }

        // Small twigs for fullness: more as the tree grows.
        var twigRnd = SeededRandom(tree.seed, "twigs")
        let perLimb = 2
        for limb in g.limbs where limb.points.count > 3 && (real == .flytrap || real == .herb) {
            let count = Int((CGFloat(perLimb) * (0.5 + stage) * CGFloat(habit.countScale)).rounded())
            for _ in 0..<count {
                let t = twigRnd.cg(0.35, 0.85)
                let at = point(on: limb.points, at: t)
                let dir = direction(on: limb.points, at: t)
                let a = atan2(Double(dir.dy), Double(dir.dx)) + .pi / 2 + Double(twigRnd.sign()) * twigRnd.range(0.5, 0.9)
                let len = pathLength(limb.points) * twigRnd.cg(0.16, 0.3)
                let (twig, _) = TreeGeometry.grow(from: at, angleFromUp: a, length: len, width: max(1, limb.w1 * 1.2),
                                                  species: real, twist: twist, droop: droop, rnd: &twigRnd, depth: 3, sag: sag, wobble: wobble)
                var ownedTwig = twig
                ownedTwig.owner = limb.owner
                g.twigs.append(ownedTwig)
                // Coral forks again and again, into a dense fan.
                if species == .coral, twig.points.count > 3 {
                    for side in [-1.0, 1.0] {
                        let p2 = twig.points.last!
                        let d2 = direction(on: twig.points, at: 0.95)
                        let a2 = atan2(Double(d2.dy), Double(d2.dx)) + .pi / 2 + side * twigRnd.range(0.35, 0.6)
                        let (fork, _) = TreeGeometry.grow(from: p2, angleFromUp: a2, length: len * twigRnd.cg(0.45, 0.65), width: max(0.8, twig.w1),
                                                          species: species, twist: twist, droop: 0, rnd: &twigRnd, depth: 3)
                        g.twigs.append(fork)
                    }
                }
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
        g.buildSkeleton(tree)
        g.placeCards()
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
        func ml(_ l: Limb) -> Limb { Limb(points: l.points.map(m), w0: l.w0 * s, w1: l.w1 * s, depth: l.depth, owner: l.owner) }
        limbs = limbs.map(ml)
        twigs = twigs.map(ml)
        tips = tips.map { Tip(id: $0.id, point: m($0.point), angle: $0.angle) }
        scaffoldEnds = scaffoldEnds.map(m)
        ghosts = ghosts.map { Ghost(id: $0.id, from: m($0.from), control: m($0.control), to: m($0.to)) }
        base = CGPoint(x: base.x + dx, y: base.y)
        height *= s
        let c = max(0.7, s.squareRoot())
        cardSize = CGSize(width: cardSize.width * c, height: cardSize.height * c)
    }

    /// One branch: a gently bending curve from `start`, with species habits (droop, curl, kinks).
    static func grow(from start: CGPoint, angleFromUp: Double, length: CGFloat, width: CGFloat, species: Species,
                     twist: CGFloat, droop: CGFloat, rnd: inout SeededRandom, depth: Int,
                     sag: Double = 0, wobble: Double = 1, push: Double = 0) -> (Limb, Tip) {
        var pts: [CGPoint] = [start]
        let steps = 8
        var a = angleFromUp
        var p = start
        let seg = length / CGFloat(steps)
        let curl = species == .alien ? Double(twist) * 0.16 * (angleFromUp >= 0 ? 1 : -1) : 0
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            switch species {
            case .cactus:
                // Out sideways for a few steps, then a sharp elbow straight up, like a saguaro arm.
                if i > 3 && abs(a) > 0.1 { a -= (angleFromUp >= 0 ? 1 : -1) * min(abs(a), 0.42) }
            case .kelp: a += 0.16 * sin(Double(i) * 1.4 + Double(width)) - a * 0.08
            case .fern: a += (angleFromUp >= 0 ? 1 : -1) * 0.07 * t * 2.4
            case .herb: a += (angleFromUp >= 0 ? 1 : -1) * 0.02 + rnd.range(-0.06, 0.06)
            case .mushroom: a += rnd.range(-0.04, 0.04) - a * 0.05
            case .crystal: a += rnd.range(-0.05, 0.05)
            case .dendrite: a += rnd.range(-0.16, 0.16)
            case .willow: a += (angleFromUp >= 0 ? 1 : -1) * (0.05 + 0.12 * Double(droop)) * t * 2.2
            case .conifer: a += (angleFromUp >= 0 ? 1 : -1) * 0.025
            case .oak: a += rnd.range(-0.22, 0.22) * wobble
            case .alien: a += curl * (1 + t * 2)
            case .flytrap: a += (angleFromUp >= 0 ? 1 : -1) * 0.03
            case .coral: a += rnd.range(-0.12, 0.12) * wobble
            }
            // The recipe's droop: branches that hold themselves up sag, or lift, a little more.
            if sag != 0, [.oak, .alien, .crystal, .herb, .conifer, .coral, .dendrite, .flytrap].contains(species) {
                a += (angleFromUp >= 0 ? 1 : -1) * sag * t * 2
            }
            // Wind: every branch is nudged the same way.
            a += push
            p = CGPoint(x: p.x + CGFloat(sin(a)) * seg + rnd.cg(-0.6, 0.6), y: p.y - CGFloat(cos(a)) * seg + rnd.cg(-0.6, 0.6))
            pts.append(p)
        }
        let last = pts[pts.count - 1], prev = pts[pts.count - 2]
        let tipAngle = atan2(Double(last.y - prev.y), Double(last.x - prev.x))
        let end: CGFloat
        switch species {
        case .coral: end = 0.55
        case .cactus: end = 0.85
        case .mushroom: end = 0.7
        case .dendrite: end = 0.2
        default: end = 0.25
        }
        let limb = Limb(points: pts, w0: width, w1: max(0.9, width * end), depth: depth)
        return (limb, Tip(id: "", point: last, angle: tipAngle))
    }

    /// Where along the trunk a crown's main limbs leave it.
    static func attach(_ c: TreeStructure.Crown) -> (Double, Double) {
        switch c {
        case .round: return (0.4, 0.86)
        case .columnar: return (0.18, 0.92)
        case .vase: return (0.3, 0.5)
        case .spreading: return (0.42, 0.66)
        case .weeping: return (0.42, 0.88)
        case .windswept: return (0.45, 0.88)
        }
    }

    /// A main limb for a crown shape: its angle from straight up and its length.
    static func crownBranch(_ c: TreeStructure.Crown, t: Double, side: Double, H: CGFloat, angleK: Double,
                            rnd: inout SeededRandom) -> (Double, CGFloat) {
        let a: Double, len: CGFloat
        switch c {
        case .round: a = rnd.range(0.65, 1.05); len = H * CGFloat(0.46 - 0.2 * t)
        case .columnar: a = rnd.range(0.42, 0.68); len = H * CGFloat(0.38 - 0.2 * t)
        case .vase: a = rnd.range(0.36, 0.6); len = H * CGFloat(0.66 - 0.1 * t)
        case .spreading: a = rnd.range(1.1, 1.36); len = H * CGFloat(0.7 - 0.25 * t)
        case .weeping: a = rnd.range(0.55, 0.85); len = H * CGFloat(0.56 - 0.12 * t)
        case .windswept: a = rnd.range(0.95, 1.3); len = H * CGFloat(0.55 - 0.15 * t)
        }
        return (side * min(1.5, a * angleK), len * rnd.cg(0.88, 1.08))
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
                Text(paper.shortAuthors).font(.custom(Typeface.text, size: max(3, 4 * s))).foregroundColor(PlantInk.ink.opacity(0.7))
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
    /// Close up: the whole title.
    var full = false

    var body: some View {
        let s = size.width / 60
        VStack(spacing: 2 * s) {
            Text(paper.title)
                .font(.custom(Typeface.hand, size: max(4, 6 * s)))
                .foregroundColor(PlantInk.pencil)
                .multilineTextAlignment(.center)
                .lineLimit(full ? 9 : 5)
                .minimumScaleFactor(full ? 0.5 : 0.6)
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
