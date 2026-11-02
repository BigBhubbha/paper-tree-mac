// Spacing the cards on a tree: paper pages near their tips but never on top of each other, and
// suggestions out past the edge of the crown on their pencil branches. A short relaxation pass,
// the same every time for the same tree.
import CoreGraphics

extension TreeGeometry {
    /// Crown outline as an ellipse: what the suggestions are pushed out of.
    private func crownEllipse() -> (center: CGPoint, a: CGFloat, b: CGFloat) {
        var box = CGRect.null
        for c in clumps {
            let p = nodes[c.node].p
            let o = CGPoint(x: p.x + c.offset.x, y: p.y + c.offset.y)
            box = box.union(CGRect(x: o.x - c.rx, y: o.y - c.ry, width: c.rx * 2, height: c.ry * 2))
        }
        for t in tiers {
            let c = CGPoint(x: nodes[t.node].p.x + t.offset.x, y: nodes[t.node].p.y + t.offset.y)
            box = box.union(CGRect(x: c.x - t.half, y: c.y - t.height, width: t.half * 2, height: t.height * 1.3))
        }
        for n in nodes where n.p.y < base.y - height * 0.25 { box = box.union(CGRect(origin: n.p, size: .zero)) }
        if box.isNull { box = CGRect(x: base.x - 20, y: base.y - height, width: 40, height: height) }
        return (CGPoint(x: box.midX, y: box.midY), max(20, box.width / 2), max(20, box.height / 2))
    }

