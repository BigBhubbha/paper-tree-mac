// Settings, drawn as the instrument drawer of the field journal (Plate II):
//   a printed herbarium label holding the reader's answers, a slip with the real count of cards,
//   the switches as hanging specimen tags you answer in pencil, a drawn keyboard figure for the
//   shortcut, and the explainer's address tucked under "For tinkerers" at the very bottom.
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var state: AppState
    var showWelcome: () -> Void
    var checkForUpdates: () -> Void

    @State private var endpointDraft: String = ""
    @State private var tokenDraft: String = ""
    @State private var testStatus: String = ""
    @State private var testing = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String = ""
    @State private var showTinkerers: Bool

    static let size = NSSize(width: 640, height: 760)

    init(state: AppState, showWelcome: @escaping () -> Void,
         checkForUpdates: @escaping () -> Void, showTinkerers: Bool = false) {
        self.state = state
        self.showWelcome = showWelcome
        self.checkForUpdates = checkForUpdates
        _showTinkerers = State(initialValue: showTinkerers)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Paper Tree \(version)" : "Paper Tree \(version), build \(build)"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) { content }
            .frame(width: SettingsView.size.width, height: SettingsView.size.height)
            .background(DeskBackground().ignoresSafeArea())
            .onAppear {
                endpointDraft = state.endpoint
                tokenDraft = state.clientToken
                state.accessibilityGranted = Accessibility.isTrusted
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
    }

    /// The page itself (outside the scroll view, so snapshots can render it).
    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead

            HStack(alignment: .top, spacing: 26) {
                ReaderLabel(state: state, redoSetup: showWelcome)
                    .frame(width: 352)
                VStack(alignment: .leading, spacing: 18) {
                    CountSlip(count: state.specimenCount)
                    permission
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 22)

            switches.padding(.top, 30)

            figure.padding(.top, 30)

            colophon.padding(.top, 30)
        }
        .padding(.horizontal, 34)
        .padding(.top, 34)
        .padding(.bottom, 26)
        .frame(width: SettingsView.size.width, alignment: .topLeading)
        .background(
            PaperSheet(corner: 2, graph: true)
                .shadow(color: Palette.ink.opacity(0.14), radius: 6, x: 0, y: 3)
                .padding(10)
        )
        .overlay(alignment: .topLeading) {
            Tape().rotationEffect(.degrees(-6)).offset(x: 40, y: 2)
        }
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Plate II.").font(.typewriter(11.5)).foregroundColor(Palette.red)
                Text("Instruments").font(.typewriter(11.5)).foregroundColor(Palette.ink3)
            }
            .padding(.leading, 2)
            Text("The instrument drawer")
                .font(.fell(34))
                .foregroundColor(Palette.ink)
                .padding(.top, 2)
            Text("How Paper Tree reads alongside you. Answers and switches save the moment you change them.")
                .font(.text(14.5))
                .foregroundColor(Palette.ink2)
                .frame(maxWidth: 420, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            // A printer's double rule: a heavy line over a hairline.
            VStack(spacing: 2.5) {
                Rectangle().fill(Palette.ink).frame(height: 1.6)
                Rectangle().fill(Palette.ink.opacity(0.7)).frame(height: 0.6)
            }
            .padding(.top, 14)
        }
    }

    // MARK: Permission

    @ViewBuilder private var permission: some View {
        if state.accessibilityGranted {
            HStack(alignment: .center, spacing: 6) {
                ApprovalStamp(granted: true).scaleEffect(0.72).frame(width: 80, height: 80)
                Text("macOS lets me read your highlights.")
                    .font(.hand(14))
                    .foregroundColor(Palette.green)
                    .fixedSize(horizontal: false, vertical: true)
                    .rotationEffect(.degrees(-1.5))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("I can't read highlights yet. macOS needs to let me in first.")
                    .font(.hand(14.5))
                    .foregroundColor(Palette.red)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Let Paper Tree in") { showWelcome() }
                    .buttonStyle(StampButtonStyle(compact: true))
            }
            .rotationEffect(.degrees(-1))
        }
    }

    // MARK: Switches

    private var switches: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead("Switches", aside: "circle on or off")
            VStack(alignment: .leading, spacing: 14) {
                SpecimenTag(number: 1, label: "research mode", tilt: -0.7) {
                    switchRow("Highlight anything and the card opens by itself. Triple-tap right Option to flip it from anywhere.",
                              isOn: $state.researchMode, name: "Research mode")
                }
                .frame(width: 548)

                SpecimenTag(number: 2, label: "copy fallback", tilt: 0.5) {
                    switchRow("Some apps hide their text from me. Then I press Cmd+C for you and put your clipboard back after.",
                              isOn: $state.copyFallbackEnabled, name: "Copy fallback")
                }
                .frame(width: 530)
                .padding(.leading, 22)

                SpecimenTag(number: 3, label: "open at login", tilt: -0.3) {
                    switchRow(loginError.isEmpty ? "Start Paper Tree when you log in, so it is already on your bench." : loginError,
                              isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }), name: "Open at login")
                }
                .frame(width: 512)
                .padding(.leading, 8)
            }
            .padding(.top, 14)
        }
    }

    private func switchRow(_ detail: String, isOn: Binding<Bool>, name: String) -> some View {
        HStack(alignment: .center, spacing: 18) {
            Text(detail)
                .font(.text(13.5))
                .foregroundColor(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HandSwitch(isOn: isOn, name: name)
        }
    }

    // MARK: Figure

    private var figure: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead("The shortcut", aside: "click the marked key")
            OptionKeyFigure()
                .padding(.top, 12)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Fig. 1.").font(.fellItalic(14)).foregroundColor(Palette.ink)
                Text("The right Option key. Two quick taps open the island at the notch; three flip Research mode.")
                    .font(.text(13))
                    .foregroundColor(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.leading, 40)
        }
    }

    // MARK: Colophon and tinkerers

    private var colophon: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Palette.ink.opacity(0.35)).frame(height: 0.6)
            HStack(alignment: .firstTextBaseline) {
                Text(versionText).font(.typewriter(10.5)).foregroundColor(Palette.ink3)
                Spacer()
                Button("Check for updates") { checkForUpdates() }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink2))
            }
            DisclosureGroup(isExpanded: $showTinkerers) {
                tinkerers.padding(.top, 10)
            } label: {
                Text("For tinkerers")
                    .font(.typewriter(10.5)).foregroundColor(Palette.ink3)
            }
            .accentColor(Palette.ink3)
        }
    }

    private var tinkerers: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Highlights go to Paper Tree's explainer, which asks Google's Gemini for a short answer. Change this only if you run your own copy of the explainer.")
                .font(.text(13)).foregroundColor(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            field("Server address", text: $endpointDraft, placeholder: AppState.defaultEndpoint)
            field("App token (optional)", text: $tokenDraft, placeholder: "Only if your server sets APP_TOKEN", secure: true)
            HStack(spacing: 14) {
                Button("Save") { save() }.buttonStyle(StampButtonStyle(compact: true))
                Button(testing ? "Testing..." : "Test it") { test() }
                    .buttonStyle(StampButtonStyle(compact: true, quiet: true))
                    .disabled(testing)
                Button("Use the built-in explainer") {
                    endpointDraft = AppState.defaultEndpoint
                    tokenDraft = ""
                    save()
                }
                .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            }
            if !testStatus.isEmpty {
                Text(testStatus)
                    .font(.hand(14))
                    .foregroundColor(testStatus.hasPrefix("Works") ? Palette.green : Palette.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Pieces

    private func sectionHead(_ title: String, aside: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.fellItalic(21)).foregroundColor(Palette.ink)
            Text(aside).font(.hand(13.5)).foregroundColor(Palette.pencil)
                .rotationEffect(.degrees(-2))
        }
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.typewriter(10.5)).foregroundColor(Palette.ink3)
            Group {
                if secure { SecureField(placeholder, text: text) } else { TextField(placeholder, text: text) }
            }
            .textFieldStyle(.plain)
            .font(.typewriter(12.5))
            .foregroundColor(Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 2).fill(Palette.paper2))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.ink.opacity(0.45), lineWidth: 0.9))
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
        let client = ExplainClient(endpoint: state.endpoint, token: state.clientToken, configured: state.endpointIsConfigured, profile: state.profilePayload)
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

