// Reading a paper inside the island: the PDF on a desk, a margin for notes, and a rail with the
// paper's details, search, page thumbnails and every note. Select text for a small bar: Explain,
// highlight in an ink, underline, or comment. Without a free PDF, the abstract in the same style.
import AppKit
import Combine
import PDFKit
import SwiftUI

@MainActor
final class ReaderModel: ObservableObject {
    enum Status: Equatable { case loading, ready, unavailable }
    enum Rail: Equatable { case pages, notes }
    /// Text selected in the PDF, waiting for an action from the bar.
    struct Pick: Equatable {
        var text: String
        var page: Int
        var rects: [CGRect]
        /// Top center of the selection, in the reader's view (top-left origin).
        var anchor: CGPoint
        var context: String
        var screen: NSRect
    }

    let paper: Paper
    let marks: MarkStore
    @Published var status: Status = .loading
    @Published private(set) var document: PDFDocument?
    @Published var pick: Pick?
    @Published var editing: UUID?
    @Published var placingSticky = false
    @Published var query = ""
    @Published private(set) var results: [PDFSelection] = []
    @Published private(set) var resultIndex = 0
    @Published var page = 0
    @Published var zoomPercent = 100
    @Published var rail: Rail = .notes
    @Published var ink: MarkInk = .marigold
    weak var view: ReaderPDFView?
    var onExplain: (String, String, NSRect) -> Void = { _, _, _ in }

    private var annotations: [Int: MarksAnnotation] = [:]
    private(set) var originals: [Int: CGRect] = [:]
    private var thumbs: [Int: NSImage] = [:]
    private var started = false

    init(paper: Paper, persist: Bool = true) {
        self.paper = paper
        self.marks = MarkStore(paperId: paper.id, persist: persist)
        marks.onChange = { [weak self] in self?.refreshMarks() }
    }

    var pageCount: Int { document?.pageCount ?? 0 }

    func load() {
        guard !started, status == .loading else { return }
        started = true
        Task {
            if let data = await PaperLibrary.load(paper), let doc = PDFDocument(data: data) {
                setDocument(doc)
            } else {
                status = .unavailable
            }
        }
    }

