// Entry point. Paper Tree is a regular app: it has a Dock icon and shows up in Cmd+Tab,
// plus the island at the notch (double-tap right Option) and a small menu bar item. Clicking the Dock icon opens Settings.
import AppKit

// Top-level code runs on the main thread; tell the compiler so it can create the @MainActor delegate.
MainActor.assumeIsolated {
    if Snapshots.runIfRequested() { exit(0) }
    let app = NSApplication.shared
    let appDelegate = AppDelegate()
    app.delegate = appDelegate
    app.setActivationPolicy(.regular)
    app.run()
    _ = appDelegate // keep the delegate alive for the life of the app (NSApplication.delegate is weak)
}
