// `PaperTree --paper-tree-snapshots <folder>` renders the main surfaces to PNGs and quits.
// CI uses it so design changes can be reviewed without a Mac. Nothing here runs in normal use.
// It writes sample answers into this Mac's Paper Tree settings, so only run it on a build machine.
import AppKit
import CoreText
import PDFKit
import SwiftUI

@MainActor
enum Snapshots {
    /// True while rendering, so views can swap AppKit-backed controls for drawable stand-ins.
    static var isRendering = false

    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--paper-tree-snapshots"), i + 1 < args.count else { return false }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Typeface.registerBundledFonts()
        isRendering = true
        render(to: dir)
        renderGrove(to: dir)
        renderSpace(to: dir)
        renderTopics(to: dir)
        renderBuddy(to: dir)
        return true
    }

    private static func save<V: View>(_ view: V, _ name: String, to dir: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { print("snapshot failed: \(name)"); return }
        let rep = NSBitmapImageRep(cgImage: cg)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent(name + ".png"))
            print("snapshot: \(name).png \(cg.width)x\(cg.height)")
        }
    }

    private static func render(to dir: URL) {
        let state = AppState.shared
        state.profileSchool = "hs11"
        state.profileExpertise = "classes"
        state.profileFields = ["biology", "chemistry"]
        state.profileLength = "balanced"

        // Explanation card with a real answer from the explainer (recorded, not live).
        let model = CardModel()
        model.selection = "Brain myeloid cells, including infiltrating monocyte-derived macrophages (MDMs) and microglia, play critical roles in ischemic brain injury"
        model.phase = .loaded(Explanation(
            text: "These are special immune cells in the brain that help clean up damage and manage swelling when someone has a stroke or loses blood flow.",
            terms: [GlossaryTerm(term: "myeloid cells", meaning: "a type of immune cell"),
                    GlossaryTerm(term: "macrophages", meaning: "cells that clear away cellular debris"),
                    GlossaryTerm(term: "microglia", meaning: "immune cells that live in the brain"),
                    GlossaryTerm(term: "ischemic", meaning: "caused by a lack of blood flow")]))
        save(ExplanationCardView(model: model).padding(20).background(Color(hex: 0xF3EFE6)), "card-plain", to: dir)

        let loading = CardModel()
        loading.selection = "photorespiration increases"
        save(ExplanationCardView(model: loading).padding(20).background(Color(hex: 0xF3EFE6)), "card-loading", to: dir)

        let island = IslandModel()
        island.notchSize = CGSize(width: 190, height: 32)
        island.mode = .expanded
        let flash = IslandModel()
        flash.mode = .flash(on: true)
        save(IslandView(model: flash, state: state, store: TreeStore(persist: false))
                .frame(width: 420, height: 110).background(Color(hex: 0x6E7B86)), "island-flash", to: dir)

        for step in SetupStep.allCases {
            save(SetupView(state: state, island: island, initialStep: step.rawValue, explainPractice: { _, _, _ in }, done: {}),
                 "setup-" + String(format: "%02d", step.rawValue + 1) + "-\(step)", to: dir)
        }
        // Settings as this build machine really is (no cards opened, no Accessibility).
        save(SettingsView(state: state, showWelcome: {}, checkForUpdates: {}).content
                .background(DeskBackground()), "settings", to: dir)
        // Design sample only: a Mac that has opened 128 cards and granted Accessibility.
        UserDefaults.standard.set(128, forKey: "specimenCount")
        state.accessibilityGranted = true
        save(SettingsView(state: state, showWelcome: {}, checkForUpdates: {}).content
                .background(DeskBackground()), "settings-sample-count", to: dir)
        save(SettingsView(state: state, showWelcome: {}, checkForUpdates: {}, showTinkerers: true).content
                .background(DeskBackground()), "settings-tinkerers", to: dir)
    }

    // MARK: The grove

    /// Island backdrop: a desktop-ish blue-grey, so the black island reads as it does on a Mac.
    private static let desk = Color(hex: 0x6E7B86)

    private static func renderGrove(to dir: URL) {
        let state = AppState.shared
        let store = TreeStore(persist: false)
        store.trees = SampleGrove.trees()
        // A fixed clock, so wind and growth render the same every time.
        TreeClock.frozen = Date()
        // Real front pages, rendered from each paper's open-access PDF, for the trees shown up close.
        for tree in store.trees where tree.number == 1 || tree.number == 3 || tree.number == 6 {
            for p in tree.papers + tree.suggestions.map(\.paper) {
                if let img = frontPage(p) { store.thumbnails[p.id] = img }
            }
        }
        print("front pages rendered: \(store.thumbnails.count)")

        let grove = CGSize(width: 1360, height: 800)
        func island(_ configure: (IslandModel) -> Void) -> IslandModel {
            let m = IslandModel()
            m.notchSize = CGSize(width: 190, height: 32)
            m.groveSize = grove
            configure(m)
            return m
        }
        func shoot(_ m: IslandModel, _ name: String, size: CGSize) {
            save(IslandView(model: m, state: state, store: store)
                    .frame(width: size.width, height: size.height).background(desk), name, to: dir)
        }
        let full = CGSize(width: grove.width + 40, height: grove.height + 32 + 30)

        shoot(island { $0.mode = .expanded; $0.page = .grove }, "grove-overview", size: full)
        // The same grove with fewer and with more trees: sheets stay big, New tree stays in view.
        let all = store.trees
        store.trees = Array(all.prefix(3))
        shoot(island { $0.mode = .expanded; $0.page = .grove }, "grove-overview-3", size: full)
        store.trees = Array(all.prefix(2))
        shoot(island { $0.mode = .expanded; $0.page = .grove }, "grove-overview-2", size: full)
        store.trees = all + SampleGrove.offshoots(of: all)
        shoot(island { $0.mode = .expanded; $0.page = .grove }, "grove-overview-many", size: full)
        store.trees = all
        if let cs = store.trees.first(where: { $0.number == 1 }) {
            shoot(island { $0.mode = .expanded; $0.page = .tree(cs.id) }, "grove-tree-grown", size: full)
            if let s = cs.suggestions.first {
                save(SuggestionSlip(suggestion: s, tree: cs, store: store, done: {}).padding(20).background(desk),
                     "grove-suggestion-slip", to: dir)
            }
        }
        if let eco = store.trees.first(where: { $0.number == 3 }) {
            shoot(island { $0.mode = .expanded; $0.page = .tree(eco.id) }, "grove-tree-medium", size: full)
        }
        if let sapling = store.trees.first(where: { $0.number == 6 }) {
            shoot(island { $0.mode = .expanded; $0.page = .tree(sapling.id) }, "grove-tree-sapling", size: full)
        }
        shoot(island { $0.mode = .expanded; $0.page = .newTree }, "grove-new-tree", size: full)

        // The add chooser, half open, with a paper found (as the server matched it).
        let adding = island {
            $0.mode = .adding
            $0.adding = AddRequest(highlighted: SampleGrove.addedPaper.title, lookup: .found(SampleGrove.photoCandidates, confident: true))
        }
        shoot(adding, "island-add-found", size: CGSize(width: 680, height: 32 + IslandModel.addingSize.height + 30))
        let looking = island { $0.mode = .adding; $0.adding = AddRequest(highlighted: SampleGrove.addedPaper.title) }
        shoot(looking, "island-add-looking", size: CGSize(width: 680, height: 32 + IslandModel.addingSize.height + 30))
        store.plantingNewTree = ""
        shoot(adding, "island-add-planting", size: CGSize(width: 680, height: 32 + IslandModel.addingSize.height + 30))
        store.plantingNewTree = nil

        let tall = CGSize(width: 720, height: 32 + IslandModel.addingSize.height + 6 * 46 + 70 + 60)
        // "Is this it?": real, ambiguous lookups.
        shoot(island { $0.mode = .adding; $0.adding = AddRequest(highlighted: "Deep learning", lookup: .found(SampleGrove.deepCandidates, confident: false)) },
              "island-add-is-this-it", size: tall)
        shoot(island { $0.mode = .adding; $0.adding = AddRequest(highlighted: "Generative Adversarial Nets", lookup: .found(SampleGrove.ganCandidates, confident: false)) },
              "island-add-is-this-it-gan", size: tall)
        shoot(island {
            $0.mode = .adding
            var r = AddRequest(highlighted: SampleGrove.addedPaper.title, lookup: .found(SampleGrove.photoCandidates, confident: true))
            r.showAll = true
            $0.adding = r
        }, "island-add-pick-another", size: tall)

        // Changing a paper's match after it was added.
        if let cs = store.trees.first(where: { $0.number == 1 }), let gan = cs.papers.first(where: { $0.title.lowercased().contains("adversarial") }) {
            let m = island { $0.mode = .expanded }
            save(TreeSheetPage(model: m, store: store, tree: cs, rematching: gan.id, rematchPreset: SampleGrove.ganCandidates)
                    .padding(24).frame(width: 1312, height: 760).background(PaperSheet(corner: 18, graph: true)), "grove-change-match", to: dir)
        }

        // Every species with the same papers, as a chooser thumbnail and as a small sheet.
        if let eco = store.trees.first(where: { $0.number == 3 }) {
            let species = Species.allCases
            let rows = [Array(species.prefix(7)), Array(species.dropFirst(7))]
            func variant(_ sp: Species) -> PaperTreeData {
                var t = eco
                t.look = TreeLook(species: sp, commonName: sp.plainName, leafTone: eco.look.leafTone, vigor: 0.6, twist: 0.5, droop: 0.4)
                t.suggestions = []
                return t
            }
            let sampler = VStack(alignment: .leading, spacing: 14) {
                ForEach(0..<2, id: \.self) { r in
                HStack(spacing: 14) {
                    ForEach(rows[r], id: \.self) { sp in
                        VStack(spacing: 4) {
                            TreeDrawing(tree: variant(sp), geometry: TreeGeometry.make(variant(sp), in: CGSize(width: 84, height: 70)), detail: 0.5)
                                .frame(width: 84, height: 70).clipped()
                                .background(Color(hex: 0xFBF8EE))
                                .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.3), lineWidth: 0.7))
                            Text(sp.plainName).font(.ui(11)).foregroundColor(Palette.ink)
                        }
                    }
                }
                HStack(spacing: 14) {
                    ForEach(rows[r], id: \.self) { sp in
                        TreeCanvas(tree: variant(sp), store: store).frame(width: 200, height: 230).clipped()
                            .background(Color(hex: 0xFBF8EE))
                            .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.2), lineWidth: 0.7))
                    }
                }
                }
            }
            .padding(16)
            .background(Color(hex: 0xEFE9DA))
            save(sampler, "species-sampler", to: dir)
        }

        // One tap with a title highlighted: the grove opens with "Add this paper" on top.
        shoot(island { $0.mode = .expanded; $0.page = .grove; $0.highlight = SampleGrove.addedPaper.title }, "grove-add-highlight", size: full)

        renderMotion(to: dir, store: store, grove: grove)

        let note = island { $0.mode = .note("Added to Tree No. 3") }
        shoot(note, "island-note", size: CGSize(width: 460, height: 110))

        // The same tree at several sizes, to show it growing from a sapling.
        if let cs = store.trees.first(where: { $0.number == 1 }) {
            let stages: [PaperTreeData] = [1, 2, 4, 7, 12].map { n in
                var t = cs
                let kept = Array(cs.papers.prefix(n))
                t.papers = kept.map { p in
                    var p = p
                    if let parent = p.parentId, !kept.contains(where: { $0.id == parent }) { p.parentId = nil }
                    return p
                }
                t.suggestions = []
                return t
            }
            let row = HStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { _, t in
                    VStack(spacing: 4) {
                        TreeCanvas(tree: t, store: store).frame(width: 300, height: 380)
                        Text("\(t.papers.count) \(t.papers.count == 1 ? "paper" : "papers")")
                            .font(.typewriter(11)).foregroundColor(Palette.ink3)
                    }
                }
            }
            .padding(16)
            .background(Color(hex: 0xFBF8EE))
            save(row, "grove-growth-stages", to: dir)
        }
    }

    // MARK: Motion, as frame sequences (CI turns them into video)

    private static func renderMotion(to dir: URL, store: TreeStore, grove: CGSize) {
        let state = AppState.shared
        guard let start = TreeClock.frozen else { return }
        let growDir = dir.appendingPathComponent("frames/grow", isDirectory: true)
        let islandDir = dir.appendingPathComponent("frames/island", isDirectory: true)
        try? FileManager.default.createDirectory(at: growDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: islandDir, withIntermediateDirectories: true)

        // A paper is added to Tree No. 3: its branch reaches out, leaves unfurl, the page lands,
        // then the pencil branches sketch themselves in. 24 frames a second.
        if let cs = store.trees.first(where: { $0.number == 1 }) {
            // A young oak with five papers, so the new branch is easy to follow.
            var t = cs
            let kept = Array(cs.papers.sorted { $0.addedAt < $1.addedAt }.prefix(5))
            t.papers = kept.map { p in
                var p = p
                if let parent = p.parentId, !kept.contains(where: { $0.id == parent }) { p.parentId = nil }
                return p
            }
            t.suggestions = Array(cs.suggestions.filter { s in kept.contains { $0.id == s.fromPaperId } }.prefix(2))
            t.look = TreeLook(species: .oak, commonName: "oak", leafTone: "moss", vigor: 0.6, twist: 0.4, droop: 0.4)
            let born = start.addingTimeInterval(0.4)
            if let k = t.papers.indices.max(by: { t.papers[$0].addedAt < t.papers[$1].addedAt }) { t.papers[k].addedAt = born }
            TreeClock.sketchStart = born.addingTimeInterval(TreeGrowth.duration - 0.2)
            for f in 0..<96 {
                TreeClock.frozen = start.addingTimeInterval(Double(f) / 24)
                save(TreeCanvas(tree: t, store: store).frame(width: 640, height: 600).background(Color(hex: 0xFBF8EE)),
                     String(format: "f%03d", f), to: growDir)
            }
            TreeClock.sketchStart = nil
            TreeClock.frozen = start
        }

        // The island springing open out of the notch, with the grove fading up inside it. 30 frames a second.
        let m = IslandModel()
        m.notchSize = CGSize(width: 190, height: 32)
        m.groveSize = grove
        m.mode = .expanded
        m.page = .grove
        let frame = CGSize(width: grove.width + 40, height: grove.height + 32 + 30)
        for f in 0..<36 {
            let t = Double(f) / 30
            save(IslandOpeningFrame(model: m, state: state, store: store, time: t).frame(width: frame.width, height: frame.height)
                    .background(desk), String(format: "f%03d", f), to: islandDir)
        }
    }

    /// Page 1 of a paper through the app's whole chain (known links, the server's search, OpenAlex),
    /// waiting for it (snapshots run synchronously).
    private static func frontPage(_ paper: Paper) -> NSImage? {
        let done = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var hit: (Data, String)? }
        let box = Box()
        let client = TreeClient.current
        Task.detached {
            box.hit = await TreeStore.findFrontPage(for: paper, client: client)
            done.signal()
        }
        guard done.wait(timeout: .now() + 90) == .success, let hit = box.hit else {
            print("front page: none for \(paper.title)")
            return nil
        }
        print("front page: \(paper.title) <- \(hit.1)")
        return NSImage(data: hit.0)
    }
}

