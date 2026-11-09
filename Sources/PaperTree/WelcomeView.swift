// Shared drawn pieces for setup and Settings: the desk, tape, a margin bracket, the approval stamp
// and a check mark.
import SwiftUI

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
    /// The small line under APPROVED.
    var caption: String = "access on"

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
                        Text(caption)
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
                    .font(.ui(11))
                    .foregroundColor(Palette.ink3)
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
