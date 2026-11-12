// First-run setup, one small step per page, with the flask buddy acting out each one:
//   welcome; four "about you" questions, one per page, answered in your own words; Accessibility; then four hands-on steps
//   (tap once to open the island, highlight to explain, add a paper, double-tap Research mode);
//   and a last page to celebrate. Pages turn like a notebook; a sprig along the bottom grows a
//   leaf for every page done. Re-open any time from Settings > Redo setup.
import SwiftUI
import AppKit

enum SetupStep: Int, CaseIterable {
    case welcome, school, background, fields, length, permission, tap, highlight, add, research, finish

    var head: String {
        switch self {
        case .welcome: return "Hello"
        case .school, .background, .fields, .length: return "About you"
        case .permission: return "Permission"
        case .tap: return "Open the island"
        case .highlight: return "Explain"
        case .add: return "Add a paper"
        case .research: return "Research mode"
        case .finish: return "All set"
        }
    }

    var act: BuddyAct {
        switch self {
        case .welcome: return .wave
        case .school: return .school
        case .background: return .ponder
        case .fields: return .juggle
        case .length: return .scroll
        case .permission: return .knock
        case .tap: return .tap
        case .highlight: return .peer
        case .add: return .carry
        case .research: return .flip
        case .finish: return .celebrate
        }
    }

    /// The caption under the buddy, like a figure in a field guide.
    var figure: String {
        switch self {
        case .welcome: return "the flask, saying hello"
        case .school: return "the flask, ready for class"
        case .background: return "the flask, wondering"
        case .fields: return "the flask, juggling subjects"
        case .length: return "the flask, measuring a note"
        case .permission: return "the flask, knocking politely"
        case .tap: return "the flask, pressing right Option"
        case .highlight: return "the flask, peering closer"
        case .add: return "the flask, planting a paper"
        case .research: return "the flask, goggles on"
        case .finish: return "the flask, delighted"
        }
    }

    var isPractice: Bool { [.tap, .highlight, .add, .research].contains(self) }

    /// The "about you" question this page asks, if any.
    var question: ReaderQuestion? {
        switch self {
        case .school: return .school
        case .background: return .background
        case .fields: return .fields
        case .length: return .length
        default: return nil
        }
    }
}

struct SetupView: View {
    @ObservedObject var state: AppState
    @ObservedObject var island: IslandModel
    /// Shows a real explanation card for a highlight in the practice passage.
    var explainPractice: (_ text: String, _ context: String, _ screenRect: NSRect) -> Void
    var done: () -> Void

    /// After an update replay: leave out the Accessibility page while permission is granted.
    var skipPermissionIfGranted = false
    @State private var step: SetupStep
    @State private var forward = true
    /// Practice steps really done.
    @State private var did: Set<SetupStep> = []
    /// Bumped when something real happens, so the buddy can react.
    @State private var pulse = 0
    @State private var researchWasOn = false
    @State private var hint = ""
    @State private var asked = false
    private let poll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    init(state: AppState, island: IslandModel, skipPermissionIfGranted: Bool = false, initialStep: Int = 0,
         explainPractice: @escaping (_ text: String, _ context: String, _ screenRect: NSRect) -> Void,
         done: @escaping () -> Void) {
        self.state = state
        self.island = island
        self.explainPractice = explainPractice
        self.done = done
        self.skipPermissionIfGranted = skipPermissionIfGranted
        _step = State(initialValue: SetupStep(rawValue: initialStep) ?? .welcome)
    }

    static let size = NSSize(width: 720, height: 560)

    /// A real paper, so the lookup finds it.
    static let paperTitle = "Photosynthesis under drought and salt stress: regulation mechanisms from whole plant to cell"
    static let reference = "Chaves, Flexas & Pinheiro. Annals of Botany, 2009."
    static let passage = "Under drought, plants close their stomata to save water. That limits transpiration, so leaf temperature rises, and with less carbon dioxide reaching the chloroplasts, photorespiration increases and net carbon assimilation falls."