/// One frame of the island opening, computed from the same spring the app uses (response 0.5,
/// damping 0.76) and the same content transition (blur, rise, fade after a short delay).
struct IslandOpeningFrame: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var state: AppState
    @ObservedObject var store: TreeStore
    var time: Double

    static func spring(_ t: Double, response: Double = 0.5, damping: Double = 0.76) -> Double {
        guard t > 0 else { return 0 }
        let w = 2 * Double.pi / response
        let wd = w * (1 - damping * damping).squareRoot()
        return 1 - exp(-damping * w * t) * (cos(wd * t) + damping * w / wd * sin(wd * t))
    }

    var body: some View {
        let k = CGFloat(Self.spring(time))
        let notch = model.notchSize
        let open = CGSize(width: model.groveSize.width, height: notch.height + model.groveSize.height)
        let size = CGSize(width: notch.width + (open.width - notch.width) * k, height: max(0, notch.height + (open.height - notch.height) * k))
        let radius = min(notch.height / 2, 18) + (34 - min(notch.height / 2, 18)) * k
        let reveal = CGFloat(1 - Self.spring(time - 0.09))
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                IslandShape(bottomRadius: radius, earRadius: 8 + 4 * k)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.35 * Double(min(1, k * 3))), radius: 14, x: 0, y: 6)
                GroveView(model: model, state: state, store: store)
                    .modifier(BlurRise(amount: max(0, min(1, reveal))))
                    .padding(.top, notch.height)
                    .frame(width: open.width, height: open.height, alignment: .top)
                    .frame(width: max(1, size.width), height: max(1, size.height), alignment: .top)
                    .clipped()
            }
            .frame(width: max(1, size.width), height: max(1, size.height))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: Room to read: a busy tree up close, and the paper reader

