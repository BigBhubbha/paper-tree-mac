// The reader's download, drawn as a specimen packet on the instrument drawer: what it is, how big,
// a pencil-ruled measuring tape for progress, and plain buttons to start, pause, retry or remove.
// The same tape shows up in the Listen tab when a podcast needs the reader first.
import SwiftUI

struct ReaderShelf: View {
    @ObservedObject var download: ReaderDownload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "The reader") {
                Text("runs on this Mac, no internet needed").font(.ui(12.5)).foregroundColor(Palette.ink3)
            }
            packet.padding(.top, 14)
        }
    }

    private var packet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Specimen").font(.typewriter(10.5)).foregroundColor(Palette.red)
                        Text(download.writer.title.lowercased() + ", with two voices").font(.typewriter(10.5)).foregroundColor(Palette.ink3)
                    }
                    Text(headline).font(.fell(24)).foregroundColor(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(blurb).font(.text(13.5)).foregroundColor(Palette.ink2).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                BuddyView(mood: download.phase == .downloading || download.phase == .checking ? .thinking : .idle,
                          researchMode: download.isReady, animated: !Snapshots.isRendering)
                    .frame(width: 58, height: 58)
            }
            if showsChoice { choice }
            if showsTape { ReaderTape(download: download) }
            problem
            buttons
        }
        .padding(18)
        .background(
            PaperSheet(corner: 2)
                .shadow(color: Palette.ink.opacity(0.12), radius: 3, x: 0, y: 2)
        )
        .overlay(alignment: .topTrailing) { Tape().rotationEffect(.degrees(5)).offset(x: -30, y: -8) }
        .animation(Motion.pick(Motion.settle), value: download.phase)
    }

    private var headline: String {
        switch download.phase {
        case .notStarted: return "Download the reader"
        case .noSpace: return "Not enough room on this Mac"
        case .downloading: return "Downloading the reader"
        case .paused: return "Download paused"
        case .checking: return "Checking the files"
        case .ready: return "The reader is on this Mac"
        case .failed: return "The download stopped"
        }
    }

    private var blurb: String {
        switch download.phase {
        case .ready:
            return "Highlights, podcasts and tree labels are written right here. Nothing you read leaves this Mac, and it works offline."
        case .checking:
            return "Making sure every file arrived whole. This takes a few seconds."
        default:
            return "Paper Tree explains highlights, writes podcasts and names your trees with a model that runs on this Mac. It's a one-time download of \(download.allBytes.sizeText). After that it works offline, and nothing you read leaves your computer."
        }
    }

    private var showsChoice: Bool {
        switch download.phase {
        case .notStarted, .noSpace: return true
        case .failed: return download.doneBytes == 0
        default: return false
        }
    }

    private var showsTape: Bool {
        switch download.phase {
        case .downloading, .paused, .checking: return true
        case .failed: return download.doneBytes > 0
        default: return false
        }
    }

    private var choice: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(LocalModels.writers) { w in
                Button {
                    withAnimation(Motion.pick(Motion.snappy)) { download.writerId = w.id }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        ReaderPick(on: download.writerId == w.id).frame(width: 16, height: 16).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(w.title).font(.uiBold(12.5)).foregroundColor(Palette.ink)
                                Text(w.file.bytes.sizeText).font(.text(12.5)).foregroundColor(Palette.ink3)
                                if w.id == LocalModels.suggestedWriter.id {
                                    Text("suits this Mac").font(.hand(13.5)).foregroundColor(Palette.green)
                                }
                            }
                            Text(w.detail).font(.text(12.5)).foregroundColor(Palette.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 7) {
                Circle().fill(Palette.ink3).frame(width: 3, height: 3)
                Text("Plus Juniper's and Rowan's voices (Kokoro), \(LocalModels.voiceFiles.reduce(0) { $0 + $1.bytes }.sizeText).")
                    .font(.text(12.5)).foregroundColor(Palette.ink3)
            }
            .padding(.leading, 4)
        }
    }

    @ViewBuilder private var problem: some View {
        switch download.phase {
        case .noSpace(let need, let free):
            note("It needs \(need.sizeText) free and this Mac has \(free.sizeText). Make some room, then check again.")
        case .failed(let msg):
            note(msg)
        default:
            EmptyView()
        }
    }

    private func note(_ s: String) -> some View {
        Text(s).font(.hand(15)).foregroundColor(Palette.red)
            .rotationEffect(.degrees(-0.5))
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
    }

    private var buttons: some View {
        HStack(spacing: 14) {
            switch download.phase {
            case .notStarted:
                Button("Download \(download.allBytes.sizeText)") { download.start() }.buttonStyle(StampButtonStyle())
            case .noSpace:
                Button("Check again") { download.start() }.buttonStyle(StampButtonStyle())
            case .downloading:
                Button("Pause") { download.pause() }.buttonStyle(StampButtonStyle(compact: true, quiet: true))
            case .paused:
                Button("Resume") { download.start() }.buttonStyle(StampButtonStyle())
                Button("Start over") { download.remove() }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            case .checking:
                EmptyView()
            case .failed:
                Button("Try again") { download.start() }.buttonStyle(StampButtonStyle())
            case .ready:
                Text("Stored in Application Support, Paper Tree, Models.").font(.text(12.5)).foregroundColor(Palette.ink3)
                Spacer(minLength: 0)
                Button("Remove from this Mac") { download.remove() }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            }
        }
        .padding(.top, 2)
    }
}

