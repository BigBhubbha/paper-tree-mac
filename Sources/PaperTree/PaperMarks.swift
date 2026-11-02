// Notes on a paper: highlights in a few inks, underlines, comments written on slips in the margin,
// and sticky notes. Saved per paper in Application Support (Paper Tree/annotations), in page
// coordinates, so they come back when the PDF is downloaded again. Drawn by one annotation per page.
import AppKit
import PDFKit
import SwiftUI

enum MarkInk: String, Codable, CaseIterable, Identifiable {
    case marigold, sage, rose, sky
    var id: String { rawValue }
    var rgb: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .marigold: return (0.98, 0.83, 0.36)
        case .sage: return (0.66, 0.82, 0.58)
        case .rose: return (0.95, 0.66, 0.66)
        case .sky: return (0.62, 0.78, 0.93)
        }
    }
    var ns: NSColor { NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1) }
    var swatch: Color { Color(nsColor: ns) }
    /// The pen used for underlines and slip text in this ink: a darker take on the color.
    var pen: NSColor { NSColor(srgbRed: rgb.0 * 0.55, green: rgb.1 * 0.5, blue: rgb.2 * 0.5, alpha: 1) }
    var name: String { rawValue }
}

struct PaperMark: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case highlight, underline, comment, sticky }
    var id = UUID()
    var kind: Kind
    var page: Int
    /// The marked lines (or, for a sticky note, the note itself), in PDF page coordinates.
    var rects: [CGRect]
    var ink: MarkInk = .marigold
    var quote = ""
    var note = ""
    var createdAt = Date()

    var label: String {
        switch kind {
        case .highlight: return "Highlight"
        case .underline: return "Underline"
        case .comment: return "Comment"
        case .sticky: return "Sticky note"
        }
    }
}

@MainActor
final class MarkStore: ObservableObject {
    let paperId: String
    private let persist: Bool
    @Published private(set) var marks: [PaperMark] = []

    init(paperId: String, persist: Bool = true) {
        self.paperId = paperId
        self.persist = persist
        if persist, let data = try? Data(contentsOf: file), let list = try? JSONDecoder().decode([PaperMark].self, from: data) {
            marks = list
        }
    }

    static var folder: URL { TreeStore.folder.appendingPathComponent("annotations", isDirectory: true) }
    private var file: URL {
        let safe = String(paperId.map { $0.isLetter || $0.isNumber ? $0 : "-" }.prefix(80))
        return MarkStore.folder.appendingPathComponent(safe + ".json")
    }

    func add(_ m: PaperMark) { marks.append(m); save() }
    func update(_ m: PaperMark) {
        guard let i = marks.firstIndex(where: { $0.id == m.id }) else { return }
        marks[i] = m
        save()
    }
    func delete(_ id: UUID) { marks.removeAll { $0.id == id }; save() }
    func mark(_ id: UUID) -> PaperMark? { marks.first { $0.id == id } }

    /// For design snapshots.
    func preset(_ list: [PaperMark]) { marks = list }

    private func save() {
        guard persist else { return }
        try? FileManager.default.createDirectory(at: MarkStore.folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(marks) { try? data.write(to: file, options: .atomic) }
    }
}

/// Where slips and sticky notes go on a page, shared by drawing and clicking.
enum MarkLayout {
    static let margin: CGFloat = 190

    static func slipFont() -> NSFont { NSFont(name: Typeface.hand, size: 10.5) ?? .systemFont(ofSize: 10) }

    /// Comment slips stacked down the margin, each as near its line as the ones above allow.
    static func slips(_ marks: [PaperMark], page original: CGRect) -> [UUID: CGRect] {
        var out: [UUID: CGRect] = [:]
        let comments = marks.filter { $0.kind == .comment }.sorted { ($0.rects.first?.maxY ?? 0) > ($1.rects.first?.maxY ?? 0) }
        let w = margin - 22
        var floor = original.maxY - 10
        for m in comments {
            let text = m.note.isEmpty ? "(empty comment)" : m.note
            let size = (text as NSString).boundingRect(with: CGSize(width: w - 14, height: 400), options: [.usesLineFragmentOrigin],
                                                       attributes: [.font: slipFont()]).size
            let h = min(220, ceil(size.height) + 16)
            let top = min(floor, (m.rects.first?.maxY ?? floor) + 6)
            out[m.id] = CGRect(x: original.maxX + 12, y: top - h, width: w, height: h)
            floor = top - h - 8
        }
        return out
    }

