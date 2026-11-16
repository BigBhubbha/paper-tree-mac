// The podcast voices, made on this Mac: Kokoro-82M v1.0 (Apache 2.0) through sherpa-onnx's C API.
// Juniper is "af_heart" and Rowan is "am_michael", two of Kokoro's preset voices.
//
// Kokoro reads phonemes, not letters. Words come from Kokoro's US English lexicon (the same
// misaki phoneme set the model was trained on). A word the lexicon doesn't know is sounded out by
// macOS's own speech engine and its phonemes are mapped onto Kokoro's. Numbers are spelled out
// first. Nothing here uses espeak-ng.
import AppKit
import CSherpaOnnx
import Foundation

final class KokoroVoice: @unchecked Sendable {
    static let shared = KokoroVoice()

    static let speakerIds: [String: Int32] = ["Juniper": 3, "Rowan": 16] // af_heart, am_michael
    static let modelName = "kokoro-82m-v1.0"

    private let queue = DispatchQueue(label: "com.papertree.kokoro", qos: .userInitiated)
    private var tts: OpaquePointer?
    private var loadedDir = ""
    private var lexicon: [String: String] = [:]
    private var tokens: Set<Unicode.Scalar> = []
    private var lastUse = Date()
    private var idleTimer: DispatchSourceTimer?

    func unload() { queue.async { self.free() } }

    private func free() {
        if let tts { SherpaOnnxDestroyOfflineTts(tts) }
        tts = nil; loadedDir = ""; lexicon = [:]
        idleTimer?.cancel(); idleTimer = nil
    }

    private func load(_ dir: String) throws {
        if tts != nil, loadedDir == dir { return }
        free()
        let d = URL(fileURLWithPath: dir)
        guard let lex = try? String(contentsOf: d.appendingPathComponent("lexicon-us-en.txt"), encoding: .utf8),
              let tok = try? String(contentsOf: d.appendingPathComponent("tokens.txt"), encoding: .utf8) else {
            throw LocalLLMError(description: "The voice files are missing.")
        }
        var map: [String: String] = [:]
        map.reserveCapacity(180_000)
        lex.enumerateLines { line, _ in
            guard let sp = line.firstIndex(of: " ") else { return }
            let word = String(line[..<sp])
            if map[word] == nil { map[word] = line[line.index(after: sp)...].replacingOccurrences(of: " ", with: "") }
        }
        lexicon = map
        var set = Set<Unicode.Scalar>()
        tok.enumerateLines { line, _ in
            // "<symbol> <id>"; the symbol can be a space.
            if let s = line.unicodeScalars.first { set.insert(s) }
        }
        tokens = set

        var c = SherpaOnnxOfflineTtsConfig()
        let paths: [String] = [d.appendingPathComponent("model.onnx").path, d.appendingPathComponent("voices.bin").path,
                               d.appendingPathComponent("tokens.txt").path, d.appendingPathComponent("lexicon-us-en.txt").path, "cpu", "en-us"]
        let strings: [UnsafeMutablePointer<CChar>] = paths.compactMap { strdup($0) }
        defer { for s in strings { Darwin.free(s) } }
        guard strings.count == paths.count else { throw LocalLLMError(description: "Out of memory opening the voices.") }
        c.model.kokoro.model = UnsafePointer(strings[0])
        c.model.kokoro.voices = UnsafePointer(strings[1])
        c.model.kokoro.tokens = UnsafePointer(strings[2])
        c.model.kokoro.lexicon = UnsafePointer(strings[3])
        c.model.kokoro.lang = UnsafePointer(strings[5])
        c.model.kokoro.length_scale = 1
        c.model.provider = UnsafePointer(strings[4])
        c.model.num_threads = Int32(max(2, min(6, ProcessInfo.processInfo.activeProcessorCount - 2)))
        c.model.debug = 0
        c.max_num_sentences = 1
        c.silence_scale = 0.2
        guard let t = SherpaOnnxCreateOfflineTts(&c) else { throw LocalLLMError(description: "The voices couldn't be opened. Remove the reader and download it again.") }
        tts = t
        loadedDir = dir
    }

