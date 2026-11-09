// The podcast in the reader. The rail's Listen tab holds the invitation, the recording session
// and the transcript; the deck (a slip of paper docked under the page) plays the episode.
import AppKit
import SwiftUI

// MARK: The Listen tab

struct ListenPanel: View {
    @ObservedObject var podcast: PodcastModel
    @ObservedObject var reader: ReaderModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch podcast.phase {
            case .empty:
                PodcastInvite(podcast: podcast, reader: reader, problem: nil).transition(.listenSwap)
            case .failed(let msg):
                PodcastInvite(podcast: podcast, reader: reader, problem: msg).transition(.listenSwap)
            case .making:
                PodcastSession(podcast: podcast).transition(.listenSwap)
            case .ready:
                PodcastTranscript(podcast: podcast, reader: reader).transition(.listenSwap)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(Motion.pick(Motion.page), value: podcast.phase)
    }
}

extension AnyTransition {
    /// A sheet in the notebook giving way to the next: rises in through a soft blur.
    static var listenSwap: AnyTransition {
        if Motion.reduced { return .opacity }
        return .asymmetric(insertion: .modifier(active: BlurRise(amount: 1), identity: BlurRise(amount: 0)),
                           removal: .opacity.animation(.easeOut(duration: 0.14)))
    }
}

/// Before there is an episode: who the hosts are, what it costs in time, and the button.
struct PodcastInvite: View {
    @ObservedObject var podcast: PodcastModel
    @ObservedObject var reader: ReaderModel
    var problem: String?