extension Snapshots {
    private static func shootIsland(_ m: IslandModel, _ store: TreeStore, _ name: String, to dir: URL) {
        let size = CGSize(width: m.groveSize.width + 40, height: m.groveSize.height + 32 + 30)
        save(IslandView(model: m, state: AppState.shared, store: store)
                .frame(width: size.width, height: size.height).background(Color(hex: 0x6E7B86)), name, to: dir)
    }

    static func renderSpace(to dir: URL) {
        TreeClock.frozen = Date()
        TreeClock.sketchStart = nil
        let store = TreeStore(persist: false)
        let all = SampleGrove.trees()
        guard let cs = all.first(where: { $0.number == 1 }) else { return }
        // A busy willow like the one in the bug report: six papers and six suggestions.
        var dense = cs
        let kept = Array(cs.papers.sorted { $0.addedAt < $1.addedAt }.prefix(6))
        dense.papers = kept.map { p in
            var p = p
            if let parent = p.parentId, !kept.contains(where: { $0.id == parent }) { p.parentId = nil }
            return p
        }
        let extra = all.filter { $0.number != 1 }.flatMap(\.papers)
        var sugg: [Suggestion] = []
        for (k, p) in (cs.suggestions.map(\.paper) + extra).prefix(6).enumerated() {
            sugg.append(Suggestion(paper: p, fromPaperId: kept[k % kept.count].id))
        }
        dense.suggestions = sugg
        dense.look = TreeLook(species: .willow, commonName: "weeping reader", leafTone: "plum", vigor: 0.6, twist: 0.4, droop: 0.6)
        store.trees = [dense] + all.filter { $0.number != 1 }
        for p in dense.papers { if let img = frontPage(p) { store.thumbnails[p.id] = img } }

        func island(_ configure: (IslandModel) -> Void) -> IslandModel {
            let m = IslandModel()
            m.notchSize = CGSize(width: 190, height: 32)
            m.groveSize = CGSize(width: 1360, height: 800)
            m.mode = .expanded
            configure(m)
            return m
        }
        shootIsland(island { $0.page = .tree(dense.id) }, store, "tree-fit", to: dir)
        shootIsland(island { $0.page = .tree(dense.id); $0.treeStartZoom = 2.4; $0.treeStartPan = CGSize(width: 260, height: 300) }, store, "tree-zoomed-in", to: dir)
        shootIsland(island { $0.page = .tree(dense.id); $0.treeStartZoom = 0.5 }, store, "tree-zoomed-out", to: dir)
        shootIsland(island { $0.page = .grove }, store, "grove-spaced", to: dir)

        // The reader, on a sample paper written for these snapshots.
        var sample = Paper(id: "sample-dry-spell", title: "Leaves in a dry spell: how plants trade water for carbon",
                           authors: ["Sample text", "written for Paper Tree design snapshots"], year: 2026, venue: "Paper Tree design notes")
        sample.abstract = SamplePaper.abstract
        sample.fields = ["Biology", "Environmental Science"]
        sample.url = "https://www.semanticscholar.org/search?q=leaves%20in%20a%20dry%20spell"
        var host = dense
        host.papers.append(sample)
        store.trees[0] = host

        func reader(_ setup: (ReaderModel, PDFDocument) -> Void) -> ReaderModel {
            let r = ReaderModel(paper: sample, persist: false)
            if let doc = PDFDocument(data: SamplePaper.pdf()) {
                r.setDocument(doc)
                setup(r, doc)
            }
            return r
        }
        func rects(_ doc: PDFDocument, _ phrase: String) -> (Int, [CGRect])? {
            guard let sel = doc.findString(phrase, withOptions: .caseInsensitive).first, let page = sel.pages.first else { return nil }
            let lines = sel.selectionsByLine().map { $0.bounds(for: page) }
            return (doc.index(for: page), lines.isEmpty ? [sel.bounds(for: page)] : lines)
        }
        let annotated = reader { r, doc in
            var list: [PaperMark] = []
            if let (p, rs) = rects(doc, "close their stomata to save water") { list.append(PaperMark(kind: .highlight, page: p, rects: rs, ink: .marigold, quote: "close their stomata to save water")) }
            if let (p, rs) = rects(doc, "net carbon assimilation falls") { list.append(PaperMark(kind: .underline, page: p, rects: rs, ink: .rose, quote: "net carbon assimilation falls")) }
            if let (p, rs) = rects(doc, "photorespiration increases") {
                list.append(PaperMark(kind: .comment, page: p, rects: rs, ink: .sage, quote: "photorespiration increases",
                                      note: "So the leaf wastes some of the light it catches? Compare with the C4 grasses in section 3."))
            }
            if let (p, rs) = rects(doc, "chemical signals upward") {
                list.append(PaperMark(kind: .comment, page: p, rects: rs, ink: .sky, quote: "chemical signals upward", note: "Which signal? Look up abscisic acid."))
            }
            list.append(PaperMark(kind: .sticky, page: 0, rects: [CGRect(x: 618, y: 580, width: 150, height: 108)], ink: .marigold,
                                  note: "Ask in class: does this hold for desert plants too?"))
            r.marks.preset(list)
        }
        shootIsland(island { $0.page = .paper(host.id, sample.id); $0.readerPreset = annotated }, store, "reader-annotated", to: dir)

        let selecting = reader { r, doc in
            r.marks.preset([])
            r.rail = .pages
            if let (p, rs) = rects(doc, "Rubisco also reacts with oxygen") {
                r.pick = ReaderModel.Pick(text: "Rubisco also reacts with oxygen", page: p, rects: rs, anchor: .zero, context: "", screen: .zero)
            }
        }
        shootIsland(island { $0.page = .paper(host.id, sample.id); $0.readerPreset = selecting }, store, "reader-selection", to: dir)

        let editing = reader { r, doc in
            if let (p, rs) = rects(doc, "photorespiration increases") {
                let m = PaperMark(kind: .comment, page: p, rects: rs, ink: .sage, quote: "photorespiration increases",
                                  note: "So the leaf wastes some of the light it catches?")
                r.marks.preset([m])
                r.editing = m.id
            }
        }
        shootIsland(island { $0.page = .paper(host.id, sample.id); $0.readerPreset = editing }, store, "reader-editing", to: dir)

        let missing = ReaderModel(paper: sample, persist: false)
        missing.status = .unavailable
        shootIsland(island { $0.page = .paper(host.id, sample.id); $0.readerPreset = missing }, store, "reader-no-pdf", to: dir)
    }
}