// MARK: - The reader's label

/// A printed herbarium label: a double-ruled box, a centered heading, typed field names,
/// and the reader's own answers written in by hand. Click an answer to change it.
private struct ReaderLabel: View {
    @ObservedObject var state: AppState
    var redoSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 1) {
                Text("Paper Tree Herbarium").font(.fell(15.5)).foregroundColor(Palette.ink)
                Text("the reader, as determined in setup").font(.textItalic(11.5)).foregroundColor(Palette.ink3)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)

            row("year", options: ReaderProfile.schoolYears, value: $state.profileSchool)
            row("background", options: ReaderProfile.expertise, value: $state.profileExpertise)
            fieldsRow
            row("notes", options: ReaderProfile.lengths, value: $state.profileLength)

            HStack(alignment: .firstTextBaseline) {
                Text("det. you").font(.typewriter(9.5)).foregroundColor(Palette.ink3)
                Spacer()
                Button("walk through setup again") { redoSetup() }
                    .buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: 0xFBF8EE))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.8), lineWidth: 1.1))
        .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.45), lineWidth: 0.5).padding(3.5))
        .shadow(color: Palette.ink.opacity(0.08), radius: 1.5, x: 0, y: 1)
        .rotationEffect(.degrees(-0.4))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About you")
    }

    private func row(_ title: String, options: [ProfileOption], value: Binding<String>) -> some View {
        line(title) {
            Menu {
                ForEach(options) { o in Button(o.label) { value.wrappedValue = o.id } }
                Divider()
                Button("Leave blank") { value.wrappedValue = "" }
            } label: {
                answer(ReaderProfile.label(value.wrappedValue, in: options))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(title)
        }
    }

    private var fieldsRow: some View {
        let picked = ReaderProfile.fields.filter { state.profileFields.contains($0.id) }.map(\.short)
        return line("reads") {
            Menu {
                ForEach(ReaderProfile.fields) { o in
                    Button((state.profileFields.contains(o.id) ? "\u{2713} " : "    ") + o.label) {
                        if let i = state.profileFields.firstIndex(of: o.id) { state.profileFields.remove(at: i) }
                        else { state.profileFields.append(o.id) }
                    }
                }
            } label: {
                answer(picked.isEmpty ? nil : picked.joined(separator: ", "))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("fields you read")
        }
    }

    private func answer(_ text: String?) -> some View {
        Text(text ?? "blank, tap to fill in")
            .font(.hand(text == nil ? 14 : 16))
            .foregroundColor(text == nil ? Palette.pencil : Color(hex: 0x23314A)) // blue-black fountain pen ink
            .lineLimit(1)
    }

    /// A typed field name, then the handwritten answer sitting on a dotted ruled line.
    private func line<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title + ":").font(.typewriter(11)).foregroundColor(Palette.ink2)
                .frame(width: 86, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
            DottedRule().stroke(Palette.ink.opacity(0.35), style: StrokeStyle(lineWidth: 0.8, dash: [1, 3]))
                .frame(height: 1)
                .padding(.leading, 94)
        }
    }
}

