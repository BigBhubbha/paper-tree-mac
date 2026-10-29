// The island: a black pill that grows out of the notch, Dynamic Island style.
// Double-tap the right Option key to open or close it; triple-tap to flip Research mode.
import AppKit
import SwiftUI
import Combine

// MARK: Model

@MainActor
final class IslandModel: ObservableObject {
    enum Mode: Equatable {
        case hidden
        case flash(on: Bool)
        case expanded
    }

    @Published var mode: Mode = .hidden
    /// Size of the notch (or a small stand-in on Macs without one). The pill starts and ends here.
    @Published var notchSize = CGSize(width: 190, height: 32)
    @Published var hasNotch = true

    var onOpenSettings: () -> Void = {}
    var onCheckForUpdates: () -> Void = {}
    var onRequestAccess: () -> Void = {}
    var onQuit: () -> Void = {}

    static let expandedSize = CGSize(width: 400, height: 262)
    static let flashExtraWidth: CGFloat = 170
    static let flashExtraHeight: CGFloat = 30

    var pillSize: CGSize {
        switch mode {
        case .hidden:
            return hasNotch ? notchSize : CGSize(width: notchSize.width * 0.6, height: 0)
        case .flash:
            return CGSize(width: notchSize.width + IslandModel.flashExtraWidth,
                          height: notchSize.height + IslandModel.flashExtraHeight)
        case .expanded:
            return CGSize(width: IslandModel.expandedSize.width,
                          height: notchSize.height + IslandModel.expandedSize.height)
        }
    }
}

// MARK: Controller

@MainActor
final class IslandController {
    private let state = AppState.shared
    let model = IslandModel()
    private let panel: IslandPanel
    private var bag = Set<AnyCancellable>()
    private var outsideMonitors: [Any] = []
    private var collapseTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    /// Room around the pill for its shadow.
    private let margin: CGFloat = 24

    var isExpanded: Bool { model.mode == .expanded }

    init() {
        panel = IslandPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10))
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: IslandView(model: model, state: state))
        host.sizingOptions = []
        panel.contentView = host
        panel.onEscape = { [weak self] in self?.close() }

        model.onQuit = { NSApp.terminate(nil) }

        // A small flash whenever Research mode changes, unless the full panel is already open.
        state.$researchMode.dropFirst().removeDuplicates().sink { [weak self] on in
            Task { @MainActor in
                guard let self, !self.isExpanded else { return }
                self.flash(researchOn: on)
            }
        }.store(in: &bag)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.placeOnScreen() }
        }
    }

    // MARK: Placement

    /// The built-in display (the one with the notch) if there is one, else the main display.
    private var homeScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func measureNotch(_ screen: NSScreen) {
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            model.hasNotch = true
            model.notchSize = CGSize(width: max(120, width), height: top)
        } else {
            let bar = screen.frame.maxY - screen.visibleFrame.maxY
            model.hasNotch = false
            model.notchSize = CGSize(width: 190, height: max(22, min(bar, 30)))
        }
    }

    /// The panel is sized for the largest pill so the spring never gets cut off, and sits flush with the top.
    private func placeOnScreen() {
        guard let screen = homeScreen else { return }
        measureNotch(screen)
        let w = max(IslandModel.expandedSize.width, model.notchSize.width + IslandModel.flashExtraWidth) + margin * 2
        let h = model.notchSize.height + IslandModel.expandedSize.height + margin
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h), display: true)
    }

    // MARK: Open, close, flash

    func toggle() { isExpanded ? close() : open() }

    func open() {
        collapseTask?.cancel()
        hideTask?.cancel()
        state.accessibilityGranted = Accessibility.isTrusted
        state.refreshMood()
        if !panel.isVisible { placeOnScreen(); model.mode = .hidden }
        panel.ignoresMouseEvents = false
        panel.allowsKey = true
        panel.orderFrontRegardless()
        panel.makeKey()
        // Let the collapsed pill draw first, then spring it open.
        DispatchQueue.main.async { [weak self] in
            withAnimation(IslandView.spring) { self?.model.mode = .expanded }
        }
        installOutsideClickMonitors()
    }

    func close() {
        guard model.mode != .hidden else { return }
        removeOutsideClickMonitors()
        collapseTask?.cancel()
        panel.allowsKey = false
        withAnimation(IslandView.spring) { model.mode = .hidden }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard let self, !Task.isCancelled, self.model.mode == .hidden else { return }
            self.panel.orderOut(nil)
        }
    }

    /// A brief "Research mode on/off" pill that collapses back into the notch.
    func flash(researchOn: Bool) {
        hideTask?.cancel()
        collapseTask?.cancel()
        if !panel.isVisible { placeOnScreen(); model.mode = .hidden }
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            withAnimation(IslandView.spring) { self?.model.mode = .flash(on: researchOn) }
        }
        collapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self, !Task.isCancelled else { return }
            if case .flash = self.model.mode { self.close() }
        }
    }

    // MARK: Click outside to close

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()
        if let g = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            Task { @MainActor in self?.close() }
        }) { outsideMonitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] e in
            let number = e.windowNumber
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                guard let self else { return }
                if number != self.panel.windowNumber || !self.pillFrameOnScreen.contains(location) { self.close() }
            }
            return e
        }) { outsideMonitors.append(l) }
    }

    private func removeOutsideClickMonitors() {
        outsideMonitors.forEach { NSEvent.removeMonitor($0) }
        outsideMonitors.removeAll()
    }

    /// Where the open pill is on screen (the panel itself is a bit bigger for the shadow).
    private var pillFrameOnScreen: NSRect {
        let size = model.pillSize
        let f = panel.frame
        return NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height, width: size.width, height: size.height)
    }
}