/// A two-page sample paper for snapshots, set with Core Text so it has real, selectable text.
enum SamplePaper {
    static let abstract = "This sample text stands in for a paper in design snapshots. It describes, in general terms, how leaves balance water loss against carbon uptake when soil dries: stomata close, leaf temperature rises, photorespiration increases, and net carbon assimilation falls."

    static let body: [(String, String)] = [
        ("Introduction", "Under drought, plants close their stomata to save water. That limits transpiration, so leaf temperature rises, and with less carbon dioxide reaching the chloroplasts, photorespiration increases and net carbon assimilation falls. How quickly a plant makes this trade, and how far, shapes its water use efficiency over a season."),
        ("Why the trade costs carbon", "The enzyme that fixes carbon, Rubisco, works best when carbon dioxide is plentiful inside the leaf. Rubisco also reacts with oxygen, and that side reaction becomes more common as carbon dioxide inside the leaf drops. The plant then spends energy recovering carbon it had already fixed. Plants with C4 metabolism concentrate carbon dioxide around Rubisco and lose less this way, which is one reason many grasses of hot, dry places use it."),
        ("Signals from the roots", "Stomata do not wait for the leaf to wilt. As soil dries, roots send chemical signals upward, and guard cells respond within hours. The result is a leaf that is cautious early, closing partly before damage occurs, and that recovers slowly after rain while the signals fade."),
        ("What this means for growth", "A season of mild drought often costs more growth than a short severe one, because the leaf spends many days partly closed. Breeding for crops that keep stomata open a little longer, without running out of water, is an active line of work. The figures in a real paper would show these curves; this sample text has none."),
    ]

