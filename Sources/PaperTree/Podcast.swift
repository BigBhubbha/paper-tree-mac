// A podcast of the open paper: two AI hosts, Juniper (asks) and Rowan (explains), talk it through.
// The server writes the script (/api/podcast/script) and records it a part at a time
// (/api/podcast/voice); the app stitches the parts into one episode, saves it beside the paper,
// and plays it in the reader with a transcript that follows the voice.
import AVFoundation
import AppKit
import Combine
import PDFKit
import SwiftUI

// MARK: What an episode is

struct PodcastLine: Codable, Identifiable, Equatable, Sendable {
    var id: Int
    var speaker: String
    var text: String
    /// A short span copied from the paper that this line is about (checked by the server), or empty.
    var quote: String
    var section: String
    var sig: String
    var start: Double = 0
    var end: Double = 0
}

struct PodcastEpisode: Codable, Equatable {
    var paperId: String
    var title: String
    var lines: [PodcastLine]
    var duration: Double
    /// Loudness of the whole episode in a few hundred steps, for the drawn waveform.
    var peaks: [Float]
    var made: Date
    var take: Int
    /// "paper" when made from the full text, "abstract" when that was all there was.
    var source: String
    var scriptModel: String
    var voiceModel: String
    var audioFile: String
}

enum PodcastHost {
    static func ink(_ speaker: String) -> MarkInk { speaker == "Juniper" ? .rose : .sage }
    static func role(_ speaker: String) -> String { speaker == "Juniper" ? "asks" : "explains" }
    /// The darker pen of each host's ink, for names.
    static func pen(_ speaker: String) -> Color { Color(nsColor: ink(speaker).pen) }
}

// MARK: Where episodes live: Application Support/Paper Tree/podcasts/<paper>/

@MainActor
enum PodcastLibrary {
    static var folder: URL { TreeStore.folder.appendingPathComponent("podcasts", isDirectory: true) }

    static func folder(for paperId: String) -> URL {
        let safe = String(paperId.map { $0.isLetter || $0.isNumber ? $0 : "-" }.prefix(80))
        return folder.appendingPathComponent(safe, isDirectory: true)
    }