/// Transparent, non-activating panel. It can take Esc without pulling focus from the app you're reading.
final class IslandPanel: FloatingPanel {
    var onEscape: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

// MARK: Views

struct IslandView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var state: AppState

    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.78)

    var body: some View {
        let size = model.pillSize
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                IslandShape(bottomRadius: model.mode == .expanded ? 30 : min(size.height / 2, 18))
                    .fill(Color.black)
                    .shadow(color: .black.opacity(model.mode == .hidden ? 0 : 0.35), radius: 14, x: 0, y: 6)

                content
                    .padding(.top, model.notchSize.height)
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .clipped()
            }
            .frame(width: size.width, height: size.height)
            .opacity(model.mode == .hidden && !model.hasNotch ? 0 : 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var content: some View {
        switch model.mode {
        case .hidden:
            EmptyView()
        case .flash(let on):
            HStack(spacing: 10) {
                BuddyView(mood: .idle, researchMode: on, compact: true)
                    .frame(width: 22, height: 22)
                Text(on ? "Research mode on" : "Research mode off")
                    .font(.uiBold(13))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
                Circle()
                    .fill(on ? Palette.mint : Color.white.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 22)
            .frame(height: IslandModel.flashExtraHeight)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
        case .expanded:
            IslandPanelContent(model: model, state: state)
                .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.12)))
        }
    }
}

/// What's inside the open island: a field-journal slip set into the black pill.
private struct IslandPanelContent: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 9) {
                BuddyView(mood: state.mood, researchMode: state.researchMode, compact: true)
                    .frame(width: 24, height: 24)
                Text("Paper Tree")
                    .font(.fell(19))
                    .foregroundColor(.white)
                Spacer()
                Text("Field kit, No. 1")
                    .font(.typewriter(10.5))
                    .foregroundColor(Palette.mint.opacity(0.85))
            }
            .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: $state.researchMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Research mode")
                            .font(.uiBold(14.5))
                            .foregroundColor(Palette.ink)
                        Text(state.researchMode ? "On. Highlight anything and it explains." : "Off. Highlight freely.")
                            .font(.ui(12))
                            .foregroundColor(Palette.ink3)
                    }
                }
                .toggleStyle(InkToggleStyle())

                status.padding(.top, 10)

                Rectangle().fill(Palette.rule).frame(height: 1).padding(.top, 10)

                HStack(spacing: 14) {
                    Button("Settings", action: model.onOpenSettings).buttonStyle(InkLinkButtonStyle())
                    Button("Check for Updates", action: model.onCheckForUpdates).buttonStyle(InkLinkButtonStyle())
                    Spacer()
                    Button("Quit", action: model.onQuit).buttonStyle(InkLinkButtonStyle(color: Palette.ink3))
                }
                .padding(.top, 9)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PaperSheet(corner: 12, graph: true))

            Text("double-tap right Option to open, triple-tap to toggle research mode")
                .font(.typewriter(9.5))
                .foregroundColor(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var status: some View {
        if !state.accessibilityGranted {
            HStack(alignment: .center, spacing: 8) {
                Circle().fill(Palette.red).frame(width: 7, height: 7)
                Text("I can't see highlights yet.")
                    .font(.ui(12.5)).foregroundColor(Palette.ink2)
                Spacer(minLength: 4)
                Button("Grant access", action: model.onRequestAccess)
                    .buttonStyle(StampButtonStyle(compact: true))
            }
        } else if !state.endpointIsConfigured {
            HStack(spacing: 8) {
                Circle().fill(Palette.red).frame(width: 7, height: 7)
                Text("No explainer connected. Check Settings.")
                    .font(.ui(12.5)).foregroundColor(Palette.ink2)
            }
        } else {
            HStack(spacing: 8) {
                Circle().fill(Palette.green).frame(width: 7, height: 7)
                Text("Explainer connected. Ready when you are.")
                    .font(.hand(14)).foregroundColor(Palette.green)
            }
        }
    }
}