    private func scheduleIdle() {
        lastUse = Date()
        idleTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 240)
        t.setEventHandler { [weak self] in
            guard let self, Date().timeIntervalSince(self.lastUse) >= 239 else { return }
            self.free()
        }
        t.resume()
        idleTimer = t
    }

    /// Reads one part of a script aloud: the samples, and where each line starts and ends.
    func voice(_ lines: [PodcastClient.ScriptLine], cancel: CancelFlag? = nil) async throws -> PodcastClient.Part {
        guard let dir = LocalModels.voicePath() else { throw LocalWriter.ReaderMissing() }
        let flag = cancel ?? CancelFlag()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<PodcastClient.Part, Error>) in
                queue.async {
                    do { cont.resume(returning: try self.run(dir: dir, lines, cancel: flag)) } catch { cont.resume(throwing: error) }
                }
            }
        } onCancel: { flag.set() }
    }

    private func run(dir: String, _ lines: [PodcastClient.ScriptLine], cancel: CancelFlag) throws -> PodcastClient.Part {
        try load(dir)
        defer { scheduleIdle() }
        guard let tts else { throw LocalLLMError(description: "The voices aren't loaded.") }
        let rate = Double(SherpaOnnxOfflineTtsSampleRate(tts))
        let gap = [Int16](repeating: 0, count: Int(rate * 0.3))
        var all: [Int16] = []
        var timings: [[Double]] = []
        for (k, line) in lines.enumerated() {
            if cancel.isSet { throw CancellationError() }
            if k > 0 { all += gap }
            let start = Double(all.count) / rate
            let sentences = phonemeSentences(line.text)
            var samples: [Int16] = []
            for s in sentences where !s.isEmpty {
                var points = s.unicodeScalars.filter { tokens.contains($0) }.map { Int32($0.value) }
                guard !points.isEmpty else { continue }
                var lens = [Int32(points.count)]
                var g = SherpaOnnxGenerationConfig()
                g.sid = Self.speakerIds[line.speaker] ?? 3
                g.speed = line.speaker == "Rowan" ? 0.98 : 1.02
                g.silence_scale = 0.2
                let audio: UnsafePointer<SherpaOnnxGeneratedAudio>? = points.withUnsafeMutableBufferPointer { pb in
                    lens.withUnsafeMutableBufferPointer { lb in
                        g.phoneme_codepoints = UnsafePointer(pb.baseAddress)
                        g.phoneme_codepoints_lens = UnsafePointer(lb.baseAddress)
                        g.phoneme_codepoints_num_sentences = 1
                        return SherpaOnnxOfflineTtsGenerateWithConfig(tts, "", &g, nil, nil)
                    }
                }
                guard let audio else { continue }
                let n = Int(audio.pointee.n)
                if let p = audio.pointee.samples, n > 0 {
                    samples.reserveCapacity(samples.count + n)
                    for i in 0..<n { samples.append(Int16(max(-1, min(1, p[i])) * 32_000)) }
                    samples += [Int16](repeating: 0, count: Int(rate * 0.12))
                }
                SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio)
            }
            all += trimSilence(samples)
            timings.append([start, Double(all.count) / rate])
        }
        return PodcastClient.Part(samples: all, rate: rate, timings: timings, model: Self.modelName)
    }

    /// Drops the quiet tail Kokoro leaves, so turns don't drag.
    private func trimSilence(_ s: [Int16]) -> [Int16] {
        var end = s.count
        while end > 0 && abs(Int(s[end - 1])) < 200 { end -= 1 }
        return Array(s[0..<min(s.count, end + 2400)])
    }

    // MARK: Words to phonemes

    /// One string of Kokoro phonemes per sentence.
    func phonemeSentences(_ text: String) -> [String] {
        let spoken = Self.spellNumbers(text)
        var sentences: [String] = []
        var words: [String] = []
        let pattern = #"[A-Za-z]+(?:['\u2019][A-Za-z]+)*|[.,!?;:]"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = spoken as NSString
        for m in re.matches(in: spoken, range: NSRange(location: 0, length: ns.length)) {
            let tok = ns.substring(with: m.range)
            if tok.count == 1, ".,!?;:".contains(tok) {
                if !words.isEmpty { words[words.count - 1] += tok }
                if ".!?".contains(tok), !words.isEmpty, words.count >= 3 {
                    sentences.append(words.joined(separator: " ")); words = []
                }
                continue
            }
            let p = phonemes(for: tok)
            if !p.isEmpty { words.append(p) }
            // Very long sentences get split at a comma-free point so Kokoro stays in range.
            if words.count >= 60 { sentences.append(words.joined(separator: " ") + ","); words = [] }
        }
        if !words.isEmpty { sentences.append(words.joined(separator: " ")) }
        return sentences
    }

    func phonemes(for raw: String) -> String {
        let w = raw.replacingOccurrences(of: "\u{2019}", with: "'").lowercased()
        if w == "a" { return "ə" }
        if let p = lexicon[w] { return p }
        if w.hasSuffix("'s"), let p = lexicon[String(w.dropLast(2))] { return p + (p.last.map { "ptkfθ".contains($0) } == true ? "s" : "z") }
        if w.hasSuffix("s"), let p = lexicon[String(w.dropLast())] { return p + "z" }
        // Short all-caps words are read letter by letter (DNA, RNA).
        if raw.count <= 5, raw == raw.uppercased(), raw.count > 1 { return spell(w) }
        let apple = AppleSounds.phonemes(raw)
        if !apple.isEmpty { return apple }
        return spell(w)
    }

    private func spell(_ w: String) -> String {
        w.compactMap { ch -> String? in ch.isLetter ? lexicon[String(ch)] : nil }.joined(separator: " ")
    }

    /// 2019 → "twenty nineteen", 3.5 → "three point five", 40% → "forty percent".
    static func spellNumbers(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "%", with: " percent").replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "/", with: " ")
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .spellOut
        guard let re = try? NSRegularExpression(pattern: #"\d+(?:,\d{3})*(?:\.\d+)?"#) else { return t }
        let ns = t as NSString
        var out = ""
        var last = 0
        for m in re.matches(in: t, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let s = ns.substring(with: m.range).replacingOccurrences(of: ",", with: "")
            var words = ""
            if let v = Int(s), s.count == 4, (1100...2099).contains(v), v % 1000 >= 10 || v < 2000 {
                let hi = v / 100, lo = v % 100
                words = (f.string(from: NSNumber(value: hi)) ?? "") + " " + (lo == 0 ? "hundred" : lo < 10 ? "oh " + (f.string(from: NSNumber(value: lo)) ?? "") : (f.string(from: NSNumber(value: lo)) ?? ""))
            } else if s.contains(".") {
                let parts = s.split(separator: ".")
                words = (f.string(from: NSNumber(value: Int(parts[0]) ?? 0)) ?? "") + " point " + parts[1].compactMap { Int(String($0)) }.map { f.string(from: NSNumber(value: $0)) ?? "" }.joined(separator: " ")
            } else if let v = Int(s) {
                words = f.string(from: NSNumber(value: v)) ?? s
            }
            out += " " + words.replacingOccurrences(of: "-", with: " ") + " "
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        t = out
        return t
    }
}