    private var fromAbstract: Bool { reader.status != .ready }
    private var enough: Bool { reader.status == .ready || reader.paper.abstract.count >= 400 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Listen to this paper").font(.fell(23)).foregroundColor(Palette.ink).entrance(0)
            Text("Two AI hosts talk it through in plain words. Juniper asks what you might ask. Rowan explains, using only what the paper says.")
                .font(.text(13.5)).foregroundColor(Palette.ink2).lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .entrance(1)
            HStack(spacing: 12) {
                HostTag(speaker: "Juniper").rotationEffect(.degrees(-2))
                HostTag(speaker: "Rowan").rotationEffect(.degrees(1.4)).offset(y: 4)
            }
            .padding(.vertical, 4)
            .entrance(2)
            VStack(alignment: .leading, spacing: 4) {
                fact("about 3 to 6 minutes long")
                fact("takes a minute or two to make")
                fact("kept with the paper for next time")
            }
            .entrance(3)
            if fromAbstract {
                Text(enough ? "There's no PDF here, so they'll only have the abstract to go on." : "There isn't enough text here for a podcast. It needs the PDF or a longer abstract.")
                    .font(.hand(14)).foregroundColor(Palette.red).rotationEffect(.degrees(-0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let problem {
                HStack(alignment: .top, spacing: 8) {
                    Rectangle().fill(Palette.red.opacity(0.75)).frame(width: 3)
                    Text(problem).font(.text(12.5)).foregroundColor(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
                .transition(.opacity)
            }
            Button {
                let src = reader.podcastText()
                podcast.make(text: src.text, source: src.source)
            } label: {
                Label(problem == nil ? "Make podcast" : "Try again", systemImage: "headphones")
            }
            .buttonStyle(StampButtonStyle())
            .disabled(!enough)
            .opacity(enough ? 1 : 0.45)
            .padding(.top, 2)
            .entrance(4)
            Text("Made by AI from the paper's text, so it can get things wrong. Check anything that matters against the page.")
                .font(.hand(13)).foregroundColor(Palette.pencil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .entrance(5)
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private func fact(_ s: String) -> some View {
        HStack(spacing: 7) {
            Circle().fill(Palette.ink3).frame(width: 3, height: 3)
            Text(s).font(.typewriter(10.5)).foregroundColor(Palette.ink3)
        }
    }
}

/// A manila specimen tag for a host: name typed, role in their ink, a hole for the string.
struct HostTag: View {
    var speaker: String

    var body: some View {
        HStack(spacing: 8) {
            Circle().strokeBorder(Palette.ink.opacity(0.35), lineWidth: 0.8)
                .background(Circle().fill(Color(hex: 0xDCD2BB)))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: -1) {
                Text(speaker.uppercased()).font(.typewriter(10.5)).foregroundColor(Palette.ink)
                Text(PodcastHost.role(speaker)).font(.hand(15)).foregroundColor(PodcastHost.pen(speaker))
            }
            Rectangle().fill(PodcastHost.ink(speaker).swatch).frame(width: 4, height: 26).cornerRadius(1)
        }
        .padding(.leading, 9).padding(.trailing, 10).padding(.vertical, 6)
        .background(
            HostTagShape().fill(Color(hex: 0xEADDB9))
                .overlay(Image(nsImage: PaperGrain.image).resizable(resizingMode: .tile).opacity(0.5).clipShape(HostTagShape()))
                .shadow(color: .black.opacity(0.14), radius: 1.5, x: 0.5, y: 1)
        )
        .overlay(HostTagShape().stroke(Palette.ink.opacity(0.22), lineWidth: 0.7))
        .accessibilityElement(children: .combine)
    }
}

/// A shipping tag: square on the right, corners clipped on the left where the string goes.
struct HostTagShape: Shape {
    func path(in r: CGRect) -> Path {
        let c = min(9, r.height * 0.3)
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

// MARK: Recording: an honest log of what is happening, with the flask keeping you company

struct PodcastSession: View {
    @ObservedObject var podcast: PodcastModel

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recording").font(.fell(23)).foregroundColor(Palette.ink)
                Spacer()
                if let s = podcast.startedAt { Elapsed(since: s).font(.typewriter(12)).foregroundColor(Palette.ink3) }
            }
            Text("Usually a minute or two. You can keep reading while it works.")
                .font(.text(12.5)).foregroundColor(Palette.ink3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: 8) {
                BuddyView(mood: .thinking, researchMode: true).frame(width: 54, height: 54)
                Text(flaskSays)
                    .font(.hand(15.5)).foregroundColor(Color(hex: 0x23314A))
                    .fixedSize(horizontal: false, vertical: true)
                    .id(flaskSays)
                    .transition(Motion.reduced ? .opacity : .opacity.combined(with: .offset(y: 4)))
            }
            .animation(Motion.pick(Motion.snappy), value: flaskSays)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(PodcastModel.Step.allCases, id: \.rawValue) { s in entry(s) }
            }
            .padding(.vertical, 2)
            TapeStrip(peaks: podcast.draftPeaks, done: podcast.partsDone, total: podcast.partsTotal)
                .frame(height: 34)
            scriptPreview
            Button("Stop recording") { podcast.cancel() }
                .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                .font(.ui(11.5))
        }
        .padding(.top, 6)
    }

    private var flaskSays: String {
        switch podcast.step {
        case .reading: return "Reading it through first."
        case .writing: return "Juniper and Rowan are writing their lines."
        case .recording: return podcast.waitingUntil != nil ? "The voice model is busy. Waiting our turn." : "Quiet, please. We're recording."
        case .binding: return "Putting the parts together."
        }
    }

    private func title(_ s: PodcastModel.Step) -> String {
        switch s {
        case .reading: return "Read the paper"
        case .writing: return "Write the script"
        case .recording: return "Record the voices"
        case .binding: return "Bind the episode"
        }
    }

    @ViewBuilder private func detail(_ s: PodcastModel.Step) -> some View {
        let done = podcast.stepDone[s] != nil
        switch s {
        case .reading:
            Text(podcast.readNote)
        case .writing:
            if done { Text("\(podcast.draft.count) lines") } else if podcast.step == s, let t = podcast.stepStarted[s] { Elapsed(since: t) }
        case .recording:
            if let until = podcast.waitingUntil {
                Countdown(until: until)
            } else if podcast.partsTotal > 0 {
                Text("part \(min(podcast.partsDone + (done ? 0 : 1), podcast.partsTotal)) of \(podcast.partsTotal)")
            }
        case .binding:
            if podcast.step == s && !done { Text("saving") }
        }
    }

    private func entry(_ s: PodcastModel.Step) -> some View {
        let done = podcast.stepDone[s] != nil
        let active = podcast.step == s && !done
        return HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text("\(s.rawValue + 1).").font(.typewriter(11)).foregroundColor(Palette.ink3).frame(width: 18, alignment: .leading)
            Text(title(s)).font(.text(13.5))
                .foregroundColor(done || active ? Palette.ink : Palette.ink3.opacity(0.7))
            Spacer(minLength: 6)
            detail(s).font(.typewriter(10)).foregroundColor(Palette.ink3).lineLimit(1)
            ZStack {
                if done {
                    PenTick().stroke(Palette.green, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 13, height: 11)
                        .transition(Motion.reduced ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
                } else if active {
                    PencilDots()
                }
            }
            .frame(width: 18, height: 12)
            .animation(Motion.pick(Motion.land), value: done)
        }
    }

    @ViewBuilder private var scriptPreview: some View {
        if podcast.draft.isEmpty {
            ScriptScribble(count: 6).frame(height: 96).padding(.top, 4)
        } else {
            GroveScroll(axis: .vertical) {
                VStack(alignment: .leading, spacing: 7) {
                    if !podcast.draftTitle.isEmpty {
                        Text(podcast.draftTitle).font(.fellItalic(16)).foregroundColor(Palette.ink)
                    }
                    ForEach(podcast.draft) { l in
                        let inked = podcast.recorded.contains(l.id)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(l.speaker.prefix(1)).font(.typewriter(10)).foregroundColor(PodcastHost.pen(l.speaker))
                                .frame(width: 10)
                            Text(l.text).font(.text(12)).foregroundColor(inked ? Palette.ink2 : Palette.pencil.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .animation(Motion.pick(.easeOut(duration: 0.6)), value: inked)
                    }
                }
                .padding(.vertical, 4)
            }
            .mask(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
        }
    }
}

/// A pen tick, drawn rather than typeset.
struct PenTick: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.05))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.36, y: r.maxY), control: CGPoint(x: r.minX + r.width * 0.2, y: r.midY + r.height * 0.3))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.minX + r.width * 0.55, y: r.midY - r.height * 0.1))
        return p
    }
}