/// Flat top that tucks into the notch, rounded bottom corners, and small outward curves
/// at the top corners so the pill looks like it flows out of the bezel.
struct IslandShape: Shape {
    var bottomRadius: CGFloat
    var earRadius: CGFloat = 8

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in r: CGRect) -> Path {
        let br = max(0, min(bottomRadius, r.height / 2, r.width / 2))
        let ear = min(earRadius, r.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX - ear, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX + ear, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + ear), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        p.addQuadCurve(to: CGPoint(x: r.maxX - br, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + br, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - br), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + ear))
        p.addQuadCurve(to: CGPoint(x: r.minX - ear, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: Right Option taps

/// Counts quick taps of the RIGHT Option key (key code 61) and reports double and triple taps.
/// It only looks at that one key's up and down; other keys just reset the count and are never stored.
@MainActor
final class RightOptionTapDetector {
    var onDoubleTap: () -> Void = {}
    var onTripleTap: () -> Void = {}

    private var monitors: [Any] = []
    private var downAt: Date?
    private var continuesSequence = false
    private var tapCount = 0
    private var lastTapAt = Date.distantPast
    private var decideTask: Task<Void, Never>?

    /// Max gap between taps, and max time the key may be held for it to count as a tap.
    private let window: TimeInterval = 0.35
    private let maxHold: TimeInterval = 0.3

    private static let rightOptionKeyCode: UInt16 = 61
    private static let rightOptionDeviceMask: UInt = 0x40 // NX_DEVICERALTKEYMASK

    struct KeyInfo: Sendable {
        var isFlagsChanged: Bool
        var keyCode: UInt16
        var rawFlags: UInt
        var otherModifiers: Bool
    }

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] e in
            let info = RightOptionTapDetector.info(e)
            Task { @MainActor in self?.handle(info) }
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] e in
            let info = RightOptionTapDetector.info(e)
            Task { @MainActor in self?.handle(info) }
            return e
        }) { monitors.append(l) }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    nonisolated private static func info(_ e: NSEvent) -> KeyInfo {
        let flags = e.modifierFlags
        let others = flags.contains(.command) || flags.contains(.control) || flags.contains(.shift) || flags.contains(.function)
        return KeyInfo(isFlagsChanged: e.type == .flagsChanged, keyCode: e.keyCode,
                       rawFlags: flags.rawValue, otherModifiers: others)
    }

    private func reset() {
        tapCount = 0
        downAt = nil
        decideTask?.cancel()
        decideTask = nil
    }

    private func handle(_ k: KeyInfo) {
        // Any other key, or any other modifier, breaks the sequence.
        guard k.isFlagsChanged, k.keyCode == RightOptionTapDetector.rightOptionKeyCode, !k.otherModifiers else {
            reset()
            return
        }
        let rightDown = k.rawFlags & RightOptionTapDetector.rightOptionDeviceMask != 0
        let now = Date()
        if rightDown {
            // A new press continues the sequence only if it comes soon after the last release.
            continuesSequence = tapCount > 0 && now.timeIntervalSince(lastTapAt) <= window
            downAt = now
            decideTask?.cancel()
            return
        }
        // Released.
        guard let down = downAt, now.timeIntervalSince(down) <= maxHold else { reset(); return }
        downAt = nil
        tapCount = continuesSequence ? tapCount + 1 : 1
        lastTapAt = now

        if tapCount >= 3 {
            reset()
            onTripleTap()
        } else if tapCount == 2 {
            // Wait out the tap window in case a third tap is coming.
            decideTask?.cancel()
            decideTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64((self?.window ?? 0.35) * 1_000_000_000))
                guard let self, !Task.isCancelled, self.tapCount == 2 else { return }
                self.reset()
                self.onDoubleTap()
            }
        }
    }
}
