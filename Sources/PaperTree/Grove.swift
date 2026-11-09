// What the island shows when it opens wide: the grove. Every tree is mounted on its own herbarium
// sheet with a label in the lower right corner, the way pressed specimens are kept. Click a tree to
// look at it closely; click a paper at a branch tip to open it; click a pencil branch to keep or prune it.
import AppKit
import SwiftUI

enum GrovePage: Equatable {
    case grove
    case tree(UUID)
    case newTree
    /// A paper open in the reader: its tree, and its id.
    case paper(UUID, String)
}

/// One paper someone highlighted and tapped to add, while we look it up.
struct AddRequest: Equatable {
    enum Lookup: Equatable { case looking, found([Paper], confident: Bool), notFound(String) }
    var highlighted: String
    var lookup: Lookup = .looking
    /// The candidate picked from the list.
    var chosen: Paper?
    /// "None of these": add it with just the highlighted title.
    var asHighlighted = false
    /// "Pick another match" opened the list even though the first match looked right.
    var showAll = false
    /// Made once, so its id stays the same however often it is read.
    private let localId = "local-" + UUID().uuidString

    init(highlighted: String, lookup: Lookup = .looking) {
        self.highlighted = highlighted
        self.lookup = lookup
    }

    var candidates: [Paper] {
        if case .found(let list, _) = lookup { return list }
        return []
    }

    var confident: Bool {
        if case .found(_, let c) = lookup { return c }
        return false
    }

    /// The list of matches is open: the match is unsure, or they asked to pick another.
    var choosing: Bool { !candidates.isEmpty && (showAll || !confident) && chosen == nil && !asHighlighted }

    /// What goes on the tree, or nil while we still need them to pick.
    var paper: Paper? {
        if asHighlighted { return Paper(id: localId, title: highlighted) }
        if let chosen { return chosen }
        switch lookup {
        case .looking: return nil
        case .found(let list, let confident): return confident && !showAll ? list.first : nil
        case .notFound: return Paper(id: localId, title: highlighted)
        }
    }
}

/// A scroll view, except in design snapshots, where AppKit-backed scrolling can't be drawn.
struct GroveScroll<Content: View>: View {
    var axis: Axis.Set
    var indicators = false
    @ViewBuilder var content: Content
    var body: some View {
        if Snapshots.isRendering {
            GeometryReader { geo in
                content
                    .fixedSize(horizontal: axis.contains(.horizontal), vertical: axis.contains(.vertical))
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .clipped()
            }
        } else {
            ScrollView(axis, showsIndicators: indicators) { content }
        }
    }
}

// MARK: - The grove (the wide-open island)

struct GroveView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var state: AppState
    @ObservedObject var store: TreeStore

    var body: some View {
        VStack(spacing: 10) {
            header
            if let h = model.highlight {
                AddHighlightBar(text: h) {
                    model.onAddHighlight(h)
                } dismiss: {
                    withAnimation(Motion.pick(Motion.snappy)) { model.highlight = nil }
                }
                .transition(Motion.reduced ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
            ZStack {
                PaperSheet(corner: 18)
                page
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
            }
            // The gesture is taught in setup and in Settings, so it only shows here before the first tree.
            if store.trees.isEmpty {
                Text("Tap right Option to open or close. Tap it twice for Research mode.")
                    .font(.typewriter(9.5))
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            BuddyView(mood: state.mood, researchMode: state.researchMode, compact: true).frame(width: 24, height: 24)
                .padding(.trailing, -6)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Paper Tree").font(.fell(21)).foregroundColor(.white)
                Text(store.trees.isEmpty ? "the grove, unplanted" : "the grove, \(store.trees.count) \(store.trees.count == 1 ? "tree" : "trees")")
                    .font(.typewriter(10.5)).foregroundColor(Color.white.opacity(0.55))
            }
            Spacer()
            ResearchSwitch(on: state.researchMode) { state.researchMode.toggle() }
                .help("Double-tap right Option does this too")
            darkLink("Settings", model.onOpenSettings)
            darkLink("Quit", model.onQuit)
        }
        .padding(.horizontal, 8)
    }

    private func darkLink(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(InkLinkButtonStyle(color: Color.white.opacity(0.72)))
    }

    @ViewBuilder private var page: some View {
        switch model.page {
        case .newTree:
            NewTreePage(model: model, store: store)
                .transition(.zoomIn)
        case .tree(let id):
            if let tree = store.trees.first(where: { $0.id == id }) {
                TreeSheetPage(model: model, store: store, tree: tree, startZoom: model.treeStartZoom, startPan: model.treeStartPan)
                    .transition(.zoomIn)
            } else {
                overview.transition(.opacity)
            }
        case .grove:
            overview.transition(.opacity)
        case .paper(let treeId, let paperId):
            if let tree = store.trees.first(where: { $0.id == treeId }), let paper = tree.papers.first(where: { $0.id == paperId }) {
                // The front page flies out of its branch tip and opens up into the reader.
                PaperReaderPage(model: model, store: store, tree: tree, paper: paper, preset: model.readerPreset)
                    .transition(Motion.reduced ? .opacity : .asymmetric(
                        insertion: .scale(scale: 0.08, anchor: model.readerOrigin).combined(with: .opacity),
                        removal: .scale(scale: 0.08, anchor: model.readerOrigin).combined(with: .opacity)))
            } else {
                overview.transition(.opacity)
            }
        }
    }

    @ViewBuilder private var overview: some View {
        if store.trees.isEmpty {
            NewTreePage(model: model, store: store)
        } else {
            GroveOverview(model: model, store: store)
        }
    }
}

/// The highlight you had when you opened the island, offered as a paper to add.
struct AddHighlightBar: View {
    var text: String
    var add: () -> Void
    var dismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("You highlighted").font(.typewriter(10)).foregroundColor(Palette.ink3)
                Text("\u{201C}\(text)\u{201D}")
                    .font(.text(15)).foregroundColor(Palette.ink)
                    .lineLimit(1).truncationMode(.middle)
                    .padding(.horizontal, 3)
                    .background(Palette.marker.opacity(0.5).padding(.vertical, 2))
            }
            Spacer(minLength: 10)
            Button("Add this paper", action: add)
                .buttonStyle(StampButtonStyle())
                .keyboardShortcut(.defaultAction)
                .help("Look it up and choose a tree for it (Return)")
            Button("Not now", action: dismiss)
                .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(PaperSheet(corner: 14))
    }
}

// MARK: - All trees side by side

