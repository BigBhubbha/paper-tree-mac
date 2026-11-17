// The reader's own models, downloaded once and kept in
// ~/Library/Application Support/Paper Tree/Models:
//   the writer (Qwen 3.5, 4-bit GGUF, Apache 2.0) explains highlights, writes podcast scripts and
//   names trees; the voices (Kokoro-82M v1.0, Apache 2.0) read the podcasts aloud.
// Downloads are plain HTTPS range requests to Hugging Face, written to "<file>.part", so a pause,
// a dropped connection or a quit picks up where it stopped. Every file is checked against its
// SHA-256 before it counts.
import CryptoKit
import Foundation
import SwiftUI

struct ModelFile: Sendable, Hashable {
    var name: String
    var url: String
    var bytes: Int64
    var sha256: String
}

/// One writer model the reader can use.
struct WriterChoice: Identifiable, Sendable, Hashable {
    var id: String
    var title: String
    var detail: String
    var file: ModelFile
    /// Memory this Mac should have for it to run comfortably.
    var memoryGB: Int
    var fitsThisMac: Bool { Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824 >= Double(memoryGB) - 1 }
}

enum LocalModels {
    static var root: URL {
        // Application Support/Paper Tree/Models (the same folder TreeStore uses, worked out here so
        // it can be read from any thread).
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Paper Tree/Models", isDirectory: true)
    }

    // Pinned to exact files: same bytes for everyone, checked by hash.
    static let writers: [WriterChoice] = [
        WriterChoice(id: "qwen3.5-4b-q4km", title: "Quick reader",
                     detail: "Qwen 3.5, 4 billion parameters. Answers in seconds. The default, fine on 8 GB Macs.",
                     file: ModelFile(name: "Qwen3.5-4B-Q4_K_M.gguf",
                                     url: "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/e87f176479d0855a907a41277aca2f8ee7a09523/Qwen3.5-4B-Q4_K_M.gguf",
                                     bytes: 2_740_937_888, sha256: "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4"),
                     memoryGB: 8),
        WriterChoice(id: "qwen3.5-9b-q4km", title: "Full reader",
                     detail: "Qwen 3.5, 9 billion parameters. A little richer, but about twice as slow. Optional, for Macs with 16 GB of memory or more.",
                     file: ModelFile(name: "Qwen3.5-9B-Q4_K_M.gguf",
                                     url: "https://huggingface.co/lmstudio-community/Qwen3.5-9B-GGUF/resolve/1379f25c6b505a3fc737bd7818cb09389cf807c1/Qwen3.5-9B-Q4_K_M.gguf",
                                     bytes: 5_627_044_256, sha256: "cd76ec205963b3b33350093e6904d9de16c4e666fd104e1f632d25c7f15f2a13"),
                     memoryGB: 16),
    ]

    static let voiceFolder = "kokoro-v1.0"
    private static let kokoro = "https://huggingface.co/csukuangfj/kokoro-multi-lang-v1_0/resolve/f7b96bb6bef5c5da4d3aa4f4e0498fbbf62dc78b/"
    static let voiceFiles: [ModelFile] = [
        ModelFile(name: "model.onnx", url: kokoro + "model.onnx", bytes: 325_560_556,
                  sha256: "b40f62b166ac8164b0627ef48a0b358eda0985e272fb03ef5252e7206305da11"),
        ModelFile(name: "voices.bin", url: kokoro + "voices.bin", bytes: 28_200_960,
                  sha256: "1c5a5b983d3d50d8586d437a51f3faa2da7919ce76a013c081e65671a3447c29"),
        ModelFile(name: "tokens.txt", url: kokoro + "tokens.txt", bytes: 687,
                  sha256: "6ebb6bb288f20f3ae8d004d3c2ca27697da27c037d75e81a60e2a6a663f95425"),
        ModelFile(name: "lexicon-us-en.txt", url: kokoro + "lexicon-us-en.txt", bytes: 5_956_885,
                  sha256: "7daaab53a181be9885b853a8582bf1838186317e5dadacbcef9c426d6fa0da14"),
    ]

    /// The default writer on every Mac: the 4B, because explanations need to come back in seconds.
    /// The 9B stays in the list as an option for 16 GB Macs.
    static var suggestedWriter: WriterChoice { writers[0] }