    static func hit(_ marks: [PaperMark], page original: CGRect, at p: CGPoint) -> PaperMark? {
        if let s = marks.last(where: { $0.kind == .sticky && ($0.rects.first ?? .zero).contains(p) }) { return s }
        let slips = slips(marks, page: original)
        return marks.first { slips[$0.id]?.contains(p) == true }
    }
}

/// One per page: draws the margin, then every mark on that page.
final class MarksAnnotation: PDFAnnotation {
    var marks: [PaperMark] = []
    var original: CGRect = .zero

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        // The margin: a slightly darker paper with a ruled line, like a field notebook.
        let margin = CGRect(x: original.maxX, y: original.minY, width: MarkLayout.margin, height: original.height)
        context.setFillColor(NSColor(srgbRed: 0.96, green: 0.94, blue: 0.88, alpha: 1).cgColor)
        context.fill(margin)
        context.setStrokeColor(NSColor(srgbRed: 0.78, green: 0.35, blue: 0.3, alpha: 0.45).cgColor)
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: original.maxX + 4, y: original.minY))
        context.addLine(to: CGPoint(x: original.maxX + 4, y: original.maxY))
        context.strokePath()

        for m in marks where m.kind == .highlight || m.kind == .comment {
            context.saveGState()
            context.setBlendMode(.multiply)
            context.setFillColor(m.ink.ns.withAlphaComponent(m.kind == .comment ? 0.3 : 0.55).cgColor)
            for r in m.rects { context.fill(r.insetBy(dx: -1.5, dy: -0.5)) }
            context.restoreGState()
        }
        for m in marks where m.kind == .underline {
            context.setStrokeColor(m.ink.pen.cgColor)
            context.setLineWidth(1.1)
            context.setLineCap(.round)
            for r in m.rects {
                // A hand-drawn line: a little wobble, not a ruler.
                let y = r.minY + 0.5
                context.move(to: CGPoint(x: r.minX, y: y))
                var x = r.minX
                var k = 0
                while x < r.maxX {
                    x = min(r.maxX, x + 6)
                    k += 1
                    context.addLine(to: CGPoint(x: x, y: y + (k % 2 == 0 ? 0.35 : -0.35)))
                }
            }
            context.strokePath()
        }

        let slips = MarkLayout.slips(marks, page: original)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for m in marks where m.kind == .comment {
            guard let r = slips[m.id] else { continue }
            // A pencil lead from the end of the quote to its slip.
            if let line = m.rects.last {
                context.setStrokeColor(NSColor(srgbRed: 0.42, green: 0.42, blue: 0.46, alpha: 0.6).cgColor)
                context.setLineWidth(0.6)
                context.setLineDash(phase: 0, lengths: [2, 2])
                context.move(to: CGPoint(x: line.maxX + 2, y: line.midY))
                context.addLine(to: CGPoint(x: r.minX, y: r.maxY - 8))
                context.strokePath()
                context.setLineDash(phase: 0, lengths: [])
            }
            slip(r, text: m.note.isEmpty ? "(empty comment)" : m.note, ink: m.ink, in: context, tilt: (m.id.uuid.0 % 2 == 0) ? 0.012 : -0.01)
        }
        for m in marks where m.kind == .sticky {
            guard let r = m.rects.first else { continue }
            sticky(r, text: m.note.isEmpty ? "(empty note)" : m.note, ink: m.ink, in: context)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func slip(_ r: CGRect, text: String, ink: MarkInk, in ctx: CGContext, tilt: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: r.midX, y: r.midY)
        ctx.rotate(by: tilt)
        ctx.translateBy(x: -r.midX, y: -r.midY)
        ctx.setShadow(offset: CGSize(width: 0.6, height: -1.2), blur: 2, color: NSColor.black.withAlphaComponent(0.18).cgColor)
        ctx.setFillColor(NSColor(srgbRed: 1, green: 0.99, blue: 0.96, alpha: 1).cgColor)
        ctx.fill(r)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setFillColor(ink.ns.withAlphaComponent(0.9).cgColor)
        ctx.fill(CGRect(x: r.minX, y: r.maxY - 3, width: r.width, height: 3))
        let para = NSMutableParagraphStyle()
        para.lineSpacing = -1
        (text as NSString).draw(with: r.insetBy(dx: 7, dy: 6), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                attributes: [.font: MarkLayout.slipFont(), .foregroundColor: NSColor(srgbRed: 0.14, green: 0.19, blue: 0.29, alpha: 1),
                                             .paragraphStyle: para])
        ctx.restoreGState()
    }

    private func sticky(_ r: CGRect, text: String, ink: MarkInk, in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: r.midX, y: r.midY)
        ctx.rotate(by: -0.025)
        ctx.translateBy(x: -r.midX, y: -r.midY)
        ctx.setShadow(offset: CGSize(width: 1, height: -2.5), blur: 4, color: NSColor.black.withAlphaComponent(0.22).cgColor)
        let base = NSColor(srgbRed: 0.99, green: 0.92, blue: 0.6, alpha: 1).blended(withFraction: 0.35, of: ink.ns) ?? ink.ns
        ctx.setFillColor(base.cgColor)
        ctx.fill(r)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        // A strip of tape at the top.
        ctx.setFillColor(NSColor(srgbRed: 0.91, green: 0.87, blue: 0.71, alpha: 0.85).cgColor)
        ctx.fill(CGRect(x: r.midX - 18, y: r.maxY - 5, width: 36, height: 10))
        let font = NSFont(name: Typeface.hand, size: 11.5) ?? .systemFont(ofSize: 11)
        (text as NSString).draw(with: r.insetBy(dx: 9, dy: 9), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                attributes: [.font: font, .foregroundColor: NSColor(srgbRed: 0.18, green: 0.16, blue: 0.12, alpha: 1)])
        ctx.restoreGState()
    }
}

