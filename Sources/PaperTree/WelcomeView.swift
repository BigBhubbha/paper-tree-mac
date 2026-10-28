// First-run card that explains, in plain words, why Paper Tree needs Accessibility.
import SwiftUI

struct WelcomeView: View {
    @ObservedObject var state: AppState
    var openSettings: () -> Void
    var done: () -> Void

    private let poll = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    init(state: AppState, openSettings: @escaping () -> Void, done: @escaping () -> Void) {
        self.state = state
        self.openSettings = openSettings
        self.done = done
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                BuddyView(mood: state.accessibilityGranted ? .idle : .needsAccess, researchMode: state.accessibilityGranted)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hi. I'm your lab flask.")
                        .font(.fell(30))
                        .foregroundColor(Palette.ink)
                    Text("Highlight anything you're reading, click it, and I'll explain it in plain words.")
                        .font(.text(15.5))
                        .foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Rectangle().fill(Palette.rule).frame(height: 1).padding(.vertical, 18)

            Text("One permission first")
                .font(.fellItalic(20))
                .foregroundColor(Palette.ink)

            VStack(alignment: .leading, spacing: 9) {
                step("1.", "Paper Tree needs Accessibility so it can read the text you highlight in Preview, Safari, Chrome, Word, and other apps.")
                step("2.", "It only reads your highlight, and only while research mode is on. It doesn't record what you type.")
                step("3.", "The highlight is sent to your Paper Tree server to be explained, and nowhere else.")
            }
            .padding(.top, 10)

            HStack(spacing: 10) {
                Circle().fill(state.accessibilityGranted ? Palette.green : Palette.red).frame(width: 9, height: 9)
                Text(state.accessibilityGranted ? "Accessibility is on. You're set." : "Waiting for you to switch Paper Tree on in System Settings...")
                    .font(.ui(13))
                    .foregroundColor(Palette.ink2)
            }
            .padding(.top, 18)

            if !state.accessibilityGranted {
                Text("System Settings, Privacy & Security, Accessibility, then switch on Paper Tree. If it is already on after a rebuild, remove it with the minus button and add it again.")
                    .font(.hand(14))
                    .foregroundColor(Palette.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .rotationEffect(.degrees(-0.6))
                    .padding(.top, 10)
            }

            Spacer(minLength: 16)

            HStack(spacing: 16) {
                if state.accessibilityGranted {
                    Button("Start reading") { done() }.buttonStyle(StampButtonStyle())
                } else {
                    Button("Open Accessibility settings") {
                        Accessibility.requestTrust()
                        Accessibility.openAccessibilitySettings()
                    }
                    .buttonStyle(StampButtonStyle())
                    Button("Later") { done() }.buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                }
                Spacer()
                Button("Server settings") { openSettings() }.buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
            }
        }
        .padding(28)
        .frame(width: 540, height: 520)
        .background(PaperSheet(corner: 0, graph: true).ignoresSafeArea())
        .onReceive(poll) { _ in
            let trusted = Accessibility.isTrusted
            if trusted != state.accessibilityGranted {
                state.accessibilityGranted = trusted
                state.refreshMood()
            }
        }
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(n).font(.typewriter(13)).foregroundColor(Palette.green)
            Text(text).font(.text(14.5)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
        }
    }
}