    /// Widens every page by a margin for comment slips and hangs one drawing annotation on it.
    func setDocument(_ doc: PDFDocument) {
        started = true
        annotations = [:]
        originals = [:]
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let crop = page.bounds(for: .cropBox)
            let wide = CGRect(x: crop.minX, y: crop.minY, width: crop.width + MarkLayout.margin, height: crop.height)
            page.setBounds(page.bounds(for: .mediaBox).union(wide), for: .mediaBox)
            page.setBounds(wide, for: .cropBox)
            let a = MarksAnnotation(bounds: wide, forType: .square, withProperties: nil)
            a.original = crop
            a.marks = marks.marks.filter { $0.page == i }
            page.addAnnotation(a)
            annotations[i] = a
            originals[i] = crop
        }
        document = doc
        status = .ready
    }

    private func refreshMarks() {
        thumbs = [:]
        for (i, a) in annotations {
            a.marks = marks.marks.filter { $0.page == i }
            if let v = view, let p = document?.page(at: i) { v.annotationsChanged(on: p) }
        }
        view?.needsDisplay = true
        view?.documentView?.needsDisplay = true
        objectWillChange.send()
    }

    // MARK: Actions on a selection

    func mark(_ kind: PaperMark.Kind, ink: MarkInk? = nil) {
        guard let pick else { return }
        if let ink { self.ink = ink }
        let m = PaperMark(kind: kind, page: pick.page, rects: pick.rects, ink: self.ink, quote: pick.text)
        marks.add(m)
        view?.clearSelection()
        self.pick = nil
        if kind == .comment { editing = m.id }
        rail = .notes
    }

    func explain() {
        guard let pick else { return }
        onExplain(pick.text, pick.context, pick.screen)
        self.pick = nil
    }

    func addSticky(page: Int, at p: CGPoint) {
        let m = PaperMark(kind: .sticky, page: page, rects: [CGRect(x: p.x - 12, y: p.y - 104, width: 150, height: 112)], ink: ink)
        marks.add(m)
        placingSticky = false
        editing = m.id
        rail = .notes
    }

    func hit(page: Int, at p: CGPoint) -> PaperMark? {
        guard let o = originals[page] else { return nil }
        return MarkLayout.hit(marks.marks.filter { $0.page == page }, page: o, at: p)
    }

    /// Reads the PDF view's selection after a mouse-up.
    func selectionChanged() {
        guard let v = view, let doc = document, let sel = v.currentSelection,
              let text = sel.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              let page = sel.pages.first else { pick = nil; return }
        let idx = doc.index(for: page)
        var rects = sel.selectionsByLine().map { $0.bounds(for: page) }.filter { $0.width > 0.5 && $0.height > 0.5 }
        if rects.isEmpty { rects = [sel.bounds(for: page)] }
        let box = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        let inView = v.convert(box, from: page)
        let top = v.isFlipped ? inView.minY : v.bounds.height - inView.maxY
        let screen = v.window.map { $0.convertToScreen(v.convert(inView, to: nil)) } ?? .zero
        pick = Pick(text: String(text.prefix(1200)), page: idx, rects: rects,
                    anchor: CGPoint(x: inView.midX, y: top), context: context(around: text, on: page), screen: screen)
    }

    private func context(around text: String, on page: PDFPage) -> String {
        guard let all = page.string as NSString? else { return "" }
        let r = all.range(of: String(text.prefix(80)))
        guard r.location != NSNotFound else { return "" }
        let start = max(0, r.location - 400), end = min(all.length, r.location + r.length + 400)
        return all.substring(with: NSRange(location: start, length: end - start))
    }

    // MARK: Going places

    func jump(_ m: PaperMark) {
        guard let p = document?.page(at: m.page), let r = m.rects.first else { return }
        view?.go(to: r.insetBy(dx: -40, dy: -80), on: p)
        page = m.page
    }

    func go(page i: Int) {
        guard let p = document?.page(at: i) else { return }
        view?.go(to: p)
        page = i
    }

    func search() {
        guard let doc = document, query.trimmingCharacters(in: .whitespaces).count > 1 else { results = []; view?.highlightedSelections = nil; return }
        results = doc.findString(query, withOptions: .caseInsensitive)
        for r in results { r.color = MarkInk.sky.ns.withAlphaComponent(0.6) }
        view?.highlightedSelections = results
        resultIndex = 0
        showResult()
    }

    func step(_ d: Int) {
        guard !results.isEmpty else { return }
        resultIndex = (resultIndex + d + results.count) % results.count
        showResult()
    }

    private func showResult() {
        guard resultIndex < results.count else { return }
        let r = results[resultIndex]
        view?.setCurrentSelection(r, animate: true)
        view?.scrollSelectionToVisible(nil)
        if let p = r.pages.first, let doc = document { page = doc.index(for: p) }
    }

    func zoom(_ d: Int) {
        guard let v = view else { return }
        if d > 0 { v.zoomIn(nil) } else if d < 0 { v.zoomOut(nil) } else { v.autoScales = true }
    }

    func thumbnail(_ i: Int) -> NSImage? {
        if let t = thumbs[i] { return t }
        guard let p = document?.page(at: i) else { return nil }
        let t = p.thumbnail(of: NSSize(width: 220, height: 260), for: .cropBox)
        thumbs[i] = t
        return t
    }

    var resultLabel: String {
        if results.isEmpty { return query.isEmpty ? "" : "no matches" }
        return "\(resultIndex + 1) of \(results.count)"
    }
}

// MARK: The PDF view

final class ReaderPDFView: PDFView {
    weak var reader: ReaderModel?

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let r = reader, let doc = document, let page = page(for: p, nearest: true) {
            let idx = doc.index(for: page)
            let at = convert(p, to: page)
            if r.placingSticky { r.addSticky(page: idx, at: at); return }
            if let m = r.hit(page: idx, at: at) { r.editing = m.id; return }
        }
        reader?.pick = nil
        super.mouseDown(with: event)
        // PDFView tracks the drag inside mouseDown, so the selection is final here.
        reader?.selectionChanged()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        reader?.selectionChanged()
    }
}

struct PDFReaderView: NSViewRepresentable {
    @ObservedObject var reader: ReaderModel

    func makeNSView(context: Context) -> ReaderPDFView {
        let v = ReaderPDFView()
        v.reader = reader
        reader.view = v
        v.displayMode = .singlePageContinuous
        v.displaysPageBreaks = true
        v.pageBreakMargins = NSEdgeInsets(top: 18, left: 18, bottom: 26, right: 18)
        v.backgroundColor = NSColor(srgbRed: 0.86, green: 0.82, blue: 0.73, alpha: 1)
        v.document = reader.document
        v.autoScales = true
        context.coordinator.watch(v, reader)
        return v
    }

