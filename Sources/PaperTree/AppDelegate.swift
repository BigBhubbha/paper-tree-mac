// Wires everything together: buddy, menu bar item, selection monitor, card, and windows.
import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState.shared
    private var buddy: BuddyController!
    private var card: CardController!
    private var monitor: SelectionMonitor!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Typeface.registerBundledFonts()
        state.accessibilityGranted = Accessibility.isTrusted

        card = CardController()
        card.onOpenSettings = { [weak self] in self?.openSettings() }

        buddy = BuddyController()
        buddy.onOpenSettings = { [weak self] in self?.openSettings() }
        buddy.onRequestAccess = { [weak self] in self?.openWelcome() }
        buddy.setVisible(state.showBuddy)

        monitor = SelectionMonitor(card: card)
        monitor.start()

        setUpStatusItem()
        state.refreshMood()

        if !state.accessibilityGranted || !state.hasOnboarded {
            openWelcome()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.image(research: state.researchMode)
        statusItem.button?.toolTip = "Paper Tree"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        state.$researchMode.sink { [weak self] on in
            Task { @MainActor in self?.statusItem.button?.image = MenuBarIcon.image(research: on) }
        }.store(in: &bag)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "Paper Tree", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let research = NSMenuItem(title: "Research mode", action: #selector(toggleResearch), keyEquivalent: "")
        research.state = state.researchMode ? .on : .off
        research.target = self
        menu.addItem(research)

        let show = NSMenuItem(title: state.showBuddy ? "Hide buddy" : "Show buddy", action: #selector(toggleBuddy), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let reset = NSMenuItem(title: "Move buddy back to the notch", action: #selector(resetBuddy), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())
        if !Accessibility.isTrusted {
            let access = NSMenuItem(title: "Turn on Accessibility...", action: #selector(showWelcome), keyEquivalent: "")
            access.target = self
            menu.addItem(access)
        }
        let settings = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Paper Tree", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleResearch() { state.researchMode.toggle() }
    @objc private func toggleBuddy() { state.showBuddy.toggle() }
    @objc private func resetBuddy() { buddy.resetPosition() }
    @objc private func showSettings() { openSettings() }
    @objc private func showWelcome() { openWelcome() }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Windows

    private func makeWindow(title: String, size: NSSize, view: some View) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(red: 0xF8 / 255, green: 0xF3 / 255, blue: 0xE6 / 255, alpha: 1)
        window.contentView = NSHostingView(rootView: view)
        window.center()
        return window
    }

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: "Paper Tree Settings", size: NSSize(width: 520, height: 640),
                                        view: SettingsView(state: state,
                                                           resetBuddy: { [weak self] in self?.buddy.resetPosition() },
                                                           showWelcome: { [weak self] in self?.openWelcome() }))
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func openWelcome() {
        if welcomeWindow == nil {
            welcomeWindow = makeWindow(title: "Welcome to Paper Tree", size: NSSize(width: 540, height: 520),
                                       view: WelcomeView(state: state,
                                                         openSettings: { [weak self] in self?.openSettings() },
                                                         done: { [weak self] in
                                                             self?.state.hasOnboarded = true
                                                             if self?.state.accessibilityGranted == true { self?.state.researchMode = true }
                                                             self?.welcomeWindow?.close()
                                                         }))
        }
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow?.makeKeyAndOrderFront(nil)
    }
}

/// Menu bar glyph: a small flask outline, filled when research mode is on.
enum MenuBarIcon {
    static func image(research: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let p = NSBezierPath()
            p.move(to: NSPoint(x: 7.2, y: 2.5))
            p.line(to: NSPoint(x: 7.2, y: 7))
            p.line(to: NSPoint(x: 3.2, y: 14))
            p.curve(to: NSPoint(x: 4.6, y: 16), controlPoint1: NSPoint(x: 2.7, y: 15), controlPoint2: NSPoint(x: 3.4, y: 16))
            p.line(to: NSPoint(x: 13.4, y: 16))
            p.curve(to: NSPoint(x: 14.8, y: 14), controlPoint1: NSPoint(x: 14.6, y: 16), controlPoint2: NSPoint(x: 15.3, y: 15))
            p.line(to: NSPoint(x: 10.8, y: 7))
            p.line(to: NSPoint(x: 10.8, y: 2.5))
            p.lineJoinStyle = .round
            p.lineCapStyle = .round
            p.lineWidth = 1.5
            NSColor.black.setStroke()
            p.stroke()
            let rim = NSBezierPath()
            rim.move(to: NSPoint(x: 6, y: 2.5))
            rim.line(to: NSPoint(x: 12, y: 2.5))
            rim.lineWidth = 1.5
            rim.lineCapStyle = .round
            rim.stroke()
            if research {
                let liquid = NSBezierPath()
                liquid.move(to: NSPoint(x: 5.3, y: 10.6))
                liquid.line(to: NSPoint(x: 12.7, y: 10.6))
                liquid.line(to: NSPoint(x: 14.6, y: 14.2))
                liquid.curve(to: NSPoint(x: 13.3, y: 15.4), controlPoint1: NSPoint(x: 14.8, y: 14.8), controlPoint2: NSPoint(x: 14.2, y: 15.4))
                liquid.line(to: NSPoint(x: 4.7, y: 15.4))
                liquid.curve(to: NSPoint(x: 3.4, y: 14.2), controlPoint1: NSPoint(x: 3.8, y: 15.4), controlPoint2: NSPoint(x: 3.2, y: 14.8))
                liquid.close()
                NSColor.black.setFill()
                liquid.fill()
            } else {
                let dot = NSBezierPath(ovalIn: NSRect(x: 8.2, y: 10.5, width: 1.8, height: 1.8))
                NSColor.black.setFill()
                dot.fill()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