struct GroveOverview: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var store: TreeStore

    /// How the sheets are laid out for a number of trees in a space: one row for up to three trees,
    /// then two rows of sheets that never get narrower than a little under their height. Past what
    /// fits, the rows scroll sideways; the New tree sheet stays pinned outside the scroll.
    struct Layout {
        var rows: Int, columns: Int, cell: CGSize, spacing: CGFloat
        /// Sheets are 3:4 portrait: close to a real herbarium sheet, with less empty paper under the plant.
        static let aspect: CGFloat = 3.0 / 4.0
        static func make(count: Int, in size: CGSize, spacing: CGFloat = 16) -> Layout {
            let n = max(1, count)
            // Try one row, then two: keep whichever gives the bigger sheet while they still fit side by side.
            // Past what fits, two rows of sheets scroll sideways.
            func fit(_ rows: Int) -> (w: CGFloat, fits: Bool) {
                let columns = Int((Double(n) / Double(rows)).rounded(.up))
                let h = (size.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
                let even = (size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
                let w = min(h * aspect, even)
                return (w, w >= h * aspect * 0.72)
            }
            let one = fit(1), two = fit(2)
            let rows = (n == 1 || one.w >= two.w) ? 1 : 2
            let columns = Int((Double(n) / Double(rows)).rounded(.up))
            let rowH = (size.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            let w = rows == 1 ? one.w : (two.fits ? two.w : rowH * aspect * 0.72)
            let cell = CGSize(width: floor(w), height: floor(min(rowH, w / aspect)))
            return Layout(rows: rows, columns: columns, cell: cell, spacing: spacing)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let plate: CGFloat = 150
            let area = CGSize(width: geo.size.width - plate - 14, height: geo.size.height)
            let trees = store.trees.sorted { $0.number < $1.number }
            let L = Layout.make(count: trees.count, in: area)
            let gridW = CGFloat(L.columns) * L.cell.width + CGFloat(L.columns - 1) * L.spacing
            let gridH = CGFloat(L.rows) * L.cell.height + CGFloat(L.rows - 1) * L.spacing
            let overflow = gridW > area.width + 1
            // When everything fits, the sheets and the New tree plate sit together in the middle of
            // the board, like sheets laid out on a table. Past that, the sheets scroll sideways.
            let shownW = overflow ? area.width : gridW
            let top = max(0, (area.height - gridH) / 2)
            HStack(alignment: .top, spacing: 14) {
                GroveScroll(axis: .horizontal, indicators: overflow) {
                    // Lazy: with dozens of trees, only the sheets on screen are drawn and animated.
                    LazyHStack(alignment: .top, spacing: L.spacing) {
                        ForEach(0..<L.columns, id: \.self) { c in
                            VStack(spacing: L.spacing) {
                                ForEach(0..<L.rows, id: \.self) { r in
                                    // Row by row when it all fits (1, 2, 3 across the top); column by column
                                    // when it scrolls, so new trees appear at the scrolling end.
                                    let i = overflow ? c * L.rows + r : r * L.columns + c
                                    if i < trees.count {
                                        let tree = trees[i]
                                        SpecimenPlate(tree: tree, store: store, compact: true, tight: L.rows > 1, sheetWidth: L.cell.width) {
                                            withAnimation(Motion.pick(Motion.page)) { model.page = .tree(tree.id) }
                                        }
                                        .frame(width: L.cell.width, height: L.cell.height)
                                        .mounted(seed: tree.id)
                                    } else {
                                        Color.clear.frame(width: L.cell.width, height: L.cell.height)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, top)
                    .padding(.trailing, 2)
                }
                .frame(width: shownW, height: area.height)
                PlantPlate { withAnimation(Motion.pick(Motion.page)) { model.page = .newTree } }
                    .frame(width: plate, height: gridH)
                    .padding(.top, top)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

/// One mounted specimen: the tree, its papers and pencil branches, and the label in the corner.
struct SpecimenPlate: View {
    var tree: PaperTreeData
    @ObservedObject var store: TreeStore
    var compact: Bool
    /// Short sheets (two rows in the grove): a smaller label, so the plant keeps the room.
    var tight = false
    /// The sheet's width in the grove, so the label can sit lower right at a fraction of it.
    var sheetWidth: CGFloat? = nil
    var onOpen: (() -> Void)? = nil
    /// On the tree's own page: zoom and pan, and papers open in the reader.
    var onOpenPaper: ((Paper, CGPoint) -> Void)? = nil
    var startZoom: CGFloat = 1
    var startPan: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let open = onOpenPaper {
                    TreeViewport(tree: tree, store: store, startZoom: startZoom, startPan: startPan, onOpenPaper: open)
                } else {
                    TreeCanvas(tree: tree, store: store, lively: !compact, groundedAt: compact ? 10 : nil)
                }
            }
            .clipped()
            HStack(alignment: .bottom) {
                if !compact {
                    Text(String(format: "Sheet PT-%04d", tree.number))
                        .font(.typewriter(9.5)).foregroundColor(Palette.ink3)
                }
                Spacer(minLength: 0)
                HerbariumLabel(tree: tree, compact: compact, tight: tight, sheetWidth: sheetWidth)
                    .onTapGesture { onOpen?() }
            }
            .padding(.horizontal, compact ? 7 : 8)
            .padding(.bottom, compact ? 7 : 6)
        }
        // In the grove the accession number is stamped at the top, the way a real sheet is numbered.
        .overlay(alignment: .topLeading) {
            if compact {
                Text(String(format: "PT-%04d", tree.number))
                    .font(.typewriter(8.5)).foregroundColor(Palette.ink3)
                    .padding(.leading, 8).padding(.top, 7)
            }
        }
        .background(
            Rectangle().fill(Color(hex: 0xFBF8EE))
                .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.14), lineWidth: 0.6))
                .shadow(color: Palette.ink.opacity(0.12), radius: 1.5, x: 0, y: 1)
                .shadow(color: Palette.ink.opacity(0.08), radius: 10, x: 0, y: 6)
        )
        .contentShape(Rectangle())
        .hoverLift(compact ? 1 : 0)
        .onTapGesture(count: 2) { onOpen?() }
        .help(onOpen == nil ? "" : "Click the label to look closer")
    }
}

/// The label in the lower right of a herbarium sheet: four lines at most. The catalog line with the count,
/// the name, the made-up binomial, and one hand-written line, the common name. Where it grew from is
/// told once, on the tree's own page.
struct HerbariumLabel: View {
    var tree: PaperTreeData
    var compact: Bool
    var tight = false
    var sheetWidth: CGFloat? = nil

    var body: some View {
        if tight { tightBody } else { fullBody }
    }

    private var count: String {
        "\(tree.papers.count) \(tree.papers.count == 1 ? "paper" : "papers")"
    }

    private var common: String {
        tree.look.commonName.isEmpty ? "a young \(tree.look.species.plainName)" : tree.look.commonName.lowercased()
    }

    /// Small sheets: the name and the count only.
    private var tightBody: some View {
        VStack(alignment: .leading, spacing: 1) {
            tree.nameText(14).foregroundColor(Palette.ink)
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text(count).font(.typewriter(8.5)).foregroundColor(Palette.ink3)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(width: sheetWidth.map { $0 * 0.62 }, alignment: .leading)
        .frame(maxWidth: sheetWidth == nil ? CGFloat.infinity : nil, alignment: .leading)
        .background(Color(hex: 0xFFFDF6))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.75), lineWidth: 0.9))
        .rotationEffect(.degrees(-0.6))
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Paper Tree Herbarium").font(.typewriter(8.5))
                Spacer(minLength: 4)
                Text(count + (tree.suggestions.isEmpty || compact ? "" : ", \(tree.suggestions.count) suggested"))
                    .font(.typewriter(8.5)).fixedSize()
            }
            .foregroundColor(Palette.ink3)
            tree.nameText(compact ? 15 : 19).foregroundColor(Palette.ink)
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            if !tree.look.latinName.isEmpty {
                Text(tree.look.latinName).font(.text(compact ? 11.5 : 13)).foregroundColor(Palette.ink2).lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Text(common)
                .font(.hand(compact ? 12.5 : 14)).foregroundColor(Palette.ink.opacity(0.85)).lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(width: compact ? sheetWidth.map { $0 * 0.68 } : nil, alignment: .leading)
        .frame(maxWidth: compact ? (sheetWidth == nil ? CGFloat.infinity : nil) : 260, alignment: .leading)
        .background(Color(hex: 0xFFFDF6))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.75), lineWidth: 0.9))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.35), lineWidth: 0.4).padding(2.5))
        .rotationEffect(.degrees(-0.6))
    }
}