/// macOS's speech engine knows how to sound out any English word. Its phonemes (Apple's
/// MacinTalk set, like "_hEHl1OW") are mapped onto Kokoro's.
enum AppleSounds {
    private static let lock = NSLock()
    private static var synth: NSSpeechSynthesizer?
    private static var cache: [String: String] = [:]

    static let vowels: [String: String] = [
        "AE": "æ", "EY": "A", "AO": "ɔ", "AX": "ə", "IY": "i", "EH": "ɛ", "IH": "ɪ", "AY": "I", "IX": "ɪ",
        "AA": "ɑ", "UW": "u", "UH": "ʊ", "UX": "ʌ", "OW": "O", "AW": "W", "OY": "Y",
    ]
    static let consonants: [Character: String] = [
        "b": "b", "C": "ʧ", "d": "d", "D": "ð", "f": "f", "g": "ɡ", "h": "h", "J": "ʤ", "k": "k", "l": "l",
        "m": "m", "n": "n", "N": "ŋ", "p": "p", "r": "ɹ", "s": "s", "S": "ʃ", "t": "t", "T": "θ", "v": "v",
        "w": "w", "y": "j", "z": "z", "Z": "ʒ",
    ]

    static func phonemes(_ word: String) -> String {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[word] { return c }
        if synth == nil { synth = NSSpeechSynthesizer() }
        let apple = synth?.phonemes(from: word) ?? ""
        let out = map(apple)
        cache[word] = out
        return out
    }

    /// "_hEHl1OW" → "hɛlˈO"
    static func map(_ apple: String) -> String {
        var out = ""
        let chars = Array(apple)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "1" { out += "ˈ"; i += 1; continue }
            if c == "2" { out += "ˌ"; i += 1; continue }
            if i + 1 < chars.count, let v = vowels[String(chars[i...i + 1])] { out += v; i += 2; continue }
            if let k = consonants[c] { out += k }
            i += 1
        }
        return out
    }
}
