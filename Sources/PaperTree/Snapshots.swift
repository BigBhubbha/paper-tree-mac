// `PaperTree --paper-tree-snapshots <folder>` renders the main surfaces to PNGs and quits.
// CI uses it so design changes can be reviewed without a Mac. Nothing here runs in normal use.
// It writes sample answers into this Mac's Paper Tree settings, so only run it on a build machine.
import AppKit
import SwiftUI

@MainActor
enum Snapshots {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--paper-tree-snapshots"), i + 1 < args.count else { return false }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Typeface.registerBundledFonts()
        render(to: dir)
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
        save(IslandView(model: island, state: state)
                .frame(width: 460, height: 340).background(Color(hex: 0x6E7B86)), "island-open", to: dir)
        let flash = IslandModel()
        flash.mode = .flash(on: true)
        save(IslandView(model: flash, state: state)
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
}