/// A sheet mounted in the grove: a slight tilt and a small drop, both seeded from the tree's id,
/// so each sheet sits a little differently but never moves between launches.
private struct Mounted: ViewModifier {
    var seed: UUID
    func body(content: Content) -> some View {
        let (tilt, drop) = Self.place(seed)
        return content
            .rotationEffect(.degrees(tilt))
            .offset(y: drop)
    }

    /// Stable across launches (Swift's hashValue is not), from the UUID's own bytes.
    static func place(_ id: UUID) -> (Double, CGFloat) {
        let u = id.uuid
        let a = Double(u.0 ^ u.5 ^ u.9) / 255
        let b = Double(u.3 ^ u.11 ^ u.14) / 255
        return (-0.7 + 1.4 * a, CGFloat(5 * b))
    }
}

extension View {
    fileprivate func mounted(seed: UUID) -> some View { modifier(Mounted(seed: seed)) }
}

/// The empty plate at the end of the grove: a pencil outline and a sprout.
private struct PlantPlate: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Spacer()
                Sprout()
                    .stroke(Palette.ink3, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 28, height: 28)
                Text("New tree").font(.fell(19)).foregroundColor(Palette.ink)
                Text("start from one paper").font(.ui(12.5)).foregroundColor(Palette.ink3)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(PencilOutline().stroke(Palette.pencil.opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A rectangle drawn by hand in pencil: each side wanders 2 to 3 pt, the same way every time.
struct PencilOutline: Shape {
    var seed: UInt64 = 7
    func path(in r: CGRect) -> Path {
        var rnd = SeededRandom(seed, "pencil-outline")
        let inset = r.insetBy(dx: 2, dy: 2)
        let corners = [CGPoint(x: inset.minX, y: inset.minY), CGPoint(x: inset.maxX, y: inset.minY),
                       CGPoint(x: inset.maxX, y: inset.maxY), CGPoint(x: inset.minX, y: inset.maxY)]
        var p = Path()
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4]
            let len = hypot(b.x - a.x, b.y - a.y)
            let nx = -(b.y - a.y) / max(1, len), ny = (b.x - a.x) / max(1, len)
            // Start a hair past the corner and overshoot the end, as a pencil does.
            let start = CGPoint(x: a.x + rnd.cg(-1.5, 1.5), y: a.y + rnd.cg(-1.5, 1.5))
            let end = CGPoint(x: b.x + rnd.cg(-1.5, 1.5), y: b.y + rnd.cg(-1.5, 1.5))
            let w1 = rnd.cg(-3, 3), w2 = rnd.cg(-3, 3)
            p.move(to: start)
            p.addCurve(to: end,
                       control1: CGPoint(x: a.x + (b.x - a.x) * 0.33 + nx * w1, y: a.y + (b.y - a.y) * 0.33 + ny * w1),
                       control2: CGPoint(x: a.x + (b.x - a.x) * 0.66 + nx * w2, y: a.y + (b.y - a.y) * 0.66 + ny * w2))
        }
        return p
    }
}

/// The Research mode switch in the island header: a typed label, then "on" and "off",
/// with the current word circled in pencil, the way you would circle it on a form.
struct ResearchSwitch: View {
    var on: Bool
    var action: () -> Void
    @Namespace private var ns

    var body: some View {
        Button(action: { withAnimation(Motion.pick(Motion.snappy)) { action() } }) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("Research mode").font(.typewriter(11)).foregroundColor(Color.white.opacity(0.7))
                word("on", selected: on)
                Text("/").font(.ui(12.5)).foregroundColor(.white.opacity(0.35))
                word("off", selected: !on)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Research mode")
        .accessibilityValue(on ? "On" : "Off")
    }

