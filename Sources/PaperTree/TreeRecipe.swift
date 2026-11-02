import Foundation

/// A whole design for one tree, from the tree customizer (/api/tree/recipe) or, until that answers,
/// a local one grown from the tree's seed. The plant body stays in `TreeLook.species`; this holds the
/// rest: palette, leaf, branch habit, size and an accent. Every number is 0...1 and 0.5 means "as the
/// plant usually grows", so a tree with no recipe at all draws exactly as it did before.
struct TreeRecipe: Codable, Hashable, Sendable {
    /// Hex colors: trunk or stem (the main body for a cactus, coral, mushroom or neuron), leaves, accent.
    var bark: String
    var leaf: String
    var accentColor: String
    /// auto, lobed, lance, oval, heart, fan, shard.
    var leafShape: String = "auto"
    /// 0 reaching up, 1 weeping.
    var droop = 0.5
    /// 0 narrow, 1 wide open.
    var spread = 0.5
    /// 0 airy, 1 full.
    var density = 0.5
    var height = 0.5
    var girth = 0.5
    var twist = 0.5
    /// none, blossom, berry, fruit, glow, pods.
    var accent = "none"
    var amount = 0.0
    var tendrils = false
    /// Which model designed it (nil for a local recipe).
    var model: String? = nil

    static let shapes = ["auto", "lobed", "lance", "oval", "heart", "fan", "shard"]
    static let accents = ["none", "blossom", "berry", "fruit", "glow", "pods"]

    /// The same checks the Worker makes, so a bad cache entry or an old file can't draw anything garish.
    func safe(for species: Species) -> TreeRecipe {
        var r = self
        let d = Self.defaults(species)
        r.bark = Hue.safe(bark, role: .bark, species: species) ?? d.bark
        r.leaf = Hue.safe(leaf, role: .leaf, species: species) ?? d.leaf
        r.accentColor = Hue.safe(accentColor, role: .accent, species: species) ?? d.accentColor
        if !Self.shapes.contains(r.leafShape) || ![.oak, .willow, .herb].contains(species) { r.leafShape = "auto" }
        if !Self.accents.contains(r.accent) { r.accent = "none" }
        if ["blossom", "berry", "fruit"].contains(r.accent) && [.mushroom, .kelp, .dendrite].contains(species) { r.accent = "glow" }
        func unit(_ v: Double) -> Double { v.isFinite ? max(0, min(1, v)) : 0.5 }
        r.droop = unit(droop); r.spread = unit(spread); r.density = unit(density)
        r.height = max(0.15, min(0.85, unit(height))); r.girth = max(0.15, min(0.85, unit(girth))); r.twist = unit(twist)
        r.amount = r.accent == "none" ? 0 : max(0.2, unit(amount))
        return r
    }

    /// The plant's own colors.
    static func defaults(_ s: Species) -> TreeRecipe {
        let p: (String, String, String)
        switch s {
        case .oak: p = ("#6E553F", "#7F9C6B", "#E89AB0")
        case .willow: p = ("#6B5A45", "#8FA36A", "#F6F1E4")
        case .conifer: p = ("#5E4632", "#2F5E4F", "#C8423B")
        case .flytrap: p = ("#7C9A3A", "#95B23E", "#C8423B")
        case .alien: p = ("#56656B", "#8FC7D8", "#9B7BC8")
        case .coral: p = ("#D9694F", "#E58066", "#F6F1E4")
        case .kelp: p = ("#8A6F2E", "#8A7A3A", "#E8B53A")
        case .dendrite: p = ("#5B4E86", "#8C78C8", "#E8B53A")
        case .crystal: p = ("#4E5D6C", "#8FC7D8", "#6E93D6")
        case .herb: p = ("#6F8F45", "#7F9C6B", "#9B7BC8")
        case .cactus: p = ("#5F8A4E", "#6F9A57", "#E89AB0")
        case .fern: p = ("#6E5A3A", "#5E7A3A", "#C79A3A")
        case .mushroom: p = ("#E9DDC4", "#B5533A", "#F6F1E4")
        }
        return TreeRecipe(bark: p.0, leaf: p.1, accentColor: p.2)
    }