/// Open-access PDFs, kept on disk in Application Support (Paper Tree/papers) once downloaded.
@MainActor
enum PaperLibrary {
    static var folder: URL { TreeStore.folder.appendingPathComponent("papers", isDirectory: true) }

    static func file(for paper: Paper) -> URL {
        let safe = String(paper.id.map { $0.isLetter || $0.isNumber ? $0 : "-" }.prefix(80))
        return folder.appendingPathComponent(safe + ".pdf")
    }

    /// The paper's PDF: from disk if we have it, else from the links we know, then any the server or OpenAlex can find.
    static func load(_ paper: Paper) async -> Data? {
        let f = file(for: paper)
        if let data = try? Data(contentsOf: f), PDFDocument(data: data) != nil { return data }
        var tried: [String] = []
        func attempt(_ list: [String]) async -> Data? {
            for u in list where !tried.contains(u) {
                tried.append(u)
                guard let url = URL(string: u), url.scheme == "https" || url.scheme == "http" else { continue }
                if let d = await download(url) { return d }
            }
            return nil
        }
        var data = await attempt(paper.pdfCandidates)
        if data == nil, !paper.isLocal, let more = try? await TreeClient.current.pdfs(for: paper, tried: tried) { data = await attempt(more) }
        if data == nil, !paper.isLocal, let direct = await DirectSources.openAlexPdfs(for: paper) { data = await attempt(direct) }
        if let data {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? data.write(to: f, options: .atomic)
        }
        return data
    }

    nonisolated static func download(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 40)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) PaperTree", forHTTPHeaderField: "User-Agent")
        request.setValue("application/pdf,*/*;q=0.8", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count < 80_000_000,
              data.prefix(1024).range(of: Data("%PDF".utf8)) != nil, PDFDocument(data: data) != nil else { return nil }
        return data
    }
}