/// Three pencil dots that take turns, for the step in progress.
struct PencilDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: Motion.reduced || Snapshots.isRendering)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (sin(t * 4.2 - Double(i) * 0.9) + 1) / 2
                    Circle().fill(Palette.ink2.opacity(0.25 + 0.6 * phase)).frame(width: 3.2, height: 3.2)
                        .offset(y: Motion.reduced ? 0 : -1.6 * phase)
                }
            }
        }
    }
}

/// Lines of pencil writing themselves, while the script is being written.
struct ScriptScribble: View {
    var count: Int
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: Motion.reduced || Snapshots.isRendering)) { tl in
            let t = Motion.reduced || Snapshots.isRendering ? 2.6 : tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let period = 6.5
                let cycle = t.truncatingRemainder(dividingBy: period) / period
                let fade = cycle > 0.88 ? (1 - (cycle - 0.88) / 0.12) : 1
                let gap = size.height / CGFloat(count)
                for i in 0..<count {
                    let reveal = max(0, min(1, cycle * 1.25 * Double(count) - Double(i)))
                    guard reveal > 0 else { continue }
                    let width = size.width * (i == count - 1 ? 0.55 : 0.82 + 0.14 * CGFloat(sin(Double(i) * 2.3)))
                    var p = Path()
                    let y = gap * (CGFloat(i) + 0.6)
                    let end = width * CGFloat(reveal)
                    p.move(to: CGPoint(x: 0, y: y))
                    var x: CGFloat = 0
                    while x < end {
                        x = min(end, x + 4)
                        p.addLine(to: CGPoint(x: x, y: y + 1.6 * CGFloat(sin(Double(x) / 5.5 + Double(i))) + 0.7 * CGFloat(sin(Double(x) / 1.7))))
                    }
                    ctx.stroke(p, with: .color(Palette.pencil.opacity(0.55 * fade)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The tape so far: each recorded part's real loudness, filling a strip marked out in parts.
struct TapeStrip: View {
    var peaks: [Float]
    var done: Int
    var total: Int

    var body: some View {
        Canvas { ctx, size in
            let n = max(1, total)
            let frame = Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2)
            ctx.fill(frame, with: .color(Color.white.opacity(0.45)))
            ctx.stroke(frame, with: .color(Palette.ink.opacity(0.18)), lineWidth: 0.7)
            for k in 1..<n {
                let x = size.width * CGFloat(k) / CGFloat(n)
                var p = Path(); p.move(to: CGPoint(x: x, y: 4)); p.addLine(to: CGPoint(x: x, y: size.height - 4))
                ctx.stroke(p, with: .color(Palette.pencil.opacity(0.45)), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2.5]))
            }
            guard !peaks.isEmpty, done > 0 else { return }
            // Where the finished parts reach, assuming the rest run about as long.
            let filled = size.width * CGFloat(done) / CGFloat(n)
            let step = filled / CGFloat(peaks.count)
            let mid = size.height / 2
            var bars = Path()
            for (i, v) in peaks.enumerated() {
                let x = step * (CGFloat(i) + 0.5)
                let h = max(1.2, CGFloat(v) * (size.height - 10) / 2)
                bars.move(to: CGPoint(x: x, y: mid - h)); bars.addLine(to: CGPoint(x: x, y: mid + h))
            }
            ctx.stroke(bars, with: .color(Palette.ink2.opacity(0.75)), style: StrokeStyle(lineWidth: max(0.8, min(1.6, step * 0.6)), lineCap: .round))
        }
        .accessibilityLabel("Recorded \(done) of \(total) parts")
    }
}

struct Elapsed: View {
    var since: Date
    var body: some View {
        TimelineView(.periodic(from: since, by: 1)) { tl in
            Text(max(0, tl.date.timeIntervalSince(since)).clock).monospacedDigit()
        }
    }
}

struct Countdown: View {
    var until: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            Text("busy, again in " + max(0, until.timeIntervalSince(tl.date)).rounded(.up).clock).monospacedDigit()
        }
    }
}