    /// A recipe made on this Mac from the plant guess and the tree's seed, so even offline no two
    /// trees match. Colors shift a little around the plant's own, and the habit wanders around the middle.
    static func local(for look: TreeLook, seed: UInt64) -> TreeRecipe {
        var rnd = SeededRandom(seed, "recipe")
        let s = look.species
        var r = defaults(s)
        r.bark = Hue.nudge(r.bark, hue: rnd.range(-10, 10), light: rnd.range(-0.05, 0.05))
        r.leaf = Hue.nudge(PlantInk.leafRGB(s, toneName: look.leafTone).hex, hue: rnd.range(-14, 14), light: rnd.range(-0.06, 0.06))
        r.leafShape = look.leafShape ?? "auto"
        r.droop = rnd.range(0.3, 0.7)
        r.spread = rnd.range(0.3, 0.75)
        r.density = rnd.range(0.35, 0.75)
        r.height = rnd.range(0.35, 0.7)
        r.girth = rnd.range(0.35, 0.65)
        r.twist = rnd.range(0.25, 0.7)
        r.tendrils = look.tendrils ?? false
        if let b = look.bloom, b != "none" {
            r.accent = b
            r.accentColor = PlantInk.bloomRGB(look.bloomTone).hex
            r.amount = rnd.range(0.4, 0.8)
        } else if [.alien, .dendrite, .crystal].contains(s) {
            r.accent = "glow"; r.amount = rnd.range(0.4, 0.8)
        }
        return r.safe(for: s)
    }

    /// Part of the way toward another recipe: numbers and colors drift, choices switch.
    func easing(toward o: TreeRecipe, by k: Double) -> TreeRecipe {
        var out = o
        func m(_ a: Double, _ b: Double) -> Double { a + (b - a) * k }
        out.droop = m(droop, o.droop); out.spread = m(spread, o.spread); out.density = m(density, o.density)
        out.height = m(height, o.height); out.girth = m(girth, o.girth); out.twist = m(twist, o.twist)
        out.amount = accent == o.accent ? m(amount, o.amount) : o.amount
        out.bark = RGB(hex: bark).mix(RGB(hex: o.bark), k).hex
        out.leaf = RGB(hex: leaf).mix(RGB(hex: o.leaf), k).hex
        out.accentColor = RGB(hex: accentColor).mix(RGB(hex: o.accentColor), k).hex
        return out
    }
}

/// The numbers the drawing code reads, as CGFloat-friendly doubles. 0.5 everywhere is the classic plant.
struct TreeHabit {
    var droop: Double, spread: Double, density: Double, height: Double, girth: Double, twist: Double
    /// Multipliers centered on 1 (0.5 gives exactly 1).
    var heightScale: Double { 0.82 + 0.36 * height }
    var girthScale: Double { 0.72 + 0.56 * girth }
    var spreadScale: Double { 0.78 + 0.44 * spread }
    /// Leaf spacing: denser means closer leaves.
    var spacingScale: Double { 1.28 - 0.56 * density }
    var countScale: Double { 0.6 + 0.8 * density }
    /// Extra bend per step for branches that do not droop on their own (0 at droop 0.5).
    var sag: Double { (droop - 0.5) * 0.1 }
}

