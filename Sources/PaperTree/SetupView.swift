// First-run setup, written as five entries in the field journal:
//   001-002  two pages of specimen tags about the reader (circle an answer in pencil)
//   003      the Accessibility sheet, stamped when macOS lets us in
//   004      a practice bench: real island, real Research mode, a real explanation card
//   005      entry closed
// Re-open any time from Settings > Redo setup.
import SwiftUI
import AppKit

struct SetupView: View {
    @ObservedObject var state: AppState
    @ObservedObject var island: IslandModel
    /// Shows a real explanation card for a highlight in the practice passage.
    var explainPractice: (_ text: String, _ context: String, _ screenRect: NSRect) -> Void
    var done: () -> Void

    /// After an update replay: leave out the Accessibility page while permission is granted.
    var skipPermissionIfGranted = false
    @State private var step: Int

    init(state: AppState, island: IslandModel, skipPermissionIfGranted: Bool = false, initialStep: Int = 0,
         explainPractice: @escaping (_ text: String, _ context: String, _ screenRect: NSRect) -> Void,
         done: @escaping () -> Void) {
        self.state = state
        self.island = island
        self.explainPractice = explainPractice
        self.done = done
        self.skipPermissionIfGranted = skipPermissionIfGranted
        _step = State(initialValue: initialStep)
    }
    @State private var forward = true
    private let poll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    static let size = NSSize(width: 700, height: 600)
    private let titles = ["The reader", "The reader, cont.", "Permission", "Practice", "Entry closed"]

    var body: some View {
        VStack(spacing: 0) {
            runningHead
            ZStack {
                page
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            footer
        }
        .padding(.top, 30)
        .padding(.horizontal, 30)
        .padding(.bottom, 20)
        .frame(width: SetupView.size.width, height: SetupView.size.height)
        .background(DeskBackground().ignoresSafeArea())
        .onReceive(poll) { _ in
            let trusted = Accessibility.isTrusted
            if trusted != state.accessibilityGranted {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) { state.accessibilityGranted = trusted }
                state.refreshMood()
            }
        }
    }

    // MARK: Chrome

    private var runningHead: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Paper Tree, field notes on reading")
                Spacer()
                Text(String(format: "Entry No. %03d  \u{00B7}  %@", step + 1, titles[step]))
            }
            .font(.typewriter(10.5))
            .foregroundColor(Palette.ink3)
            .padding(.horizontal, 6)
            Rectangle().fill(Palette.ink.opacity(0.55)).frame(height: 0.8)
        }
        .padding(.bottom, 18)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            if step == 0 {
                Button("Skip setup for now") { done() }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            } else if step < 4 {
                Button("Back") { go(step - 1) }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            }
            Spacer()
            PageTicks(count: 5, current: step)
            Spacer()
            switch step {
            case 0, 1:
                Button("Next") { go(step + 1) }.buttonStyle(StampButtonStyle())
            case 2:
                if state.accessibilityGranted {
                    Button("Next") { go(3) }.buttonStyle(StampButtonStyle())
                } else {
                    Button("I'll do this later") { go(3) }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                }
            case 3:
                Button("Skip practice") { go(4) }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            default:
                Button("Start reading") { done() }.buttonStyle(StampButtonStyle())
            }
        }
        .frame(height: 40)
        .padding(.top, 12)
        .padding(.horizontal, 6)
    }

    private func go(_ next: Int) {
        var next = next
        // Entry 003 is the permission page; hop over it when it has nothing to ask.
        if next == 2 && skipPermissionIfGranted && state.accessibilityGranted { next = next > step ? 3 : 1 }
        forward = next > step
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { step = max(0, min(4, next)) }
    }

    @ViewBuilder private var page: some View {
        switch step {
        case 0: ReaderTagsPageOne(state: state)
        case 1: ReaderTagsPageTwo(state: state)
        case 2: AccessibilitySheet(state: state).padding(.top, 6)
        case 3: PracticeBench(state: state, island: island, explainPractice: explainPractice, finished: { go(4) })
        default: ClosingEntry(state: state)
        }
    }
}

// MARK: - Entries 001 and 002: specimen tags