private struct DottedRule: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

// MARK: - The count slip

/// A small taped slip with the real number of explanation cards this Mac has opened.
private struct CountSlip: View {
    var count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("specimens so far").font(.typewriter(10.5)).foregroundColor(Palette.ink3)
            Text(count.formatted())
                .font(.fell(count > 9999 ? 36 : 46))
                .foregroundColor(Palette.ink)
                .padding(.top, 2)
            Text(count == 0 ? "None yet. Turn on Research mode and highlight a line."
                            : (count == 1 ? "card opened on this Mac" : "cards opened on this Mac"))
                .font(.hand(14))
                .foregroundColor(count == 0 ? Palette.pencil : Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if count > 0 {
                Text("practice cards count too")
                    .font(.typewriter(9))
                    .foregroundColor(Palette.ink3)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(width: 176, alignment: .leading)
        .background(
            Rectangle().fill(Color(hex: 0xF3EBD3))
                .overlay(Image(nsImage: PaperGrain.image).resizable(resizingMode: .tile).opacity(0.5))
                .shadow(color: Palette.ink.opacity(0.12), radius: 2, x: 1, y: 2)
        )
        .overlay(alignment: .top) {
            Tape().scaleEffect(x: 0.62, y: 0.8).rotationEffect(.degrees(4)).offset(y: -12)
        }
        .rotationEffect(.degrees(2.2))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hand switch

/// "on / off" written in pencil; the current one is circled in red. Click either word.
struct HandSwitch: View {
    @Binding var isOn: Bool
    var name: String

    var body: some View {
        HStack(spacing: 6) {
            word("on", selected: isOn) { isOn = true }
            Text("/").font(.hand(15)).foregroundColor(Palette.pencil)
            word("off", selected: !isOn) { isOn = false }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { isOn.toggle() }
    }

    private func word(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.3)) { action() }
        } label: {
            Text(text)
                .font(.hand(17))
                .foregroundColor(selected ? Palette.ink : Palette.pencil)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(
                    PencilCircle(seed: text.count + 2)
                        .trim(from: 0, to: selected ? 1 : 0)
                        .stroke(selected && text == "on" ? Palette.green : Palette.red.opacity(0.85),
                                style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .padding(.horizontal, -2)
                        .padding(.vertical, -1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fig. 1, the keyboard

/// The right end of a Mac keyboard's bottom row, drawn in ink. The right Option key is
/// marked in highlighter; red pen notes say what two and three taps do. Clicking the
/// marked key plays the double tap.
struct OptionKeyFigure: View {
    @State private var pressed = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: .bottom, spacing: 7) {
                // The space bar runs off the left edge, so it reads as part of a bigger keyboard.
                DrawnKey(width: 150, tilt: 0.3) { EmptyView() }
                    .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .leading, endPoint: .trailing))
                DrawnKey(width: 66, tilt: -0.5) { keyLabel(symbol: "\u{2318}", word: "command") }
                DrawnKey(width: 60, tilt: 0.6, marked: true, pressed: pressed) { keyLabel(symbol: "\u{2325}", word: "option") }
                    .onTapGesture { playDoubleTap() }
                    .help("Click to see a double tap")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Right Option key. Click to see a double tap.")
                ArrowCluster()
            }
            .padding(.top, 58)
            .padding(.leading, 34)

            // Red pen notes, pointing at the marked key.
            HandNote(text: "tap tap: the island opens", arrowTo: CGPoint(x: 18, y: 50))
                .offset(x: 222, y: 0)
            HandNote(text: "tap tap tap: Research mode on or off", arrowTo: CGPoint(x: -20, y: 30), flip: true)
                .offset(x: 330, y: 26)
        }
        .frame(height: 124, alignment: .topLeading)
    }

    private func keyLabel(symbol: String, word: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Spacer(); Text(symbol).font(.system(size: 10.5)) }
            Spacer(minLength: 0)
            Text(word).font(.ui(9.5))
        }
        .foregroundColor(Palette.ink2)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
    }