    static func pdf() -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        func font(_ name: String, _ size: CGFloat) -> NSFont { NSFont(name: name, size: size) ?? .systemFont(ofSize: size) }
        let justified = NSMutableParagraphStyle()
        justified.alignment = .justified
        justified.lineSpacing = 2.5
        justified.paragraphSpacing = 8
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.paragraphSpacing = 6

        let first = NSMutableAttributedString()
        first.append(NSAttributedString(string: "PAPER TREE DESIGN NOTES, SAMPLE TEXT\n", attributes: [.font: font(Typeface.text, 8.5), .paragraphStyle: centered, .foregroundColor: NSColor.darkGray]))
        first.append(NSAttributedString(string: "Leaves in a dry spell: how plants trade water for carbon\n", attributes: [.font: font(Typeface.textMedium, 20), .paragraphStyle: centered]))
        first.append(NSAttributedString(string: "Sample text written for Paper Tree design snapshots\n\n", attributes: [.font: font(Typeface.textItalic, 11), .paragraphStyle: centered]))
        first.append(NSAttributedString(string: "Abstract. ", attributes: [.font: font(Typeface.textMedium, 10.5), .paragraphStyle: justified]))
        first.append(NSAttributedString(string: abstract + "\n\n", attributes: [.font: font(Typeface.textItalic, 10.5), .paragraphStyle: justified]))
        for (k, (head, text)) in body.enumerated() {
            first.append(NSAttributedString(string: "\(k + 1). \(head)\n", attributes: [.font: font(Typeface.textMedium, 12), .paragraphStyle: justified]))
            first.append(NSAttributedString(string: text + "\n", attributes: [.font: font(Typeface.text, 11), .paragraphStyle: justified]))
        }
        let setter = CTFramesetterCreateWithAttributedString(first as CFAttributedString)
        var start = 0
        var pages = 0
        while start < first.length && pages < 4 {
            ctx.beginPDFPage(nil)
            let path = CGPath(rect: CGRect(x: 72, y: 80, width: 468, height: 640), transform: nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
            let page = NSAttributedString(string: "\(pages + 1)", attributes: [.font: font(Typeface.text, 9)])
            let line = CTLineCreateWithAttributedString(page as CFAttributedString)
            ctx.textPosition = CGPoint(x: 302, y: 50)
            CTLineDraw(line, ctx)
            ctx.endPDFPage()
            let visible = CTFrameGetVisibleStringRange(frame)
            if visible.length == 0 { break }
            start += visible.length
            pages += 1
        }
        ctx.closePDF()
        return data as Data
    }
}

/// Results gathered from side-by-side work in snapshots.
final class ParallelSlots<T>: @unchecked Sendable {
    var v: [T?]
    let lock = NSLock()
    init(_ n: Int) { v = Array(repeating: nil, count: n) }
}

// MARK: Plants that reflect their papers, a big grove, and the buddy in motion

extension Snapshots {
    struct Topic { var name: String; var fields: [String]; var titles: [String] }

