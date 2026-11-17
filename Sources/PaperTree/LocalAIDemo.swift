// A developer and CI check of the on-device reader: writes a real explanation, a real podcast script
// and voices it with Kokoro, times each step, saves the sample episode and draws the screens.
//   PaperTree --paper-tree-local-ai-demo <dir> [--explain-only] [--tag name]
// Needs PAPER_TREE_WRITER_MODEL (a .gguf) and PAPER_TREE_VOICE_DIR (the Kokoro folder).
import AppKit
import Metal
import PDFKit
import SwiftUI

@MainActor
enum LocalAIDemo {
    struct Report: Encodable {
        var hardware: [String: String] = [:]
        var writerModel = ""
        var writerBytes: Int64 = 0
        var steps: [Step] = []
        var notes: [String] = []
    }
    struct Step: Encodable {
        var name: String
        var seconds: Double
        var loadSeconds: Double?
        var promptTokens: Int?
        var cachedTokens: Int?
        var promptSeconds: Double?
        var generatedTokens: Int?
        var generateSeconds: Double?
        var tokensPerSecond: Double?
        var usedGPU: Bool?
        var audioSeconds: Double?
        var peakRSSMB: Double?
        var output: String?
        var retried: Bool?
    }

    static let highlight = "Rubisco also reacts with oxygen, and that side reaction becomes more common as carbon dioxide inside the leaf drops."