    private func playDoubleTap() {
        Task { @MainActor in
            for _ in 0..<2 {
                withAnimation(.easeOut(duration: 0.07)) { pressed = true }
                try? await Task.sleep(nanoseconds: 110_000_000)
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pressed = false }
                try? await Task.sleep(nanoseconds: 140_000_000)
            }
        }
    }
}

/// One keycap drawn in ink: a top face over a thicker bottom edge, slightly off square.
private struct DrawnKey<Label: View>: View {
    var width: CGFloat
    var tilt: Double = 0
    var marked = false
    var pressed = false
    @ViewBuilder var label: Label

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Palette.ink.opacity(0.75))
                .offset(y: 2.5)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: 0xFBF8EE))
                .overlay(
                    // Highlighter over the key that matters, a little outside the lines.
                    marked ? AnyView(RoundedRectangle(cornerRadius: 3).fill(Palette.marker.opacity(0.6))
                        .padding(.horizontal, -3).padding(.vertical, 6).rotationEffect(.degrees(-3))) : AnyView(EmptyView())
                )
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1.1))
                .overlay(label)
                .offset(y: pressed ? 2.5 : 0)
        }
        .frame(width: width, height: 40)
        .rotationEffect(.degrees(tilt))
    }
}

/// The inverted-T arrow keys, half height on top and bottom like a real Mac.
private struct ArrowCluster: View {
    var body: some View {
        VStack(spacing: 3) {
            arrow("\u{25B2}").frame(width: 30, height: 18)
            HStack(spacing: 3) {
                arrow("\u{25C0}").frame(width: 30, height: 18)
                arrow("\u{25BC}").frame(width: 30, height: 18)
                arrow("\u{25B6}").frame(width: 30, height: 18)
            }
        }
        .rotationEffect(.degrees(-0.4))
    }

    private func arrow(_ s: String) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color(hex: 0xFBF8EE))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1))
            .overlay(Text(s).font(.system(size: 6.5)).foregroundColor(Palette.ink2))
    }
}

/// A red pen note with a loose curved arrow from its first letter toward a point.
private struct HandNote: View {
    var text: String
    var arrowTo: CGPoint
    var flip = false

    var body: some View {
        Text(text)
            .font(.hand(14.5))
            .foregroundColor(Palette.red)
            .fixedSize()
            .overlay(alignment: .topLeading) {
                PenArrow(to: arrowTo, flip: flip)
                    .stroke(Palette.red.opacity(0.85), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                    .frame(width: 1, height: 1)
                    .offset(x: flip ? 0 : 4, y: 20)
            }
            .rotationEffect(.degrees(flip ? 1.5 : -2))
    }
}

private struct PenArrow: Shape {
    var to: CGPoint
    var flip: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        let start = CGPoint(x: r.minX, y: r.minY)
        let end = CGPoint(x: start.x + to.x, y: start.y + to.y)
        let control = CGPoint(x: start.x + (flip ? to.x * 0.1 : to.x * 0.9), y: start.y + to.y * 0.2)
        p.move(to: start)
        p.addQuadCurve(to: end, control: control)
        // Arrowhead, drawn as two short strokes.
        let angle = atan2(end.y - control.y, end.x - control.x)
        for side in [-1.0, 1.0] {
            let a = angle + .pi + side * 0.45
            p.move(to: end)
            p.addLine(to: CGPoint(x: end.x + 7 * CGFloat(cos(a)), y: end.y + 7 * CGFloat(sin(a))))
        }
        return p
    }
}