    static func load(_ paperId: String) -> PodcastEpisode? {
        let dir = folder(for: paperId)
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("episode.json")),
              let ep = try? JSONDecoder().decode(PodcastEpisode.self, from: data),
              FileManager.default.fileExists(atPath: dir.appendingPathComponent(ep.audioFile).path) else { return nil }
        return ep
    }

    static func audioURL(_ ep: PodcastEpisode) -> URL { folder(for: ep.paperId).appendingPathComponent(ep.audioFile) }

    /// Writes the audio (AAC, or WAV if this Mac can't encode AAC) and then the episode beside it.
    static func save(_ ep: PodcastEpisode, samples: [Int16], rate: Double) async throws -> PodcastEpisode {
        let dir = folder(for: ep.paperId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = Int(ep.made.timeIntervalSince1970)
        let m4a = dir.appendingPathComponent("episode-\(stamp).m4a")
        let wavURL = dir.appendingPathComponent("episode-\(stamp).wav")
        var out = ep
        let encoded = await Task.detached(priority: .userInitiated) { () -> Bool in
            (try? PodcastAudio.writeAAC(samples, rate: rate, to: m4a)) != nil
        }.value
        if encoded {
            out.audioFile = m4a.lastPathComponent
        } else {
            try? FileManager.default.removeItem(at: m4a)
            try PodcastAudio.wav(samples, rate: rate).write(to: wavURL, options: .atomic)
            out.audioFile = wavURL.lastPathComponent
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        try enc.encode(out).write(to: dir.appendingPathComponent("episode.json"), options: .atomic)
        // Older takes go once the new one is safely on disk.
        for f in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        where f.hasPrefix("episode-") && f != out.audioFile {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
        return out
    }
}

enum PodcastAudio {
    static func writeAAC(_ samples: [Int16], rate: Double, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        let step = 32_768
        var at = 0
        while at < samples.count {
            let n = min(step, samples.count - at)
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n)),
                  let ch = buf.floatChannelData?[0] else { throw CocoaError(.fileWriteUnknown) }
            for i in 0..<n { ch[i] = Float(samples[at + i]) / 32768 }
            buf.frameLength = AVAudioFrameCount(n)
            try file.write(from: buf)
            at += n
        }
    }

    static func wav(_ samples: [Int16], rate: Double) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        let bytes = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        samples.withUnsafeBufferPointer { d.append(Data(buffer: $0)) }
        return d
    }

    /// The samples in a WAV file from the server (16-bit mono PCM), and its sample rate.
    static func samples(fromWAV data: Data) -> (samples: [Int16], rate: Double)? {
        let bytes = [UInt8](data)
        guard bytes.count > 44, String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF" else { return nil }
        func u32(_ i: Int) -> Int { Int(bytes[i]) | Int(bytes[i + 1]) << 8 | Int(bytes[i + 2]) << 16 | Int(bytes[i + 3]) << 24 }
        var rate = 24_000.0
        var i = 12
        while i + 8 <= bytes.count {
            let id = String(bytes: bytes[i..<i + 4], encoding: .ascii) ?? ""
            let size = u32(i + 4)
            if id == "fmt " { rate = Double(u32(i + 12)) }
            if id == "data" {
                let start = i + 8, end = min(bytes.count, start + size)
                var out = [Int16](repeating: 0, count: (end - start) / 2)
                for k in 0..<out.count { out[k] = Int16(bitPattern: UInt16(bytes[start + 2 * k]) | UInt16(bytes[start + 2 * k + 1]) << 8) }
                return (out, rate)
            }
            i += 8 + size + (size & 1)
        }
        return nil
    }

    /// Loudness in `count` steps, each 0...1, with a gentle curve so quiet speech still shows.
    static func peaks(_ samples: [Int16], count: Int) -> [Float] {
        guard !samples.isEmpty, count > 0 else { return [] }
        let per = max(1, samples.count / count)
        var out: [Float] = []
        out.reserveCapacity(count)
        for b in 0..<count {
            let a = b * per
            guard a < samples.count else { out.append(0); continue }
            let e = min(samples.count, a + per)
            var sum: Float = 0
            var k = a
            while k < e { let v = Float(samples[k]) / 32768; sum += v * v; k += 4 }
            let rms = (sum / Float(max(1, (e - a) / 4))).squareRoot()
            out.append(rms)
        }
        let m = max(out.max() ?? 1, 0.0001)
        return out.map { min(1, ($0 / m).squareRoot()) }
    }
}

// MARK: Talking to the server

struct PodcastClient {
    var base: String
    var token: String

    @MainActor static var current: PodcastClient { PodcastClient(base: AppState.shared.endpoint, token: AppState.shared.clientToken) }

    struct Failure: Error, Equatable {
        var message: String
        var retryAfter: Double? = nil
        var exhausted = false
        var next: String? = nil
    }