    mutating func placeCards() {
        let w = cardSize.width, h = cardSize.height
        let gap = w * 0.32
        let crown = crownEllipse()
        struct Card { var id: String; var p: CGPoint; var home: CGPoint; var ghost: Bool; var from: CGPoint }
        var cards: [Card] = []

        for t in tips {
            let lift = h * 0.42
            let home = CGPoint(x: t.point.x + CGFloat(cos(t.angle)) * lift, y: t.point.y + CGFloat(sin(t.angle)) * lift)
            cards.append(Card(id: t.id, p: home, home: home, ghost: false, from: t.point))
        }
        // Suggestions start just outside the crown, in the direction of the paper they grow from.
        for gh in ghosts {
            var d = CGVector(dx: gh.to.x - crown.center.x, dy: gh.to.y - crown.center.y)
            if d.dy > 0 { d.dy *= 0.3 }                      // never down into the ground
            let len = max(0.001, (d.dx * d.dx + d.dy * d.dy).squareRoot())
            d = CGVector(dx: d.dx / len, dy: d.dy / len)
            let reach = 1 / ((d.dx * d.dx) / (crown.a * crown.a) + (d.dy * d.dy) / (crown.b * crown.b)).squareRoot()
            let out = reach + max(w, h) * 0.85
            let home = CGPoint(x: crown.center.x + d.dx * out, y: crown.center.y + d.dy * out)
            cards.append(Card(id: gh.id, p: home, home: home, ghost: true, from: gh.from))
        }

        func outsideCrown(_ p: CGPoint, margin: CGFloat) -> CGPoint {
            let a = crown.a + margin, b = crown.b + margin
            let dx = p.x - crown.center.x, dy = p.y - crown.center.y
            let k = (dx * dx) / (a * a) + (dy * dy) / (b * b)
            guard k < 1 else { return p }
            let s = 1 / max(0.05, k.squareRoot())
            return CGPoint(x: crown.center.x + dx * s, y: crown.center.y + dy * s)
        }

        let floorY = base.y - h * 0.6
        for _ in 0..<160 {
            // Push overlapping cards apart along the shorter way out.
            for i in cards.indices {
                for j in cards.indices where j > i {
                    let dx = cards[j].p.x - cards[i].p.x, dy = cards[j].p.y - cards[i].p.y
                    let ox = (w + gap) - abs(dx), oy = (h + gap) - abs(dy)
                    guard ox > 0, oy > 0 else { continue }
                    let wi: CGFloat = cards[i].ghost ? 0.6 : 0.4, wj: CGFloat = cards[j].ghost ? 0.6 : 0.4
                    let total = wi + wj
                    if ox < oy {
                        let s: CGFloat = dx == 0 ? (i % 2 == 0 ? 1 : -1) : (dx > 0 ? 1 : -1)
                        cards[i].p.x -= s * ox * wi / total; cards[j].p.x += s * ox * wj / total
                    } else {
                        let s: CGFloat = dy == 0 ? 1 : (dy > 0 ? 1 : -1)
                        cards[i].p.y -= s * oy * wi / total; cards[j].p.y += s * oy * wj / total
                    }
                }
            }
            for i in cards.indices {
                // A gentle pull home, and the rules: suggestions stay out of the crown, nothing below the ground.
                let k: CGFloat = cards[i].ghost ? 0.03 : 0.06
                cards[i].p.x += (cards[i].home.x - cards[i].p.x) * k
                cards[i].p.y += (cards[i].home.y - cards[i].p.y) * k
                if cards[i].ghost { cards[i].p = outsideCrown(cards[i].p, margin: max(w, h) * 0.55) }
                cards[i].p.y = min(cards[i].p.y, floorY)
            }
        }

        cardCenters = [:]
        leaders = []
        for c in cards {
            cardCenters[c.id] = c.p
            if !c.ghost, hypot(c.p.x - c.home.x, c.p.y - c.home.y) > h * 0.35 { leaders.insert(c.id) }
        }
        // Pencil branches end at the edge of their card nearest the paper they come from.
        for i in ghosts.indices {
            guard let c = cardCenters[ghosts[i].id] else { continue }
            let f = ghosts[i].from
            let dx = f.x - c.x, dy = f.y - c.y
            let sx = abs(dx) > 0.001 ? (w / 2) / abs(dx) : .infinity, sy = abs(dy) > 0.001 ? (h / 2) / abs(dy) : .infinity
            let s = min(1, min(sx, sy))
            let to = CGPoint(x: c.x + dx * s, y: c.y + dy * s)
            let mid = CGPoint(x: (f.x + to.x) / 2, y: (f.y + to.y) / 2)
            let len = hypot(to.x - f.x, to.y - f.y)
            ghosts[i].to = to
            ghosts[i].control = CGPoint(x: mid.x + (to.y - f.y) / max(1, len) * len * 0.12, y: mid.y - len * 0.1)
        }
        // Thin the leaves behind paper cards.
        let rects = tips.compactMap { t in cardCenters[t.id].map { CGRect(x: $0.x - w * 0.75, y: $0.y - h * 0.7, width: w * 1.5, height: h * 1.4) } }
        for i in clumps.indices {
            let p = nodes[clumps[i].node].p
            let o = CGPoint(x: p.x + clumps[i].offset.x, y: p.y + clumps[i].offset.y)
            if rects.contains(where: { $0.insetBy(dx: -clumps[i].rx * 0.3, dy: -clumps[i].ry * 0.3).contains(o) }) { clumps[i].thin = 0.38 }
        }

        // Everything drawn, for the camera.
        var box = CGRect(x: base.x - max(60, height * 0.55 + 40), y: base.y - 8, width: max(60, height * 0.55 + 40) * 2, height: 24)
        for n in nodes { box = box.union(CGRect(x: n.p.x - n.r, y: n.p.y - n.r, width: n.r * 2, height: n.r * 2)) }
        for c in clumps {
            let p = nodes[c.node].p
            box = box.union(CGRect(x: p.x + c.offset.x - c.rx * 1.2, y: p.y + c.offset.y - c.ry * 1.2, width: c.rx * 2.4, height: c.ry * 2.4))
        }
        for s in strands { box = box.union(CGRect(x: nodes[s.node].p.x - 4, y: nodes[s.node].p.y, width: 8, height: s.length)) }
        for c in cardCenters.values { box = box.union(CGRect(x: c.x - w * 0.7, y: c.y - h * 0.7, width: w * 1.4, height: h * 1.4)) }
        contentBounds = box
    }
}
