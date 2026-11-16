// The writer that runs on this Mac: a 4-bit Qwen 3.5 model in llama.cpp (Metal on Apple Silicon).
// One model and one context stay loaded while they're being used and are let go after a few idle
// minutes, so the memory comes back. Requests run one at a time on a private queue.
//
// Output can be held to a GBNF grammar (see Resources/LocalAI/*.gbnf). Each token is sampled
// normally first and only checked against the grammar; if it doesn't fit, the token is sampled again
// with the grammar applied to the whole vocabulary. That's how llama.cpp's own tools do it, and it
// keeps the grammar cheap.
import Foundation
import llama

struct LocalLLMError: Error, CustomStringConvertible {
    var description: String
}

final class LocalLLM: @unchecked Sendable {
    static let shared = LocalLLM()

    struct Request: Sendable {
        var prompt: String
        var grammar: String?
        var maxTokens: Int
        var temperature: Float = 0.6
        var topP: Float = 0.9
        var topK: Int32 = 40
        var minP: Float = 0.05
        var repeatPenalty: Float = 1.05
        /// DRY ("don't repeat yourself"): penalizes copying a run of earlier words. 0 is off.
        var dry: Float = 0
        var seed: UInt32 = UInt32.random(in: 1...UInt32.max - 1)
    }

    struct Stats: Sendable {
        var promptTokens = 0
        var generatedTokens = 0
        var loadSeconds = 0.0
        var promptSeconds = 0.0
        var generateSeconds = 0.0
        var usedGPU = false
        var model = ""
        var tokensPerSecond: Double { generateSeconds > 0 ? Double(generatedTokens) / generateSeconds : 0 }
    }

    private let queue = DispatchQueue(label: "com.papertree.local-llm", qos: .userInitiated)
    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private var loadedPath = ""
    private var usedGPU = false
    private var lastUse = Date()
    private var idleTimer: DispatchSourceTimer?
    private static let contextSize: UInt32 = 12_288
    /// Let the model go after this long unused (it holds a few GB).
    static var idleSeconds: Double = 300

    /// Apple Silicon's performance cores (the efficiency cores slow generation down), if known.
    static let performanceCores: Int? = {
        var n: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("hw.perflevel0.physicalcpu", &n, &size, nil, 0) == 0, n > 0 else { return nil }
        return Int(n)
    }()

    private init() {
        llama_backend_init()
        // Quiet: llama.cpp logs a lot to stderr. Errors still show.
        llama_log_set({ level, text, _ in
            guard level == GGML_LOG_LEVEL_ERROR, let text else { return }
            FileHandle.standardError.write(String(cString: text).data(using: .utf8) ?? Data())
        }, nil)
    }

    var isLoaded: Bool { queue.sync { model != nil } }