    struct ScriptLine: Codable, Sendable { var speaker: String; var text: String; var quote: String?; var section: String?; var sig: String }
    struct Script: Decodable, Sendable { var title: String; var lines: [ScriptLine]; var model: String? }
    struct Part: Sendable { var samples: [Int16]; var rate: Double; var timings: [[Double]]; var model: String }

    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 150
        c.timeoutIntervalForResource = 300
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        return URLSession(configuration: c)
    }()

    private func request(_ path: String, _ body: Data) throws -> URLRequest {
        var b = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = b.range(of: "/api/explain") { b = String(b[..<r.lowerBound]) }
        while b.hasSuffix("/") { b.removeLast() }
        guard let u = URL(string: b + path), u.scheme == "https" || u.host == "127.0.0.1" || u.host == "localhost" else {
            throw Failure(message: "Paper Tree's server address isn't set. Check Settings.")
        }
        var r = URLRequest(url: u, timeoutInterval: 150)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { r.setValue(token, forHTTPHeaderField: "X-Paper-Tree-Token") }
        r.httpBody = body
        return r
    }

    private func failure(_ data: Data, _ status: Int) -> Failure {
        let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        var f = Failure(message: (o?["error"] as? String) ?? "The server said \(status).")
        f.retryAfter = (o?["retryAfter"] as? NSNumber)?.doubleValue
        f.exhausted = (o?["exhausted"] as? Bool) ?? false
        f.next = o?["next"] as? String
        if status == 404 { f.message = "This server doesn't make podcasts yet." }
        return f
    }

    private func send(_ r: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await Self.session.data(for: r)
            guard let http = response as? HTTPURLResponse else { throw Failure(message: "No answer from the server.") }
            return (data, http)
        } catch let f as Failure {
            throw f
        } catch {
            if (error as? URLError)?.code == .cancelled || error is CancellationError { throw CancellationError() }
            if (error as? URLError)?.code == .timedOut { throw Failure(message: "The server took too long to answer.") }
            throw Failure(message: "Couldn't reach the server. Check your connection.")
        }
    }

    func script(paper: Paper, text: String, source: String, take: Int) async throws -> Script {
        var body: [String: Any] = ["title": paper.title, "authors": Array(paper.authors.prefix(6)), "text": text, "source": source, "take": take]
        if let y = paper.year { body["year"] = y }
        let (data, http) = try await send(request("/api/podcast/script", try JSONSerialization.data(withJSONObject: body)))
        guard http.statusCode == 200 else { throw failure(data, http.statusCode) }
        do { return try JSONDecoder().decode(Script.self, from: data) } catch { throw Failure(message: "The script came back in a shape I can't read.") }
    }

    func voice(_ lines: [ScriptLine], model: String?) async throws -> Part {
        var body: [String: Any] = ["lines": lines.map { ["speaker": $0.speaker, "text": $0.text, "sig": $0.sig] }]
        if let model { body["model"] = model }
        let (data, http) = try await send(request("/api/podcast/voice", try JSONSerialization.data(withJSONObject: body)))
        guard http.statusCode == 200 else { throw failure(data, http.statusCode) }
        guard let (samples, rate) = PodcastAudio.samples(fromWAV: data) else { throw Failure(message: "The recording came back damaged.") }
        let header = http.value(forHTTPHeaderField: "X-Podcast-Timings") ?? "[]"
        let timings = ((try? JSONSerialization.jsonObject(with: Data(header.utf8))) as? [[NSNumber]])?.map { $0.map { $0.doubleValue / 1000 } } ?? []
        return Part(samples: samples, rate: rate, timings: timings, model: http.value(forHTTPHeaderField: "X-Podcast-Model") ?? "")
    }
}

// MARK: One paper's podcast: making it, saving it, playing it

