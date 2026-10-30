// What the island shows when it opens wide: the grove. Every tree is mounted on its own herbarium
// sheet with a label in the lower right corner, the way pressed specimens are kept. Click a tree to
// look at it closely; click a paper at a branch tip to open it; click a pencil branch to keep or prune it.
import AppKit
import SwiftUI

enum GrovePage: Equatable {
    case grove
    case tree(UUID)
    case newTree
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
            ZStack {
                PaperSheet(corner: 18, graph: true)
                page
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
            }
            Text("tap right Option: add a highlighted paper     tap tap: open or close     tap tap tap: Research mode")
                .font(.typewriter(9.5))
                .foregroundColor(Color.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            BuddyView(mood: state.mood, researchMode: state.researchMode, compact: true).frame(width: 24, height: 24)
            Text("Paper Tree").font(.fell(21)).foregroundColor(.white)
            Text(store.trees.isEmpty ? "the grove, unplanted" : "the grove, \(store.trees.count) \(store.trees.count == 1 ? "tree" : "trees")")
                .font(.typewriter(10.5)).foregroundColor(Palette.mintLight.opacity(0.85))
            Spacer()
            Button {
                state.researchMode.toggle()
            } label: {
                HStack(spacing: 7) {
                    Circle().fill(state.researchMode ? Palette.mint : Color.white.opacity(0.25)).frame(width: 8, height: 8)
                    Text(state.researchMode ? "Research mode on" : "Research mode off")
                        .font(.uiBold(12.5)).foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Triple-tap right Option does this too")
            darkLink("Settings", model.onOpenSettings)
            darkLink("Check for Updates", model.onCheckForUpdates)
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
        case .tree(let id):
            if let tree = store.trees.first(where: { $0.id == id }) {
                TreeSheetPage(model: model, store: store, tree: tree)
            } else {
                overview
            }
        case .grove:
            overview
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

// MARK: - All trees side by side

struct GroveOverview: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var store: TreeStore

    /// How the sheets are laid out for a number of trees in a space: one row for up to three trees,
    /// then two rows of sheets that never get narrower than a little under their height. Past what
    /// fits, the rows scroll sideways; the New tree sheet stays pinned outside the scroll.
    struct Layout {
        var rows: Int, columns: Int, cell: CGSize, spacing: CGFloat
        static func make(count: Int, in size: CGSize, spacing: CGFloat = 12) -> Layout {
            let n = max(1, count)
            let rows = n <= 3 ? 1 : 2
            let columns = Int((Double(n) / Double(rows)).rounded(.up))
            let h = (size.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            let even = (size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let w = rows == 1 ? min(even, h * 1.25) : max(h * 0.95, min(even, h * 1.3))
            return Layout(rows: rows, columns: columns, cell: CGSize(width: floor(w), height: floor(h)), spacing: spacing)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let plate: CGFloat = 150
            let area = CGSize(width: geo.size.width - plate - 14, height: geo.size.height)
            let trees = store.trees.sorted { $0.number < $1.number }
            let L = Layout.make(count: trees.count, in: area)
            let overflow = CGFloat(L.columns) * L.cell.width + CGFloat(L.columns - 1) * L.spacing > area.width + 1
            HStack(alignment: .top, spacing: 14) {
                GroveScroll(axis: .horizontal, indicators: overflow) {
                    HStack(alignment: .top, spacing: L.spacing) {
                        ForEach(0..<L.columns, id: \.self) { c in
                            VStack(spacing: L.spacing) {
                                ForEach(0..<L.rows, id: \.self) { r in
                                    let i = c * L.rows + r
                                    if i < trees.count {
                                        let tree = trees[i]
                                        SpecimenPlate(tree: tree, store: store, compact: true, tight: L.rows > 1) {
                                            withAnimation(.easeInOut(duration: 0.25)) { model.page = .tree(tree.id) }
                                        }
                                        .frame(width: L.cell.width, height: L.cell.height)
                                    } else {
                                        Color.clear.frame(width: L.cell.width, height: L.cell.height)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(width: area.width, height: area.height)
                PlantPlate { withAnimation(.easeInOut(duration: 0.25)) { model.page = .newTree } }
                    .frame(width: plate, height: geo.size.height)
            }
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
    var onOpen: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            TreeCanvas(tree: tree, store: store)
                .clipped()
            HStack(alignment: .bottom) {
                Text(String(format: "Sheet PT-%04d", tree.number))
                    .font(.typewriter(9.5)).foregroundColor(Palette.ink3)
                Spacer()
                HerbariumLabel(tree: tree, compact: compact, tight: tight)
                    .onTapGesture { onOpen?() }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .background(
            Rectangle().fill(Color(hex: 0xFBF8EE))
                .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.18), lineWidth: 0.8))
                .shadow(color: Palette.ink.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen?() }
        .help(onOpen == nil ? "" : "Click the label to look closer")
    }
}

/// The label in the lower right of a herbarium sheet: name, made-up binomial, what it holds.
struct HerbariumLabel: View {
    var tree: PaperTreeData
    var compact: Bool
    var tight = false

    var body: some View {
        if tight { tightBody } else { fullBody }
    }

    private var tightBody: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(tree.displayName).font(.fell(14)).foregroundColor(Palette.ink).lineLimit(1)
                Text("\(tree.papers.count) \(tree.papers.count == 1 ? "paper" : "papers")")
                    .font(.typewriter(8.5)).foregroundColor(Palette.ink3).fixedSize()
            }
            Text(tree.look.commonName.isEmpty ? "a young \(tree.look.species.plainName)" : tree.look.commonName.lowercased())
                .font(.hand(12)).foregroundColor(Color(hex: 0x23314A)).lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: 200, alignment: .leading)
        .background(Color(hex: 0xFFFDF6))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.75), lineWidth: 0.9))
        .rotationEffect(.degrees(-0.6))
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Paper Tree Herbarium").font(.typewriter(compact ? 8 : 9)).foregroundColor(Palette.ink3)
            Text(tree.displayName).font(.fell(compact ? 15 : 19)).foregroundColor(Palette.ink).lineLimit(1)
            if !tree.look.latinName.isEmpty {
                Text(tree.look.latinName).font(.textItalic(compact ? 11 : 13)).foregroundColor(Palette.ink2).lineLimit(1)
            }
            Text(tree.look.commonName.isEmpty ? "a young \(tree.look.species.plainName)" : tree.look.commonName.lowercased())
                .font(.hand(compact ? 12 : 14)).foregroundColor(Color(hex: 0x23314A)).lineLimit(1)
            Text("\(tree.papers.count) \(tree.papers.count == 1 ? "paper" : "papers")" + (tree.suggestions.isEmpty ? "" : ", \(tree.suggestions.count) suggested"))
                .font(.typewriter(compact ? 8.5 : 9.5)).foregroundColor(Palette.ink3)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: compact ? 190 : 260, alignment: .leading)
        .background(Color(hex: 0xFFFDF6))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.75), lineWidth: 0.9))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.35), lineWidth: 0.4).padding(2.5))
        .rotationEffect(.degrees(-0.6))
    }
}