    static func writer(id: String) -> WriterChoice? { writers.first { $0.id == id } }

    static func url(for file: ModelFile, voice: Bool) -> URL {
        voice ? root.appendingPathComponent(voiceFolder, isDirectory: true).appendingPathComponent(file.name)
              : root.appendingPathComponent(file.name)
    }

    /// A developer or CI override: PAPER_TREE_WRITER_MODEL=/path/model.gguf, PAPER_TREE_VOICE_DIR=/path/kokoro.
    static var writerOverride: String? { ProcessInfo.processInfo.environment["PAPER_TREE_WRITER_MODEL"].flatMap { $0.isEmpty ? nil : $0 } }
    static var voiceOverride: String? { ProcessInfo.processInfo.environment["PAPER_TREE_VOICE_DIR"].flatMap { $0.isEmpty ? nil : $0 } }

    /// Where the chosen writer lives, if it's fully downloaded and checked. Safe from any thread.
    static func writerPath() -> String? {
        if let o = writerOverride { return o }
        let id = UserDefaults.standard.string(forKey: ReaderDownload.writerKey) ?? suggestedWriter.id
        guard let w = writer(id: id) else { return nil }
        let u = url(for: w.file, voice: false)
        return isVerified(w.file, at: u) ? u.path : nil
    }

    /// The Kokoro folder, if every voice file is there and checked. Safe from any thread.
    static func voicePath() -> String? {
        if let o = voiceOverride { return o }
        let ok = voiceFiles.allSatisfy { isVerified($0, at: url(for: $0, voice: true)) }
        return ok ? root.appendingPathComponent(voiceFolder).path : nil
    }

    static func markerURL(_ u: URL) -> URL { u.appendingPathExtension("ok") }

    static func isVerified(_ f: ModelFile, at u: URL) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: u.path)[.size] as? NSNumber)?.int64Value ?? -1
        guard size == f.bytes else { return false }
        return (try? String(contentsOf: markerURL(u), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) == f.sha256
    }
}

/// Downloads the reader once, with progress, pause, retry and a disk space check.
@MainActor
final class ReaderDownload: NSObject, ObservableObject {
    static let shared = ReaderDownload()
    nonisolated static let writerKey = "localWriterModel"

    enum Phase: Equatable {
        case notStarted
        case noSpace(need: Int64, free: Int64)
        case downloading
        case paused
        case checking
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .notStarted
    @Published var writerId: String {
        didSet { UserDefaults.standard.set(writerId, forKey: Self.writerKey); refresh() }
    }
    @Published private(set) var doneBytes: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var bytesPerSecond: Double = 0
    @Published private(set) var currentFile = ""

    private var queue: [(ModelFile, Bool)] = []
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var handle: FileHandle?
    private var fileStart: Int64 = 0
    private var fileGot: Int64 = 0
    private var lastTick = Date()
    private var lastTickBytes: Int64 = 0
    private var expectingRange = false
    /// The files of earlier steps already counted in doneBytes.
    private var finishedBytes: Int64 = 0

    override init() {
        writerId = UserDefaults.standard.string(forKey: Self.writerKey) ?? LocalModels.suggestedWriter.id
        super.init()
        refresh()
    }

    var writer: WriterChoice { LocalModels.writer(id: writerId) ?? LocalModels.suggestedWriter }
    var isReady: Bool { phase == .ready }
    var fraction: Double { totalBytes > 0 ? min(1, Double(doneBytes) / Double(totalBytes)) : 0 }

    /// Everything this download needs, writer first.
    var files: [(ModelFile, Bool)] { [(writer.file, false)] + LocalModels.voiceFiles.map { ($0, true) } }
    var allBytes: Int64 { files.reduce(0) { $0 + $1.0.bytes } }

    var secondsLeft: Double? {
        guard phase == .downloading, bytesPerSecond > 50_000 else { return nil }
        return Double(totalBytes - doneBytes) / bytesPerSecond
    }