    private func word(_ w: String, selected: Bool) -> some View {
        Text(w).font(.ui(12.5))
            .foregroundColor(Color.white.opacity(selected ? 0.95 : 0.45))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background {
                if selected {
                    HandCircle()
                        .stroke(Palette.paper, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                        .padding(-2)
                        .matchedGeometryEffect(id: "circle", in: ns)
                }
            }
    }
}

/// A loose ellipse drawn in one stroke that overshoots where it began.
struct HandCircle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rx = r.width / 2, ry = r.height / 2
        let steps = 40
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let ang = -2.2 + f * (2 * .pi + 0.45)
            let wob = 1 + 0.05 * sin(f * 9) - 0.04 * f
            let pt = CGPoint(x: c.x + CGFloat(cos(ang) * wob) * rx, y: c.y + CGFloat(sin(ang) * wob) * ry - CGFloat(f) * 0.8)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

// MARK: - The tree with clickable tips

struct TreeCanvas: View {
    var tree: PaperTreeData
    @ObservedObject var store: TreeStore
    /// Big trees on their own page move at full frame rate; sheets in the grove sway more lazily.
    var lively = true
    /// 1 is the whole tree fitted to the view; more is closer.
    var zoom: CGFloat = 1
    /// Sideways and up-down shift of the view, in points.
    var pan: CGSize = .zero
    /// On a tree's own page: papers open in the reader and get readable captions up close.
    var onOpenPaper: ((Paper, CGPoint) -> Void)? = nil
    /// Grove sheets: the drawing sits on the bottom edge, this many points above it, instead of centered.
    var groundedAt: CGFloat? = nil
    @State private var openGhost: String?
    @State private var appeared = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// False when the island panel (or any host window) is not key, so idle sway stops while you work elsewhere.
    @Environment(\.controlActiveState) private var controlActiveState

    /// How much room a tree gets to spread out in, relative to the view: more for busy trees.
    static func world(for tree: PaperTreeData, in size: CGSize) -> CGSize {
        let busy = CGFloat(tree.papers.count + tree.suggestions.count)
        let k = min(1.8, 1 + 0.07 * max(0, busy - 5))
        return CGSize(width: max(200, size.width * k), height: max(200, size.height * k))
    }

    /// Drawing coordinates to view coordinates: fit everything drawn, then zoom and pan.
    static func camera(_ g: TreeGeometry, in size: CGSize, zoom: CGFloat, pan: CGSize, pad: CGFloat,
                       groundedAt: CGFloat? = nil) -> (CGAffineTransform, CGFloat) {
        let b = g.contentBounds.isEmpty ? CGRect(origin: .zero, size: size) : g.contentBounds
        let fit = min((size.width - pad * 2) / max(1, b.width), (size.height - pad - (groundedAt ?? pad)) / max(1, b.height))
        let s = max(0.01, fit * zoom)
        if let ground = groundedAt {
            let t = CGAffineTransform(translationX: size.width / 2 + pan.width, y: size.height - ground + pan.height)
                .scaledBy(x: s, y: s)
                .translatedBy(x: -b.midX, y: -b.maxY)
            return (t, s)
        }
        let t = CGAffineTransform(translationX: size.width / 2 + pan.width, y: size.height / 2 + pan.height)
            .scaledBy(x: s, y: s)
            .translatedBy(x: -b.midX, y: -b.midY)
        return (t, s)
    }

    /// No sway loop while Reduce Motion is on, the host window is not key, or a snapshot froze the clock.
    /// GroveView itself is only in the hierarchy while the island is expanded, so a collapsed island
    /// already tears the TimelineView down.
    private var swayPaused: Bool {
        reduceMotion
            || controlActiveState != .key
            || TreeClock.frozen != nil
    }

    var body: some View {
        GeometryReader { geo in
            let world = Self.world(for: tree, in: geo.size)
            let g = TreeGeometry.cached(tree, in: world)
            TimelineView(.animation(minimumInterval: lively ? 1.0 / 30 : 1.0 / 12, paused: swayPaused)) { timeline in
                scene(g, world: world, size: geo.size, now: TreeClock.frozen ?? timeline.date)
            }
        }
    }

    /// 0 to 1 while a tree turns into a different plant after a re-read; nil when there is nothing to cross.
    static func morph(_ tree: PaperTreeData, now: Date) -> CGFloat? {
        guard tree.priorLook != nil, let at = tree.lookChangedAt else { return nil }
        let t = now.timeIntervalSince(at) / 2.8
        guard t >= 0, t < 1 else { return nil }
        return CGFloat(t * t * (3 - 2 * t))
    }