// MARK: The transcript

struct PodcastTranscript: View {
    @ObservedObject var podcast: PodcastModel
    @ObservedObject var reader: ReaderModel
    @State private var confirmNew = false

    var body: some View {
        if let ep = podcast.episode {
            VStack(alignment: .leading, spacing: 10) {
                header(ep)
                Rectangle().fill(Palette.ink.opacity(0.18)).frame(height: 0.8)
                ScrollViewReader { proxy in
                    GroveScroll(axis: .vertical) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(ep.lines) { l in
                                TranscriptLine(line: l, state: state(of: l), onTap: { podcast.jump(to: l) })
                                    .id(l.id)
                            }
                            Text("That's the episode.").font(.hand(14)).foregroundColor(Palette.pencil)
                                .padding(.top, 10).padding(.leading, 8)
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: podcast.currentLine) { i in
                        guard podcast.follow, let i else { return }
                        withAnimation(Motion.pick(Motion.page)) { proxy.scrollTo(i, anchor: UnitPoint(x: 0, y: 0.28)) }
                    }
                }
                footer
            }
            .padding(.top, 4)
        }
    }

    private func state(of l: PodcastLine) -> TranscriptLine.State {
        guard let c = podcast.currentLine else { return .ahead }
        return l.id == c ? .now : (l.id < c ? .heard : .ahead)
    }

    private func header(_ ep: PodcastEpisode) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("AI podcast, \(Int((ep.duration / 60).rounded(.down))) min \(Int(ep.duration) % 60) s" + (ep.source == "abstract" ? ", from the abstract" : ""))
                .font(.typewriter(10)).foregroundColor(Palette.ink3)
            Text(ep.title).font(.fell(20)).foregroundColor(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                ForEach(["Juniper", "Rowan"], id: \.self) { s in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1).fill(PodcastHost.ink(s).swatch).frame(width: 9, height: 4)
                        Text("\(s) \(PodcastHost.role(s))").font(.hand(13.5)).foregroundColor(PodcastHost.pen(s))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            if podcast.justMade {
                RecordedStamp()
                    .rotationEffect(.degrees(-9))
                    .offset(x: 2, y: -4)
                    .transition(Motion.reduced ? .opacity : .scale(scale: 1.8).combined(with: .opacity))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Palette.ink.opacity(0.18)).frame(height: 0.8)
            Button {
                withAnimation(Motion.pick(Motion.snappy)) { podcast.follow.toggle() }
                if !podcast.follow { reader.clearFollow() }
            } label: {
                HStack(spacing: 7) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.ink.opacity(0.55), lineWidth: 1).frame(width: 13, height: 13)
                        if podcast.follow {
                            PenTick().stroke(Palette.green, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                                .frame(width: 12, height: 10).offset(x: 1, y: -1)
                                .transition(.opacity)
                        }
                    }
                    Text("Follow along on the page").font(.ui(12)).foregroundColor(Palette.ink2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Mark and scroll to the passage each line is about")
            if confirmNew {
                HStack(spacing: 12) {
                    Text("Replace this episode?").font(.ui(12)).foregroundColor(Palette.ink)
                    Button("Make a new one") {
                        confirmNew = false
                        let src = reader.podcastText()
                        reader.clearFollow()
                        podcast.make(text: src.text, source: src.source)
                    }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.red))
                    Button("Keep it") { withAnimation(Motion.pick(Motion.snappy)) { confirmNew = false } }
                        .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                }
                .font(.ui(11.5))
                .transition(.opacity)
            } else {
                Button("Regenerate") { withAnimation(Motion.pick(Motion.snappy)) { confirmNew = true } }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                    .font(.ui(11.5))
                    .help("Write and record a new take of this episode")
            }
            Text("AI voices, written from the paper. Check anything that matters against the page.")
                .font(.hand(12.5)).foregroundColor(Palette.pencil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One line of the transcript. The line being spoken gets a sweep of marker, like a highlighter.
struct TranscriptLine: View {
    enum State { case heard, now, ahead }
    var line: PodcastLine
    var state: State
    var onTap: () -> Void
    @SwiftUI.State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(line.speaker.uppercased()).font(.typewriter(9.5)).foregroundColor(PodcastHost.pen(line.speaker))
                if !line.section.isEmpty && !line.quote.isEmpty {
                    Text("\u{00A7} " + line.section.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression).lowercased())
                        .font(.typewriter(9)).foregroundColor(Palette.pencil).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(line.start.clock).font(.typewriter(9)).foregroundColor(Palette.pencil)
                    .opacity(hover || state == .now ? 1 : 0)
            }
            Text(line.text)
                .font(.text(13.5))
                .foregroundColor(state == .ahead ? Palette.ink2.opacity(0.78) : (state == .now ? Palette.ink : Palette.ink2))
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .background(alignment: .leading) {
                    MarkerSweep(seed: line.id)
                        .fill(Palette.marker.opacity(0.5))
                        .padding(.horizontal, -3).padding(.vertical, -1)
                        .scaleEffect(x: state == .now ? 1 : 0.001, anchor: .leading)
                        .opacity(state == .now ? 1 : 0)
                        .animation(Motion.pick(.spring(response: 0.55, dampingFraction: 0.9)), value: state == .now)
                }
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(hover ? 0.42 : 0)))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { h in withAnimation(Motion.snappy) { hover = h } }
        .help("Play from here")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Plays from this line")
    }
}

