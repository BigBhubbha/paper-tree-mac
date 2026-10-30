// The trees: what they hold, where they are saved, and how they talk to the explainer server.
// Saved as JSON in ~/Library/Application Support/Paper Tree/trees.json. Front pages are cached as PNGs next to it.
import AppKit
import Foundation
import PDFKit

// MARK: Data

struct Paper: Codable, Identifiable, Hashable, Sendable {
    var id: String              // Semantic Scholar paperId, OpenAlex "W..." id, "doi:...", or "local-<uuid>" when not found
    var title: String
    var authors: [String] = []
    var year: Int?
    var venue: String = ""
    var abstract: String = ""
    var pdf: String = ""        // open-access PDF, if there is one
    var url: String = ""        // Semantic Scholar page
    var fields: [String] = []
    /// The paper this one grew from (its branch sprouts from that paper's branch). Nil means the trunk.
    var parentId: String?
    var addedAt = Date()
    // Optional, so trees saved before these existed still load.
    var doi: String?
    var arxiv: String?
    /// More open-access PDF links to try for the front page, best first.
    var pdfs: [String]?
    var cites: Int?
    /// Where the record came from: Semantic Scholar, OpenAlex, or Crossref.
    var source: String?

    /// Every PDF link we know, best first.
    var pdfCandidates: [String] {
        var out: [String] = []
        for u in [pdf] + (pdfs ?? []) where !u.isEmpty && !out.contains(u) { out.append(u) }
        return out
    }

    var isLocal: Bool { id.hasPrefix("local-") }

    /// One line of who, where, when: "Vaswani et al., NeurIPS, 2017".
    var byline: String {
        [shortAuthors, venue, year.map(String.init) ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var shortAuthors: String {
        guard let first = authors.first else { return "" }
        let last = first.split(separator: " ").last.map(String.init) ?? first
        return authors.count > 1 ? "\(last) et al." : last
    }

    var openURL: URL? { URL(string: pdf.isEmpty ? url : pdf) ?? URL(string: url) }
}

/// A suggested paper, drawn as a pencil branch until you keep or prune it.
struct Suggestion: Codable, Identifiable, Hashable, Sendable {
    var paper: Paper
    var fromPaperId: String
    var id: String { paper.id }
}

enum Species: String, Codable, CaseIterable, Sendable {
    case oak, willow, conifer, flytrap, alien, coral

    var plainName: String {
        switch self {
        case .oak: return "oak"
        case .willow: return "willow"
        case .conifer: return "conifer"
        case .flytrap: return "venus flytrap"
        case .alien: return "alien tree"
        case .coral: return "coral tree"
        }
    }

    /// Used until the AI has had a look, and whenever it can't be reached.
    static func guess(fields: [String], seed: UInt64) -> Species {
        let f = Set(fields.map { $0.lowercased() })
        if f.contains("computer science") { return .alien }
        if f.contains("medicine") { return .flytrap }
        if f.contains("mathematics") || f.contains("physics") || f.contains("engineering") { return .conifer }
        if f.contains("psychology") || f.contains("sociology") || f.contains("education") || f.contains("art") || f.contains("philosophy") { return .willow }
        if f.contains("chemistry") || f.contains("materials science") || f.contains("environmental science") || f.contains("geology") { return .coral }
        if f.contains("biology") { return .oak }
        return Species.allCases[Int(seed % UInt64(Species.allCases.count))]
    }
}

struct TreeLook: Codable, Hashable, Sendable {
    var species: Species
    var commonName = ""
    var latinName = ""
    var note = ""
    var leafTone = "sage"
    var vigor = 0.5
    var twist = 0.5
    var droop = 0.5
    /// True once Gemini picked it (false while it is a local guess).
    var fromAI = false
}

struct PaperTreeData: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var number: Int
    var name: String
    var createdAt = Date()
    var seed: UInt64
    var look: TreeLook
    var papers: [Paper] = []
    var suggestions: [Suggestion] = []
    var dismissed: [String] = []
    /// Paper counts at which we last asked the AI about the species.
    var lookCheckedAt: Int = 0

    var displayName: String { name.isEmpty ? "Tree No. \(number)" : name }
    var allFields: [String] {
        var counts: [String: Int] = [:]
        for p in papers { for f in p.fields { counts[f, default: 0] += 1 } }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }
}

// MARK: Store

@MainActor
final class TreeStore: ObservableObject {
    static let shared = TreeStore(persist: true)