    private func scene(_ g: TreeGeometry, world: CGSize, size: CGSize, now: Date) -> some View {
        let still = reduceMotion
        let growing = still ? nil : TreeGrowth.current(tree, at: now)
        let pose = g.pose(time: still ? 0 : now.timeIntervalSinceReferenceDate, wind: still ? 0 : 1, growing: growing)
        let sketchFrom = TreeClock.sketchStart ?? (TreeClock.frozen == nil ? appeared : nil)
        var sketch: [String: CGFloat] = [:]
        if let sketchFrom, !still {
            for (k, gh) in g.ghosts.enumerated() {
                sketch[gh.id] = CGFloat(max(0, min(1, (now.timeIntervalSince(sketchFrom) - 0.35 - Double(k) * 0.22) / 0.9)))
            }
        }
        let (cam, scale) = Self.camera(g, in: size, zoom: zoom, pan: pan, pad: onOpenPaper == nil ? 6 : 18, groundedAt: groundedAt)
        let card = CGSize(width: g.cardSize.width * scale, height: g.cardSize.height * scale)
        let papers = tree.papers.sorted { $0.addedAt < $1.addedAt }
        let morph = still ? nil : Self.morph(tree, now: now)
        return ZStack(alignment: .topLeading) {
            if let m = morph, let prior = tree.priorLook {
                // The old plant fades and settles while the new one comes up through it.
                let old = Self.before(tree, prior)
                let og = TreeGeometry.cached(old, in: world)
                TreeDrawing(tree: old, geometry: og, pose: og.pose(time: now.timeIntervalSinceReferenceDate, wind: 1, growing: nil), camera: cam)
                    .opacity(Double(1 - m))
                    .scaleEffect(1 - 0.04 * m, anchor: .bottom)
            }
            TreeDrawing(tree: tree, geometry: g, pose: pose, sketch: sketch, camera: cam)
                .opacity(Double(morph ?? 1))
                .scaleEffect(0.96 + 0.04 * (morph ?? 1), anchor: .bottom)
            ForEach(g.ghosts, id: \.id) { ghost in
                if let s = tree.suggestions.first(where: { $0.id == ghost.id }) {
                    GhostTipCard(paper: s.paper, size: card, full: card.width > 90)
                        .opacity(Self.ghostOpacity(sketch[ghost.id] ?? 1))
                        .position(Self.spot(ghost.id, node: ghost.node, home: ghost.from, g: g, pose: pose, cam: cam))
                        .onTapGesture { openGhost = s.id }
                        .help("Suggested: \(s.paper.title)")
                        .popover(isPresented: Binding(get: { openGhost == s.id }, set: { if !$0 { openGhost = nil } }), arrowEdge: .bottom) {
                            SuggestionSlip(suggestion: s, tree: tree, store: store) { openGhost = nil }
                        }
                }
            }
            ForEach(Array(g.tips.enumerated()), id: \.element.id) { i, tip in
                if let paper = tree.papers.first(where: { $0.id == tip.id }) {
                    tipCard(paper, tip: tip, index: i, owner: papers.firstIndex(where: { $0.id == paper.id }) ?? 0,
                            g: g, pose: pose, cam: cam, card: card, growing: growing)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private static func before(_ tree: PaperTreeData, _ prior: TreeLook) -> PaperTreeData {
        var old = tree
        old.look = prior
        old.priorLook = nil
        old.lookChangedAt = nil
        return old
    }

    private static func ghostOpacity(_ drawn: CGFloat) -> Double {
        Double(max(0, min(1, (drawn - 0.75) / 0.25)))
    }

    /// Where a card sits on screen: its spaced-out place, carried along as its branch sways.
    private static func spot(_ id: String, node: Int, home: CGPoint, g: TreeGeometry, pose: TreeGeometry.Pose, cam: CGAffineTransform) -> CGPoint {
        let c = g.cardCenters[id] ?? home
        let now: CGPoint = node < pose.p.count ? pose.p[node] : home
        let rest: CGPoint = node < g.nodes.count ? g.nodes[node].p : home
        return CGPoint(x: c.x + now.x - rest.x, y: c.y + now.y - rest.y).applying(cam)
    }

    private func tipCard(_ paper: Paper, tip: TreeGeometry.Tip, index i: Int, owner: Int, g: TreeGeometry,
                         pose: TreeGeometry.Pose, cam: CGAffineTransform, card: CGSize,
                         growing: (owner: Int, progress: CGFloat)?) -> some View {
        // The newest paper's page drops onto its tip once the branch has grown out.
        var land: CGFloat = 1
        if let growing, growing.owner == owner { land = max(0, (growing.progress - 0.68) / 0.32) }
        let settle: CGFloat = TreeGrowth.spring(land)
        let at = Self.spot(tip.id, node: tip.node, home: tip.point, g: g, pose: pose, cam: cam)
        let sway: Double = tip.node < pose.p.count ? Double(pose.p[tip.node].x - g.nodes[tip.node].p.x) * 0.8 : 0
        let tilt: Double = (Double((i * 37) % 11) - 5) * (card.width > 90 ? 0.4 : 1) + sway + Double(1 - settle) * 9
        let opacity: Double = land <= 0 ? 0 : Double(min(1, land * 3))
        var help = paper.title
        if !paper.shortAuthors.isEmpty { help += ", " + paper.shortAuthors }
        if let y = paper.year { help += " (\(y))" }
        let open = onOpenPaper
        return TipCardWithCaption(paper: paper, image: store.thumbnails[paper.id], size: card, tilt: tilt,
                                  caption: open != nil && card.width > 96)
            .scaleEffect(0.82 + 0.18 * settle)
            .opacity(opacity)
            .position(x: at.x, y: at.y - (1 - settle) * card.height * 0.8)
            .onTapGesture { open?(paper, at) }
            .help(open == nil ? help : help + "\nClick to read it here")
    }
}

/// A paper card, with its title and authors written underneath once there's room to read them.
struct TipCardWithCaption: View {
    var paper: Paper
    var image: NSImage?
    var size: CGSize
    var tilt: Double
    var caption: Bool

    var body: some View {
        PaperTipCard(paper: paper, image: image, size: size, tilt: tilt)
            .overlay(alignment: .top) {
                if caption {
                    VStack(spacing: 2) {
                        Text(paper.title)
                            .font(.custom(Typeface.textMedium, size: min(15, max(10, size.width * 0.085))))
                            .foregroundColor(PlantInk.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        Text([paper.shortAuthors, paper.year.map(String.init) ?? ""].filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.custom(Typeface.text, size: min(13, max(9, size.width * 0.07))))
                            .foregroundColor(PlantInk.ink.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .frame(width: size.width * 1.35)
                    .background(Color(hex: 0xFCFAF3).opacity(0.92))
                    .overlay(Rectangle().strokeBorder(PlantInk.ink.opacity(0.25), lineWidth: 0.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: size.height + 8)
                    .allowsHitTesting(false)
                }
            }
    }
}

/// The tree on its own page: pinch, Command plus and minus, or the buttons to zoom; scroll or drag to move around.
struct TreeViewport: View {
    var tree: PaperTreeData
    @ObservedObject var store: TreeStore
    var onOpenPaper: (Paper, CGPoint) -> Void
    @State private var zoom: CGFloat
    @State private var pan: CGSize
    @GestureState private var pinch: CGFloat = 1
    @State private var dragFrom: CGSize?
    @State private var box = ViewportBox()

    static let zoomRange: ClosedRange<CGFloat> = 0.4...3

    init(tree: PaperTreeData, store: TreeStore, startZoom: CGFloat = 1, startPan: CGSize = .zero,
         onOpenPaper: @escaping (Paper, CGPoint) -> Void) {
        self.tree = tree
        self.store = store
        self.onOpenPaper = onOpenPaper
        _zoom = State(initialValue: startZoom)
        _pan = State(initialValue: startPan)
    }

    private var liveZoom: CGFloat { clamp(zoom * pinch) }
    private var livePan: CGSize { CGSize(width: pan.width * liveZoom / zoom, height: pan.height * liveZoom / zoom) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                TreeCanvas(tree: tree, store: store, zoom: liveZoom, pan: livePan, onOpenPaper: onOpenPaper)
                    .contentShape(Rectangle())
                    .gesture(MagnificationGesture()
                        .updating($pinch) { v, s, _ in s = v }
                        .onEnded { v in setZoom(zoom * v, animated: false) })
                    .simultaneousGesture(DragGesture(minimumDistance: 4)
                        .onChanged { v in
                            let from = dragFrom ?? pan
                            if dragFrom == nil { dragFrom = pan }
                            pan = CGSize(width: from.width + v.translation.width, height: from.height + v.translation.height)
                        }
                        .onEnded { _ in dragFrom = nil })
                controls.padding(10)
            }
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { box.frame = g.frame(in: .global) }
                    .onChange(of: g.frame(in: .global)) { box.frame = $0 }
            })
            .onAppear { install() }
            .onDisappear { box.remove() }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            zoomButton("minus", "Zoom out (Command minus)") { setZoom(zoom / 1.3) }
            Text(String(format: "%d%%", Int((liveZoom * 100).rounded())))
                .font(.typewriter(10.5)).foregroundColor(Palette.ink2).frame(width: 44)
            zoomButton("plus", "Zoom in (Command plus)") { setZoom(zoom * 1.3) }
            Rectangle().fill(Palette.ink.opacity(0.18)).frame(width: 1, height: 16).padding(.horizontal, 4)
            Button { fit() } label: {
                Text("Fit").font(.uiBold(11.5)).foregroundColor(Palette.ink2).padding(.horizontal, 8).frame(height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Fit the whole tree (Command 0)")
        }
        .padding(.horizontal, 4)
        .background(Capsule().fill(Color(hex: 0xFCFAF3)).shadow(color: .black.opacity(0.12), radius: 2, y: 1))
        .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.2), lineWidth: 0.7))
    }

    private func zoomButton(_ icon: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.ink2)
                .frame(width: 26, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func clamp(_ z: CGFloat) -> CGFloat { min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, z)) }

    private func setZoom(_ z: CGFloat, animated: Bool = true) {
        let new = clamp(z)
        let k = new / max(0.01, zoom)
        let change = {
            pan = CGSize(width: pan.width * k, height: pan.height * k)
            zoom = new
        }
        if animated { withAnimation(Motion.pick(Motion.snappy), change) } else { change() }
    }

    private func fit() {
        withAnimation(Motion.pick(Motion.page)) { zoom = 1; pan = .zero }
    }

    /// Two-finger scrolling pans, Command-scroll zooms, Command plus, minus and 0 zoom from the keyboard.
    private func install() {
        box.remove()
        let frameBox = box
        // Monitors decide right away whether the event is ours; the change itself happens on the main actor.
        let scroll = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { e in
            guard e.window is IslandPanel, frameBox.contains(e) else { return e }
            let k: CGFloat = e.hasPreciseScrollingDeltas ? 1 : 10
            let dx = e.scrollingDeltaX * k, dy = e.scrollingDeltaY * k
            let zooming = e.modifierFlags.contains(.command)
            Task { @MainActor in
                if zooming { setZoom(zoom * (1 + dy * 0.004), animated: false) }
                else { pan = CGSize(width: pan.width + dx, height: pan.height + dy) }
            }
            return nil
        }
        let keys = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { e in
            guard e.window is IslandPanel, e.modifierFlags.contains(.command) else { return e }
            let key = e.charactersIgnoringModifiers ?? ""
            guard ["=", "+", "-", "_", "0"].contains(key) else { return e }
            Task { @MainActor in
                switch key {
                case "=", "+": setZoom(zoom * 1.3)
                case "-", "_": setZoom(zoom / 1.3)
                default: fit()
                }
            }
            return nil
        }
        box.monitors = [scroll, keys].compactMap { $0 }
    }
}

/// Where the viewport is in its window, and its event monitors, kept outside SwiftUI's view values.
final class ViewportBox {
    var frame: CGRect = .zero
    var monitors: [Any] = []

    func contains(_ e: NSEvent) -> Bool {
        guard let h = e.window?.contentView?.bounds.height else { return false }
        let p = CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y)
        return frame.contains(p)
    }

    func remove() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }

    deinit { monitors.forEach { NSEvent.removeMonitor($0) } }
}

/// What a pencil branch says when you click it.
struct SuggestionSlip: View {
    var suggestion: Suggestion
    var tree: PaperTreeData
    @ObservedObject var store: TreeStore
    var done: () -> Void

    var body: some View {
        let from = tree.papers.first { $0.id == suggestion.fromPaperId }
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested, from Semantic Scholar").font(.typewriter(10)).foregroundColor(Palette.ink3)
            Text(suggestion.paper.title).font(.textMedium(15)).foregroundColor(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text([suggestion.paper.authors.prefix(3).joined(separator: ", "), suggestion.paper.year.map(String.init) ?? ""]
                    .filter { !$0.isEmpty }.joined(separator: ", "))
                .font(.ui(12)).foregroundColor(Palette.ink3)
            if let from {
                Text("It builds on \u{201C}\(from.title)\u{201D}.")
                    .font(.text(13)).foregroundColor(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Button("Keep it") { store.keep(suggestion, in: tree.id); done() }
                    .buttonStyle(StampButtonStyle(compact: true))
                Button("Prune it") { store.prune(suggestion, in: tree.id); done() }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                Spacer()
                if let u = suggestion.paper.openURL {
                    Button("Read it first") { NSWorkspace.shared.open(u) }
                        .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
        .background(PaperSheet(corner: 0))
    }
}

// MARK: - One tree, up close

struct TreeSheetPage: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var store: TreeStore
    var tree: PaperTreeData
    /// The paper whose match is being changed (its id), and, for snapshots, the matches to offer.
    @State var rematching: String? = nil
    var rematchPreset: [Paper]? = nil
    @State private var hovered: String?
    var startZoom: CGFloat = 1
    var startPan: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 18) {
                ZStack(alignment: .topLeading) {
                    SpecimenPlate(tree: tree, store: store, compact: false,
                                  onOpenPaper: { paper, at in read(paper, at: at, in: geo.size) },
                                  startZoom: startZoom, startPan: startPan)
                    Button("All trees") { withAnimation(Motion.pick(Motion.page)) { model.page = .grove } }
                        .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
                        .padding(12)
                }
                notes.frame(width: 270)
            }
        }
    }

    /// Opens a paper in the reader, growing out of where it was clicked.
    private func read(_ paper: Paper, at point: CGPoint, in size: CGSize) {
        model.readerOrigin = UnitPoint(x: max(0, min(1, point.x / max(1, size.width))), y: max(0, min(1, point.y / max(1, size.height))))
        withAnimation(Motion.pick(Motion.open)) { model.page = .paper(tree.id, paper.id) }
    }

