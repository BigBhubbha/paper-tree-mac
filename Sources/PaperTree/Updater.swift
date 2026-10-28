// Built-in updates through Sparkle 2. The feed, public key, and daily automatic checks live in Info.plist.
import AppKit
import Sparkle

@MainActor
final class Updater {
    private let driverDelegate = UpdaterDriverDelegate()
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: driverDelegate)
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    /// "Check for Updates..." from the menu bar menu.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}

/// Paper Tree has no Dock icon, so when a scheduled check finds an update we bring the app
/// forward first, otherwise Sparkle's window could open behind whatever you are reading.
final class UpdaterDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        true
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }
}
