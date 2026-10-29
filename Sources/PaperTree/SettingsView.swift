// Settings: where the explainer lives, plus a few preferences.
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var state: AppState
    var resetBuddy: () -> Void
    var showWelcome: () -> Void
    var checkForUpdates: () -> Void

    @State private var endpointDraft: String = ""
    @State private var tokenDraft: String = ""
    @State private var testStatus: String = ""
    @State private var testing = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String = ""

    init(state: AppState, resetBuddy: @escaping () -> Void, showWelcome: @escaping () -> Void,
         checkForUpdates: @escaping () -> Void) {
        self.state = state
        self.resetBuddy = resetBuddy
        self.showWelcome = showWelcome
        self.checkForUpdates = checkForUpdates
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        return "Paper Tree for Mac, version \(version)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Settings").font(.fell(30)).foregroundColor(Palette.ink)
                Spacer()
                Text("Plate II. Instruments").font(.typewriter(11)).foregroundColor(Palette.ink3)
            }
            Rectangle().fill(Palette.ink).frame(height: 1.2).padding(.top, 8)

            section("The explainer") {
                Text("Paper Tree sends your highlight to your own small server, which asks the AI. No key ever lives in this app.")
                    .font(.text(14)).foregroundColor(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                field("Server address", text: $endpointDraft, placeholder: AppState.defaultEndpoint)
                field("App token (optional)", text: $tokenDraft, placeholder: "Only if your server sets APP_TOKEN", secure: true)
                HStack(spacing: 14) {
                    Button("Save") { save() }.buttonStyle(StampButtonStyle(compact: true))
                    Button(testing ? "Testing..." : "Test it") { test() }
                        .buttonStyle(StampButtonStyle(compact: true, quiet: true))
                        .disabled(testing)
                    Text(testStatus)
                        .font(.hand(14))
                        .foregroundColor(testStatus.hasPrefix("Works") ? Palette.green : Palette.red)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }

            section("Behavior") {
                Toggle(isOn: $state.researchMode) { label("Research mode", "Highlight, then click, to get an explanation.") }
                    .toggleStyle(InkToggleStyle())
                Toggle(isOn: $state.copyFallbackEnabled) {
                    label("Copy fallback", "For apps that hide their text, Paper Tree presses Cmd+C for you and then puts your clipboard back.")
                }
                .toggleStyle(InkToggleStyle())
                Toggle(isOn: $state.showBuddy) { label("Show the buddy", "Hide it if you only want the menu bar item.") }
                    .toggleStyle(InkToggleStyle())
                Toggle(isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) })) {
                    label("Open at login", loginError.isEmpty ? "Start Paper Tree when you log in." : loginError)
                }
                .toggleStyle(InkToggleStyle())
            }

            section("Permissions") {
                HStack(spacing: 8) {
                    Circle().fill(state.accessibilityGranted ? Palette.green : Palette.red).frame(width: 8, height: 8)
                    Text(state.accessibilityGranted ? "Accessibility is on. I can read highlights." : "Accessibility is off. I can't read highlights yet.")
                        .font(.ui(13)).foregroundColor(Palette.ink2)
                    Spacer()
                    Button("Set up") { showWelcome() }.buttonStyle(InkLinkButtonStyle())
                }
                HStack {
                    Button("Put the buddy back by the notch") { resetBuddy() }.buttonStyle(InkLinkButtonStyle())
                    Spacer()
                }
            }

            Spacer(minLength: 0)
            HStack {
                Text(versionText)
                    .font(.typewriter(10)).foregroundColor(Palette.ink3)
                Spacer()
                Button("Check for Updates") { checkForUpdates() }
                    .buttonStyle(StampButtonStyle(compact: true, quiet: true))
            }
        }
        .padding(26)
        .frame(width: 520, height: 640)
        .background(PaperSheet(corner: 0, graph: true).ignoresSafeArea())
        .onAppear {
            endpointDraft = state.endpoint
            tokenDraft = state.clientToken
            state.accessibilityGranted = Accessibility.isTrusted
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.fellItalic(19)).foregroundColor(Palette.ink)
            content()
        }
        .padding(.top, 20)
    }

    private func label(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.uiBold(13.5)).foregroundColor(Palette.ink)
            Text(detail).font(.ui(12)).foregroundColor(Palette.ink3).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.ui(12)).foregroundColor(Palette.ink3)
            Group {
                if secure { SecureField(placeholder, text: text) } else { TextField(placeholder, text: text) }
            }
            .textFieldStyle(.plain)
            .font(.typewriter(13))
            .foregroundColor(Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 3).fill(Palette.paper2))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ink.opacity(0.55), lineWidth: 1))
        }
    }

    // MARK: Actions

    private func save() {
        state.endpoint = endpointDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        state.clientToken = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        testStatus = state.endpointIsConfigured ? "Saved." : "Saved, but that address doesn't look right yet."
    }

    private func test() {
        save()
        testing = true
        testStatus = ""
        let client = ExplainClient(endpoint: state.endpoint, token: state.clientToken, configured: state.endpointIsConfigured)
        Task { @MainActor in
            do {
                _ = try await client.explain(text: "photosynthesis", context: "", mode: .simpler)
                testStatus = "Works. The explainer answered."
            } catch let err as ExplainError {
                testStatus = err.title
            } catch {
                testStatus = error.localizedDescription
            }
            testing = false
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = ""
        } catch {
            loginError = "macOS said no. Move Paper Tree to Applications and try again."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