    static let topics: [Topic] = [
        Topic(name: "Animal behavior", fields: ["Biology"], titles: ["Social learning in wild chimpanzees", "Foraging behavior of honeybees under predation risk", "Song learning in zebra finches", "Migration routes of monarch butterflies", "Predator avoidance in schooling fish", "Tool use in New Caledonian crows"]),
        Topic(name: "Oceans", fields: ["Environmental Science"], titles: ["Kelp forest decline along the California coast", "Ocean warming and the redistribution of fisheries", "Sea otters as a keystone species in kelp forests", "Plankton blooms and ocean color from satellites", "Coastal upwelling and marine productivity", "Marine heatwaves in the North Pacific"]),
        Topic(name: "The brain", fields: ["Neuroscience", "Biology"], titles: ["Dendritic computation in cortical pyramidal neurons", "Place cells in the hippocampus", "Synaptic plasticity and memory", "The default mode network of the brain", "Dopamine neurons and reward prediction error", "Grid cells in the entorhinal cortex"]),
        Topic(name: "Stars", fields: ["Physics"], titles: ["Observational evidence from supernovae for an accelerating universe", "A terrestrial planet candidate orbiting Proxima Centauri", "Observation of gravitational waves from a binary black hole merger", "First results from the Event Horizon Telescope: the shadow of a black hole", "Rotation curves of spiral galaxies and dark matter", "Exoplanet atmospheres observed with JWST"]),
        Topic(name: "Plants", fields: ["Biology"], titles: ["Photosynthesis under drought and salt stress", "Flowering time control in Arabidopsis", "Root architecture and nutrient uptake in crops", "Pollinator networks in alpine meadows", "The worldwide leaf economics spectrum", "Seed dispersal by birds in tropical forests"]),
        Topic(name: "Computing", fields: ["Computer Science"], titles: ["Attention is all you need", "Deep residual learning for image recognition", "BERT: pre-training of deep bidirectional transformers", "ImageNet classification with deep convolutional neural networks", "A note on two problems in connexion with graphs", "MapReduce: simplified data processing on large clusters"]),
        Topic(name: "Medicine", fields: ["Medicine"], titles: ["Statins for the primary prevention of cardiovascular disease", "Safety and efficacy of the BNT162b2 mRNA COVID-19 vaccine", "Aspirin in the primary prevention of stroke", "Antibiotic resistance in hospital acquired infections", "Early goal directed therapy in the treatment of severe sepsis", "Metformin and the prevention of type 2 diabetes"]),
        Topic(name: "Fungi", fields: ["Biology"], titles: ["Mycorrhizal fungi and nutrient exchange in forests", "The human gut microbiome in health and disease", "Fungal networks connecting trees in a forest", "Decomposition of leaf litter by soil fungi", "Bacterial communities in agricultural soil", "The discovery of penicillin from Penicillium mould"]),
        Topic(name: "Evolution", fields: ["Biology"], titles: ["A draft sequence of the Neandertal genome", "A programmable dual RNA guided DNA endonuclease in adaptive bacterial immunity", "Phylogeny of the flowering plants from DNA sequences", "A feathered dinosaur from the Jurassic of China", "Evolution of antibiotic resistance genes", "Genomic signatures of natural selection in humans"]),
        Topic(name: "Deserts", fields: ["Geology", "Environmental Science"], titles: ["Desertification and drought in the Sahel", "Plate tectonics and the rise of mountain ranges", "Mineral weathering in arid soils", "Groundwater depletion in dry regions", "Volcanic eruptions and climate", "Fault slip and earthquake prediction"]),
        Topic(name: "Chemistry", fields: ["Chemistry", "Materials Science"], titles: ["Catalysis on metal surfaces", "Polymer design for recyclable plastics", "Coral reef calcification under ocean acidification", "Metal organic frameworks for carbon capture", "Self assembly of molecular cages", "Electrolytes for lithium batteries"]),
        Topic(name: "Mathematics", fields: ["Mathematics", "Physics"], titles: ["The entropy formula for the Ricci flow", "Statistical mechanics of phase transitions", "Renormalization in quantum field theory", "Finite element methods in engineering", "Bayesian inference for physical models", "Deterministic nonperiodic flow"]),
        Topic(name: "People", fields: ["Psychology"], titles: ["Judgment under uncertainty: heuristics and biases", "Delay of gratification in children", "Opinions and social pressure", "Attachment in early childhood", "Mindset and achievement in school", "Reconstruction of automobile destruction: eyewitness memory"]),
    ]

