// Setup, entry 003: a taped specimen sheet where the flask introduces itself, says in a
// handwritten note why it needs Accessibility, and gets stamped once you approve it.
// The small drawn pieces at the bottom (tape, marks, stamp) are shared with the rest of setup.
import SwiftUI

/// Setup entry 003: the specimen sheet that asks for Accessibility and stamps itself when it's on.
struct AccessibilitySheet: View {
    @ObservedObject var state: AppState
    @State private var asked = false

    private var granted: Bool { state.accessibilityGranted }

    var body: some View { sheet }

    // MARK: The specimen sheet

    private var sheet: some View {
        ZStack(alignment: .topLeading) {
            PaperSheet(corner: 2, graph: true)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 26) {
                    specimen
                    introduction
                }

                Spacer(minLength: 12)

                HStack(alignment: .bottom) {
                    action
                    Spacer()
                    ApprovalStamp(granted: granted)
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 30)
            .padding(.bottom, 24)

            // Two strips of tape holding the sheet down.
            Tape().rotationEffect(.degrees(-7)).offset(x: 34, y: -11)
            Tape().rotationEffect(.degrees(5)).offset(x: 430, y: -10)
        }
        .frame(height: 410)
        .rotationEffect(.degrees(-0.5))
        .shadow(color: Palette.ink.opacity(0.13), radius: 7, x: 0, y: 4)
    }

    /// Fig. 1: the flask itself, pressed inside a pencil frame with registration marks.
    private var specimen: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Palette.pencil.opacity(0.7), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                RegistrationMarks().stroke(Palette.ink.opacity(0.45), lineWidth: 0.8)
                BuddyView(mood: granted ? .idle : .needsAccess, researchMode: granted)
                    .frame(width: 118, height: 118)
            }
            .frame(width: 150, height: 150)

            ScaleBar().frame(width: 60, height: 9)

            VStack(alignment: .leading, spacing: 1) {
                (Text("Fig. 1. ").font(.fell(14)) + Text("Ampulla lectoris").font(.fellItalic(14)))
                    .foregroundColor(Palette.ink)
                Text("the reading flask")
                    .font(.text(12.5))
                    .foregroundColor(Palette.ink3)
                Text("PT-0001")
                    .font(.typewriter(10.5))
                    .foregroundColor(Palette.ink3)
                    .padding(.top, 3)
            }
        }
        .frame(width: 150, alignment: .leading)
    }

    /// The flask's own words, then the handwritten reason it needs Accessibility.
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hello. I'm the flask.")
                .font(.fell(31))
                .foregroundColor(Palette.ink)
            Text("I live in the notch. Double-tap the right Option key to open me, triple-tap to toggle Research mode. Then highlight a hard line in any paper and I'll explain it in plain words.")
                .font(.text(15))
                .foregroundColor(Palette.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            // Red-pen margin note with a bracket, like a correction in the notebook.
            HStack(alignment: .top, spacing: 10) {
                MarginBracket()
                    .stroke(Palette.red.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("why I'm asking:")
                        .font(.hand(15))
                    Text("to read what you highlight in Preview, Chrome, or Word, macOS has to let me in under Accessibility. I only read the words you highlight, and only while research mode is on. I never see what you type.")
                        .font(.hand(14.5))
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Palette.red)
            }
            .rotationEffect(.degrees(-0.8))
            .padding(.top, 16)
        }
    }

    /// The one thing to do on this page.
    @ViewBuilder
    private var action: some View {
        VStack(alignment: .leading, spacing: 9) {
            if granted {
                Text("You're in. I can see highlights now.")
                    .font(.hand(15))
                    .foregroundColor(Palette.green)
                Text("Next, a quick practice run.")
                    .font(.text(13.5))
                    .foregroundColor(Palette.ink3)
            } else {
                Button("Let me read highlights") {
                    asked = true
                    Accessibility.requestTrust()
                    Accessibility.openAccessibilitySettings()
                }
                .buttonStyle(StampButtonStyle())
                Text("Privacy & Security  >  Accessibility  >  Paper Tree")
                    .font(.typewriter(10.5))
                    .foregroundColor(Palette.ink3)
                if asked {
                    Text("Already switched on? Switch it off and on again, and I'll see it.")
                        .font(.hand(13))
                        .foregroundColor(Palette.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Pieces

/// The lab bench behind the sheet: darker paper with grain.
struct DeskBackground: View {
    var body: some View {
        Palette.paper
            .overlay(Image(nsImage: PaperGrain.image).resizable(resizingMode: .tile).opacity(0.9))
    }
}

/// A strip of translucent masking tape.
struct Tape: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xE8DDB4).opacity(0.78))
            .frame(width: 96, height: 24)
            .overlay(Rectangle().stroke(Color(hex: 0xC9BC8E).opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
    }
}

/// Corner crop marks, like the plates on the landing site.
struct RegistrationMarks: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l: CGFloat = 9, inset: CGFloat = -5
        let corners = [CGPoint(x: r.minX + inset, y: r.minY + inset), CGPoint(x: r.maxX - inset, y: r.minY + inset),
                       CGPoint(x: r.minX + inset, y: r.maxY - inset), CGPoint(x: r.maxX - inset, y: r.maxY - inset)]
        for (i, c) in corners.enumerated() {
            let dx: CGFloat = i % 2 == 0 ? 1 : -1
            let dy: CGFloat = i < 2 ? 1 : -1
            p.move(to: CGPoint(x: c.x + dx * l, y: c.y)); p.addLine(to: c); p.addLine(to: CGPoint(x: c.x, y: c.y + dy * l))
        }
        return p
    }
}

/// A tiny "1 cm" scale bar under the figure.
struct ScaleBar: View {
    var body: some View {
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.ink.opacity(0.7)).frame(width: 34, height: 1)
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in Rectangle().fill(Palette.ink.opacity(0.7)).frame(width: 1, height: 5) }
                }
            }
            Text("1 cm").font(.typewriter(8.5)).foregroundColor(Palette.ink3)
        }
    }
}