    func updateNSView(_ v: ReaderPDFView, context: Context) {
        if v.document !== reader.document { v.document = reader.document; v.autoScales = true }
        v.reader = reader
        reader.view = v
    }

    func makeCoordinator() -> Watcher { Watcher() }

    final class Watcher: NSObject {
        private var tokens: [NSObjectProtocol] = []
        deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }

        @MainActor func watch(_ v: ReaderPDFView, _ reader: ReaderModel) {
            let c = NotificationCenter.default
            tokens.append(c.addObserver(forName: .PDFViewPageChanged, object: v, queue: .main) { [weak v, weak reader] _ in
                Task { @MainActor in
                    guard let v, let reader, let p = v.currentPage, let doc = v.document else { return }
                    reader.page = doc.index(for: p)
                }
            })
            tokens.append(c.addObserver(forName: .PDFViewScaleChanged, object: v, queue: .main) { [weak v, weak reader] _ in
                Task { @MainActor in
                    guard let v, let reader else { return }
                    reader.zoomPercent = Int((v.scaleFactor * 100).rounded())
                }
            })
            // Scrolling moves the text out from under the bar, so the bar goes.
            if let clip = v.documentView?.enclosingScrollView?.contentView {
                clip.postsBoundsChangedNotifications = true
                tokens.append(c.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: .main) { [weak reader] _ in
                    Task { @MainActor in if reader?.pick != nil { reader?.pick = nil } }
                })
            }
        }
    }
}

// MARK: The page