@MainActor
final class PodcastModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    enum Phase: Equatable { case empty, making, ready, failed(String) }
    enum Step: Int, CaseIterable { case reading, writing, recording, binding }

    let paper: Paper
    @Published var phase: Phase = .empty
    @Published var step: Step = .reading
    @Published var startedAt: Date?
    @Published var stepStarted: [Step: Date] = [:]
    @Published var stepDone: [Step: Date] = [:]
    /// What we're working from, for the "Read the paper" entry.
    @Published var readNote = ""
    /// The script while it's being recorded; `recorded` holds the ids of lines already in the can.
    @Published var draft: [PodcastLine] = []
    @Published var draftTitle = ""
    @Published var recorded: Set<Int> = []
    @Published var partsDone = 0
    @Published var partsTotal = 0
    /// The tape so far, drawn as it comes in.
    @Published var draftPeaks: [Float] = []
    /// Set while the voice model asks us to wait.
    @Published var waitingUntil: Date?
    @Published var episode: PodcastEpisode?
    /// True for a moment after an episode is finished, so the stamp can land.
    @Published var justMade = false

    @Published var isPlaying = false
    @Published var time: Double = 0
    @Published var rate: Float = 1
    @Published var follow = true
    @Published private(set) var currentLine: Int?

    private var player: AVAudioPlayer?
    private var ticker: Timer?
    private var job: Task<Void, Never>?

    static let partSize = 9
    static let rates: [Float] = [1, 1.25, 1.5, 2]

    init(paper: Paper, load: Bool = true) {
        self.paper = paper
        super.init()
        if load, let ep = PodcastLibrary.load(paper.id) {
            episode = ep
            phase = .ready
        }
    }

    var duration: Double { episode?.duration ?? 0 }
    var lines: [PodcastLine] { episode?.lines ?? draft }

    /// Where the player really is, read fresh (for drawing the playhead every frame).
    var liveTime: Double { player.map { $0.isPlaying ? $0.currentTime : time } ?? time }

    // MARK: Making

    func make(text: String, source: String) {
        guard phase != .making else { return }
        pause()
        let take = (episode?.take ?? -1) + 1
        phase = .making
        startedAt = Date()
        stepStarted = [.reading: Date()]
        stepDone = [:]
        step = .reading
        draft = []; draftTitle = ""; recorded = []; draftPeaks = []
        partsDone = 0; partsTotal = 0; waitingUntil = nil; justMade = false
        let chars = text.count
        readNote = source == "abstract" ? "only the abstract, \(chars.formatted()) characters" : "\(chars.formatted()) characters of text"
        job = Task { [weak self] in await self?.run(text: text, source: source, take: take) }
    }

    func cancel() {
        job?.cancel()
        job = nil
        waitingUntil = nil
        phase = episode == nil ? .empty : .ready
    }

    private func mark(_ s: Step) {
        stepDone[step] = Date()
        step = s
        stepStarted[s] = Date()
    }

    private func run(text: String, source: String, take: Int) async {
        let client = PodcastClient.current
        do {
            try await Task.sleep(nanoseconds: 450_000_000) // let "reading" register before the long wait
            mark(.writing)
            let script = try await client.script(paper: paper, text: text, source: source, take: take)
            try Task.checkCancellation()
            draftTitle = script.title
            draft = script.lines.enumerated().map { i, l in
                PodcastLine(id: i, speaker: l.speaker, text: l.text, quote: l.quote ?? "", section: l.section ?? "", sig: l.sig)
            }
            mark(.recording)
            let parts = stride(from: 0, to: script.lines.count, by: Self.partSize).map { Array(script.lines[$0..<min($0 + Self.partSize, script.lines.count)]) }
            partsTotal = parts.count
            var results = [PodcastClient.Part?](repeating: nil, count: parts.count)
            var model: String? = nil
            var attempt = 0
            while true {
                do {
                    // Part one alone, so every other part can ask for the same voice model.
                    let first = try await record(parts[0], model: model, client: client)
                    results[0] = first
                    if !first.model.isEmpty { model = first.model }
                    landPart(0, first, parts)
                    let sticky = model
                    let one: @Sendable (Int) async throws -> (Int, PodcastClient.Part) = { [weak self] k in
                        guard let self else { throw CancellationError() }
                        return (k, try await self.record(parts[k], model: sticky, client: client))
                    }
                    let found: [(Int, PodcastClient.Part)] = try await withThrowingTaskGroup(of: (Int, PodcastClient.Part).self) { group in
                        var next = 1
                        var got: [(Int, PodcastClient.Part)] = []
                        while next < parts.count && next < 3 { let k = next; next += 1; group.addTask { try await one(k) } }
                        while let done = try await group.next() {
                            got.append(done)
                            await self.landPart(done.0, done.1, parts)
                            if next < parts.count { let k = next; next += 1; group.addTask { try await one(k) } }
                        }
                        return got
                    }
                    for (k, part) in found { results[k] = part }
                    break
                } catch let f as PodcastClient.Failure where f.exhausted && f.next != nil && attempt < 2 {
                    // Today's allowance for this voice ran out partway: record it all again in the next
                    // model, so the whole episode is in one voice.
                    attempt += 1
                    model = f.next
                    results = .init(repeating: nil, count: parts.count)
                    recorded = []; partsDone = 0; draftPeaks = []
                }
            }
            mark(.binding)
            let done = results.compactMap { $0 }
            let (draftEpisode, samples) = assemble(parts, done, title: script.title, source: source, take: take,
                                                   scriptModel: script.model ?? "", voiceModel: model ?? "")
            let saved = try await PodcastLibrary.save(draftEpisode, samples: samples, rate: done.first?.rate ?? 24_000)
            try Task.checkCancellation()
            stepDone[.binding] = Date()
            self.episode = saved
            self.player = nil
            time = 0
            currentLine = nil
            withAnimation(Motion.pick(Motion.page)) { phase = .ready }
            withAnimation(Motion.pick(Motion.land).delay(0.25)) { justMade = true }
            draft = []
        } catch is CancellationError {
            return
        } catch let f as PodcastClient.Failure {
            waitingUntil = nil
            phase = .failed(f.exhausted ? "The voice model has used up today's allowance. Try again tomorrow." : f.message)
        } catch {
            waitingUntil = nil
            phase = .failed("Something went wrong saving the episode.")
        }
    }

    /// Records one part, waiting out a busy voice model a few times.
    nonisolated private func record(_ lines: [PodcastClient.ScriptLine], model: String?, client: PodcastClient) async throws -> PodcastClient.Part {
        var tries = 0
        while true {
            try Task.checkCancellation()
            do {
                let part = try await client.voice(lines, model: model)
                await MainActor.run { self.waitingUntil = nil }
                return part
            } catch let f as PodcastClient.Failure where !f.exhausted && f.retryAfter != nil && tries < 4 {
                tries += 1
                let wait = min(90, max(3, f.retryAfter ?? 20))
                await MainActor.run { self.waitingUntil = Date().addingTimeInterval(wait) }
                try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }

    private func landPart(_ k: Int, _ part: PodcastClient.Part, _ parts: [[PodcastClient.ScriptLine]]) {
        let firstId = k * Self.partSize
        withAnimation(Motion.pick(.easeOut(duration: 0.5))) {
            for j in 0..<parts[k].count { recorded.insert(firstId + j) }
            partsDone += 1
        }
        // The live tape: each part's loudness, in order of arrival.
        withAnimation(Motion.pick(.easeOut(duration: 0.6))) {
            draftPeaks += PodcastAudio.peaks(part.samples, count: max(12, Int(Double(part.samples.count) / part.rate * 1.6)))
        }
    }

    private func assemble(_ parts: [[PodcastClient.ScriptLine]], _ results: [PodcastClient.Part], title: String, source: String,
                          take: Int, scriptModel: String, voiceModel: String) -> (PodcastEpisode, [Int16]) {
        let rate = results.first?.rate ?? 24_000
        let breath = [Int16](repeating: 0, count: Int(rate * 0.18))
        var all: [Int16] = []
        var lines: [PodcastLine] = []
        var id = 0
        for (k, part) in results.enumerated() {
            let at = Double(all.count) / rate
            let partDur = Double(part.samples.count) / rate
            for (j, l) in parts[k].enumerated() {
                let t = j < part.timings.count && part.timings[j].count == 2 ? part.timings[j]
                    : [partDur * Double(j) / Double(parts[k].count), partDur * Double(j + 1) / Double(parts[k].count)]
                lines.append(PodcastLine(id: id, speaker: l.speaker, text: l.text, quote: l.quote ?? "", section: l.section ?? "", sig: l.sig,
                                         start: at + t[0], end: at + min(t[1], partDur)))
                id += 1
            }
            all += part.samples
            if k < results.count - 1 { all += breath }
        }
        let ep = PodcastEpisode(paperId: paper.id, title: title, lines: lines, duration: Double(all.count) / rate,
                                peaks: PodcastAudio.peaks(all, count: 640), made: Date(), take: take, source: source,
                                scriptModel: scriptModel, voiceModel: voiceModel, audioFile: "")
        return (ep, all)
    }

    // MARK: Playing

    private func ensurePlayer() -> AVAudioPlayer? {
        if let player { return player }
        guard let ep = episode, let p = try? AVAudioPlayer(contentsOf: PodcastLibrary.audioURL(ep)) else { return nil }
        p.enableRate = true
        p.rate = rate
        p.delegate = self
        p.prepareToPlay()
        player = p
        return p
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard let p = ensurePlayer() else { phase = .failed("The saved episode couldn't be opened. Make it again."); return }
        if time >= duration - 0.05 { time = 0 }
        p.currentTime = time
        p.rate = rate
        p.play()
        isPlaying = true
        justMade = false
        startTicker()
    }

    func pause() {
        player?.pause()
        if let p = player { time = p.currentTime }
        isPlaying = false
        ticker?.invalidate(); ticker = nil
    }

    func seek(to t: Double) {
        time = max(0, min(duration, t))
        player?.currentTime = time
        updateLine()
    }

    func jump(to line: PodcastLine) {
        seek(to: line.start)
        if !isPlaying { play() }
    }

    func skip(_ d: Double) { seek(to: (isPlaying ? (player?.currentTime ?? time) : time) + d) }

    func setRate(_ r: Float) {
        rate = r
        player?.rate = r
    }

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 1.0 / 12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let p = self.player, self.isPlaying else { return }
                self.time = p.currentTime
                self.updateLine()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func updateLine() {
        guard let ls = episode?.lines, !ls.isEmpty else { currentLine = nil; return }
        // The line being spoken, or (in the breath between lines) the one about to start.
        let i = ls.lastIndex { $0.start <= time + 0.08 } ?? 0
        if currentLine != i { currentLine = i }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.ticker?.invalidate(); self.ticker = nil
            self.time = self.duration
        }
    }

    // MARK: For design snapshots

    /// Partway through recording `ep`: script written, `parts` of five parts in the can.
    func presetMaking(_ ep: PodcastEpisode, parts: Int, elapsed: Double) {
        let now = Date()
        phase = .making
        step = .recording
        startedAt = now.addingTimeInterval(-elapsed)
        stepStarted = [.reading: now.addingTimeInterval(-elapsed), .writing: now.addingTimeInterval(-elapsed + 0.5), .recording: now.addingTimeInterval(-elapsed + 12)]
        stepDone = [.reading: now.addingTimeInterval(-elapsed + 0.5), .writing: now.addingTimeInterval(-elapsed + 12)]
        readNote = "1,880 characters of text"
        draft = ep.lines
        draftTitle = ep.title
        partsTotal = 5
        partsDone = parts
        recorded = Set(0..<min(ep.lines.count, parts * Self.partSize))
        let reach = min(ep.lines.count, parts * Self.partSize)
        let cut = reach < ep.lines.count ? ep.lines[reach].start : ep.duration
        draftPeaks = Array(ep.peaks.prefix(Int(Double(ep.peaks.count) * cut / ep.duration)))
    }

    func preset(episode: PodcastEpisode?, phase: Phase, time: Double = 0, playing: Bool = false) {
        self.episode = episode
        self.phase = phase
        self.time = time
        self.isPlaying = playing
        updateLine()
    }
}

/// Keeps each paper's podcast alive while you move around the island, so a recording in progress
/// carries on and comes back where you left it.
@MainActor
final class PodcastDesk {
    static let shared = PodcastDesk()
    private var models: [String: PodcastModel] = [:]

    func model(for paper: Paper) -> PodcastModel {
        if let m = models[paper.id] { return m }
        let m = PodcastModel(paper: paper, load: !Snapshots.isRendering)
        models[paper.id] = m
        return m
    }

    func preset(_ m: PodcastModel) { models[m.paper.id] = m }
}

extension Double {
    /// 3:41
    var clock: String {
        let s = Int(self.rounded(.down))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }
}