private struct ReaderTagsPageOne: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("First, who's reading?")
                .font(.fell(30)).foregroundColor(Palette.ink)
            Text("Fill in two tags so I can pitch my notes at your level. Circle one on each. You can change these in Settings whenever you like.")
                .font(.text(15)).foregroundColor(Palette.ink2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            SpecimenTag(number: 1, label: "year in school", tilt: -0.6) {
                CircleChoices(options: ReaderProfile.schoolYears, selected: [state.profileSchool]) { id in
                    state.profileSchool = state.profileSchool == id ? "" : id
                }
            }
            .padding(.top, 20)

            SpecimenTag(number: 2, label: "science background", tilt: 0.5) {
                CircleChoices(options: ReaderProfile.expertise, selected: [state.profileExpertise]) { id in
                    state.profileExpertise = state.profileExpertise == id ? "" : id
                }
            }
            .padding(.top, 16)
            .padding(.leading, 18)
        }
        .padding(.horizontal, 8)
    }
}

private struct ReaderTagsPageTwo: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("And what do you read?")
                .font(.fell(30)).foregroundColor(Palette.ink)
            Text("Tick as many as you like on the first tag. Circle one on the second.")
                .font(.text(15)).foregroundColor(Palette.ink2)
                .padding(.top, 6)

            SpecimenTag(number: 3, label: "fields you read most", tilt: 0.4) {
                CircleChoices(options: ReaderProfile.fields, selected: Set(state.profileFields), multiple: true) { id in
                    if let i = state.profileFields.firstIndex(of: id) { state.profileFields.remove(at: i) }
                    else { state.profileFields.append(id) }
                }
            }
            .padding(.top, 20)

            SpecimenTag(number: 4, label: "how long should my notes be", tilt: -0.5) {
                CircleChoices(options: ReaderProfile.lengths, selected: [state.profileLength]) { id in
                    state.profileLength = state.profileLength == id ? "" : id
                }
            }
            .padding(.top, 16)
            .padding(.leading, 22)

            FieldNote(state: state)
                .padding(.top, 22)
                .padding(.leading, 6)
        }
        .padding(.horizontal, 8)
    }
}

/// A red-pen line that rewrites itself from the answers, so you can see they were heard.
struct FieldNote: View {
    @ObservedObject var state: AppState

    private var line: String {
        var bits: [String] = []
        if let s = ReaderProfile.schoolYears.first(where: { $0.id == state.profileSchool }) { bits.append(s.label.lowercased()) }
        if let e = ReaderProfile.expertise.first(where: { $0.id == state.profileExpertise }) { bits.append(e.short) }
        let fields = ReaderProfile.fields.filter { state.profileFields.contains($0.id) && $0.id != "other" }.map(\.short)
        if !fields.isEmpty { bits.append("reads " + fields.joined(separator: ", ")) }
        switch state.profileLength {
        case "shortest": bits.append("wants the shortest notes")
        case "thorough": bits.append("likes a little more detail")
        case "balanced": bits.append("likes balanced notes")
        default: break
        }
        return bits.isEmpty ? "nothing noted yet. That's fine too, I'll assume a curious high schooler." : bits.joined(separator: "; ") + "."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MarginBracket()
                .stroke(Palette.red.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("noted:").font(.hand(14.5))
                Text(line).font(.hand(14.5)).fixedSize(horizontal: false, vertical: true)
                    .animation(.easeOut(duration: 0.2), value: line)
            }
            .foregroundColor(Palette.red)
        }
        .rotationEffect(.degrees(-0.6))
    }
}

/// A manila specimen tag on a string: punched hole on the left, a typed number and label, then the answers.
struct SpecimenTag<Content: View>: View {
    var number: Int
    var label: String
    var tilt: Double = 0
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("No. \(number)").font(.typewriter(11.5)).foregroundColor(Palette.red)
                    Text(label).font(.typewriter(11.5)).foregroundColor(Palette.ink2)
                    Rectangle().fill(Palette.ink.opacity(0.25)).frame(height: 0.8).offset(y: -3)
                }
                content
            }
            .padding(.leading, 46)
            .padding(.trailing, 18)
            .padding(.vertical, 13)
        }
        .frame(maxWidth: 600, alignment: .leading)
        .background(
            TagShape()
                .fill(Color(hex: 0xEFE3C2))
                .overlay(Image(nsImage: PaperGrain.image).resizable(resizingMode: .tile).opacity(0.55).clipShape(TagShape()))
                .overlay(TagShape().stroke(Color(hex: 0xB9A777).opacity(0.7), lineWidth: 0.8))
                .shadow(color: Palette.ink.opacity(0.12), radius: 3, x: 0, y: 2)
        )
        .overlay(alignment: .leading) {
            // Reinforced hole with a bit of string.
            ZStack {
                Circle().fill(Color(hex: 0xE2D3A8)).frame(width: 16, height: 16)
                Circle().stroke(Color(hex: 0xB9A777), lineWidth: 0.8).frame(width: 16, height: 16)
                Circle().fill(Palette.paper).frame(width: 7, height: 7)
                TagString().stroke(Color(hex: 0x9C8F70), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                    .frame(width: 34, height: 26).offset(x: -18, y: -9)
            }
            .padding(.leading, 14)
        }
        .rotationEffect(.degrees(tilt))
    }
}

