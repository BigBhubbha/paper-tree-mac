// `PaperTree --paper-tree-snapshots <folder>` renders the main surfaces to PNGs and quits.
// CI uses it so design changes can be reviewed without a Mac. Nothing here runs in normal use.
// It writes sample answers into this Mac's Paper Tree settings, so only run it on a build machine.
import AppKit
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

        for step in 0..<5 {
            save(SetupView(state: state, island: island, initialStep: step, explainPractice: { _, _, _ in }, done: {}),
                 "setup-\(step + 1)", to: dir)
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

        // The add chooser, half open, with a paper found (its details as Semantic Scholar has them).
        let adding = island {
            $0.mode = .adding
            $0.adding = AddRequest(highlighted: SampleGrove.addedPaper.title, lookup: .found(SampleGrove.addedPaper))
        }
        shoot(adding, "island-add-found", size: CGSize(width: 680, height: 32 + IslandModel.addingSize.height + 30))
        let looking = island { $0.mode = .adding; $0.adding = AddRequest(highlighted: SampleGrove.addedPaper.title) }
        shoot(looking, "island-add-looking", size: CGSize(width: 680, height: 32 + IslandModel.addingSize.height + 30))
        store.plantingNewTree = ""
        shoot(adding, "island-add-planting", size: CGSize(width: 680, height: 32 + IslandModel.addingSize.height + 30))
        store.plantingNewTree = nil

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

    /// Downloads a paper's PDF and draws page 1, waiting for it (snapshots run synchronously).
    private static func frontPage(_ paper: Paper) -> NSImage? {
        guard let url = URL(string: paper.pdf), url.scheme == "https" else { return nil }
        let done = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var data: Data? }
        let box = Box()
        Task.detached {
            box.data = await TreeStore.renderFrontPage(url)
            done.signal()
        }
        guard done.wait(timeout: .now() + 40) == .success, let data = box.data else {
            print("front page failed: \(paper.title)")
            return nil
        }
        return NSImage(data: data)
    }
}