    @Published var trees: [PaperTreeData] = []
    /// Front pages rendered from open-access PDFs, keyed by paper id.
    @Published var thumbnails: [String: NSImage] = [:]
    /// Set by the "New tree" page: the next paper you add starts a fresh tree with this name.
    @Published var plantingNewTree: String? = nil
    @Published var lastError: String? = nil

    private let persist: Bool
    private var fetchingThumbs = Set<String>()

    init(persist: Bool) {
        self.persist = persist
        if persist { load() }
    }

    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Paper Tree", isDirectory: true)
    }
    private static var file: URL { folder.appendingPathComponent("trees.json") }
    private static var thumbFolder: URL { folder.appendingPathComponent("front-pages", isDirectory: true) }

    private func load() {
        guard let data = try? Data(contentsOf: TreeStore.file) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let saved = try? decoder.decode([PaperTreeData].self, from: data) {
            trees = saved
            for t in trees { for p in t.papers { loadThumbnail(for: p) } }
        }
    }

    private func save() {
        guard persist else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(at: TreeStore.folder, withIntermediateDirectories: true)
            try encoder.encode(trees).write(to: TreeStore.file, options: .atomic)
        } catch {
            lastError = "Couldn't save your trees: \(error.localizedDescription)"
        }
    }

    // MARK: Changes

    @discardableResult
    func newTree(name: String = "", first: Paper?) -> PaperTreeData {
        let number = (trees.map(\.number).max() ?? 0) + 1
        let seed = UInt64.random(in: 1...UInt64.max)
        let fields = first?.fields ?? []
        var tree = PaperTreeData(number: number, name: name.trimmingCharacters(in: .whitespaces), seed: seed,
                                 look: TreeLook(species: Species.guess(fields: fields, seed: seed)))
        if var p = first { p.parentId = nil; tree.papers = [p] }
        trees.append(tree)
        save()
        if let p = first { afterAdding(p, to: tree.id) }
        return tree
    }

    /// Adds a paper. It branches from the paper in this tree it is most related to (a suggestion it
    /// came from, or the newest paper sharing a field), else from the trunk.
    func add(_ paper: Paper, to treeId: UUID, from parent: String? = nil) {
        guard let i = trees.firstIndex(where: { $0.id == treeId }) else { return }
        if trees[i].papers.contains(where: { $0.id == paper.id }) { return }
        var p = paper
        p.addedAt = Date()
        p.parentId = parent ?? bestParent(for: paper, in: trees[i])
        trees[i].papers.append(p)
        trees[i].suggestions.removeAll { $0.paper.id == paper.id }
        save()
        afterAdding(p, to: treeId)
    }

    private func bestParent(for paper: Paper, in tree: PaperTreeData) -> String? {
        let mine = Set(paper.fields)
        // Only half the papers branch off another one, so the trunk keeps growing limbs too.
        let roots = tree.papers.filter { $0.parentId == nil }.count
        guard roots >= 2 else { return nil }
        let match = tree.papers.reversed().first { !$0.fields.isEmpty && !mine.isDisjoint(with: $0.fields) && depth(of: $0.id, in: tree) < 2 }
        if let match, paper.id.utf8.reduce(0, { $0 &+ Int($1) }) % 2 == 0 { return match.id }
        return nil
    }

    func depth(of id: String, in tree: PaperTreeData) -> Int {
        var d = 0
        var cur = tree.papers.first { $0.id == id }
        while let parent = cur?.parentId, d < 8 { d += 1; cur = tree.papers.first { $0.id == parent } }
        return d
    }

    func keep(_ suggestion: Suggestion, in treeId: UUID) {
        add(suggestion.paper, to: treeId, from: suggestion.fromPaperId)
    }

    func prune(_ suggestion: Suggestion, in treeId: UUID) {
        guard let i = trees.firstIndex(where: { $0.id == treeId }) else { return }
        trees[i].suggestions.removeAll { $0.id == suggestion.id }
        trees[i].dismissed.append(suggestion.id)
        save()
    }

    func remove(paperId: String, from treeId: UUID) {
        guard let i = trees.firstIndex(where: { $0.id == treeId }) else { return }
        let parent = trees[i].papers.first { $0.id == paperId }?.parentId
        trees[i].papers.removeAll { $0.id == paperId }
        for j in trees[i].papers.indices where trees[i].papers[j].parentId == paperId { trees[i].papers[j].parentId = parent }
        trees[i].suggestions.removeAll { $0.fromPaperId == paperId }
        save()
    }

    /// Swaps a paper for a different match (the lookup picked the wrong one). It keeps its place on the
    /// tree: same parent, same children, same pencil branches, same date.
    func replace(paperId: String, in treeId: UUID, with new: Paper) {
        guard let i = trees.firstIndex(where: { $0.id == treeId }),
              let j = trees[i].papers.firstIndex(where: { $0.id == paperId }), new.id != paperId else { return }
        let old = trees[i].papers[j]
        if trees[i].papers.contains(where: { $0.id == new.id }) {
            // Already on this tree: just drop the wrong one.
            remove(paperId: paperId, from: treeId)
            return
        }
        var p = new
        p.parentId = old.parentId
        p.addedAt = old.addedAt
        trees[i].papers[j] = p
        for k in trees[i].papers.indices where trees[i].papers[k].parentId == paperId { trees[i].papers[k].parentId = new.id }
        // Suggestions came from the wrong paper's neighbours, so they go; new ones grow from the right one.
        trees[i].suggestions.removeAll { $0.fromPaperId == paperId || $0.id == new.id }
        thumbnails[paperId] = nil
        save()
        loadThumbnail(for: p)
        Task { await suggest(from: p, in: treeId) }
    }

    func rename(_ treeId: UUID, to name: String) {
        guard let i = trees.firstIndex(where: { $0.id == treeId }) else { return }
        trees[i].name = name
        save()
    }

    func deleteTree(_ treeId: UUID) {
        trees.removeAll { $0.id == treeId }
        save()
    }

    // MARK: After a paper lands: front page, species, suggestions

    private func afterAdding(_ paper: Paper, to treeId: UUID) {
        loadThumbnail(for: paper)
        guard persist else { return }
        Task { await refreshLook(treeId) }
        Task { await suggest(from: paper, in: treeId) }
    }

    /// Ask the AI which plant this tree is at 1, 3, 6 and 10 papers, so it settles as it grows.
    private func refreshLook(_ treeId: UUID) async {
        guard let tree = trees.first(where: { $0.id == treeId }) else { return }
        let n = tree.papers.count
        guard [1, 3, 6, 10].contains(n), tree.lookCheckedAt != n else { return }
        guard let look = try? await TreeClient.current.species(titles: tree.papers.map(\.title), fields: tree.allFields) else { return }
        guard let i = trees.firstIndex(where: { $0.id == treeId }) else { return }
        trees[i].look = look
        trees[i].lookCheckedAt = n
        save()
    }

    /// Up to two pencil branches off each new paper; at most six waiting per tree.
    private func suggest(from paper: Paper, in treeId: UUID) async {
        guard !paper.isLocal, let tree = trees.first(where: { $0.id == treeId }) else { return }
        let exclude = tree.papers.map(\.id) + tree.dismissed + tree.suggestions.map(\.id) + tree.papers.compactMap { $0.doi.map { "doi:" + $0 } }
        guard let papers = try? await TreeClient.current.recommend(paper: paper, exclude: exclude, limit: 2) else { return }
        guard let i = trees.firstIndex(where: { $0.id == treeId }) else { return }
        for p in papers where !trees[i].suggestions.contains(where: { $0.id == p.id }) && !trees[i].papers.contains(where: { $0.id == p.id }) {
            trees[i].suggestions.append(Suggestion(paper: p, fromPaperId: paper.id))
        }
        if trees[i].suggestions.count > 6 { trees[i].suggestions.removeFirst(trees[i].suggestions.count - 6) }
        save()
    }

    // MARK: Front pages

    /// Papers whose front page we tried everywhere this session and couldn't get; they keep the drawn title page.
    private var noFrontPage = Set<String>()

    /// Page 1 of the paper, from the first open-access PDF that works: the links we have, then any the
    /// server can find (Semantic Scholar, OpenAlex, Unpaywall, arXiv), then OpenAlex asked from this Mac.
    func loadThumbnail(for paper: Paper) {
        let key = paper.id
        guard thumbnails[key] == nil, !fetchingThumbs.contains(key), !noFrontPage.contains(key) else { return }
        let file = TreeStore.thumbFolder.appendingPathComponent(safeName(key) + ".png")
        if let img = NSImage(contentsOf: file) { thumbnails[key] = img; return }
        guard persist, !paper.isLocal || !paper.title.isEmpty else { return }
        fetchingThumbs.insert(key)
        Task {
            defer { fetchingThumbs.remove(key) }
            guard let found = await TreeStore.findFrontPage(for: paper, client: TreeClient.current) else { noFrontPage.insert(key); return }
            let (png, url) = found
            try? FileManager.default.createDirectory(at: TreeStore.thumbFolder, withIntermediateDirectories: true)
            try? png.write(to: file, options: .atomic)
            if let img = NSImage(data: png) { thumbnails[key] = img }
            // Remember the link that worked, so "open" goes to the PDF too.
            if paper.pdf != url { setPdf(url, for: key) }
        }
    }

    private func setPdf(_ url: String, for paperId: String) {
        for i in trees.indices {
            for j in trees[i].papers.indices where trees[i].papers[j].id == paperId {
                trees[i].papers[j].pdf = url
            }
        }
        save()
    }

    /// Tries every known PDF for a paper and returns page 1 as PNG, with the link that worked.
    nonisolated static func findFrontPage(for paper: Paper, client: TreeClient) async -> (Data, String)? {
        var tried: [String] = []
        func attempt(_ list: [String]) async -> (Data, String)? {
            for u in list where !tried.contains(u) {
                tried.append(u)
                guard let url = URL(string: u), url.scheme == "https" || url.scheme == "http" else { continue }
                if let png = await renderFrontPage(url) { return (png, u) }
            }
            return nil
        }
        if let hit = await attempt(paper.pdfCandidates) { return hit }
        if let more = try? await client.pdfs(for: paper, tried: tried), let hit = await attempt(more) { return hit }
        if let direct = await DirectSources.openAlexPdfs(for: paper), let hit = await attempt(direct) { return hit }
        return nil
    }

    private func safeName(_ s: String) -> String { String(s.map { $0.isLetter || $0.isNumber ? $0 : "-" }.prefix(80)) }

    /// Downloads an open-access PDF (up to 40 MB) and draws page 1 with PDFKit.
    nonisolated static func renderFrontPage(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 30)
        // Some repositories turn away anything that doesn't look like a browser.
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) PaperTree", forHTTPHeaderField: "User-Agent")
        request.setValue("application/pdf,*/*;q=0.8", forHTTPHeaderField: "Accept")
        guard let result = try? await URLSession.shared.data(for: request) else { return nil }
        let (data, response) = result
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 40_000_000,
              data.starts(with: Array("%PDF".utf8)) || data.prefix(1024).range(of: Data("%PDF".utf8)) != nil,
              let doc = PDFDocument(data: data), let page = doc.page(at: 0) else { return nil }
        let image = page.thumbnail(of: NSSize(width: 300, height: 400), for: .cropBox)
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: Talking to the server

