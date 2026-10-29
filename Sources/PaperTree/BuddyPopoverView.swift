// The little field-kit card that opens when you click the buddy.
import SwiftUI

struct BuddyPopoverView: View {
    @ObservedObject var state: AppState
    var openSettings: () -> Void
    var requestAccess: () -> Void
    var checkForUpdates: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Masthead
            HStack(alignment: .firstTextBaseline) {
                Text("Paper Tree")
                    .font(.fell(24))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text("Field kit, No. 1")
                    .font(.typewriter(10.5))
                    .foregroundColor(Palette.ink3)
            }
            Rectangle().fill(Palette.ink).frame(height: 1.2).padding(.top, 8)

            HStack(alignment: .center, spacing: 12) {
                BuddyView(mood: state.mood, researchMode: state.researchMode)
                    .frame(width: 54, height: 54)
                Toggle(isOn: $state.researchMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Research mode")
                            .font(.uiBold(14.5))
                            .foregroundColor(Palette.ink)
                        Text(state.researchMode ? "On. Goggles are on." : "Off. Highlight freely.")
                            .font(.ui(12))
                            .foregroundColor(Palette.ink3)
                    }
                }
                .toggleStyle(InkToggleStyle())
            }
            .padding(.top, 12)

            // Red-pen margin note: how to use it.
            VStack(alignment: .leading, spacing: 3) {
                Text("highlight a line, then click it.")
                Text("I'll explain it in plain words.")
            }
            .font(.hand(14.5))
            .foregroundColor(Palette.red)
            .rotationEffect(.degrees(-1.2))
            .padding(.top, 12)
            .padding(.leading, 4)

            if !state.accessibilityGranted {
                HStack(alignment: .top, spacing: 10) {
                    Text("!")
                        .font(.uiBold(12))
                        .foregroundColor(Palette.paper2)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Palette.red))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("I can't see highlights yet. Turn on Accessibility for Paper Tree.")
                            .font(.ui(12.5))
                            .foregroundColor(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Grant access", action: requestAccess)
                            .buttonStyle(StampButtonStyle(compact: true))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 4).fill(Palette.paper.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.red.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                .padding(.top, 14)
            } else if !state.endpointIsConfigured {
                HStack(alignment: .top, spacing: 8) {
                    Text("Note.")
                        .font(.typewriter(11.5))
                        .foregroundColor(Palette.red)
                    Text("No explainer connected yet. Add your server address in Settings.")
                        .font(.ui(12.5))
                        .foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)
            }

            Rectangle().fill(Palette.rule).frame(height: 1).padding(.top, 14)

            HStack(spacing: 14) {
                Button("Settings", action: openSettings).buttonStyle(InkLinkButtonStyle())
                Button("Check for Updates", action: checkForUpdates).buttonStyle(InkLinkButtonStyle())
                Spacer()
                Button("Quit", action: quit).buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            }
            .padding(.top, 10)

            Text(state.researchMode ? "Fig. 1. Erlenmeyer, at work" : "Fig. 1. Erlenmeyer, at rest")
                .font(.typewriter(10))
                .foregroundColor(Palette.ink3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: 300)
        .background(PaperSheet(corner: 0, graph: true))
        .onAppear { state.accessibilityGranted = Accessibility.isTrusted; state.refreshMood() }
    }
}