/// A pencil ring, filled with a small ink dot when picked.
struct ReaderPick: View {
    var on: Bool
    var body: some View {
        ZStack {
            Circle().strokeBorder(Palette.ink.opacity(0.7), lineWidth: 1.1)
            if on {
                Circle().fill(Palette.green).padding(3.5)
                    .transition(Motion.reduced ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .animation(Motion.pick(Motion.land), value: on)
    }
}

/// Progress as a measuring tape: ruled ticks every tenth, green ink filling in, numbers in
/// Newsreader underneath.
struct ReaderTape: View {
    @ObservedObject var download: ReaderDownload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: 0xEADDB9))
                        .overlay(RoundedRectangle(cornerRadius: 1.5).strokeBorder(Palette.ink.opacity(0.35), lineWidth: 0.8))
                    RoundedRectangle(cornerRadius: 1.5).fill(Palette.green.opacity(download.phase == .paused ? 0.45 : 0.8))
                        .frame(width: max(2, w * download.fraction))
                        .animation(Motion.pick(.easeOut(duration: 0.5)), value: download.fraction)
                    Canvas { ctx, size in
                        for i in 1..<40 {
                            let x = size.width * CGFloat(i) / 40
                            let tall: CGFloat = i % 10 == 0 ? 0.62 : i % 5 == 0 ? 0.44 : 0.26
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height * tall))
                            ctx.stroke(p, with: .color(Palette.ink.opacity(0.4)), lineWidth: 0.6)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 16)
            HStack(alignment: .firstTextBaseline) {
                Text("\(download.doneBytes.sizeText) of \(download.totalBytes.sizeText)").font(.text(12.5)).foregroundColor(Palette.ink2)
                Text("\(Int((download.fraction * 100).rounded(.down))) percent").font(.text(12.5)).foregroundColor(Palette.ink3)
                Spacer()
                Text(status).font(.text(12.5)).foregroundColor(Palette.ink3)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var status: String {
        switch download.phase {
        case .paused: return "paused, picks up where it stopped"
        case .checking: return "checking"
        case .failed: return "stopped"
        default:
            guard let left = download.secondsLeft else { return download.currentFile.isEmpty ? "starting" : "fetching \(download.currentFile)" }
            if left < 90 { return "under 2 minutes left" }
            return "about \(Int((left / 60).rounded())) minutes left"
        }
    }
}

/// In the Listen tab: the reader has to come first, with the tape when it's on its way.
struct ReaderNeeded: View {
    @ObservedObject var download: ReaderDownload
    var what: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The reader isn't on this Mac yet.").font(.hand(16)).foregroundColor(Palette.red)
                .rotationEffect(.degrees(-0.6))
            Text("\(what) It's a one-time download of \(download.allBytes.sizeText), then it all works offline.")
                .font(.text(12.5)).foregroundColor(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            switch download.phase {
            case .downloading, .paused, .checking:
                ReaderTape(download: download)
                if download.phase == .paused {
                    Button("Resume") { download.start() }.buttonStyle(StampButtonStyle(compact: true))
                }
            case .noSpace(let need, let free):
                Text("It needs \(need.sizeText) free and this Mac has \(free.sizeText).").font(.text(12.5)).foregroundColor(Palette.red)
                Button("Check again") { download.start() }.buttonStyle(StampButtonStyle(compact: true))
            case .failed(let msg):
                Text(msg).font(.text(12.5)).foregroundColor(Palette.red).fixedSize(horizontal: false, vertical: true)
                Button("Try again") { download.start() }.buttonStyle(StampButtonStyle(compact: true))
            default:
                Button {
                    download.start()
                } label: {
                    Label("Download the reader", systemImage: "arrow.down.circle")
                }
                .buttonStyle(StampButtonStyle())
            }
        }
        .animation(Motion.pick(Motion.settle), value: download.phase)
    }
}