/// A highlighter stroke: slightly uneven edges and ends, never a perfect box.
struct MarkerSweep: Shape {
    var seed: Int
    func path(in r: CGRect) -> Path {
        func wob(_ k: Int) -> CGFloat { CGFloat(sin(Double(seed * 7 + k) * 1.73)) }
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 1.5 * wob(1), y: r.minY + 1.5 + wob(2)))
        p.addCurve(to: CGPoint(x: r.maxX - 1 + 2 * wob(3), y: r.minY + 1 + wob(4)),
                   control1: CGPoint(x: r.minX + r.width * 0.3, y: r.minY + wob(5)),
                   control2: CGPoint(x: r.minX + r.width * 0.7, y: r.minY + 2 + wob(6)))
        p.addQuadCurve(to: CGPoint(x: r.maxX + 1.5 * wob(7), y: r.maxY - 1 + wob(8)), control: CGPoint(x: r.maxX + 3, y: r.midY))
        p.addCurve(to: CGPoint(x: r.minX + 1 + wob(9), y: r.maxY - 0.5 + wob(10)),
                   control1: CGPoint(x: r.minX + r.width * 0.65, y: r.maxY + 1 + wob(11)),
                   control2: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY - 1.5 + wob(12)))
        p.addQuadCurve(to: CGPoint(x: r.minX + 1.5 * wob(1), y: r.minY + 1.5 + wob(2)), control: CGPoint(x: r.minX - 2.5, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// Green ink, pressed on once when a new episode is done.
struct RecordedStamp: View {
    var body: some View {
        Text("RECORDED")
            .font(.typewriter(11)).tracking(1.5)
            .foregroundColor(Palette.green.opacity(0.85))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.green.opacity(0.8), lineWidth: 1.4))
            .overlay(RoundedRectangle(cornerRadius: 1).strokeBorder(Palette.green.opacity(0.45), lineWidth: 0.6).padding(2.5))
            .blendMode(.multiply)
            .accessibilityLabel("Recorded")
    }
}