    var body: some View {
        VStack(spacing: 0) {
            runningHead
            ZStack {
                page
                    .id(step)
                    .transition(.pageTurn(forward: forward))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            footer
        }
        .padding(.top, 26)
        .padding(.horizontal, 30)
        .padding(.bottom, 18)
        .frame(width: SetupView.size.width, height: SetupView.size.height)
        .background(DeskBackground().ignoresSafeArea())
        .onReceive(poll) { _ in
            let trusted = Accessibility.isTrusted
            if trusted != state.accessibilityGranted {
                withAnimation(Motion.pick(Motion.land)) { state.accessibilityGranted = trusted }
                state.refreshMood()
                if trusted { pulse += 1 }
            }
        }
        .onAppear { researchWasOn = state.researchMode }
        .onChange(of: island.mode) { mode in
            if step == .tap && mode == .expanded { stamp(.tap) }
            if step == .add && mode == .adding { stamp(.add) }
        }
        .onChange(of: state.researchMode) { on in
            if step == .research && on { stamp(.research) }
            if on { hint = "" }
        }
    }

    private func stamp(_ s: SetupStep) {
        withAnimation(Motion.pick(Motion.land)) { _ = did.insert(s) }
        pulse += 1
    }

    // MARK: Chrome

    private var runningHead: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Paper Tree, field notes on reading")
                Spacer()
                // Only the entry number: the sprig at the bottom is the one progress bar.
                Text(String(format: "Entry %02d", step.rawValue + 1))
            }
            .font(.typewriter(10.5))
            .foregroundColor(Palette.ink3)
            .padding(.horizontal, 6)
            Rectangle().fill(Palette.ink.opacity(0.55)).frame(height: 0.8)
        }
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            Group {
                if step == .welcome {
                    Button("Skip setup") { done() }
                        .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                } else if step != .finish {
                    Button("Back") { go(-1) }
                        .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                }
            }
            .frame(width: 120, alignment: .leading)
            Spacer()
            ProgressSprig(count: SetupStep.allCases.count, current: step.rawValue)
                .frame(width: 280, height: 34)
            Spacer()
            Group {
                switch step {
                case .welcome:
                    Button("Begin") { go(1) }.buttonStyle(StampButtonStyle())
                case .permission where !state.accessibilityGranted:
                    Button("I'll do this later") { go(1) }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                case .finish:
                    Button("Start reading") { done() }.buttonStyle(StampButtonStyle())
                default:
                    if let q = step.question,
                       state.answer(q).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Skip for now") { go(1) }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                    } else if step.isPractice && !did.contains(step) {
                        Button("Skip this step") { go(1) }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                    } else {
                        Button("Next") { go(1) }.buttonStyle(StampButtonStyle())
                    }
                }
            }
            .frame(width: 140, alignment: .trailing)
        }
        .frame(height: 44)
        .padding(.top, 10)
        .padding(.horizontal, 6)
    }

    private func go(_ by: Int) {
        var next = step.rawValue + by
        // Hop over the permission page when it has nothing to ask.
        if next == SetupStep.permission.rawValue && skipPermissionIfGranted && state.accessibilityGranted { next += by }
        guard let s = SetupStep(rawValue: max(0, min(SetupStep.allCases.count - 1, next))) else { return }
        forward = by > 0
        hint = ""
        if s == .research { researchWasOn = state.researchMode }
        withAnimation(Motion.pick(Motion.page)) { step = s }
    }

    // MARK: Pages

    private var page: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                BuddyStage(act: step.act, research: state.researchMode, granted: state.accessibilityGranted, pulse: pulse)
                    .frame(width: 250, height: 290)
                (Text("Fig. \(step.rawValue + 1). ").font(.typewriter(11)) + Text(step.figure).font(.text(13)))
                    .foregroundColor(Palette.ink3)
            }
            .frame(width: 258)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 20)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func kicker(_ s: String) -> some View {
        Text(s).font(.typewriter(11)).foregroundColor(Palette.red).padding(.bottom, 6)
    }

    private func title(_ s: String) -> some View {
        Text(s).font(.fell(32)).foregroundColor(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ s: String) -> some View {
        Text(s).font(.text(15.5)).foregroundColor(Palette.ink2).lineSpacing(2.5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            kicker("a hello")
            title("Hello. I'm the flask.")
            line("I live in your Mac's notch. Highlight something hard in a paper and I'll explain it in plain words. Add the papers you read and I'll grow them into trees.")
            handNote("This takes about two minutes, one small step at a time.")
                .padding(.top, 22)
        case .school, .background, .fields, .length:
            if let q = step.question { question(q) }
        case .permission:
            kicker("permission")
            title("Let me see what you highlight.")
            line("To read highlights in Preview, Chrome or Word, macOS has to let me in under Accessibility. I only read the words you highlight, and only while Research mode is on. I never see what you type.")
            permissionAction.padding(.top, 20)
        case .tap:
            kicker("try it")
            title("Tap the right Option key once.")
            line("The island grows out of the notch and shows your trees. Tap again, or press Esc, to put it away.")
            DoneLine(done: did.contains(.tap), waiting: "Waiting for a tap on right Option.", yes: "Opened. That's the island.")
                .padding(.top, 20)
        case .highlight:
            kicker("try it")
            title("Highlight a phrase.")
            line("Drag across a few words in the sample, like \"photorespiration\". A note opens right beside them.")
            passageSheet.padding(.top, 14)
            DoneLine(done: did.contains(.highlight), waiting: "Waiting for a highlight.", yes: "Explained. Close the note whenever you like.")
                .padding(.top, 12)
        case .add:
            kicker("try it")
            title("Add a paper to a tree.")
            line("Highlight the title below, tap right Option, then choose Add this paper. I'll find it and ask which tree should get it.")
            titleSheet.padding(.top, 14)
            DoneLine(done: did.contains(.add), waiting: "Waiting for Add this paper.", yes: "Found it. Pick a tree, or plant a new one.")
                .padding(.top, 12)
        case .research:
            kicker("try it")
            title("Double-tap for Research mode.")
            line("Double-tap right Option. The island flashes, and from then on I explain whatever you highlight, in any app. Double-tap again to stop.")
            DoneLine(done: did.contains(.research),
                     waiting: researchWasOn ? "Research mode is already on. Double-tap to switch it off, then again to switch it back on." : "Waiting for a double tap.",
                     yes: "Research mode is on. Goggles on.")
                .padding(.top, 20)
        case .finish:
            kicker("done")
            HStack(alignment: .center, spacing: 14) {
                title("You're all set.")
                FinishStamp()
            }
            line("I'll be in the notch. Open a paper, turn on Research mode, and highlight whatever slows you down.")
            VStack(alignment: .leading, spacing: 7) {
                KeyLine(taps: 1, does: "Tap right Option once to open or close the island, and add what you highlighted.")
                KeyLine(taps: 2, does: "Tap it twice for Research mode, on or off.")
                KeyLine(taps: 0, does: "Highlight a line and it explains, a moment after you let go.")
            }
            .padding(.top, 16)
            FieldNote(state: state).padding(.top, 18)
        }
    }

    /// One "about you" question: the prompt, then a specimen tag with ruled lines to write on,
    /// and a quiet hint underneath. Nothing is required; an empty answer just moves on.
    @ViewBuilder private func question(_ q: ReaderQuestion) -> some View {
        kicker("about you")
        title(q.title)
        line(q.invite)
        SpecimenTag(number: q.rawValue + 1, total: ReaderQuestion.allCases.count, label: q.tag,
                    tilt: [-0.6, 0.5, 0.4, -0.5][q.rawValue]) {
            LongAnswerField(text: answerBinding(q), placeholder: q.placeholder,
                            accessibilityName: q.accessibilityName, focusOnAppear: true)
        }
        .padding(.top, 18)
        Text(q.hint)
            .font(.text(12.5))
            .foregroundColor(Palette.ink3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 9)
            .padding(.leading, 46)
    }

    private func answerBinding(_ q: ReaderQuestion) -> Binding<String> {
        Binding(get: { state.answer(q) }, set: { new in
            let old = state.answer(q)
            state.setAnswer(q, new)
            // The flask answers when you start writing, and again at the end of each sentence.
            let ended = new.count > old.count && (new.last.map { ".!?".contains($0) } ?? false)
            if (old.isEmpty && !new.isEmpty) || ended { pulse += 1 }
        })
    }

    private func handNote(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            MarginBracket()
                .stroke(Palette.red.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 26)
            Text(s).font(.hand(15.5)).foregroundColor(Palette.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .rotationEffect(.degrees(-0.8))
    }

    @ViewBuilder private var permissionAction: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 9) {
                if state.accessibilityGranted {
                    Text("You're in. I can see highlights now.").font(.text(15)).foregroundColor(Palette.ink2)
                } else {
                    Button("Let me read highlights") {
                        asked = true
                        Accessibility.requestTrust()
                        Accessibility.openAccessibilitySettings()
                    }
                    .buttonStyle(StampButtonStyle())
                    Text("Privacy & Security  >  Accessibility  >  Paper Tree")
                        .font(.typewriter(10.5)).foregroundColor(Palette.ink3)
                    if asked {
                        Text("Already switched on? Switch it off and on again, and I'll see it.")
                            .font(.ui(12.5)).foregroundColor(Palette.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer()
            ApprovalStamp(granted: state.accessibilityGranted).scaleEffect(0.8)
        }
    }

    private var passageSheet: some View {
        ZStack(alignment: .topLeading) {
            PaperSheet(corner: 2, graph: false)
            VStack(alignment: .leading, spacing: 6) {
                Text("Leaves in a dry spell").font(.fell(17)).foregroundColor(Palette.ink)
                if Snapshots.isRendering {
                    Text(SetupView.passage).font(.text(15)).foregroundColor(Palette.ink).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true).frame(height: 110, alignment: .top)
                } else {
                    PracticeTextView(text: SetupView.passage, size: 15) { text, rect in
                        hint = ""
                        explainPractice(text, SetupView.passage, rect)
                        stamp(.highlight)
                    }
                    .frame(height: 110)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)
            Tape().rotationEffect(.degrees(-5)).offset(x: 20, y: -11)
        }
        .fixedSize(horizontal: false, vertical: true)
        .rotationEffect(.degrees(-0.4))
        .shadow(color: Palette.ink.opacity(0.12), radius: 5, x: 0, y: 3)
    }

    private var titleSheet: some View {
        ZStack(alignment: .topLeading) {
            PaperSheet(corner: 2, graph: false)
            VStack(alignment: .leading, spacing: 6) {
                Text("Further reading").font(.typewriter(10)).foregroundColor(Palette.ink3)
                if Snapshots.isRendering {
                    Text(SetupView.paperTitle).font(.text(15)).foregroundColor(Palette.ink).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true).frame(height: 44, alignment: .top)
                } else {
                    PracticeTextView(text: SetupView.paperTitle, size: 15) { _, _ in }
                        .frame(height: 44)
                }
                Text(SetupView.reference).font(.text(12.5)).foregroundColor(Palette.ink2)
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)
            Tape().rotationEffect(.degrees(4)).offset(x: 180, y: -11)
        }
        .fixedSize(horizontal: false, vertical: true)
        .rotationEffect(.degrees(0.4))
        .shadow(color: Palette.ink.opacity(0.12), radius: 5, x: 0, y: 3)
    }
}

/// "Waiting for..." in pencil, then a green stamp once it's done.
private struct DoneLine: View {
    var done: Bool
    var waiting: String
    var yes: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle().stroke(Palette.pencil.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if done {
                    ZStack {
                        Circle().stroke(Palette.green, lineWidth: 2)
                        CheckMark().stroke(Palette.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .frame(width: 16, height: 12)
                    }
                    .rotationEffect(.degrees(-10))
                    .transition(.scale(scale: 1.8).combined(with: .opacity))
                }
            }
            .frame(width: 30, height: 30)
            Text(done ? yes : waiting)
                .font(.ui(12.5))
                .foregroundColor(done ? Palette.green : Palette.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "Not done")
    }
}

/// The progress line along the bottom: a sprig that puts out a leaf for each page done, with a
/// bud on the page you're on.
struct ProgressSprig: View {
    var count: Int
    var current: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let gap = w / CGFloat(max(1, count - 1))
            ZStack(alignment: .topLeading) {
                SprigStem(count: count)
                    .stroke(Color(hex: 0x6E553F).opacity(0.8), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                ForEach(0..<count, id: \.self) { i in
                    let x = CGFloat(i) * gap
                    let y = h / 2 + CGFloat(sin(Double(i) * 1.3)) * 2
                    let up = i % 2 == 0
                    ZStack {
                        if i < current {
                            SprigLeaf()
                                .fill(Color(hex: 0x7F9C6B))
                                .overlay(SprigLeaf().stroke(Palette.ink.opacity(0.55), lineWidth: 0.7))
                                .frame(width: 13, height: 7)
                                .rotationEffect(.degrees(up ? -40 : 40), anchor: .leading)
                                .offset(x: 6, y: 0)
                                .transition(.scale(scale: 0.01, anchor: .leading).combined(with: .opacity))
                        }
                        if i == count - 1 && current == count - 1 {
                            // The last page: its leaf unfurls instead of a bud.
                            UnfurlingLeaf(up: up)
                        }
                        let finished = current == count - 1
                        Circle()
                            .fill(i == current && !finished ? Palette.red : (i <= current ? Color(hex: 0x6E553F) : Palette.pencil.opacity(0.4)))
                            .frame(width: i == current && !finished ? 9 : 4, height: i == current && !finished ? 9 : 4)
                        if i == current && !finished {
                            Circle().stroke(Palette.red.opacity(0.5), lineWidth: 1).frame(width: 15, height: 15)
                        }
                    }
                    .position(x: x, y: y)
                }
            }
        }
        .animation(Motion.pick(Motion.settle), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

private struct SprigStem: Shape {
    var count: Int
    func path(in r: CGRect) -> Path {
        var p = Path()
        let gap = r.width / CGFloat(max(1, count - 1))
        p.move(to: CGPoint(x: 0, y: r.midY))
        for i in 1..<max(2, count) {
            let x = CGFloat(i) * gap
            let y = r.midY + CGFloat(sin(Double(i) * 1.3)) * 2
            p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - gap / 2, y: r.midY + (i % 2 == 0 ? 2.5 : -2.5)))
        }
        return p
    }
}

private struct SprigLeaf: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.3))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.3))
        return p
    }
}