    /// Writes a reply. `onText` gets the whole reply so far, every few tokens, on a background queue.
    func generate(modelPath: String, _ req: Request, onText: (@Sendable (String) -> Void)? = nil) async throws -> (String, Stats) {
        let cancel = CancelFlag()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, Stats), Error>) in
                queue.async {
                    do { cont.resume(returning: try self.run(modelPath: modelPath, req, cancel: cancel, onText: onText)) } catch { cont.resume(throwing: error) }
                }
            }
        } onCancel: { cancel.set() }
    }

    /// Loads the model in the background if it isn't already, so the first answer starts sooner.
    func prewarm(modelPath: String) {
        queue.async {
            guard self.model == nil || self.loadedPath != modelPath else { self.lastUse = Date(); return }
            var s = Stats()
            if (try? self.load(modelPath, stats: &s)) != nil { self.scheduleIdle() }
        }
    }

    /// Frees the model now (for memory pressure, or when the reader is removed).
    func unload() { queue.async { self.free() } }

    // MARK: On the queue

    private func free() {
        if let c = ctx { llama_free(c) }
        if let m = model { llama_model_free(m) }
        ctx = nil; model = nil; loadedPath = ""
        idleTimer?.cancel(); idleTimer = nil
    }

    private func load(_ path: String, stats: inout Stats) throws {
        if model != nil, loadedPath == path, ctx != nil { return }
        free()
        guard FileManager.default.fileExists(atPath: path) else { throw LocalLLMError(description: "The reader's model file is missing.") }
        let t0 = Date()
        let forceCPU = ProcessInfo.processInfo.environment["PAPER_TREE_LLM_CPU"] == "1"
        func open(gpu: Bool) -> (OpaquePointer, OpaquePointer)? {
            var mp = llama_model_default_params()
            mp.n_gpu_layers = gpu ? -1 : 0
            guard let m = llama_model_load_from_file(path, mp) else { return nil }
            var cp = llama_context_default_params()
            cp.n_ctx = Self.contextSize
            cp.n_batch = 512
            cp.n_ubatch = 512
            let cores = max(1, ProcessInfo.processInfo.activeProcessorCount)
            cp.n_threads = Int32(min(8, Self.performanceCores ?? max(1, cores <= 4 ? cores : cores - 2)))
            cp.n_threads_batch = Int32(max(1, min(8, cores)))
            cp.offload_kqv = gpu
            // On the CPU path keep everything on the CPU: no big batches handed to the GPU either
            // (a virtual Mac's GPU can be far slower than its cores).
            cp.op_offload = gpu
            guard let c = llama_init_from_model(m, cp) else { llama_model_free(m); return nil }
            return (m, c)
        }
        // Metal first; a Mac (or a virtual one) without a usable GPU falls back to the CPU.
        let gpuOK = !forceCPU && llama_supports_gpu_offload()
        if gpuOK, let (m, c) = open(gpu: true) {
            model = m; ctx = c; usedGPU = true
        } else if let (m, c) = open(gpu: false) {
            model = m; ctx = c; usedGPU = false
        } else {
            throw LocalLLMError(description: "The reader's model couldn't be opened. It may be damaged; remove it and download it again.")
        }
        loadedPath = path
        stats.loadSeconds = Date().timeIntervalSince(t0)
    }

    private func scheduleIdle() {
        lastUse = Date()
        idleTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + Self.idleSeconds)
        t.setEventHandler { [weak self] in
            guard let self, Date().timeIntervalSince(self.lastUse) >= Self.idleSeconds - 1 else { return }
            self.free()
        }
        t.resume()
        idleTimer = t
    }

    private func tokenize(_ vocab: OpaquePointer, _ text: String) -> [llama_token] {
        let utf8 = Array(text.utf8CString)
        let len = Int32(utf8.count - 1)
        var tokens = [llama_token](repeating: 0, count: Int(len) + 16)
        var n = utf8.withUnsafeBufferPointer { p in llama_tokenize(vocab, p.baseAddress, len, &tokens, Int32(tokens.count), false, true) }
        if n < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-n))
            n = utf8.withUnsafeBufferPointer { p in llama_tokenize(vocab, p.baseAddress, len, &tokens, Int32(tokens.count), false, true) }
        }
        return Array(tokens.prefix(Int(max(0, n))))
    }

    private func piece(_ vocab: OpaquePointer, _ token: llama_token) -> [UInt8] {
        var buf = [CChar](repeating: 0, count: 64)
        var n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, false)
        if n < 0 {
            buf = [CChar](repeating: 0, count: Int(-n))
            n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, false)
        }
        return buf.prefix(Int(max(0, n))).map { UInt8(bitPattern: $0) }
    }

    private func run(modelPath: String, _ req: Request, cancel: CancelFlag, onText: (@Sendable (String) -> Void)?) throws -> (String, Stats) {
        var stats = Stats()
        try load(modelPath, stats: &stats)
        defer { scheduleIdle() }
        guard let model, let ctx, let vocab = llama_model_get_vocab(model) else { throw LocalLLMError(description: "The reader isn't loaded.") }
        stats.usedGPU = usedGPU
        stats.model = URL(fileURLWithPath: modelPath).lastPathComponent
        llama_memory_clear(llama_get_memory(ctx), true)

        var tokens = tokenize(vocab, req.prompt)
        let room = Int(llama_n_ctx(ctx)) - req.maxTokens - 8
        guard !tokens.isEmpty else { throw LocalLLMError(description: "Nothing to read.") }
        if tokens.count > room { throw LocalLLMError(description: "That's more text than the reader can take in at once.") }
        stats.promptTokens = tokens.count

        // Read the prompt in batches.
        let t1 = Date()
        var at = 0
        while at < tokens.count {
            if cancel.isSet { throw CancellationError() }
            let n = min(512, tokens.count - at)
            let rc = tokens.withUnsafeMutableBufferPointer { p in llama_decode(ctx, llama_batch_get_one(p.baseAddress! + at, Int32(n))) }
            if rc != 0 { throw LocalLLMError(description: "The reader stumbled reading the prompt (\(rc)).") }
            at += n
        }
        stats.promptSeconds = Date().timeIntervalSince(t1)
        let verbose = ProcessInfo.processInfo.environment["PAPER_TREE_LLM_LOG"] == "1"
        func say(_ s: String) { if verbose { FileHandle.standardError.write(Data(("[llm] " + s + "\n").utf8)) } }
        say("prompt \(tokens.count) tokens in \(String(format: "%.1f", stats.promptSeconds)) s, GPU \(usedGPU)")

        // Samplers: the usual chain, and the grammar on the side.
        let nVocab = llama_vocab_n_tokens(vocab)
        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())!
        defer { llama_sampler_free(chain) }
        llama_sampler_chain_add(chain, llama_sampler_init_penalties(nVocab, 64, req.repeatPenalty, 0, 0))
        if req.dry > 0 {
            // Breakers end a match, so the JSON around each line isn't counted as repeating.
            let breakerText: [String] = ["\n", ":", "\"", "*"]
            let breakers: [UnsafeMutablePointer<CChar>] = breakerText.compactMap { (t: String) -> UnsafeMutablePointer<CChar>? in strdup(t) }
            var ptrs: [UnsafePointer<CChar>?] = breakers.map { (m: UnsafeMutablePointer<CChar>) -> UnsafePointer<CChar>? in UnsafePointer(m) }
            let dry = ptrs.withUnsafeMutableBufferPointer { b in
                llama_sampler_init_dry(vocab, req.dry, 1.75, 2, -1, b.baseAddress, b.count)
            }
            breakers.forEach { Darwin.free($0) }
            if let dry { llama_sampler_chain_add(chain, dry) }
        }
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(req.topK))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(req.topP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_min_p(req.minP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(req.temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(req.seed))
        var grammar: UnsafeMutablePointer<llama_sampler>? = nil
        if let g = req.grammar, !g.isEmpty {
            grammar = llama_sampler_init_grammar(vocab, g, "root")
            if grammar == nil { throw LocalLLMError(description: "The reply format file is broken.") }
        }
        defer { if let grammar { llama_sampler_free(grammar) } }

        var cands = [llama_token_data](repeating: llama_token_data(id: 0, logit: 0, p: 0), count: Int(nVocab))
        func fill(_ logits: UnsafeMutablePointer<Float>) {
            for i in 0..<Int(nVocab) { cands[i] = llama_token_data(id: llama_token(i), logit: logits[i], p: 0) }
        }
        func pick(withGrammar: Bool) -> llama_token {
            guard let logits = llama_get_logits_ith(ctx, -1) else { return llama_vocab_eos(vocab) }
            fill(logits)
            return cands.withUnsafeMutableBufferPointer { buf -> llama_token in
                var arr = llama_token_data_array(data: buf.baseAddress, size: buf.count, selected: -1, sorted: false)
                if withGrammar, let grammar { llama_sampler_apply(grammar, &arr) }
                llama_sampler_apply(chain, &arr)
                guard arr.selected >= 0, arr.selected < arr.size else { return llama_vocab_eos(vocab) }
                return arr.data[Int(arr.selected)].id
            }
        }
        func fits(_ token: llama_token) -> Bool {
            guard let grammar else { return true }
            var one = llama_token_data(id: token, logit: 1, p: 0)
            return withUnsafeMutablePointer(to: &one) { p -> Bool in
                var arr = llama_token_data_array(data: p, size: 1, selected: -1, sorted: false)
                llama_sampler_apply(grammar, &arr)
                return arr.data[0].logit.isFinite
            }
        }

        let t2 = Date()
        var bytes: [UInt8] = []
        var lastSent = 0
        var produced = 0
        while produced < req.maxTokens {
            if cancel.isSet { throw CancellationError() }
            var token = pick(withGrammar: false)
            if !fits(token) { token = pick(withGrammar: true) }
            llama_sampler_accept(chain, token)
            if llama_vocab_is_eog(vocab, token) { break }
            if let grammar { llama_sampler_accept(grammar, token) }
            bytes += piece(vocab, token)
            produced += 1
            if verbose, produced % 100 == 0 { say("\(produced) tokens, \(String(format: "%.1f", Date().timeIntervalSince(t2))) s") }
            if let onText, produced - lastSent >= 3 {
                lastSent = produced
                onText(Self.validUTF8(bytes))
            }
            var one = token
            let rc = llama_decode(ctx, llama_batch_get_one(&one, 1))
            if rc != 0 { throw LocalLLMError(description: "The reader stumbled while writing (\(rc)).") }
        }
        stats.generatedTokens = produced
        stats.generateSeconds = Date().timeIntervalSince(t2)
        let text = Self.validUTF8(bytes)
        onText?(text)
        return (text, stats)
    }

    /// The longest prefix that is whole UTF-8 (a character can be split across tokens).
    static func validUTF8(_ b: [UInt8]) -> String {
        var end = b.count
        while end > 0 {
            if let s = String(bytes: b[0..<end], encoding: .utf8) { return s }
            end -= 1
            if b.count - end > 4 { break }
        }
        return String(decoding: b, as: UTF8.self)
    }
}

/// A thread-safe "stop" flag shared with the generation loop.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