// MARK: The deck: plays the episode, docked under the page

struct PodcastDeck: View {
    @ObservedObject var podcast: PodcastModel

    var body: some View {
        if let ep = podcast.episode {
            HStack(alignment: .center, spacing: 16) {
                PlayStamp(playing: podcast.isPlaying) { podcast.toggle() }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(ep.title).font(.fell(16.5)).foregroundColor(Palette.ink).lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(podcast.time.clock) / \(ep.duration.clock)")
                            .font(.typewriter(10.5)).foregroundColor(Palette.ink3).monospacedDigit()
                    }
                    Scrubber(podcast: podcast, episode: ep).frame(height: 42)
                    HStack(spacing: 10) {
                        nowSpeaking(ep)
                        Spacer(minLength: 6)
                        skip("gobackward.15", "Back 15 seconds") { podcast.skip(-15) }
                        skip("goforward.15", "Forward 15 seconds") { podcast.skip(15) }
                    }
                }
                Rectangle().fill(Palette.ink.opacity(0.16)).frame(width: 0.8, height: 70)
                SpeedPicker(podcast: podcast)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 14).padding(.trailing, 16).padding(.vertical, 12)
            .frame(maxWidth: 720)
            .background(
                PaperSheet(corner: 3)
                    .shadow(color: .black.opacity(0.2), radius: 7, y: 3)
            )
            .overlay(alignment: .topLeading) {
                // One piece of tape holding the slip to the desk.
                Rectangle().fill(Color(hex: 0xEFE3BF).opacity(0.82))
                    .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.06), lineWidth: 0.6))
                    .frame(width: 46, height: 15)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -14, y: -4)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private func nowSpeaking(_ ep: PodcastEpisode) -> some View {
        if let i = podcast.currentLine, i < ep.lines.count {
            let s = ep.lines[i].speaker
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1).fill(PodcastHost.ink(s).swatch).frame(width: 9, height: 4)
                Text("\(s) \(PodcastHost.role(s))").font(.hand(14)).foregroundColor(PodcastHost.pen(s))
            }
            .id(s)
            .transition(.opacity)
            .animation(Motion.pick(Motion.snappy), value: s)
        } else {
            Text("Juniper and Rowan, two AI voices").font(.hand(14)).foregroundColor(Palette.pencil)
        }
    }

    private func skip(_ icon: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12.5, weight: .medium)).foregroundColor(Palette.ink2)
                .frame(width: 24, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Play and pause as an ink stamp with the green offset, like the app's other stamps.
struct PlayStamp: View {
    var playing: Bool
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "play.fill").font(.system(size: 17, weight: .bold)).offset(x: 1.5)
                    .opacity(playing ? 0 : 1).scaleEffect(playing ? 0.5 : 1)
                Image(systemName: "pause.fill").font(.system(size: 16, weight: .bold))
                    .opacity(playing ? 1 : 0).scaleEffect(playing ? 1 : 0.5)
            }
            .foregroundColor(Palette.paper2)
            .frame(width: 50, height: 50)
            .contentShape(Circle())
        }
        .buttonStyle(PlayPress(hover: hover))
        .onHover { h in withAnimation(Motion.snappy) { hover = h } }
        .animation(Motion.pick(Motion.snappy), value: playing)
        .help(playing ? "Pause" : "Play")
        .accessibilityLabel(playing ? "Pause" : "Play")
    }
}

