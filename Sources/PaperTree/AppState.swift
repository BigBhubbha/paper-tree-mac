// Everything the app remembers between launches lives here, in UserDefaults.
import AppKit
import Combine

/// What the buddy is doing right now. Drives its face and bubbles.
enum BuddyMood: Equatable {
    case idle        // resting, happy closed eyes
    case noticed     // a highlight was captured; eyes open, waiting for a click
    case thinking    // an explanation is loading; lots of bubbles
    case needsAccess // Accessibility permission missing
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    static let placeholderEndpoint = "https://YOUR-SITE.netlify.app/api/explain"
    /// The built-in explainer. Users never have to set anything up.
    static let defaultEndpoint = "https://paper-tree-explain.papertree.workers.dev/api/explain"

    private enum Key {
        static let researchMode = "researchMode"
        static let endpoint = "explainEndpoint"
        static let clientToken = "clientToken"
        static let buddyX = "buddyCenterXFraction"
        static let showBuddy = "showBuddy"
        static let specimenCount = "specimenCount"
        static let onboarded = "onboardedAccessibility"
        static let copyFallback = "copyFallbackEnabled"
    }

    private let defaults = UserDefaults.standard

    @Published var researchMode: Bool { didSet { defaults.set(researchMode, forKey: Key.researchMode) } }
    @Published var endpoint: String { didSet { defaults.set(endpoint, forKey: Key.endpoint) } }
    /// Optional shared token, only needed if the backend sets APP_TOKEN.
    @Published var clientToken: String { didSet { defaults.set(clientToken, forKey: Key.clientToken) } }
    /// Buddy's horizontal center as a fraction of the screen width (0 to 1). Negative means "default spot".
    @Published var buddyCenterXFraction: Double { didSet { defaults.set(buddyCenterXFraction, forKey: Key.buddyX) } }
    @Published var showBuddy: Bool { didSet { defaults.set(showBuddy, forKey: Key.showBuddy) } }
    /// When Accessibility gives no text, briefly press Cmd+C to read the highlight (pasteboard is restored).
    @Published var copyFallbackEnabled: Bool { didSet { defaults.set(copyFallbackEnabled, forKey: Key.copyFallback) } }
    @Published var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: Key.onboarded) } }

    @Published var accessibilityGranted: Bool = false
    @Published var mood: BuddyMood = .idle

    private(set) var specimenCount: Int {
        get { defaults.integer(forKey: Key.specimenCount) }
        set { defaults.set(newValue, forKey: Key.specimenCount) }
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Key.researchMode: false,
            Key.endpoint: AppState.defaultEndpoint,
            Key.clientToken: "",
            Key.buddyX: -1.0,
            Key.showBuddy: true,
            Key.copyFallback: true,
            Key.onboarded: false,
        ])
        researchMode = defaults.bool(forKey: Key.researchMode)
        let saved = defaults.string(forKey: Key.endpoint) ?? AppState.defaultEndpoint
        endpoint = saved.contains("YOUR-SITE") || saved.trimmingCharacters(in: .whitespaces).isEmpty ? AppState.defaultEndpoint : saved
        clientToken = defaults.string(forKey: Key.clientToken) ?? ""
        buddyCenterXFraction = defaults.double(forKey: Key.buddyX)
        showBuddy = defaults.bool(forKey: Key.showBuddy)
        copyFallbackEnabled = defaults.bool(forKey: Key.copyFallback)
        hasOnboarded = defaults.bool(forKey: Key.onboarded)
    }

    /// True when the endpoint still looks like the placeholder or is not a usable https URL.
    var endpointIsConfigured: Bool {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("YOUR-SITE"),
              let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "https" || (scheme == "http" && (url.host == "localhost" || url.host == "127.0.0.1")),
              url.host != nil
        else { return false }
        return true
    }

    func nextSpecimenNumber() -> Int {
        specimenCount += 1
        return specimenCount
    }

    /// Recomputes the buddy's face from permissions and mode, unless it is busy thinking.
    func refreshMood(noticed: Bool = false) {
        if mood == .thinking { return }
        if !accessibilityGranted && researchMode { mood = .needsAccess; return }
        mood = noticed ? .noticed : .idle
    }
}