// MARK: - Shared pieces (also used by Settings)

/// A red-pen note that quotes the reader's own answers back, so they can see they were heard.
struct FieldNote: View {
    @ObservedObject var state: AppState
    /// Longest quote per answer, in characters.
    var limit = 46

    private var quotes: [String] {
        ReaderQuestion.allCases.compactMap { ReaderProfile.quote(state.answer($0), limit: limit) }
    }

    private var line: String {
        let q = quotes
        if q.isEmpty { return "nothing noted yet. That's fine too, I'll assume a curious high schooler." }
        return q.map { "\u{201C}\($0)\u{201D}" }.joined(separator: "  ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MarginBracket()
                .stroke(Palette.red.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(quotes.isEmpty ? "noted:" : "noted, in your words:").font(.hand(14.5))
                Text(line).font(.hand(14.5)).fixedSize(horizontal: false, vertical: true)
                    .lineLimit(5)
                    .animation(Motion.pick(Motion.snappy), value: line)
            }
            .foregroundColor(Palette.red)
        }
        .rotationEffect(.degrees(-0.6))
        .accessibilityElement(children: .combine)
    }
}

/// A manila specimen tag on a string: punched hole on the left, a typed number and label, then the answers.
struct SpecimenTag<Content: View>: View {
    var number: Int
    var total: Int? = nil
    var label: String
    var tilt: Double = 0
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(total.map { "Q. \(number) of \($0)" } ?? "No. \(number)").font(.typewriter(11.5)).foregroundColor(Palette.red)
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

/// The practice passage. A real, selectable text view: highlight a few words and, a moment after
/// you let go, it reports the words and where they sit on screen.
struct PracticeTextView: NSViewRepresentable {
    var text: String
    var size: CGFloat = 16.5
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
        let font = NSFont(name: Typeface.text, size: size) ?? .systemFont(ofSize: size)
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

/// A key drawn in ink, the same keycap as Settings Fig. 1 at 0.7 scale (two keys for a double tap,
/// a marker swipe for a highlight), then what it does in plain words.
private struct KeyLine: View {
    var taps: Int
    var does: String
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 5) {
                if taps == 0 {
                    Text("highlight").font(.typewriter(11.5)).foregroundColor(Palette.ink)
                        .padding(.horizontal, 3)
                        .background(Palette.marker.opacity(0.6).padding(.vertical, 1).rotationEffect(.degrees(-1.5)))
                } else {
                    ForEach(0..<taps, id: \.self) { i in
                        DrawnKey(width: 60, tilt: i == 0 ? -0.5 : 0.6) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack { Spacer(); Text("\u{2325}").font(.system(size: 10.5)) }
                                Spacer(minLength: 0)
                                Text("option").font(.ui(9.5))
                            }
                            .foregroundColor(Palette.ink2)
                            .padding(.horizontal, 6).padding(.vertical, 5)
                        }
                        .scaleEffect(0.7)
                        .frame(width: 42, height: 30)
                    }
                }
            }
            .frame(width: 96, alignment: .leading)
            Text(does).font(.text(14)).foregroundColor(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The green APPROVED stamp from the permission page, landing once beside the finish title.
private struct FinishStamp: View {
    @State private var landed = false
    var body: some View {
        ApprovalStamp(granted: landed || Snapshots.isRendering, caption: "set up")
            .scaleEffect(0.62)
            .frame(width: 70, height: 70)
            .onAppear {
                guard !landed else { return }
                withAnimation(Motion.pick(Motion.land).delay(0.1)) { landed = true }
            }
    }
}

/// The sprig's last leaf, unfurling once: it grows from a curl and turns a little as it opens.
private struct UnfurlingLeaf: View {
    var up: Bool
    @State private var open = false
    var body: some View {
        let shown = open || Snapshots.isRendering
        SprigLeaf()
            .fill(Palette.green.opacity(0.85))
            .overlay(SprigLeaf().stroke(Palette.ink.opacity(0.55), lineWidth: 0.7))
            .frame(width: 17, height: 9)
            .scaleEffect(shown ? 1 : 0.3, anchor: .leading)
            .rotationEffect(.degrees((up ? -40 : 40) + (shown ? 0 : (up ? -12 : 12))), anchor: .leading)
            .offset(x: 8, y: 0)
            .onAppear { withAnimation(Motion.pick(Motion.settle)) { open = true } }
    }
}