private struct PlayPress: ButtonStyle {
    var hover: Bool
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .background(Circle().fill(Palette.ink))
            .background(Circle().fill(Palette.green).offset(x: pressed ? 1 : 3, y: pressed ? 1 : 3))
            .offset(x: pressed ? 2 : (hover ? -0.5 : 0), y: pressed ? 2 : (hover ? -1 : 0))
            .animation(Motion.snappy, value: pressed)
    }
}

/// The episode's real loudness drawn as pencil strokes, inked up to the playhead.
/// Drag or click to move; a ribbon underneath shows who is talking when.
struct Scrubber: View {
    @ObservedObject var podcast: PodcastModel
    var episode: PodcastEpisode
    @State private var dragging: Double?
    @State private var hoverX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !podcast.isPlaying || dragging != nil || Snapshots.isRendering)) { _ in
                let now = dragging ?? podcast.liveTime
                Canvas { ctx, size in draw(&ctx, size, now: now) }
            }
            .overlay(alignment: .topLeading) {
                if let x = hoverX, dragging == nil {
                    Text((Double(x / w) * episode.duration).clock)
                        .font(.typewriter(9)).foregroundColor(Palette.ink2)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color(hex: 0xFFFCF3).opacity(0.95))
                        .fixedSize()
                        .position(x: min(max(16, x), w - 16), y: -8)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in dragging = Double(min(max(0, g.location.x / w), 1)) * episode.duration }
                    .onEnded { g in
                        podcast.seek(to: Double(min(max(0, g.location.x / w), 1)) * episode.duration)
                        dragging = nil
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): hoverX = p.x
                case .ended: hoverX = nil
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Position")
        .accessibilityValue("\(podcast.time.clock) of \(episode.duration.clock)")
        .accessibilityAdjustableAction { dir in podcast.skip(dir == .increment ? 15 : -15) }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, now: Double) {
        let dur = max(0.1, episode.duration)
        guard !episode.peaks.isEmpty else { return }
        let ribbon: CGFloat = 4
        let waveH = size.height - ribbon - 5
        let mid = waveH / 2
        let count = max(8, min(episode.peaks.count, Int(size.width / 3.1)))
        let step = size.width / CGFloat(count)
        let playX = size.width * CGFloat(now / dur)
        var inked = Path(), pencil = Path()
        for i in 0..<count {
            let a = Int(Double(i) / Double(count) * Double(episode.peaks.count))
            let b = max(a + 1, Int(Double(i + 1) / Double(count) * Double(episode.peaks.count)))
            let v = episode.peaks[min(a, episode.peaks.count - 1)..<min(b, episode.peaks.count)].max() ?? 0
            // A touch of hand: no two strokes the same length for the same loudness.
            let jitter = 1 + 0.06 * CGFloat(sin(Double(i) * 12.9898))
            let h = max(1.4, CGFloat(v) * (waveH - 4) / 2 * jitter)
            let x = step * (CGFloat(i) + 0.5)
            if x <= playX {
                inked.move(to: CGPoint(x: x, y: mid - h)); inked.addLine(to: CGPoint(x: x, y: mid + h))
            } else {
                pencil.move(to: CGPoint(x: x, y: mid - h)); pencil.addLine(to: CGPoint(x: x, y: mid + h))
            }
        }
        let lw = max(1, min(1.9, step * 0.58))
        ctx.stroke(pencil, with: .color(Palette.pencil.opacity(0.55)), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        ctx.stroke(inked, with: .color(Palette.ink), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        // Who talks when.
        let y = size.height - ribbon
        let current = podcast.currentLine
        for l in episode.lines {
            let x0 = size.width * CGFloat(l.start / dur), x1 = size.width * CGFloat(l.end / dur)
            let r = CGRect(x: x0, y: y, width: max(1, x1 - x0 - 1), height: ribbon)
            ctx.fill(Path(roundedRect: r, cornerRadius: 1), with: .color(PodcastHost.ink(l.speaker).swatch.opacity(l.id == current ? 1 : 0.55)))
        }
        // The playhead: a red pen line with a nib.
        var head = Path()
        head.move(to: CGPoint(x: playX, y: 0)); head.addLine(to: CGPoint(x: playX, y: waveH + 2))
        ctx.stroke(head, with: .color(Palette.red), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: playX - 3, y: -1.5, width: 6, height: 6)), with: .color(Palette.red))
    }
}