struct TreeClient {
    var base: String
    var token: String

    /// A client pointed at the same server as the explainer.
    @MainActor static var current: TreeClient {
        TreeClient(base: AppState.shared.endpoint, token: AppState.shared.clientToken)
    }

    struct ServerError: Error { var message: String; var status: Int }

    private func url(_ path: String) -> URL? {
        var b = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = b.range(of: "/api/explain") { b = String(b[..<r.lowerBound]) }
        while b.hasSuffix("/") { b.removeLast() }
        return URL(string: b + path)
    }

    private func post<T: Decodable>(_ path: String, _ body: [String: Any], as: T.Type) async throws -> T {
        guard let u = url(path) else { throw ServerError(message: "No server address.", status: 0) }
        var r = URLRequest(url: u, timeoutInterval: 25)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { r.setValue(token, forHTTPHeaderField: "X-Paper-Tree-Token") }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await ExplainClient.session.data(for: r)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw ServerError(message: msg ?? "The server said \(status).", status: status)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    struct Wire: Decodable {
        var id: String; var title: String; var authors: [String]?; var year: Int?; var venue: String?
        var abstract: String?; var pdf: String?; var pdfs: [String]?; var url: String?; var fields: [String]?
        var doi: String?; var arxiv: String?; var cites: Int?; var source: String?
        var paper: Paper {
            var p = Paper(id: id, title: title, authors: authors ?? [], year: year, venue: venue ?? "", abstract: abstract ?? "",
                          pdf: pdf ?? "", url: url ?? "", fields: fields ?? [])
            p.doi = doi.flatMap { $0.isEmpty ? nil : $0 }
            p.arxiv = arxiv.flatMap { $0.isEmpty ? nil : $0 }
            p.pdfs = pdfs
            p.cites = cites
            p.source = source
            return p
        }
    }

    /// What a title lookup found: candidates best first, and whether the first is a clear match.
    struct LookupResult: Sendable {
        var candidates: [Paper]
        var confident: Bool
        /// The server couldn't reach Semantic Scholar (rate limited) and answered without it.
        var semanticScholarBusy: Bool
    }

    func lookup(title: String, seen: [[String: Any]] = []) async throws -> LookupResult {
        struct Sources: Decodable { var semanticScholar: StringOrInt? }
        struct R: Decodable { var candidates: [Wire]?; var paper: Wire?; var confident: Bool?; var sources: Sources? }
        var body: [String: Any] = ["title": title]
        if !seen.isEmpty { body["seen"] = seen }
        let r = try await post("/api/paper/lookup", body, as: R.self)
        let list = (r.candidates ?? r.paper.map { [$0] } ?? []).map(\.paper)
        return LookupResult(candidates: list, confident: r.confident ?? (list.count == 1),
                            semanticScholarBusy: r.sources?.semanticScholar?.text == "busy")
    }

    func recommend(paper: Paper, exclude: [String], limit: Int) async throws -> [Paper] {
        struct R: Decodable { var papers: [Wire] }
        let body: [String: Any] = ["paperId": paper.id, "title": paper.title, "doi": paper.doi ?? "", "exclude": exclude, "limit": limit]
        return try await post("/api/paper/recommend", body, as: R.self).papers.map(\.paper)
    }

    func pdfs(for paper: Paper, tried: [String]) async throws -> [String] {
        struct R: Decodable { var pdfs: [String] }
        let body: [String: Any] = ["id": paper.isLocal ? "" : paper.id, "title": paper.title, "doi": paper.doi ?? "",
                                   "arxiv": paper.arxiv ?? "", "tried": tried]
        return try await post("/api/paper/pdfs", body, as: R.self).pdfs
    }

    func species(titles: [String], fields: [String]) async throws -> TreeLook {
        struct R: Decodable {
            var species: String; var commonName: String; var latinName: String; var note: String
            var leafTone: String; var vigor: Double; var twist: Double; var droop: Double
        }
        let r = try await post("/api/tree/species", ["titles": Array(titles.suffix(12)), "fields": Array(fields.prefix(8))], as: R.self)
        return TreeLook(species: Species(rawValue: r.species) ?? .oak, commonName: r.commonName, latinName: r.latinName,
                        note: r.note, leafTone: r.leafTone, vigor: r.vigor, twist: r.twist, droop: r.droop, fromAI: true)
    }
}

/// A JSON value that may be a number or a string (the server reports a count, or "busy").
struct StringOrInt: Decodable, Sendable {
    var text: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { text = s } else if let n = try? c.decode(Int.self) { text = String(n) } else { text = "" }
    }
}