    /// Works out what's already on disk.
    func refresh() {
        guard phase != .downloading, phase != .checking else { return }
        if LocalModels.writerOverride != nil && LocalModels.voiceOverride != nil { phase = .ready; return }
        let missing = files.filter { !LocalModels.isVerified($0.0, at: LocalModels.url(for: $0.0, voice: $0.1)) }
        totalBytes = allBytes
        doneBytes = allBytes - missing.reduce(0) { $0 + $1.0.bytes } + missing.reduce(0) { $0 + partSize($1) }
        if missing.isEmpty { phase = .ready } else if case .failed = phase {} else {
            phase = doneBytes > 0 ? .paused : .notStarted
        }
    }

    private func partSize(_ f: (ModelFile, Bool)) -> Int64 {
        let u = LocalModels.url(for: f.0, voice: f.1).appendingPathExtension("part")
        return (try? FileManager.default.attributesOfItem(atPath: u.path)[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Bytes still to fetch, and what the disk has free.
    func spaceCheck() -> (need: Int64, free: Int64) {
        let missing = files.filter { !LocalModels.isVerified($0.0, at: LocalModels.url(for: $0.0, voice: $0.1)) }
        let need = missing.reduce(0) { $0 + $1.0.bytes - partSize($1) }
        try? FileManager.default.createDirectory(at: LocalModels.root, withIntermediateDirectories: true)
        let values = try? LocalModels.root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let free = values?.volumeAvailableCapacityForImportantUsage ?? Int64.max
        return (need, free)
    }

    func start() {
        guard phase != .downloading, phase != .checking else { return }
        let (need, free) = spaceCheck()
        // Leave a little room so the Mac isn't left gasping.
        if free < need + 1_000_000_000 {
            phase = .noSpace(need: need + 1_000_000_000, free: free)
            return
        }
        queue = files.filter { !LocalModels.isVerified($0.0, at: LocalModels.url(for: $0.0, voice: $0.1)) }
        totalBytes = allBytes
        finishedBytes = allBytes - queue.reduce(0) { $0 + $1.0.bytes }
        doneBytes = finishedBytes + queue.reduce(0) { $0 + partSize($1) }
        lastTick = Date(); lastTickBytes = doneBytes; bytesPerSecond = 0
        phase = .downloading
        next()
    }

    func pause() {
        guard phase == .downloading else { return }
        task?.cancel(); task = nil
        try? handle?.close(); handle = nil
        session?.invalidateAndCancel(); session = nil
        phase = .paused
        bytesPerSecond = 0
    }

    /// Removes the reader from this Mac.
    func remove() {
        pause()
        LocalLLM.shared.unload()
        KokoroVoice.shared.unload()
        for (f, v) in LocalModels.writers.map({ ($0.file, false) }) + LocalModels.voiceFiles.map({ ($0, true) }) {
            let u = LocalModels.url(for: f, voice: v)
            for x in [u, u.appendingPathExtension("part"), LocalModels.markerURL(u)] { try? FileManager.default.removeItem(at: x) }
        }
        phase = .notStarted
        refresh()
    }

    private func next() {
        guard phase == .downloading else { return }
        guard let (file, voice) = queue.first else {
            phase = .ready
            currentFile = ""
            bytesPerSecond = 0
            return
        }
        let dest = LocalModels.url(for: file, voice: voice)
        let part = dest.appendingPathExtension("part")
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Finished but not yet checked (the app quit while checking).
        if partSize((file, voice)) == file.bytes { verify(file, voice: voice, part: part, dest: dest); return }
        if !FileManager.default.fileExists(atPath: part.path) { FileManager.default.createFile(atPath: part.path, contents: nil) }
        guard let h = try? FileHandle(forWritingTo: part) else { phase = .failed("Couldn't write to the Models folder."); return }
        let have = (try? h.seekToEnd()).map { Int64($0) } ?? 0
        handle = h
        fileStart = have
        fileGot = 0
        currentFile = file.name
        var req = URLRequest(url: URL(string: file.url)!, timeoutInterval: 60)
        req.setValue("PaperTree-Mac", forHTTPHeaderField: "User-Agent")
        expectingRange = have > 0
        if have > 0 { req.setValue("bytes=\(have)-", forHTTPHeaderField: "Range") }
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 60 * 60 * 6
        cfg.waitsForConnectivity = true
        let s = URLSession(configuration: cfg, delegate: self, delegateQueue: OperationQueue.main)
        session = s
        let t = s.dataTask(with: req)
        task = t
        t.resume()
    }

    fileprivate func received(_ data: Data) {
        guard phase == .downloading, let handle else { return }
        do { try handle.write(contentsOf: data) } catch {
            fail("Couldn't save the download. Is the disk full?")
            return
        }
        fileGot += Int64(data.count)
        doneBytes += Int64(data.count)
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        if dt >= 1 {
            let rate = Double(doneBytes - lastTickBytes) / dt
            bytesPerSecond = bytesPerSecond == 0 ? rate : bytesPerSecond * 0.7 + rate * 0.3
            lastTick = now; lastTickBytes = doneBytes
        }
    }

    fileprivate func responded(_ status: Int) -> Bool {
        if status == 206 && expectingRange { return true }
        if status == 200 {
            if expectingRange {
                // The server sent the whole file: start this one over.
                try? handle?.truncate(atOffset: 0)
                try? handle?.seek(toOffset: 0)
                doneBytes -= fileStart
                fileStart = 0
            }
            return true
        }
        if status == 416, let (file, voice) = queue.first, partSize((file, voice)) >= file.bytes { return true }
        fail(status == 404 ? "The download address moved. Update Paper Tree and try again." : "The download server said \(status). Try again in a bit.")
        return false
    }

    fileprivate func finished(_ error: Error?) {
        guard phase == .downloading else { return }
        try? handle?.close(); handle = nil
        session?.finishTasksAndInvalidate(); session = nil
        task = nil
        if let error {
            if (error as? URLError)?.code == .cancelled { return }
            fail((error as? URLError)?.code == .notConnectedToInternet ? "You look offline. It'll carry on from here when you try again."
                 : "The connection dropped. It'll carry on from here when you try again.")
            return
        }
        guard let (file, voice) = queue.first else { return }
        let dest = LocalModels.url(for: file, voice: voice)
        verify(file, voice: voice, part: dest.appendingPathExtension("part"), dest: dest)
    }

    private func verify(_ file: ModelFile, voice: Bool, part: URL, dest: URL) {
        let size = partSize((file, voice))
        if size < file.bytes { fail("The download stopped early. It'll carry on from here when you try again."); return }
        phase = .checking
        let expected = file.sha256
        Task.detached(priority: .utility) {
            let hash = Self.sha256(of: part)
            await MainActor.run {
                if hash == expected || expected.isEmpty {
                    try? FileManager.default.removeItem(at: dest)
                    do {
                        try FileManager.default.moveItem(at: part, to: dest)
                        try (hash ?? "").write(to: LocalModels.markerURL(dest), atomically: true, encoding: .utf8)
                    } catch {
                        self.fail("Couldn't put the download in place.")
                        return
                    }
                    self.finishedBytes += file.bytes
                    self.queue.removeFirst()
                    self.phase = .downloading
                    self.next()
                } else {
                    try? FileManager.default.removeItem(at: part)
                    self.doneBytes = max(0, self.doneBytes - file.bytes)
                    self.fail("\(file.name) came through damaged, so I threw it away. Try again to fetch it fresh.")
                }
            }
        }
    }

    private func fail(_ message: String) {
        task?.cancel(); task = nil
        try? handle?.close(); handle = nil
        session?.invalidateAndCancel(); session = nil
        bytesPerSecond = 0
        phase = .failed(message)
    }

    nonisolated static func sha256(of url: URL) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256()
        while true {
            let chunk = autoreleasepool { (try? h.read(upToCount: 8 << 20)) ?? Data() }
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: For design snapshots

    func preset(_ phase: Phase, done: Int64, total: Int64, rate: Double = 0, file: String = "") {
        self.phase = phase
        doneBytes = done
        totalBytes = total
        bytesPerSecond = rate
        currentFile = file
    }
}

extension ReaderDownload: URLSessionDataDelegate {
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                                completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        MainActor.assumeIsolated {
            completionHandler(self.responded(status) ? .allow : .cancel)
        }
    }

    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        MainActor.assumeIsolated { self.received(data) }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        MainActor.assumeIsolated { self.finished(error) }
    }
}

extension Int64 {
    /// "5.6 GB", "320 MB"
    var sizeText: String {
        let gb = Double(self) / 1_000_000_000
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return "\(Int((Double(self) / 1_000_000).rounded())) MB"
    }
}