extension TreeLook {
    var habit: TreeHabit {
        if let r = recipe {
            return TreeHabit(droop: r.droop, spread: r.spread, density: r.density, height: r.height, girth: r.girth, twist: r.twist)
        }
        return TreeHabit(droop: 0.5, spread: 0.5, density: 0.5, height: 0.5, girth: 0.5, twist: 0.5)
    }
    /// Droop and twist where the plant always used them (willow weep, alien curl).
    var droopValue: Double { recipe?.droop ?? droop }
    var twistValue: Double { recipe?.twist ?? twist }
    /// The leaf shape to draw, nil for the plant's own.
    var drawnLeafShape: String? {
        if let r = recipe { return r.leafShape == "auto" ? nil : r.leafShape }
        return leafShape
    }
    /// blossom, berry, fruit, glow, pods, or nil.
    var accentKind: String? {
        if let r = recipe { return r.accent == "none" ? nil : r.accent }
        return bloom == "none" ? nil : bloom
    }
    var accentAmount: Double { recipe?.amount ?? 0.5 }
    var hasTendrils: Bool { recipe?.tendrils ?? tendrils ?? false }

    /// A short topic signature: the plant the papers point to and their main field. The customizer is
    /// asked again only when this changes, so a growing tree does not call the AI for every paper.
    static func topicKey(fields: [String], titles: [String], seed: UInt64) -> String {
        let (sp, _) = Species.guessWithReasons(fields: fields, titles: titles, seed: seed)
        return sp.rawValue + "|" + (fields.first?.lowercased() ?? "")
    }
}

// MARK: Colors

extension RGB {
    init(hex s: String) {
        let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        self.init(UInt32(t, radix: 16) ?? 0x7F9C6B)
    }
    var hex: String {
        func c(_ v: Double) -> Int { Int((max(0, min(1, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}

/// Color checks in HSL: each role has a safe band of saturation and lightness (no neon, no mud).
enum Hue {
    enum Role { case bark, leaf, accent }

    static func range(_ role: Role, _ s: Species) -> (s: ClosedRange<Double>, l: ClosedRange<Double>) {
        switch role {
        case .bark:
            if s == .mushroom { return (0.1...0.45, 0.62...0.9) }
            if s == .coral { return (0.3...0.68, 0.4...0.66) }
            if [.cactus, .herb, .flytrap, .kelp, .dendrite].contains(s) { return (0.15...0.5, 0.25...0.55) }
            return (0.06...0.4, 0.2...0.44)
        case .leaf: return (0.12...0.6, 0.3...0.68)
        case .accent: return (0.25...0.72, 0.42...0.82)
        }
    }

    static func safe(_ hex: String, role: Role, species: Species) -> String? {
        let t = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard t.count == 6, UInt32(t, radix: 16) != nil else { return nil }
        var (h, s, l) = hsl(RGB(hex: t))
        let r = range(role, species)
        s = min(max(s, r.s.lowerBound), r.s.upperBound)
        l = min(max(l, r.l.lowerBound), r.l.upperBound)
        if role == .bark && species == .cactus { h = min(max(h, 75.0 / 360), 160.0 / 360) }
        return rgb(h, s, l).hex
    }

    /// The same color turned a few degrees and a touch lighter or darker.
    static func nudge(_ hex: String, hue: Double, light: Double) -> String {
        var (h, s, l) = hsl(RGB(hex: hex))
        h = (h + hue / 360).truncatingRemainder(dividingBy: 1); if h < 0 { h += 1 }
        l = max(0.05, min(0.95, l + light))
        return rgb(h, s, l).hex
    }

    static func hsl(_ c: RGB) -> (Double, Double, Double) {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b), l = (mx + mn) / 2
        guard mx != mn else { return (0, 0, l) }
        let d = mx - mn
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        if mx == c.r { h = (c.g - c.b) / d + (c.g < c.b ? 6 : 0) } else if mx == c.g { h = (c.b - c.r) / d + 2 } else { h = (c.r - c.g) / d + 4 }
        h /= 6
        return (h, s, l)
    }

    static func rgb(_ h: Double, _ s: Double, _ l: Double) -> RGB {
        func f(_ n: Double) -> Double {
            let k = (n + h * 12).truncatingRemainder(dividingBy: 12), a = s * min(l, 1 - l)
            return l - a * max(-1, min(k - 3, 9 - k, 1))
        }
        return RGB(r: f(0), g: f(8), b: f(4))
    }
}