// MARK: Looking a title up

/// Finds a highlighted title. The server does the matching; when its shared connection to Semantic
/// Scholar is rate limited, this Mac asks Semantic Scholar and OpenAlex itself (no keys, its own
/// allowance) and hands the server what it found to rank.
enum PaperLookup {
    static func find(_ title: String) async throws -> TreeClient.LookupResult {
        let client = await TreeClient.current
        var first: TreeClient.LookupResult?
        var firstError: Error?
        do { first = try await client.lookup(title: title) } catch { firstError = error }
        let weak = first == nil || first!.semanticScholarBusy || first!.candidates.isEmpty
        guard weak else { return first! }
        let seen = await DirectSources.candidates(for: title)
        guard !seen.isEmpty else {
            if let first { return first }
            throw firstError ?? TreeClient.ServerError(message: "I couldn't find that title.", status: 404)
        }
        do { return try await client.lookup(title: title, seen: seen) } catch {
            if let first { return first }
            throw error
        }
    }
}

/// Keyless calls straight from this Mac to Semantic Scholar and OpenAlex. Only used as a fallback.
enum DirectSources {
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.httpAdditionalHeaders = ["User-Agent": "PaperTree-Mac"]
        return URLSession(configuration: c)
    }()

    private static func getJSON(_ url: String) async -> [String: Any]? {
        guard let u = URL(string: url), let (data, response) = try? await session.data(from: u),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func q(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? s
    }

    /// Paper records shaped the way the server expects in "seen".
    static func candidates(for title: String) async -> [[String: Any]] {
        async let s2 = semanticScholar(title)
        async let oa = openAlex(title)
        return await s2 + oa
    }

    private static func semanticScholar(_ title: String) async -> [[String: Any]] {
        let fields = "paperId,title,authors,year,venue,openAccessPdf,externalIds,url,fieldsOfStudy,citationCount"
        guard let d = await getJSON("https://api.semanticscholar.org/graph/v1/paper/search?query=\(q(title))&limit=6&fields=\(fields)"),
              let rows = d["data"] as? [[String: Any]] else { return [] }
        return rows.compactMap { p in
            guard let id = p["paperId"] as? String, let t = p["title"] as? String else { return nil }
            let ext = p["externalIds"] as? [String: Any] ?? [:]
            let arxiv = ext["ArXiv"] as? String ?? ""
            var pdfs: [String] = []
            if let oa = (p["openAccessPdf"] as? [String: Any])?["url"] as? String, !oa.isEmpty { pdfs.append(oa) }
            if !arxiv.isEmpty { pdfs.append("https://arxiv.org/pdf/\(arxiv)") }
            return ["id": id, "title": t, "authors": ((p["authors"] as? [[String: Any]]) ?? []).prefix(6).compactMap { $0["name"] as? String },
                    "year": p["year"] as? Int ?? 0, "venue": p["venue"] as? String ?? "", "pdfs": pdfs,
                    "url": p["url"] as? String ?? "", "fields": p["fieldsOfStudy"] as? [String] ?? [],
                    "doi": ext["DOI"] as? String ?? "", "arxiv": arxiv, "cites": p["citationCount"] as? Int ?? 0, "source": "Semantic Scholar"]
        }
    }

    private static let oaSelect = "id,doi,title,publication_year,authorships,primary_location,best_oa_location,locations,cited_by_count,topics"

    private static func openAlexRecord(_ w: [String: Any]) -> [String: Any]? {
        guard let rawId = w["id"] as? String, let t = w["title"] as? String else { return nil }
        let doi = ((w["doi"] as? String) ?? "").replacingOccurrences(of: "https://doi.org/", with: "")
        var pdfs: [String] = []
        if let best = (w["best_oa_location"] as? [String: Any])?["pdf_url"] as? String { pdfs.append(best) }
        for l in (w["locations"] as? [[String: Any]]) ?? [] { if let u = l["pdf_url"] as? String, !pdfs.contains(u) { pdfs.append(u) } }
        let venue = ((w["primary_location"] as? [String: Any])?["source"] as? [String: Any])?["display_name"] as? String ?? ""
        let fields = ((w["topics"] as? [[String: Any]]) ?? []).compactMap { ($0["field"] as? [String: Any])?["display_name"] as? String }
        return ["id": rawId.replacingOccurrences(of: "https://openalex.org/", with: ""), "title": t,
                "authors": ((w["authorships"] as? [[String: Any]]) ?? []).prefix(6).compactMap { ($0["author"] as? [String: Any])?["display_name"] as? String },
                "year": w["publication_year"] as? Int ?? 0, "venue": venue, "pdfs": Array(pdfs.prefix(6)),
                "url": doi.isEmpty ? rawId : "https://doi.org/\(doi)", "fields": Array(Set(fields)).sorted(),
                "doi": doi, "cites": w["cited_by_count"] as? Int ?? 0, "source": "OpenAlex"]
    }

    private static func openAlex(_ title: String) async -> [[String: Any]] {
        let clean = title.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: ":", with: " ")
        guard let d = await getJSON("https://api.openalex.org/works?search=\(q(clean))&per-page=6&select=\(oaSelect)"),
              let rows = d["results"] as? [[String: Any]] else { return [] }
        return rows.compactMap(openAlexRecord)
    }

    /// Open-access PDF links OpenAlex knows for a paper, found by DOI or by its exact title.
    static func openAlexPdfs(for paper: Paper) async -> [String]? {
        var work: [String: Any]?
        if let doi = paper.doi, !doi.isEmpty {
            work = await getJSON("https://api.openalex.org/works/doi:\(q(doi))?select=\(oaSelect)")
        } else if paper.id.hasPrefix("W") {
            work = await getJSON("https://api.openalex.org/works/\(paper.id)?select=\(oaSelect)")
        } else {
            let hits = await openAlex(paper.title)
            let want = paper.title.lowercased().filter { $0.isLetter || $0.isNumber }
            if let hit = hits.first(where: { (($0["title"] as? String) ?? "").lowercased().filter { $0.isLetter || $0.isNumber } == want }) {
                return hit["pdfs"] as? [String]
            }
        }
        return work.flatMap(openAlexRecord)?["pdfs"] as? [String]
    }
}