/// The empty plate at the end of the grove: a dashed outline and a seed.
private struct PlantPlate: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "plus").font(.system(size: 20, weight: .light)).foregroundColor(Palette.ink3)
                Text("New tree").font(.fell(19)).foregroundColor(Palette.ink)
                Text("start from one paper").font(.hand(13.5)).foregroundColor(Palette.pencil)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(Rectangle().stroke(Palette.pencil.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - The tree with clickable tips

struct TreeCanvas: View {
    var tree: PaperTreeData
    @ObservedObject var store: TreeStore
    @State private var openGhost: String?

    var body: some View {
        GeometryReader { geo in
            let g = TreeGeometry.make(tree, in: geo.size)
            ZStack(alignment: .topLeading) {
                TreeDrawing(tree: tree, geometry: g)
                ForEach(g.ghosts, id: \.id) { ghost in
                    if let s = tree.suggestions.first(where: { $0.id == ghost.id }) {
                        GhostTipCard(paper: s.paper, size: g.cardSize)
                            .position(x: ghost.to.x, y: ghost.to.y - g.cardSize.height * 0.4)
                            .onTapGesture { openGhost = s.id }
                            .help("Suggested: \(s.paper.title)")
                            .popover(isPresented: Binding(get: { openGhost == s.id }, set: { if !$0 { openGhost = nil } }), arrowEdge: .bottom) {
                                SuggestionSlip(suggestion: s, tree: tree, store: store) { openGhost = nil }
                            }
                    }
                }
                ForEach(Array(g.tips.enumerated()), id: \.element.id) { i, tip in
                    if let paper = tree.papers.first(where: { $0.id == tip.id }) {
                        let dx = CGFloat(cos(tip.angle)), dy = CGFloat(sin(tip.angle))
                        let lift = g.cardSize.height * (tree.look.species == .flytrap ? 0.32 : 0.42)
                        PaperTipCard(paper: paper, image: store.thumbnails[paper.id], size: g.cardSize,
                                     tilt: Double((i * 37) % 11) - 5)
                            .position(x: tip.point.x + dx * lift, y: tip.point.y + dy * lift)
                            .onTapGesture { if let u = paper.openURL { NSWorkspace.shared.open(u) } }
                            .help(paper.title + (paper.shortAuthors.isEmpty ? "" : ", " + paper.shortAuthors) + (paper.year.map { " (\($0))" } ?? ""))
                    }
                }
            }
        }
    }
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
                    .font(.hand(13.5)).foregroundColor(Color(hex: 0x23314A))
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

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            ZStack(alignment: .topLeading) {
                SpecimenPlate(tree: tree, store: store, compact: false)
                Button("All trees") { withAnimation(.easeInOut(duration: 0.25)) { model.page = .grove } }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
                    .padding(12)
            }
            notes.frame(width: 300)
        }
    }

    private var notes: some View {
        GroveScroll(axis: .vertical) {
            VStack(alignment: .leading, spacing: 12) {
                Text(tree.displayName).font(.fell(28)).foregroundColor(Palette.ink)
                if !tree.look.note.isEmpty {
                    Text(tree.look.note).font(.hand(14.5)).foregroundColor(Palette.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .rotationEffect(.degrees(-0.8))
                }
                // Fixing a match sits at the top, where it can't scroll out of sight.
                if let id = rematching, let p = tree.papers.first(where: { $0.id == id }) {
                    RematchPanel(paper: p, treeId: tree.id, store: store, done: { rematching = nil }, preset: rematchPreset)
                        .id(id)
                }
                Text("Papers").font(.fellItalic(18)).foregroundColor(Palette.ink).padding(.top, 4)
                ForEach(Array(tree.papers.sorted { $0.addedAt < $1.addedAt }.enumerated()), id: \.element.id) { i, p in
                    Group {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(format: "%02d", i + 1)).font(.typewriter(10)).foregroundColor(Palette.red)
                            VStack(alignment: .leading, spacing: 1) {
                                Button { if let u = p.openURL { NSWorkspace.shared.open(u) } } label: {
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
                    Text("Pencil branches").font(.fellItalic(18)).foregroundColor(Palette.ink).padding(.top, 6)
                    Text("Suggested papers. Keep one and it turns to ink.").font(.text(12.5)).foregroundColor(Palette.ink3)
                    ForEach(tree.suggestions) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.paper.title).font(.hand(14)).foregroundColor(Palette.ink2)
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
                    .font(.hand(14)).foregroundColor(Palette.pencil)
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
                        .font(.hand(15)).foregroundColor(Palette.green)
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
                            withAnimation(.easeInOut(duration: 0.25)) { model.page = .grove }
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
                    HStack(spacing: 10) {
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
                    Text("Looking it up in Semantic Scholar, OpenAlex and Crossref...").font(.hand(14.5)).foregroundColor(Palette.pencil)
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
                    Text("\(why) I can still add it as you highlighted it.").font(.hand(13.5)).foregroundColor(Palette.red)
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
                Image(systemName: "plus").font(.system(size: 16, weight: .light)).foregroundColor(Palette.ink3)
                    .frame(width: 84, height: 70)
                    .overlay(Rectangle().stroke(Palette.pencil, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
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
                TreeDrawing(tree: tree, geometry: TreeGeometry.make(tree, in: CGSize(width: 84, height: 70)), detail: 0.5)
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
            Text("Change the match").font(.fellItalic(18)).foregroundColor(Palette.ink)
            Text("Right now this branch holds:").font(.text(12.5)).foregroundColor(Palette.ink3)
            Text(paper.title + (paper.byline.isEmpty ? "" : " (\(paper.byline))"))
                .font(.text(13)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            if let list = candidates ?? preset {
                if list.isEmpty {
                    Text("No other records share this title.").font(.hand(14)).foregroundColor(Palette.pencil)
                } else {
                    MatchPicker(question: "Pick another match", highlighted: paper.title, candidates: Array(list.prefix(6))) { p in
                        store.replace(paperId: paper.id, in: treeId, with: p)
                        done()
                    }
                }
            } else if let problem {
                Text(problem).font(.hand(14)).foregroundColor(Palette.red)
            } else {
                Text("Looking it up again...").font(.hand(14)).foregroundColor(Palette.pencil)
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