/// Speeds typed in a column; the chosen one is circled in pencil, and the circle moves when you pick.
struct SpeedPicker: View {
    @ObservedObject var podcast: PodcastModel
    @Namespace private var ring

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text("speed").font(.hand(12)).foregroundColor(Palette.pencil)
            ForEach(PodcastModel.rates, id: \.self) { r in
                Button {
                    withAnimation(Motion.pick(Motion.snappy)) { podcast.setRate(r) }
                } label: {
                    Text(label(r)).font(.typewriter(11)).foregroundColor(podcast.rate == r ? Palette.ink : Palette.ink3)
                        .frame(width: 44, height: 15)
                        .background {
                            if podcast.rate == r {
                                PencilRing()
                                    .stroke(Palette.ink2.opacity(0.8), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                                    .frame(width: 42, height: 17)
                                    .matchedGeometryEffect(id: "ring", in: ring)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Speed \(label(r))")
                .accessibilityAddTraits(podcast.rate == r ? .isSelected : [])
            }
        }
    }

    private func label(_ r: Float) -> String {
        r == 1 ? "1x" : r == 2 ? "2x" : String(format: "%gx", r)
    }
}

/// A loop of pencil that doesn't quite close, the way you circle an answer.
struct PencilRing: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let steps = 48
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2.15 * .pi - 0.35
            let wob = 1 + 0.035 * sin(t * 3.1)
            let pt = CGPoint(x: c.x + r.width / 2 * CGFloat(cos(t) * wob), y: c.y + r.height / 2 * CGFloat(sin(t) * wob) - CGFloat(i) * 0.03)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}
