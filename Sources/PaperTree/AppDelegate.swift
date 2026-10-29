// Wires everything together: the notch island, menu bar item, right Option taps, selection monitor, card, and windows.
import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState.shared
    private var island: IslandController!
    private var optionTaps: RightOptionTapDetector!
    private var card: CardController!
    private var monitor: SelectionMonitor!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var bag = Set<AnyCancellable>()
    private var updater: Updater?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Typeface.registerBundledFonts()
        updater = Updater()
        state.accessibilityGranted = Accessibility.isTrusted

        card = CardController()
        card.onOpenSettings = { [weak self] in self?.openSettings() }

        island = IslandController()
        island.model.onOpenSettings = { [weak self] in self?.island.close(); self?.openSettings() }
        island.model.onRequestAccess = { [weak self] in self?.island.close(); self?.openWelcome() }
        island.model.onCheckForUpdates = { [weak self] in self?.island.close(); self?.updater?.checkForUpdates() }

        // Double-tap right Option: open or close the island. Triple-tap: flip Research mode.
        optionTaps = RightOptionTapDetector()
        optionTaps.onDoubleTap = { [weak self] in self?.island.toggle() }
        optionTaps.onTripleTap = { [weak self] in
            guard let self else { return }
            self.island.close()
            self.state.researchMode.toggle()
        }
        optionTaps.start()

        monitor = SelectionMonitor(card: card)
        monitor.start()

        setUpStatusItem()
        setUpMainMenu()
        state.refreshMood()

        if !state.accessibilityGranted || state.needsSetup {
            openWelcome()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    // MARK: Main menu (shown in the menu bar while Paper Tree is the active app)

    private func setUpMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu(title: "Paper Tree")
        appItem.submenu = appMenu

        appMenu.addItem(withTitle: "About Paper Tree",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let updates = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        appMenu.addItem(updates)
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        let redo = NSMenuItem(title: "Redo setup...", action: #selector(showWelcome), keyEquivalent: "")
        redo.target = self
        appMenu.addItem(redo)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Paper Tree", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Paper Tree", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        appMenu.addItem(quit)

        // Edit menu so Cmd+C / Cmd+V / Cmd+A work in Settings text fields.
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        editItem.submenu = edit
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // Window menu so Cmd+W closes Settings or the welcome page.
        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let window = NSMenu(title: "Window")
        windowItem.submenu = window
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        NSApp.windowsMenu = window

        NSApp.mainMenu = main
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

        let open = NSMenuItem(title: "Open the island (double-tap right Option)", action: #selector(toggleIsland), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())
        if !Accessibility.isTrusted {
            let access = NSMenuItem(title: "Turn on Accessibility...", action: #selector(showWelcome), keyEquivalent: "")
            access.target = self
            menu.addItem(access)
        }
        let settings = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let redo = NSMenuItem(title: "Redo setup...", action: #selector(showWelcome), keyEquivalent: "")
        redo.target = self
        menu.addItem(redo)
        let updates = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        updates.isEnabled = updater?.canCheckForUpdates ?? false
        menu.addItem(updates)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Paper Tree", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleResearch() { state.researchMode.toggle() }
    @objc private func toggleIsland() { island.toggle() }
    @objc private func showSettings() { openSettings() }
    @objc private func checkForUpdates() { updater?.checkForUpdates() }
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
            settingsWindow = makeWindow(title: "Paper Tree Settings", size: NSSize(width: 520, height: 680),
                                        view: SettingsView(state: state,
                                                           showWelcome: { [weak self] in self?.openWelcome() },
                                                           checkForUpdates: { [weak self] in self?.updater?.checkForUpdates() }))
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// The practice passage in setup shows a real card, just like a highlight in any other app.
    private func explainPractice(text: String, context: String, rect: NSRect) {
        let sel = CapturedSelection(text: text, context: context, rect: rect, preciseRect: true,
                                    appPID: ProcessInfo.processInfo.processIdentifier, appName: "Paper Tree",
                                    capturedAt: Date(), source: .accessibility)
        card.show(for: sel, clickedAt: NSPoint(x: rect.minX + 24, y: rect.minY))
    }

    func openWelcome() {
        // Always start a fresh notebook at entry 001 (this is also "Redo setup").
        welcomeWindow?.close()
        welcomeWindow = makeWindow(title: "Set up Paper Tree", size: SetupView.size,
                                   view: SetupView(state: state,
                                                   island: island.model,
                                                   explainPractice: { [weak self] text, context, rect in
                                                       self?.explainPractice(text: text, context: context, rect: rect)
                                                   },
                                                   done: { [weak self] in
                                                       guard let self else { return }
                                                       self.state.hasOnboarded = true
                                                       self.state.setupVersionCompleted = AppState.currentSetupVersion
                                                       self.card.close()
                                                       self.welcomeWindow?.close()
                                                   }))
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
