// Entry point. Paper Tree is an "agent" app: no Dock icon, just the
// flask buddy at the top of the screen and a small menu bar item.
import AppKit

// Top-level code runs on the main thread; tell the compiler so it can create the @MainActor delegate.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let appDelegate = AppDelegate()
    app.delegate = appDelegate
    app.setActivationPolicy(.accessory)
    app.run()
    _ = appDelegate // keep the delegate alive for the life of the app (NSApplication.delegate is weak)
}