struct PaperReaderPage: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var store: TreeStore
    var tree: PaperTreeData
    var paper: Paper
    @StateObject private var reader: ReaderModel

    init(model: IslandModel, store: TreeStore, tree: PaperTreeData, paper: Paper, preset: ReaderModel? = nil) {
        self.model = model
        self.store = store
        self.tree = tree
        self.paper = paper
        _reader = StateObject(wrappedValue: preset ?? ReaderModel(paper: paper))
    }

    var body: some View {
        HStack(spacing: 0) {
            ReaderRail(reader: reader, tree: tree, paper: paper) {
                withAnimation(Motion.pick(Motion.page)) { model.page = .tree(tree.id) }
            }
            .frame(width: 272)
            ZStack {
                Color(hex: 0xDCD2BB)
                    .overlay(Image(nsImage: PaperGrain.image).resizable(resizingMode: .tile).opacity(0.35))
                content
                if let id = reader.editing, let m = reader.marks.mark(id) {
                    MarkEditor(reader: reader, mark: m)
                        .id(id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(18)
                        .transition(Motion.reduced ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                }
                if reader.status == .ready {
                    ReaderTools(reader: reader)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .onAppear {
            reader.onExplain = model.onExplain
            reader.load()
        }
    }

    @ViewBuilder private var content: some View {
        switch reader.status {
        case .loading:
            VStack(spacing: 16) {
                PaperTipCard(paper: paper, image: store.thumbnails[paper.id], size: CGSize(width: 330, height: 430), tilt: 0)
                Text("Fetching the paper").font(.typewriter(11)).foregroundColor(Palette.ink3)
            }
        case .unavailable:
            AbstractSheet(paper: paper)
        case .ready:
            if Snapshots.isRendering {
                StandInPages(reader: reader)
            } else {
                PDFReaderView(reader: reader)
                    .overlay(alignment: .topLeading) {
                        if let pick = reader.pick {
                            SelectionBar(reader: reader)
                                .fixedSize()
                                .position(x: pick.anchor.x, y: max(24, pick.anchor.y - 26))
                                .transition(.opacity)
                        }
                    }
                    .overlay(alignment: .top) {
                        if reader.placingSticky {
                            Text("Click anywhere on the page to pin the note")
                                .font(.hand(14)).foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(Palette.ink.opacity(0.85)))
                                .padding(.top, 10)
                        }
                    }
            }
        }
    }
}

/// The selection's action bar: explain it, or mark it.
struct SelectionBar: View {
    @ObservedObject var reader: ReaderModel

    var body: some View {
        HStack(spacing: 10) {
            Button { reader.explain() } label: {
                Label("Explain", systemImage: "text.bubble").font(.uiBold(12)).foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Open a plain-language card, the same as Research mode")
            divider
            ForEach(MarkInk.allCases) { ink in
                Button { reader.mark(.highlight, ink: ink) } label: {
                    Circle().fill(ink.swatch).frame(width: 15, height: 15)
                        .overlay(Circle().strokeBorder(Color.white.opacity(reader.ink == ink ? 0.95 : 0.25), lineWidth: 1.4))
                }
                .buttonStyle(.plain)
                .help("Highlight in \(ink.name)")
            }
            divider
            Button { reader.mark(.underline) } label: {
                Image(systemName: "underline").font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Underline")
            Button { reader.mark(.comment) } label: {
                Label("Comment", systemImage: "text.append").font(.uiBold(12)).foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Write a note in the margin")
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Color(hex: 0x1E1B16)).shadow(color: .black.opacity(0.3), radius: 6, y: 2))
    }

    private var divider: some View { Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 14) }
}

/// Bottom right: pin a sticky note, and zoom.
struct ReaderTools: View {
    @ObservedObject var reader: ReaderModel

    var body: some View {
        HStack(spacing: 0) {
            Button { reader.placingSticky.toggle() } label: {
                Label("Sticky note", systemImage: "note.text").font(.uiBold(11.5))
                    .foregroundColor(reader.placingSticky ? Palette.red : Palette.ink2)
                    .padding(.horizontal, 10).frame(height: 28).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Then click anywhere on the page")
            rule
            icon("minus", "Zoom out") { reader.zoom(-1) }
            Text("\(reader.zoomPercent)%").font(.typewriter(10.5)).foregroundColor(Palette.ink2).frame(width: 42)
            icon("plus", "Zoom in") { reader.zoom(1) }
            rule
            Button { reader.zoom(0) } label: {
                Text("Fit").font(.uiBold(11.5)).foregroundColor(Palette.ink2).padding(.horizontal, 9).frame(height: 28).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .background(Capsule().fill(Color(hex: 0xFCFAF3)).shadow(color: .black.opacity(0.15), radius: 3, y: 1))
        .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.2), lineWidth: 0.7))
    }

    private var rule: some View { Rectangle().fill(Palette.ink.opacity(0.18)).frame(width: 1, height: 16).padding(.horizontal, 3) }

    private func icon(_ name: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.ink2)
                .frame(width: 26, height: 28).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Edit a note: its words, its ink, or delete it.
struct MarkEditor: View {
    @ObservedObject var reader: ReaderModel
    var mark: PaperMark
    @State private var draft = ""
    @State private var ink: MarkInk = .marigold

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(mark.label), page \(mark.page + 1)").font(.typewriter(10)).foregroundColor(Palette.ink3)
                Spacer()
                ForEach(MarkInk.allCases) { k in
                    Button { ink = k } label: {
                        Circle().fill(k.swatch).frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(Palette.ink.opacity(ink == k ? 0.8 : 0.15), lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }
            }
            if !mark.quote.isEmpty {
                Text("\u{201C}\(mark.quote)\u{201D}").font(.text(12.5)).foregroundColor(Palette.ink2).lineLimit(3)
            }
            Group {
                if Snapshots.isRendering {
                    Text(draft.isEmpty ? " " : draft).font(.hand(15)).foregroundColor(Color(hex: 0x23314A))
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                } else {
                    TextEditor(text: $draft).font(.hand(15)).foregroundColor(Color(hex: 0x23314A))
                        .scrollContentBackground(.hidden)
                        .frame(height: 90)
                }
            }
            .padding(6)
            .background(Color.white.opacity(0.6))
            .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.15), lineWidth: 0.6))
            HStack(spacing: 14) {
                Button("Save") { save() }.buttonStyle(StampButtonStyle(compact: true))
                Button("Delete") {
                    reader.marks.delete(mark.id)
                    reader.editing = nil
                }
                .buttonStyle(InkLinkButtonStyle(color: Palette.red))
                Spacer()
                Button("Close") { reader.editing = nil }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Color(hex: 0xFFFCF3).shadow(color: .black.opacity(0.22), radius: 8, y: 3))
        .overlay(alignment: .top) { Rectangle().fill(ink.swatch).frame(height: 4) }
        .rotationEffect(.degrees(-0.6))
        .onAppear { draft = mark.note; ink = mark.ink }
    }

    private func save() {
        var m = mark
        m.note = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        m.ink = ink
        reader.marks.update(m)
        reader.editing = nil
    }
}

/// The rail beside the paper: what it is, search, pages and notes.
struct ReaderRail: View {
    @ObservedObject var reader: ReaderModel
    var tree: PaperTreeData
    var paper: Paper
    var back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: back) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                    Text("Back to tree")
                }
            }
            .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
            Text("from \(tree.displayName)").font(.typewriter(9.5)).foregroundColor(Palette.ink3)
            Text(paper.title).font(.fell(19)).foregroundColor(Palette.ink)
                .fixedSize(horizontal: false, vertical: true).lineLimit(5)
            if !paper.authors.isEmpty {
                Text(paper.authors.prefix(5).joined(separator: ", ") + (paper.authors.count > 5 ? ", et al." : ""))
                    .font(.text(12.5)).foregroundColor(Palette.ink2).lineLimit(3)
            }
            let meta = [paper.year.map(String.init) ?? "", paper.venue].filter { !$0.isEmpty }.joined(separator: ", ")
            if !meta.isEmpty { Text(meta).font(.typewriter(10)).foregroundColor(Palette.ink3).lineLimit(2) }
            if let u = paper.openURL {
                Button("Open in browser") { NSWorkspace.shared.open(u) }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                    .font(.ui(11))
            }
            Rectangle().fill(Palette.ink.opacity(0.18)).frame(height: 0.8).padding(.vertical, 2)
            if reader.status == .ready {
                search
                tabs
                GroveScroll(axis: .vertical) {
                    if reader.rail == .pages { pages } else { notes }
                }
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0xF7F1E3))
        .overlay(alignment: .trailing) { Rectangle().fill(Palette.ink.opacity(0.18)).frame(width: 0.8) }
    }

    private var search: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(Palette.ink3)
            if Snapshots.isRendering {
                Text(reader.query.isEmpty ? "Search this paper" : reader.query).font(.ui(12))
                    .foregroundColor(reader.query.isEmpty ? Palette.pencil : Palette.ink)
                Spacer(minLength: 0)
            } else {
                TextField("Search this paper", text: $reader.query)
                    .textFieldStyle(.plain).font(.ui(12))
                    .onSubmit { reader.search() }
            }
            if !reader.resultLabel.isEmpty {
                Text(reader.resultLabel).font(.typewriter(9.5)).foregroundColor(Palette.ink3).fixedSize()
                Button { reader.step(-1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.plain)
                Button { reader.step(1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.plain)
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(Palette.ink2)
        .padding(.horizontal, 8).frame(height: 28)
        .background(Color.white.opacity(0.7))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ink.opacity(0.2), lineWidth: 0.7))
    }

    private var tabs: some View {
        HStack(spacing: 14) {
            tab("Notes (\(reader.marks.marks.count))", .notes)
            tab("Pages (\(reader.pageCount))", .pages)
            Spacer()
        }
        .padding(.top, 2)
    }

    private func tab(_ title: String, _ r: ReaderModel.Rail) -> some View {
        Button { withAnimation(Motion.pick(Motion.snappy)) { reader.rail = r } } label: {
            Text(title).font(.fell(16)).foregroundColor(reader.rail == r ? Palette.ink : Palette.ink3)
                .overlay(alignment: .bottom) {
                    if reader.rail == r { Rectangle().fill(Palette.red.opacity(0.7)).frame(height: 1.2).offset(y: 3) }
                }
        }
        .buttonStyle(.plain)
    }

    private var pages: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
            ForEach(0..<reader.pageCount, id: \.self) { i in
                Button { reader.go(page: i) } label: {
                    VStack(spacing: 4) {
                        if let img = reader.thumbnail(i) {
                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                                .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
                                .overlay(Rectangle().strokeBorder(reader.page == i ? Palette.red.opacity(0.7) : Color.clear, lineWidth: 1.4))
                        }
                        Text("\(i + 1)").font(.typewriter(9.5)).foregroundColor(reader.page == i ? Palette.red : Palette.ink3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var notes: some View {
        let list = reader.marks.marks.sorted { ($0.page, -($0.rects.first?.maxY ?? 0)) < ($1.page, -($1.rects.first?.maxY ?? 0)) }
        if list.isEmpty {
            Text("Select text to highlight, underline or comment. Use Sticky note to pin a note anywhere.")
                .font(.hand(13.5)).foregroundColor(Palette.pencil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(list) { m in
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle().fill(m.ink.swatch).frame(width: 4)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(m.label.lowercased()), page \(m.page + 1)").font(.typewriter(9)).foregroundColor(Palette.ink3)
                            if !m.quote.isEmpty {
                                Text("\u{201C}\(m.quote)\u{201D}").font(.text(12)).foregroundColor(Palette.ink2).lineLimit(3)
                            }
                            if !m.note.isEmpty {
                                Text(m.note).font(.hand(13.5)).foregroundColor(Color(hex: 0x23314A)).lineLimit(4)
                            }
                            HStack(spacing: 12) {
                                Button("Edit") { reader.editing = m.id }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                                Button("Delete") { reader.marks.delete(m.id) }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                            }
                            .font(.ui(10.5))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture { reader.jump(m) }
                    .help("Go to it")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// No free PDF: the abstract and what we know, set like a title page.
struct AbstractSheet: View {
    var paper: Paper

    private var publisher: URL? {
        if let d = paper.doi, !d.isEmpty { return URL(string: "https://doi.org/" + d) }
        return URL(string: paper.url)
    }

    var body: some View {
        GroveScroll(axis: .vertical) {
            VStack(alignment: .leading, spacing: 12) {
                let meta = [paper.venue, paper.year.map(String.init) ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
                if !meta.isEmpty { Text(meta.uppercased()).font(.typewriter(10)).foregroundColor(Palette.ink3) }
                Text(paper.title).font(.fell(30)).foregroundColor(Palette.ink).fixedSize(horizontal: false, vertical: true)
                if !paper.authors.isEmpty {
                    Text(paper.authors.joined(separator: ", ")).font(.text(14)).foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Rectangle().fill(Palette.ink.opacity(0.25)).frame(height: 0.8).padding(.vertical, 4)
                SectionHead(title: "Abstract", size: 19)
                Text(paper.abstract.isEmpty ? "There is no abstract on record for this paper." : paper.abstract)
                    .font(.text(14.5)).foregroundColor(Palette.ink).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if !paper.fields.isEmpty {
                    Text("filed under " + paper.fields.joined(separator: ", ").lowercased())
                        .font(.hand(14.5)).foregroundColor(Palette.red).rotationEffect(.degrees(-0.8))
                }
                Rectangle().fill(Palette.ink.opacity(0.25)).frame(height: 0.8).padding(.vertical, 4)
                Text("No free copy of this paper turned up, so this is what we know about it.")
                    .font(.text(12.5)).foregroundColor(Palette.ink3)
                if let u = publisher {
                    Button("Open publisher page") { NSWorkspace.shared.open(u) }
                        .buttonStyle(StampButtonStyle(compact: true))
                }
            }
            .padding(44)
            .frame(width: 640, alignment: .leading)
            .background(Color(hex: 0xFFFDF7).shadow(color: .black.opacity(0.2), radius: 6, y: 3))
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Design snapshots can't draw a PDFView, so they get the first page drawn as a picture,
/// with the selection bar where it would be.
struct StandInPages: View {
    @ObservedObject var reader: ReaderModel

    var body: some View {
        GeometryReader { geo in
            if let page = reader.document?.page(at: 0) {
                let crop = page.bounds(for: .cropBox)
                let w = min(geo.size.width - 60, crop.width * 1.25)
                let s = w / crop.width
                let origin = CGPoint(x: (geo.size.width - w) / 2, y: 22)
                ZStack(alignment: .topLeading) {
                    Image(nsImage: page.thumbnail(of: NSSize(width: w * 2, height: crop.height * s * 2), for: .cropBox))
                        .resizable().frame(width: w, height: crop.height * s)
                        .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                        .offset(x: origin.x, y: origin.y)
                    if let pick = reader.pick {
                        ForEach(Array(pick.rects.enumerated()), id: \.offset) { _, r in
                            Rectangle().fill(Color(hex: 0x9CC3F0).opacity(0.5))
                                .frame(width: r.width * s, height: r.height * s)
                                .offset(x: origin.x + (r.minX - crop.minX) * s, y: origin.y + (crop.maxY - r.maxY) * s)
                        }
                        let top = pick.rects.map(\.maxY).max() ?? 0
                        let mid = pick.rects.map(\.midX).reduce(0, +) / CGFloat(max(1, pick.rects.count))
                        SelectionBar(reader: reader).fixedSize()
                            .position(x: origin.x + (mid - crop.minX) * s, y: origin.y + (crop.maxY - top) * s - 24)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
            }
        }
    }
}
