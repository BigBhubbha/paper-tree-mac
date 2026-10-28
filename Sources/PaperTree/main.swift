// Entry point. Paper Tree is an "agent" app: no Dock icon, just the
// flask buddy at the top of the screen and a small menu bar item.
import AppKit

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.accessory)
app.run()