    private var notes: some View {
        GroveScroll(axis: .vertical) {
            VStack(alignment: .leading, spacing: 12) {
                tree.nameText(28).foregroundColor(Palette.ink)
                if let why = tree.look.grownFromLine {
                    (Text("A \(tree.look.species.plainName), ").font(.typewriter(10.5)) + Text(why).font(.typewriter(10.5)))
                        .foregroundColor(Palette.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !tree.look.note.isEmpty {
                    Text(tree.look.note).font(.hand(14.5)).foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .rotationEffect(.degrees(-0.8))
                }
                // Fixing a match sits at the top, where it can't scroll out of sight.
                if let id = rematching, let p = tree.papers.first(where: { $0.id == id }) {
                    RematchPanel(paper: p, treeId: tree.id, store: store, done: { rematching = nil }, preset: rematchPreset)
                        .id(id)
                }
                SectionHead(title: "Papers", size: 18).padding(.top, 4)
                ForEach(Array(tree.papers.sorted { $0.addedAt < $1.addedAt }.enumerated()), id: \.element.id) { i, p in
                    Group {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(format: "%02d", i + 1)).font(.typewriter(10)).foregroundColor(Palette.red)
                            VStack(alignment: .leading, spacing: 1) {
                                Button { read(p, at: CGPoint(x: 200, y: 200), in: CGSize(width: 1000, height: 700)) } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(p.title).font(.text(13)).foregroundColor(Palette.ink).multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(p.isLocal ? "added as highlighted, not matched" : p.byline)
                                            .font(.ui(11)).foregroundColor(Palette.ink3)
                                    }
                                }
                                .buttonStyle(.plain)
                                if hovered == p.id || p.isLocal {
                                    Button(p.isLocal ? "Find a match" : "Wrong paper? Change the match") { rematching = p.id }
                                        .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
                                }
                            }
                        }
                        .padding(.horizontal, rematching == p.id ? 4 : 0)
                        .background(rematching == p.id ? Palette.marker.opacity(0.35) : Color.clear)
                        .contentShape(Rectangle())
                        .onHover { inside in hovered = inside ? p.id : (hovered == p.id ? nil : hovered) }
                        .contextMenu {
                            Button("Change the match...") { rematching = p.id }
                            Button("Remove from this tree") { store.remove(paperId: p.id, from: tree.id) }
                        }
                    }
                }
                if !tree.suggestions.isEmpty {
                    SectionHead(title: "Pencil branches", size: 18).padding(.top, 6)
                    Text("Suggested papers. Keep one and it turns to ink.").font(.text(12.5)).foregroundColor(Palette.ink3)
                    ForEach(tree.suggestions) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.paper.title).font(.text(13.5)).foregroundColor(Palette.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 12) {
                                Button("Keep it") { store.keep(s, in: tree.id) }.buttonStyle(InkLinkButtonStyle(color: Palette.green))
                                Button("Prune it") { store.prune(s, in: tree.id) }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Planting a new tree

struct NewTreePage: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var store: TreeStore
    @State private var name = ""

    private var seedTree: PaperTreeData {
        PaperTreeData(number: 0, name: "", seed: 7, look: TreeLook(species: .oak))
    }

    @ViewBuilder private var nameField: some View {
        let placeholder = "Tree No. \((store.trees.map(\.number).max() ?? 0) + 1)"
        Group {
            if Snapshots.isRendering {
                Text(placeholder).foregroundColor(Palette.pencil).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(placeholder, text: $name).textFieldStyle(.plain).foregroundColor(Color(hex: 0x23314A))
            }
        }
        .font(.hand(18))
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink.opacity(0.4)).frame(height: 0.8) }
        .frame(width: 280)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 34) {
            ZStack {
                TreeCanvas(tree: seedTree, store: store)
                Text("a seed, waiting for its first paper")
                    .font(.ui(12.5)).foregroundColor(Palette.ink3)
                    .offset(y: 70)
            }
            .frame(width: 300, height: 300)

            VStack(alignment: .leading, spacing: 14) {
                Text(store.trees.isEmpty ? "Plant your first tree" : "Plant a new tree")
                    .font(.fell(34)).foregroundColor(Palette.ink)
                Text("Every tree starts from one paper. Find it anywhere on your Mac, in a PDF, a browser or a reference list, and highlight its title. Then tap the right Option key once. That paper becomes the first branch.")
                    .font(.text(15.5)).foregroundColor(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text("name it, if you like").font(.typewriter(10.5)).foregroundColor(Palette.ink3)
                    nameField
                }
                if store.plantingNewTree != nil {
                    Text("Waiting for a title. Highlight one and tap right Option.")
                        .font(.ui(12.5)).foregroundColor(Palette.ink2)
                }
                HStack(spacing: 16) {
                    Button("I'm ready, put this away") {
                        store.plantingNewTree = name
                        model.onClose()
                    }
                    .buttonStyle(StampButtonStyle(compact: true))
                    if !store.trees.isEmpty {
                        Button("Never mind") {
                            store.plantingNewTree = nil
                            withAnimation(Motion.pick(Motion.page)) { model.page = .grove }
                        }
                        .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Choosing a tree for a new paper (the island, half open)

struct AddChooser: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var store: TreeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Add a paper").font(.fell(19)).foregroundColor(.white)
                Spacer()
                Button("Not now") { model.onClose() }
                    .buttonStyle(InkLinkButtonStyle(color: Color.white.opacity(0.72)))
                    .help("Esc does this too")
            }
            .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 10) {
                slip
                Rectangle().fill(Palette.rule).frame(height: 1)
                Text(model.adding?.choosing == true ? "Pick the paper first, then the tree." :
                        store.plantingNewTree != nil ? "Plant it as a new tree, or add it to one you have:" : "Which tree gets it?")
                    .font(.typewriter(10.5)).foregroundColor(Palette.ink3)
                GroveScroll(axis: .horizontal) {
                    LazyHStack(spacing: 10) {
                        newTreeButton
                        ForEach(store.trees) { tree in treeButton(tree) }
                    }
                    .padding(2)
                }
            }
            .padding(14)
            .background(PaperSheet(corner: 12, graph: true))
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var slip: some View {
        if let req = model.adding {
            switch req.lookup {
            case .looking:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Looking it up in Semantic Scholar, OpenAlex and Crossref...").font(.ui(12.5)).foregroundColor(Palette.ink3)
                    Text("\u{201C}\(req.highlighted)\u{201D}").font(.text(14)).foregroundColor(Palette.ink2).lineLimit(2)
                }
            case .found(let list, _):
                if req.choosing {
                    MatchPicker(question: req.showAll ? "Pick the right one" : "Is this it?",
                                highlighted: req.highlighted,
                                candidates: Array(list.prefix(req.showAll ? 6 : 3)),
                                pick: { p in model.adding?.chosen = p },
                                none: { model.adding?.asHighlighted = true })
                } else if let p = req.paper {
                    HStack(alignment: .top, spacing: 12) {
                        DrawnTitlePage(paper: p, size: CGSize(width: 48, height: 62))
                            .background(Color(hex: 0xFCFAF3))
                            .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.5), lineWidth: 0.6))
                            .rotationEffect(.degrees(-2))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.title).font(.textMedium(15)).foregroundColor(Palette.ink).lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text([p.authors.prefix(3).joined(separator: ", "), p.venue, p.year.map(String.init) ?? ""]
                                    .filter { !$0.isEmpty }.joined(separator: ", "))
                                .font(.ui(11.5)).foregroundColor(Palette.ink3).lineLimit(2)
                            if list.count > 1 || req.chosen != nil || req.asHighlighted {
                                Button("Not this one? Pick another match") {
                                    model.adding?.chosen = nil
                                    model.adding?.asHighlighted = false
                                    model.adding?.showAll = true
                                }
                                .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
                                .padding(.top, 2)
                            }
                        }
                    }
                }
            case .notFound(let why):
                VStack(alignment: .leading, spacing: 4) {
                    Text("\u{201C}\(req.highlighted)\u{201D}").font(.text(14)).foregroundColor(Palette.ink).lineLimit(2)
                    Text("\(why) I can still add it as you highlighted it.").font(.ui(12.5)).foregroundColor(Palette.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var ready: Bool { model.adding?.paper != nil }

    private var newTreeButton: some View {
        Button {
            guard let p = model.adding?.paper else { return }
            let name = store.plantingNewTree ?? ""
            store.plantingNewTree = nil
            let tree = store.newTree(name: name, first: p)
            model.onAdded(tree.id)
        } label: {
            VStack(spacing: 4) {
                Sprout().stroke(Palette.ink3, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 20, height: 20)
                    .frame(width: 84, height: 70)
                    .overlay(PencilOutline(seed: 3).stroke(Palette.pencil.opacity(0.8), lineWidth: 1))
                Text(store.plantingNewTree.map { $0.isEmpty ? "New tree" : $0 } ?? "New tree")
                    .font(.ui(11.5)).foregroundColor(Palette.ink).lineLimit(1)
            }
            .frame(width: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .opacity(ready ? 1 : 0.5)
    }

    private func treeButton(_ tree: PaperTreeData) -> some View {
        Button {
            guard let p = model.adding?.paper else { return }
            store.add(p, to: tree.id)
            model.onAdded(tree.id)
        } label: {
            VStack(spacing: 4) {
                TreeDrawing(tree: tree, geometry: TreeGeometry.cached(tree, in: CGSize(width: 84, height: 70)), detail: 0.5)
                    .frame(width: 84, height: 70)
                    .clipped()
                    .background(Color(hex: 0xFBF8EE))
                    .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.3), lineWidth: 0.7))
                Text(tree.displayName).font(.ui(11.5)).foregroundColor(Palette.ink).lineLimit(1)
            }
            .frame(width: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .opacity(ready ? 1 : 0.5)
        .help(tree.look.commonName.isEmpty ? tree.displayName : tree.look.commonName)
    }
}

// MARK: - Choosing between matches

/// "Is this it?": the closest records for a highlighted title, each with who, where and when, so the
/// right one is easy to tell from a namesake. Used when adding, and when fixing a match later.
struct MatchPicker: View {
    var question: String
    var highlighted: String
    var candidates: [Paper]
    var pick: (Paper) -> Void
    var none: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(question).font(.fell(18)).foregroundColor(Palette.ink)
                Text("for \u{201C}\(highlighted)\u{201D}").font(.text(12.5)).foregroundColor(Palette.ink3).lineLimit(1)
            }
            ForEach(Array(candidates.enumerated()), id: \.element.id) { i, p in
                Button { pick(p) } label: {
                    HStack(alignment: .top, spacing: 9) {
                        Text(String(format: "%d.", i + 1)).font(.typewriter(11)).foregroundColor(Palette.red).frame(width: 16, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title).font(.text(13.5)).foregroundColor(Palette.ink).lineLimit(2).multilineTextAlignment(.leading)
                            Text(details(p)).font(.ui(11)).foregroundColor(Palette.ink3).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Rectangle().fill(Color.white.opacity(0.35)))
                    .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.15), lineWidth: 0.6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if let none {
                Button("None of these. Add it as I highlighted it") { none() }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
                    .padding(.top, 2)
            }
        }
    }

    private func details(_ p: Paper) -> String {
        var bits = [p.authors.prefix(2).joined(separator: ", ") + (p.authors.count > 2 ? " et al." : ""), p.venue, p.year.map(String.init) ?? ""]
        if let c = p.cites, c > 0 { bits.append("cited \(c.formatted()) times") }
        if let s = p.source { bits.append(s) }
        return bits.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// Fixing a paper that was matched to the wrong record: look its title up again and pick another.
struct RematchPanel: View {
    var paper: Paper
    var treeId: UUID
    @ObservedObject var store: TreeStore
    var done: () -> Void
    /// Set for design snapshots; otherwise the panel looks the title up itself.
    var preset: [Paper]? = nil

    @State private var candidates: [Paper]?
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHead(title: "Change the match", size: 18)
            Text("Right now this branch holds:").font(.text(12.5)).foregroundColor(Palette.ink3)
            Text(paper.title + (paper.byline.isEmpty ? "" : " (\(paper.byline))"))
                .font(.text(13)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            if let list = candidates ?? preset {
                if list.isEmpty {
                    Text("No other records share this title.").font(.ui(12.5)).foregroundColor(Palette.ink3)
                } else {
                    MatchPicker(question: "Pick another match", highlighted: paper.title, candidates: Array(list.prefix(6))) { p in
                        store.replace(paperId: paper.id, in: treeId, with: p)
                        done()
                    }
                }
            } else if let problem {
                Text(problem).font(.ui(12.5)).foregroundColor(Palette.red)
            } else {
                Text("Looking it up again...").font(.ui(12.5)).foregroundColor(Palette.ink3)
            }
            Button("Keep it as it is") { done() }
                .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
        }
        .padding(12)
        .background(Rectangle().fill(Color.white.opacity(0.4)))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.25), lineWidth: 0.7))
        .task {
            guard preset == nil, candidates == nil else { return }
            do {
                let r = try await PaperLookup.find(paper.title)
                candidates = r.candidates.filter { $0.id != paper.id && ($0.doi == nil || $0.doi != paper.doi) }
            } catch {
                problem = "I couldn't reach the paper databases. Try again in a moment."
            }
        }
    }
}

extension PaperTreeData {
    /// The tree's name for a heading. IM Fell's old-style 1 reads as a dotless i, so the number in a
    /// default name ("Tree No. 1") is set in Newsreader's lining figures.
    func nameText(_ size: CGFloat) -> Text {
        if name.isEmpty {
            return Text("Tree No. ").font(.fell(size)) + Text("\(number)").font(.text(size * 0.94))
        }
        return Text(name).font(.fell(size))
    }
}