/// A hand-drawn square bracket in the margin.
struct MarginBracket: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY + 2))
        p.addQuadCurve(to: CGPoint(x: r.minX + 1, y: r.minY + 6), control: CGPoint(x: r.minX, y: r.minY + 1))
        p.addLine(to: CGPoint(x: r.minX + 2, y: r.maxY - 6))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - 1), control: CGPoint(x: r.minX + 2, y: r.maxY))
        return p
    }
}

/// Empty pencil circle while waiting; a green ink stamp with a check mark the moment access is on.
struct ApprovalStamp: View {
    var granted: Bool

    var body: some View {
        ZStack {
            if granted {
                ZStack {
                    Circle().stroke(Palette.green, lineWidth: 2.4)
                    Circle().stroke(Palette.green, lineWidth: 0.9).padding(6)
                    VStack(spacing: 2) {
                        CheckMark()
                            .stroke(Palette.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            .frame(width: 34, height: 26)
                        Text("APPROVED")
                            .font(.typewriter(11))
                            .kerning(1.6)
                        Text("access on")
                            .font(.typewriter(8.5))
                            .kerning(1)
                    }
                    .foregroundColor(Palette.green)
                }
                .opacity(0.88)
                .rotationEffect(.degrees(-9))
                .transition(.scale(scale: 1.7).combined(with: .opacity))
            } else {
                ZStack {
                    Circle().stroke(Palette.pencil.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    VStack(spacing: 2) {
                        Text("stamp here")
                        Text("when approved")
                    }
                    .font(.hand(12))
                    .foregroundColor(Palette.pencil)
                }
                .rotationEffect(.degrees(-4))
                .transition(.opacity)
            }
        }
        .frame(width: 108, height: 108)
        .accessibilityElement()
        .accessibilityLabel(granted ? "Accessibility is on" : "Waiting for Accessibility")
    }
}

struct CheckMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 2, y: r.midY + 1))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 1, y: r.minY + 2), control: CGPoint(x: r.midX + 4, y: r.midY - 2))
        return p
    }
}