/// Tag outline with clipped corners on the hole end.
struct TagShape: Shape {
    func path(in r: CGRect) -> Path {
        let c: CGFloat = 14
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 2, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 2), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 2, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.closeSubpath()
        return p
    }
}

private struct TagString: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY),
                   control1: CGPoint(x: r.maxX - 10, y: r.minY - 4),
                   control2: CGPoint(x: r.minX + 12, y: r.maxY + 6))
        return p
    }
}

/// Answers written by hand. Picking one circles it in red pencil (or ticks it, for multiple choice).
struct CircleChoices: View {
    var options: [ProfileOption]
    var selected: Set<String>
    var multiple = false
    var pick: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 16, lineSpacing: 8) {
            ForEach(options) { o in
                let on = selected.contains(o.id)
                Button { withAnimation(.easeOut(duration: 0.28)) { pick(o.id) } } label: {
                    HStack(spacing: 4) {
                        if multiple {
                            ZStack {
                                RoundedRectangle(cornerRadius: 1.5).stroke(Palette.ink.opacity(0.55), lineWidth: 0.9)
                                    .frame(width: 12, height: 12)
                                if on {
                                    CheckMark().stroke(Palette.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                        .frame(width: 13, height: 11).offset(x: 2, y: -2)
                                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                                }
                            }
                        }
                        Text(o.short)
                            .font(.hand(16.5))
                            .foregroundColor(on ? Palette.ink : Palette.ink2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        PencilCircle(seed: o.id.count)
                            .trim(from: 0, to: (on && !multiple) ? 1 : 0)
                            .stroke(Palette.red.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .padding(.horizontal, -3)
                            .padding(.vertical, -2)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(o.label)
                .accessibilityLabel(o.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// A hand-drawn loop: not quite an ellipse, and it overshoots where the pencil started.
struct PencilCircle: Shape {
    var seed: Int = 0

    func path(in r: CGRect) -> Path {
        var p = Path()
        let cx = r.midX, cy = r.midY
        let rx = r.width / 2, ry = r.height / 2
        let start = -2.6 + Double(seed % 5) * 0.12
        let steps = 64
        let sweep = 2 * Double.pi * 1.08
        for i in 0...steps {
            let t = start + sweep * Double(i) / Double(steps)
            let wobble = 1 + 0.035 * sin(3 * t + Double(seed)) + 0.02 * Double(i) / Double(steps)
            let pt = CGPoint(x: cx + CGFloat(cos(t) * wobble) * rx, y: cy + CGFloat(sin(t) * wobble) * ry)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

/// Wraps its children into lines, like words on a page.
struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW { y += lineH + lineSpacing; x = 0; lineH = 0 }
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: maxW.isFinite ? maxW : widest, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > bounds.width { y += lineH + lineSpacing; x = 0; lineH = 0 }
            s.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
    }
}

/// Five pencil ticks along the bottom; the current page's tick is inked.
private struct PageTicks: View {
    var count: Int
    var current: Int
    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Palette.ink : (i < current ? Palette.green.opacity(0.8) : Palette.pencil.opacity(0.45)))
                    .frame(width: i == current ? 18 : 8, height: 2.4)
                    .rotationEffect(.degrees(i % 2 == 0 ? -4 : 3))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
        .accessibilityLabel("Entry \(current + 1) of \(count)")
    }
}

// MARK: - Entry 004: the practice bench

private struct PracticeBench: View {
    @ObservedObject var state: AppState
    @ObservedObject var island: IslandModel
    var explainPractice: (String, String, NSRect) -> Void
    var finished: () -> Void

    @State private var openedIsland = false
    @State private var researchOn = false
    @State private var explained = false
    @State private var added = false
    @State private var researchWasAlreadyOn = false
    @State private var hint = ""

    /// A real paper, so the lookup finds it.
    static let title = "Photosynthesis under drought and salt stress: regulation mechanisms from whole plant to cell"
    static let reference = "Chaves, Flexas & Pinheiro. Annals of Botany, 2009."

    static let passage = "Under drought, plants close their stomata to save water. That limits transpiration, so leaf temperature rises, and with less carbon dioxide reaching the chloroplasts, photorespiration increases and net carbon assimilation falls."

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            // The sample, taped to the bench.
            ZStack(alignment: .topLeading) {
                PaperSheet(corner: 2, graph: false)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample passage, written for this practice")
                        .font(.typewriter(10)).foregroundColor(Palette.ink3)
                    Text("Leaves in a dry spell")
                        .font(.fell(19)).foregroundColor(Palette.ink)
                    PracticeTextView(text: PracticeBench.passage) { text, rect in
                        guard state.researchMode else {
                            hint = "Research mode is off, so nothing happened. Triple-tap right Option first."
                            return
                        }
                        hint = ""
                        explainPractice(text, PracticeBench.passage, rect)
                        if !explained {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { explained = true }
                        }
                    }
                    .frame(height: 176)
                    Rectangle().fill(Palette.pencil.opacity(0.35)).frame(height: 1)
                        .padding(.vertical, 2)
                    Text("Further reading")
                        .font(.typewriter(10)).foregroundColor(Palette.ink3)
                    PracticeTextView(text: PracticeBench.title) { _, _ in }
                        .frame(height: 64)
                    Text(PracticeBench.reference)
                        .font(.text(12.5)).italic().foregroundColor(Palette.ink2)
                    if !hint.isEmpty {
                        Text(hint).font(.hand(13.5)).foregroundColor(Palette.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 16)
                Tape().rotationEffect(.degrees(-5)).offset(x: 24, y: -11)
            }
            .frame(width: 330)
            .fixedSize(horizontal: false, vertical: true)
            .rotationEffect(.degrees(-0.4))
            .shadow(color: Palette.ink.opacity(0.12), radius: 6, x: 0, y: 3)

            // The three tasks; each one stamps itself when you actually do it.
            VStack(alignment: .leading, spacing: 18) {
                Text("Try it for real.")
                    .font(.fell(26)).foregroundColor(Palette.ink)
                TaskRow(number: 1, done: openedIsland,
                        title: "Double-tap the right Option key.",
                        detail: "The island grows out of the notch and opens your trees. Double-tap again, or press Esc, to put it away.")
                TaskRow(number: 2, done: researchOn,
                        title: "Triple-tap it.",
                        detail: researchWasAlreadyOn ? "Research mode was already on, so this one is stamped. Triple-tap turns it off and on."
                                                      : "That turns Research mode on. The island flashes to say so.")
                TaskRow(number: 3, done: explained,
                        title: "Highlight a phrase in the sample.",
                        detail: "Drag across a few words, like \"photorespiration\". A note opens right beside them.")
                TaskRow(number: 4, done: added,
                        title: "Highlight the title under \"Further reading\", then tap right Option once.",
                        detail: "The island finds the paper and asks which tree should get it. Pick one, start a new tree, or say not now.")
                if openedIsland && researchOn && explained && added {
                    Button("All four stamped. Next") { finished() }
                        .buttonStyle(StampButtonStyle(compact: true))
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 8)
        .padding(.horizontal, 6)
        .onAppear {
            if state.researchMode { researchWasAlreadyOn = true; researchOn = true }
            if island.mode == .expanded { openedIsland = true }
        }
        .onChange(of: island.mode) { mode in
            if mode == .expanded && !openedIsland {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { openedIsland = true }
            }
            if mode == .adding && !added {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { added = true }
            }
        }
        .onChange(of: state.researchMode) { on in
            if on && !researchOn {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { researchOn = true }
            }
            if on { hint = "" }
        }
    }
}

private struct TaskRow: View {
    var number: Int
    var done: Bool
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().stroke(Palette.pencil.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if done {
                    ZStack {
                        Circle().stroke(Palette.green, lineWidth: 2)
                        CheckMark().stroke(Palette.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .frame(width: 18, height: 14)
                    }
                    .rotationEffect(.degrees(-10))
                    .transition(.scale(scale: 1.8).combined(with: .opacity))
                } else {
                    Text("\(number)").font(.typewriter(13)).foregroundColor(Palette.pencil)
                }
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.uiBold(14.5))
                    .foregroundColor(done ? Palette.green : Palette.ink)
                    .strikethrough(done, color: Palette.green.opacity(0.6))
                Text(detail)
                    .font(.text(13.5))
                    .foregroundColor(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "Not done")
    }
}

/// The practice passage. A real, selectable text view: highlight a few words and, a moment after
/// you let go, it reports the words and where they sit on screen.
struct PracticeTextView: NSViewRepresentable {
    var text: String
    var onHighlight: (String, NSRect) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onHighlight: onHighlight) }

    func makeNSView(context: Context) -> NSTextView {
        let tv = NSTextView(frame: .zero)
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.isRichText = false
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = false
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 5
        let font = NSFont(name: Typeface.text, size: 16.5) ?? .systemFont(ofSize: 16)
        tv.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: NSColor(Palette.ink), .paragraphStyle: para,
        ]))
        tv.selectedTextAttributes = [.backgroundColor: NSColor(Palette.marker).withAlphaComponent(0.85),
                                     .foregroundColor: NSColor(Palette.ink)]
        tv.delegate = context.coordinator
        return tv
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        context.coordinator.onHighlight = onHighlight
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onHighlight: (String, NSRect) -> Void
        private var pending: DispatchWorkItem?
        private var last = ""

        init(onHighlight: @escaping (String, NSRect) -> Void) { self.onHighlight = onHighlight }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            schedule(tv)
        }

        private func schedule(_ tv: NSTextView) {
            pending?.cancel()
            let work = DispatchWorkItem { [weak self, weak tv] in
                guard let self, let tv else { return }
                // Still dragging: wait for the mouse to come up.
                if NSEvent.pressedMouseButtons & 1 != 0 { self.schedule(tv); return }
                self.fire(tv)
            }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        }

        private func fire(_ tv: NSTextView) {
            let range = tv.selectedRange()
            guard range.length > 0, let storage = tv.textStorage else { return }
            let text = (storage.string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2, text != last else { return }
            guard let lm = tv.layoutManager, let tc = tv.textContainer, let window = tv.window else { return }
            last = text
            let glyphs = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = lm.boundingRect(forGlyphRange: glyphs, in: tc)
            rect.origin.x += tv.textContainerOrigin.x
            rect.origin.y += tv.textContainerOrigin.y
            let inWindow = tv.convert(rect, to: nil)
            onHighlight(text, window.convertToScreen(inWindow))
        }
    }
}

// MARK: - Entry 005

private struct ClosingEntry: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Entry closed.")
                    .font(.fell(34)).foregroundColor(Palette.ink)
                Text("I'll be in the notch. Open a paper, turn on Research mode, and highlight whatever slows you down.")
                    .font(.text(15.5)).foregroundColor(Palette.ink2).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 7) {
                    KeyLine(keys: "right option, twice", does: "open or close the island")
                    KeyLine(keys: "right option, three times", does: "Research mode on or off")
                    KeyLine(keys: "highlight", does: "it explains, a moment after you let go")
                }
                .padding(.top, 16)

                FieldNote(state: state).padding(.top, 20)

                Text("Change any of this in Settings, or redo this setup from there.")
                    .font(.ui(12)).foregroundColor(Palette.ink3)
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                BuddyView(mood: .idle, researchMode: state.researchMode)
                    .frame(width: 120, height: 120)
                (Text("Fig. 5. ").font(.fell(13)) + Text("the flask, off duty").font(.fellItalic(13)))
                    .foregroundColor(Palette.ink3)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }
}

private struct KeyLine: View {
    var keys: String
    var does: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(keys)
                .font(.typewriter(11.5))
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink.opacity(0.5), lineWidth: 0.8))
            Text(does).font(.ui(13)).foregroundColor(Palette.ink2)
        }
    }
}