    /// The plant the server's Gemini call designs for these papers (waiting for it; snapshots run
    /// synchronously), or the app's own local guess when it can't be reached.
    private static func plant(for topic: Topic, seed: UInt64) -> TreeLook {
        let done = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var look: TreeLook? }
        let box = Box()
        let client = TreeClient.current
        let titles = topic.titles, fields = topic.fields
        Task.detached {
            box.look = try? await client.plant(titles: titles, fields: fields, current: nil)
            done.signal()
        }
        if done.wait(timeout: .now() + 55) == .success, let look = box.look {
            print("plant: \(topic.name) -> \(look.species.rawValue) (\(look.grownFromLine ?? ""))")
            return look
        }
        print("plant: \(topic.name) -> local guess")
        return TreeLook.guess(fields: topic.fields, titles: topic.titles, seed: seed)
    }

    private static func topicTree(_ topic: Topic, look: TreeLook, number: Int, seed: UInt64, papers n: Int) -> PaperTreeData {
        let base = Date(timeIntervalSince1970: 1_767_000_000)
        var papers: [Paper] = []
        for i in 0..<min(n, topic.titles.count) {
            let parent: String? = i >= 3 ? "t\(number)-\(i - 3)" : nil
            papers.append(Paper(id: "t\(number)-\(i)", title: topic.titles[i], authors: ["A. Reader"], year: 2010 + i,
                                fields: topic.fields, parentId: parent, addedAt: base.addingTimeInterval(Double(i) * 86_400)))
        }
        return PaperTreeData(number: number, name: topic.name, seed: seed, look: look, papers: papers, lookCheckedAt: papers.count)
    }

    static func renderTopics(to dir: URL) {
        TreeClock.frozen = Date()
        TreeClock.sketchStart = nil
        let store = TreeStore(persist: false)
        let looks = Self.parallel(topics.count) { k in plant(for: topics[k], seed: UInt64(900 + k)) }

        // Each subject as its own plant, labelled with what it grew from.
        let trees = topics.enumerated().map { k, t in topicTree(t, look: looks[k], number: k + 1, seed: UInt64(5000 + k * 97), papers: 6) }
        let grid = VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<4, id: \.self) { r in
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(trees.enumerated()).filter { $0.offset / 4 == r }, id: \.offset) { _, tree in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tree.name).font(.fell(16)).foregroundColor(Palette.ink)
                            SpecimenPlate(tree: tree, store: store, compact: false).frame(width: 330, height: 400)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: 0xEFE9DA))
        save(grid, "topic-plants", to: dir)

        // A tree whose papers drift from the sea to chemistry turns from kelp into coral, gradually.
        if let now = TreeClock.frozen {
            var morphing = trees[1]
            morphing.priorLook = looks[1]
            var coral = looks[10]
            coral.grownFrom = ["ocean chemistry", "reef calcification"]
            morphing.look = coral
            let row = HStack(spacing: 10) {
                ForEach([0.0, 0.9, 1.6, 3.0], id: \.self) { s in
                    VStack(spacing: 4) {
                        TreeCanvas(tree: { var t = morphing; t.lookChangedAt = now.addingTimeInterval(-s); return t }(), store: store)
                            .frame(width: 280, height: 320).background(Color(hex: 0xFBF8EE))
                        Text(String(format: "%.1f s", s)).font(.typewriter(11)).foregroundColor(Palette.ink3)
                    }
                }
            }
            .padding(14)
            .background(Color(hex: 0xEFE9DA))
            save(row, "topic-morph", to: dir)
        }

        // A big grove: 39 trees, three of every subject at different sizes.
        var many: [PaperTreeData] = []
        for (k, t) in topics.enumerated() {
            for (j, n) in [2, 4, 6].enumerated() {
                var tree = topicTree(t, look: looks[k], number: many.count + 1, seed: UInt64(7000 + k * 31 + j * 7), papers: n)
                tree.name = j == 0 ? t.name : "\(t.name) \(j + 1)"
                many.append(tree)
            }
        }
        store.trees = many
        let grove = CGSize(width: 1360, height: 800)
        let m = IslandModel()
        m.notchSize = CGSize(width: 190, height: 32)
        m.groveSize = grove
        m.mode = .expanded
        m.page = .grove
        save(IslandView(model: m, state: AppState.shared, store: store)
                .frame(width: grove.width + 40, height: grove.height + 32 + 30).background(desk), "grove-many-topics", to: dir)
        print("grove trees: \(many.count)")
        renderRecipes(to: dir, topicLooks: looks)
    }

    // MARK: Tree customizer recipes

    /// Runs the slow server calls side by side (each waits on its own answer).
    static func parallel<T>(_ n: Int, _ make: @escaping (Int) -> T) -> [T] {
        let slots = ParallelSlots<T>(n)
        DispatchQueue.concurrentPerform(iterations: n) { k in
            let x = make(k)
            slots.lock.lock(); slots.v[k] = x; slots.lock.unlock()
        }
        return slots.v.map { $0! }
    }

    static let oakTopics: [Topic] = [
        Topic(name: "Pollination", fields: ["Biology"], titles: ["Bumblebee visits and seed set in wildflowers", "Floral scent and pollinator choice", "Pollinator decline in farmland"]),
        Topic(name: "Autumn color", fields: ["Biology"], titles: ["Anthocyanins and red leaves in autumn", "Leaf senescence timing in temperate trees", "Warming delays autumn leaf fall"]),
        Topic(name: "Orchards", fields: ["Agricultural Science"], titles: ["Apple breeding for disease resistance", "Fruit set and thinning in pear orchards", "Pollination of cherry orchards by mason bees"]),
        Topic(name: "Old growth", fields: ["Environmental Science"], titles: ["Carbon storage in ancient oak forests", "Veteran trees as habitat for beetles", "Centuries of growth from tree rings"]),
        Topic(name: "Glowing life", fields: ["Biology"], titles: ["Bioluminescent fungi on forest floors", "Firefly flash signals and mate choice", "Luciferase chemistry in glowing organisms"]),
        Topic(name: "Seed banks", fields: ["Biology"], titles: ["Seed dormancy and long term storage", "Seed pods and dispersal by wind", "The Svalbard global seed vault"]),
        Topic(name: "City trees", fields: ["Environmental Science"], titles: ["Street trees cool urban heat islands", "Air pollution uptake by city canopies", "Tree cover and wellbeing in neighborhoods"]),
        Topic(name: "Drought", fields: ["Biology"], titles: ["Xylem embolism in drought stressed oaks", "Stomatal closure during heat waves", "Tree mortality after megadroughts"]),
    ]

    /// A recipe from the customizer with the plant body fixed, or a local one when it can't be reached.
    private static func recipe(for topic: Topic, base: Species, seed: UInt64) -> TreeLook {
        let done = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var look: TreeLook? }
        let box = Box()
        let client = TreeClient.current
        let titles = topic.titles, fields = topic.fields
        Task.detached {
            box.look = try? await client.plant(titles: titles, fields: fields, current: nil, base: base)
            done.signal()
        }
        if done.wait(timeout: .now() + 55) == .success, var look = box.look {
            look.species = base
            look.recipe = look.recipe?.personalized(seed: seed, species: base)
            if let r = look.recipe {
                print("recipe: \(topic.name) [\(r.model ?? "?")] crown \(r.crown ?? "-") trunk \(r.trunk ?? "-") limbs \(r.branchCount ?? -1) angle \(r.branchAngle ?? -1) depth \(r.branchDepth ?? -1) leaf \(r.leafSize ?? -1) gap \(r.leafGap ?? -1) bark \(r.bark) leaf \(r.leaf) accent \(r.accentColor) \(r.accent) \(r.leafShape) droop \(r.droop) spread \(r.spread) density \(r.density) height \(r.height) girth \(r.girth) twist \(r.twist)")
            }
            return look
        }
        print("recipe: \(topic.name) -> local")
        var look = TreeLook(species: base)
        look.grownFrom = topic.fields.map { $0.lowercased() }
        look.recipe = TreeRecipe.local(for: look, seed: seed)
        return look
    }

    /// One line under a plate: the recipe in plain words, with its three colors as swatches.
    private struct RecipeLine: View {
        var look: TreeLook
        var body: some View {
            let r = look.recipe
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    ForEach([r?.bark, r?.leaf, r?.accentColor].compactMap { $0 }, id: \.self) { hex in
                        Circle().fill(RGB(hex: hex).color()).frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Palette.ink.opacity(0.4), lineWidth: 0.6))
                    }
                    Text(r == nil ? "no recipe (older tree)" : "\(r!.crown ?? "?") crown, \(r!.trunk ?? "?") trunk, \(r!.accent == "none" ? "no accent" : r!.accent)")
                        .font(.typewriter(10)).foregroundColor(Palette.ink2)
                }
                if let r {
                    Text(String(format: "limbs %.2f  angle %.2f  depth %.2f  leaf %.2f  gap %.2f  height %.2f  girth %.2f",
                                r.branchCount ?? 0, r.branchAngle ?? 0, r.branchDepth ?? 0, r.leafSize ?? 0, r.leafGap ?? 0, r.height, r.girth))
                        .font(.typewriter(9)).foregroundColor(Palette.ink3)
                }
            }
        }
    }

    static func renderRecipes(to dir: URL, topicLooks: [TreeLook]) {
        let store = TreeStore(persist: false)
        let looks = Self.parallel(oakTopics.count) { k in recipe(for: oakTopics[k], base: .oak, seed: UInt64(3100 + k * 13)) }
        // Each oak has its own seed and recipe, as real trees would.
        let oaks = oakTopics.enumerated().map { k, t in topicTree(t, look: looks[k], number: k + 1, seed: 4242 + UInt64(k) * 7919, papers: 3) }
        let more = oaks.map { t -> PaperTreeData in
            var x = t
            let extra = ["Field notes on the same subject", "A long term study, part two", "A review of the evidence"]
            for (i, title) in extra.enumerated() {
                x.papers.append(Paper(id: "x\(t.number)-\(i)", title: title, authors: ["A. Reader"], year: 2020 + i, fields: t.papers.first?.fields ?? [],
                                      parentId: i == 0 ? nil : t.papers[i - 1].id, addedAt: Date(timeIntervalSince1970: 1_768_000_000 + Double(i) * 86_400)))
            }
            return x
        }
        let grid = VStack(alignment: .leading, spacing: 16) {
            Text("Eight oaks, eight seeds, eight recipes").font(.fell(20)).foregroundColor(Palette.ink)
            ForEach(0..<2, id: \.self) { r in
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(more.enumerated()).filter { $0.offset / 4 == r }, id: \.offset) { _, tree in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tree.name).font(.fell(16)).foregroundColor(Palette.ink)
                            SpecimenPlate(tree: tree, store: store, compact: false).frame(width: 330, height: 400)
                            RecipeLine(look: tree.look)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: 0xEFE9DA))
        save(grid, "recipe-oaks", to: dir)

        // An older tree without a recipe draws as it always did; then a local recipe; then the customizer's.
        var old = more[0]
        old.look.recipe = nil
        old.look.bloom = "blossom"
        var local = more[0]
        local.look.recipe = TreeRecipe.local(for: local.look, seed: 77)
        local.look.recipe?.model = nil
        let trio = HStack(alignment: .top, spacing: 16) {
            ForEach(Array([("Older tree, no recipe", old), ("Local recipe (offline)", local), ("Customizer recipe", more[0])].enumerated()), id: \.offset) { _, pair in
                VStack(alignment: .leading, spacing: 4) {
                    Text(pair.0).font(.fell(16)).foregroundColor(Palette.ink)
                    SpecimenPlate(tree: pair.1, store: store, compact: false).frame(width: 330, height: 400)
                    RecipeLine(look: pair.1.look)
                }
            }
        }
        .padding(20)
        .background(Color(hex: 0xEFE9DA))
        save(trio, "recipe-fallback", to: dir)

        // A grove: the eight oaks at two sizes, and every subject's plant with its own recipe.
        // Oaks and other subjects mixed, so the first screen shows both kinds of variety.
        var pool: [PaperTreeData] = []
        let others = topics.enumerated().filter { $0.offset < topicLooks.count }
            .map { k, t in topicTree(t, look: topicLooks[k], number: 0, seed: UInt64(8100 + k * 17), papers: 5) }
        for k in 0..<max(more.count, others.count) {
            if k < more.count { pool.append(more[k]) }
            if k < others.count { pool.append(others[k]) }
            if k < oaks.count { var b = oaks[k]; b.name = more[k].name + " 2"; b.seed = 4242 + UInt64(k); pool.append(b) }
        }
        let grove = pool.enumerated().map { i, t -> PaperTreeData in var x = t; x.number = i + 1; return x }
        store.trees = grove
        let size = CGSize(width: 1360, height: 800)
        let m = IslandModel()
        m.notchSize = CGSize(width: 190, height: 32)
        m.groveSize = size
        m.mode = .expanded
        m.page = .grove
        save(IslandView(model: m, state: AppState.shared, store: store)
                .frame(width: size.width + 40, height: size.height + 32 + 30).background(desk), "recipe-grove", to: dir)
        print("recipe grove trees: \(grove.count)")
    }

    /// Frames of setup pages with the buddy acting, for a short video (15 frames a second).
    static func renderBuddy(to dir: URL) {
        let state = AppState.shared
        state.accessibilityGranted = false
        state.researchMode = false
        let island = IslandModel()
        island.notchSize = CGSize(width: 190, height: 32)
        let frames = dir.appendingPathComponent("frames/buddy", isDirectory: true)
        try? FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        var f = 0
        for step in [SetupStep.welcome, .fields, .tap, .highlight, .add, .research, .finish] {
            let n = Int(min(3.4, step.act.loop) * 15)
            for i in 0..<n {
                BuddyStage.frozenTime = Double(i) / 15
                save(SetupView(state: state, island: island, initialStep: step.rawValue, explainPractice: { _, _, _ in }, done: {}),
                     String(format: "f%04d", f), to: frames)
                f += 1
            }
        }
        // Each act on its own, larger, for a closer look.
        let acts = dir.appendingPathComponent("frames/acts", isDirectory: true)
        try? FileManager.default.createDirectory(at: acts, withIntermediateDirectories: true)
        var g = 0
        for act in BuddyAct.allCases {
            for i in 0..<Int(act.loop * 15) {
                save(BuddyStage(act: act, time: Double(i) / 15).frame(width: 330, height: 375).background(Color(hex: 0xF3EFE6)),
                     String(format: "f%04d", g), to: acts)
                g += 1
            }
        }
        BuddyStage.frozenTime = nil
        // A still of every act at its key moment.
        let sheet = VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(Array(BuddyAct.allCases.enumerated()).filter { $0.offset / 4 == r }, id: \.offset) { _, act in
                        VStack(spacing: 2) {
                            BuddyStage(act: act, time: act.restTime).frame(width: 220, height: 250)
                            Text(act.rawValue).font(.typewriter(11)).foregroundColor(Palette.ink3)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: 0xF3EFE6))
        save(sheet, "buddy-acts", to: dir)
    }
}