    static func runIfRequested() -> Int32? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--paper-tree-local-ai-demo"), i + 1 < args.count else { return nil }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tag = args.firstIndex(of: "--tag").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "demo"
        Typeface.registerBundledFonts()
        Snapshots.isRendering = true
        guard LocalModels.writerPath() != nil else { print("PAPER_TREE_WRITER_MODEL is not set"); return 2 }
        return run(dir: dir, tag: tag, explainOnly: args.contains("--explain-only"))
    }

    /// Runs async work to the end while keeping the main run loop turning.
    static func wait<T>(_ work: @escaping @Sendable () async throws -> T) throws -> T {
        let box = Box<Result<T, Error>?>(nil)
        let lock = NSLock()
        Task.detached(priority: .userInitiated) {
            let r: Result<T, Error>
            do { r = .success(try await work()) } catch { r = .failure(error) }
            lock.withLock { box.value = r }
        }
        while true {
            let r = lock.withLock { box.value }
            if let r { return try r.get() }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    nonisolated static let t0 = Date()
    /// Progress on stderr (unbuffered), so a slow CI step shows where it is.
    nonisolated static func log(_ s: String) {
        let line = String(format: "[%6.1fs] ", Date().timeIntervalSince(t0)) + s + "\n"
        FileHandle.standardError.write(Data(line.utf8))
    }

    static func sysctl(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buf, &size, nil, 0)
        return String(cString: buf)
    }

    static func peakRSSMB() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_maxrss) / 1_048_576 // bytes on macOS
    }

    static func step(_ name: String, _ t: LocalWriter.Timing, output: String) -> Step {
        Step(name: name, seconds: t.seconds, loadSeconds: t.stats.loadSeconds, promptTokens: t.stats.promptTokens,
             cachedTokens: t.stats.cachedTokens, promptSeconds: t.stats.promptSeconds, generatedTokens: t.stats.generatedTokens, generateSeconds: t.stats.generateSeconds,
             tokensPerSecond: t.stats.tokensPerSecond, usedGPU: t.stats.usedGPU, peakRSSMB: peakRSSMB(), output: output, retried: t.retried)
    }

    static func samplePaper() -> Paper {
        var sample = Paper(id: "sample-dry-spell", title: "Leaves in a dry spell: how plants trade water for carbon",
                           authors: ["Sample text", "written for Paper Tree design snapshots"], year: 2026, venue: "Paper Tree design notes")
        sample.abstract = SamplePaper.abstract
        sample.fields = ["Biology", "Environmental Science"]
        return sample
    }

    static var sampleText: String {
        "Abstract\n" + SamplePaper.abstract + "\n\n" + SamplePaper.body.enumerated().map { "\($0 + 1). \($1.0)\n\($1.1)" }.joined(separator: "\n\n")
    }

    static func run(dir: URL, tag: String, explainOnly: Bool) -> Int32 {
        var report = Report()
        var memory: UInt64 = 0
        var ms = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memory, &ms, nil, 0)
        report.hardware = [
            "cpu": sysctl("machdep.cpu.brand_string"), "model": sysctl("hw.model"),
            "cores": "\(ProcessInfo.processInfo.activeProcessorCount)",
            "memoryGB": String(format: "%.1f", Double(memory) / 1_073_741_824),
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "metal": MTLCreateSystemDefaultDevice()?.name ?? "none",
            "performanceCores": LocalLLM.performanceCores.map(String.init) ?? "unknown",
            "forcedCPU": ProcessInfo.processInfo.environment["PAPER_TREE_LLM_CPU"] == "1" ? "yes" : "no",
        ]
        let writer = LocalModels.writerPath() ?? ""
        report.writerModel = (writer as NSString).lastPathComponent
        report.writerBytes = (try? FileManager.default.attributesOfItem(atPath: writer)[.size] as? NSNumber)?.int64Value ?? 0
        let paper = samplePaper()
        let section2 = SamplePaper.body[1].1
        let hl = highlight
        let abstract = SamplePaper.abstract
        let answers = Snapshots.sampleAnswers.map(\.1)
        let profiled = ReaderNote(school: answers[0], expertise: answers[1], fields: answers[2], length: answers[3])
        let phd = ReaderNote(school: "Fourth year PhD student", expertise: "I run gas exchange experiments on crops", fields: "Plant physiology", length: nil)
        var code: Int32 = 0
        var explanation: Explanation?

        func finish() {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try? enc.encode(report).write(to: dir.appendingPathComponent("timings-\(tag).json"))
            if let d = try? enc.encode(report), let s = String(data: d, encoding: .utf8) { print(s) }
        }

        log("hardware \(report.hardware), writer \(report.writerModel)")
        // 1. Explanations: the same highlight for two different readers.
        do {
            let (e, t) = try wait { try await LocalWriter.explain(text: hl, context: section2, mode: .plain, reader: profiled) }
            explanation = e
            log("explain 1 done in \(String(format: "%.1f", t.seconds)) s (prompt \(t.stats.promptTokens) tok in \(String(format: "%.1f", t.stats.promptSeconds)) s, \(t.stats.generatedTokens) tok at \(String(format: "%.1f", t.stats.tokensPerSecond)) tok/s, GPU \(t.stats.usedGPU)): \(e.text)")
            report.steps.append(step("explain (high school junior, short)", t, output: e.text + " | " + e.terms.map { "\($0.term): \($0.meaning)" }.joined(separator: "; ")))
            // The second answer reuses the saved prompt prefix, so it shows the speed after the first.
            let (e2, t2) = try wait { try await LocalWriter.explain(text: hl, context: section2, mode: .plain, reader: phd) }
            log("explain 2 done in \(String(format: "%.1f", t2.seconds)) s (prompt \(t2.stats.promptTokens) tok, \(t2.stats.cachedTokens) cached, read in \(String(format: "%.1f", t2.stats.promptSeconds)) s, \(t2.stats.generatedTokens) tok at \(String(format: "%.1f", t2.stats.tokensPerSecond)) tok/s): \(e2.text)")
            report.steps.append(step("explain (PhD student)", t2, output: e2.text + " | " + e2.terms.map { "\($0.term): \($0.meaning)" }.joined(separator: "; ")))
        } catch is CancellationError {
        } catch {
            report.notes.append("explain failed: \(error)")
            code = 1
        }
        let model = CardModel()
        model.selection = highlight
        if let explanation { model.phase = .loaded(explanation) }
        Snapshots.save(ExplanationCardView(model: model).padding(20).background(Color(hex: 0xF3EFE6)), "local-explanation-\(tag)", to: dir)
        if explainOnly { LocalLLM.shared.unload(); finish(); return code }

        log("explanations done")
        // 2. Tree label.
        do {
            let titles = Array(SampleGrove.trees().first?.papers.prefix(5).map(\.title) ?? [paper.title])
            let (n, t) = try wait { try await LocalWriter.treeNote(plant: .willow, titles: titles, fields: ["Biology"]) }
            report.steps.append(step("tree note", t, output: "\(n.commonName) / \(n.latinName) / \(n.note)"))
        } catch { report.notes.append("tree note failed: \(error)") }

        log("tree note done")
        // 3. The podcast: script, then voices.
        let text = sampleText
        var script: PodcastClient.Script?
        var firstLines: [PodcastClient.ScriptLine] = []
        do {
            let partial = Box<[PodcastClient.ScriptLine]>([])
            let (s, t) = try wait {
                try await LocalWriter.podcastScript(paper: paper, text: text, source: "paper") { _, lines in
                    if lines.count == 7 { partial.value = lines }
                    if !lines.isEmpty, lines.count % 5 == 0 { log("script: \(lines.count) lines") }
                }
            }
            script = s
            firstLines = partial.value
            report.steps.append(step("podcast script (\(s.lines.count) lines)", t, output: s.title))
            try? s.lines.map { "{\"speaker\": \(jsonLiteral($0.speaker)), \"text\": \(jsonLiteral($0.text)), \"quote\": \(jsonLiteral($0.quote ?? ""))}" }
                .joined(separator: "\n").write(to: dir.appendingPathComponent("sample-episode-script.jsonl"), atomically: true, encoding: .utf8)
        } catch {
            report.notes.append("podcast script failed: \(error)")
            code = 1
        }
        LocalLLM.shared.unload()

        let pm = PodcastModel(paper: paper, load: false)
        var episode: PodcastEpisode?
        if let script, LocalModels.voicePath() != nil {
            do {
                let lines = script.lines
                let parts = stride(from: 0, to: lines.count, by: PodcastModel.partSize).map { Array(lines[$0..<min($0 + PodcastModel.partSize, lines.count)]) }
                let started = Date()
                let results = try wait {
                    var out: [PodcastClient.Part] = []
                    for (k, p) in parts.enumerated() {
                        out.append(try await KokoroVoice.shared.voice(p))
                        log("voiced part \(k + 1) of \(parts.count)")
                    }
                    return out
                }
                let (ep, samples) = pm.assemble(parts, results, title: script.title, source: "paper", take: 0,
                                                scriptModel: script.model ?? "local", voiceModel: KokoroVoice.modelName)
                let rate = results.first?.rate ?? 24_000
                var saved = ep
                let m4a = dir.appendingPathComponent("sample-episode.m4a")
                if (try? PodcastAudio.writeAAC(samples, rate: rate, to: m4a)) != nil {
                    saved.audioFile = m4a.lastPathComponent
                } else {
                    try PodcastAudio.wav(samples, rate: rate).write(to: dir.appendingPathComponent("sample-episode.wav"))
                    saved.audioFile = "sample-episode.wav"
                }
                episode = saved
                let enc = JSONEncoder()
                enc.outputFormatting = [.prettyPrinted]
                try? enc.encode(saved).write(to: dir.appendingPathComponent("sample-episode.json"))
                report.steps.append(Step(name: "kokoro voices (\(lines.count) lines)", seconds: Date().timeIntervalSince(started),
                                         audioSeconds: saved.duration, peakRSSMB: peakRSSMB()))
            } catch {
                report.notes.append("voicing failed: \(error)")
                code = 1
            }
        } else if script != nil {
            report.notes.append("PAPER_TREE_VOICE_DIR is not set, so the episode wasn't voiced")
        }
        KokoroVoice.shared.unload()

        log("drawing screens")
        shootScreens(dir: dir, paper: paper, episode: episode, draft: firstLines)
        finish()
        return code
    }

    // MARK: Screens

    static func shootScreens(dir: URL, paper: Paper, episode: PodcastEpisode?, draft: [PodcastClient.ScriptLine]) {
        TreeClock.frozen = Date()
        TreeClock.sketchStart = nil
        let store = TreeStore(persist: false)
        var trees = SampleGrove.trees()
        guard !trees.isEmpty else { return }
        trees[0].papers.append(paper)
        store.trees = trees
        let host = trees[0]
        func island(_ r: ReaderModel) -> IslandModel {
            let m = IslandModel()
            m.notchSize = CGSize(width: 190, height: 32)
            m.groveSize = CGSize(width: 1360, height: 800)
            m.mode = .expanded
            m.page = .paper(host.id, paper.id)
            m.readerPreset = r
            return m
        }
        func listening(_ setup: (ReaderModel, PodcastModel) -> Void) -> ReaderModel {
            let r = ReaderModel(paper: paper, persist: false)
            if let doc = PDFDocument(data: SamplePaper.pdf()) { r.setDocument(doc) }
            r.marks.preset([])
            r.rail = .listen
            let pm = PodcastModel(paper: paper, load: false)
            setup(r, pm)
            PodcastDesk.shared.preset(pm)
            return r
        }
        let download = ReaderDownload.shared
        let total = download.allBytes

        // Before the reader is on this Mac: the Listen tab asks for it.
        download.preset(.notStarted, done: 0, total: total)
        Snapshots.shootIsland(island(listening { _, _ in }), store, "local-podcast-needs-reader", to: dir)

        download.preset(.ready, done: total, total: total)
        if let ep = episode {
            let writing = listening { _, pm in
                pm.presetMaking(ep, parts: 0, elapsed: 21)
                pm.step = .writing
                pm.stepDone = [.reading: Date().addingTimeInterval(-20)]
                pm.draft = draft.enumerated().map { PodcastLine(id: $0, speaker: $1.speaker, text: $1.text, quote: "", section: $1.section ?? "", sig: "") }
                pm.draftTitle = ep.title
                pm.partsTotal = 0
                pm.draftPeaks = []
            }
            Snapshots.shootIsland(island(writing), store, "local-podcast-writing", to: dir)
            let recording = listening { _, pm in pm.presetMaking(ep, parts: 2, elapsed: 74) }
            Snapshots.shootIsland(island(recording), store, "local-podcast-recording", to: dir)
            let k = min(3, ep.lines.count - 1)
            let playing = listening { r, pm in
                pm.preset(episode: ep, phase: .ready, time: ep.lines[k].start + 1.5, playing: true)
                if !ep.lines[k].quote.isEmpty { r.follow(ep.lines[k].quote) }
            }
            Snapshots.shootIsland(island(playing), store, "local-podcast-playing", to: dir)
            let fresh = listening { _, pm in pm.preset(episode: ep, phase: .ready); pm.justMade = true }
            Snapshots.shootIsland(island(fresh), store, "local-podcast-ready", to: dir)
        }

        // The reader shelf in Settings, in each state.
        let gb: Int64 = 1_000_000_000
        let states: [(String, ReaderDownload.Phase, Int64, Double, String)] = [
            ("not-started", .notStarted, 0, 0, ""),
            ("downloading", .downloading, Int64(Double(total) * 0.42), 18_400_000, download.writer.file.name),
            ("paused", .paused, Int64(Double(total) * 0.42), 0, ""),
            ("no-space", .noSpace(need: total + gb, free: 3 * gb + 400_000_000), 0, 0, ""),
            ("failed", .failed("The download stopped: the connection was lost. Your progress is kept."), Int64(Double(total) * 0.61), 0, ""),
            ("checking", .checking, total, 0, ""),
            ("ready", .ready, total, 0, ""),
        ]
        for (name, phase, done, rate, file) in states {
            download.preset(phase, done: done, total: total, rate: rate, file: file)
            Snapshots.save(ReaderShelf(download: download).frame(width: 520).padding(28).background(DeskBackground()),
                           "local-reader-\(name)", to: dir)
        }
        download.preset(.downloading, done: Int64(Double(total) * 0.42), total: total, rate: 18_400_000, file: download.writer.file.name)
        Snapshots.save(SettingsView(state: AppState.shared, showWelcome: {}, checkForUpdates: {}).content
                .background(DeskBackground()), "local-settings-downloading", to: dir)
        download.preset(.ready, done: total, total: total)
        Snapshots.save(SettingsView(state: AppState.shared, showWelcome: {}, checkForUpdates: {}, showTinkerers: true).content
                .background(DeskBackground()), "local-settings-tinkerers", to: dir)
    }
}
