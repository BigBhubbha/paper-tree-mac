// Everything the app remembers between launches lives here, in UserDefaults.
import AppKit
import Combine

/// What the flask is doing right now. Drives its face in the island and the card.
enum BuddyMood: Equatable {
    case idle        // resting, happy closed eyes
    case noticed     // a highlight was captured; eyes open
    case thinking    // an explanation is loading; lots of bubbles
    case needsAccess // Accessibility permission missing
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // TODO: Turn this off (set to false) before the public launch.
    /// Testing-period switch. When true, the setup walkthrough opens again after every update
    /// (any new CFBundleVersion), with your earlier answers already filled in. The Accessibility
    /// page is skipped unless permission is actually missing. Set to false for normal
    /// first-run-only setup.
    static let replaySetupOnEveryUpdate = true

    static let placeholderEndpoint = "https://YOUR-SITE.netlify.app/api/explain"
    /// The built-in explainer. Users never have to set anything up.
    static let defaultEndpoint = "https://paper-tree-explain.papertree.workers.dev/api/explain"

    private enum Key {
        static let researchMode = "researchMode"
        static let endpoint = "explainEndpoint"
        static let clientToken = "clientToken"
        static let specimenCount = "specimenCount"
        static let onboarded = "onboardedAccessibility"
        static let copyFallback = "copyFallbackEnabled"
        static let setupVersion = "setupVersionCompleted"
        static let school = "profileSchool"
        static let expertise = "profileExpertise"
        static let fields = "profileFields"
        static let length = "profileLength"
        static let lastSeenBuild = "lastSeenBuild"
    }

    private let defaults = UserDefaults.standard

    @Published var researchMode: Bool { didSet { defaults.set(researchMode, forKey: Key.researchMode) } }
    @Published var endpoint: String { didSet { defaults.set(endpoint, forKey: Key.endpoint) } }
    /// Optional shared token, only needed if the backend sets APP_TOKEN.
    @Published var clientToken: String { didSet { defaults.set(clientToken, forKey: Key.clientToken) } }
    /// When Accessibility gives no text, briefly press Cmd+C to read the highlight (pasteboard is restored).
    @Published var copyFallbackEnabled: Bool { didSet { defaults.set(copyFallbackEnabled, forKey: Key.copyFallback) } }
    @Published var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: Key.onboarded) } }

    /// Bump when setup gains a step everyone should see once (2 = the questions and practice in 0.2.3).
    static let currentSetupVersion = 2
    @Published var setupVersionCompleted: Int { didSet { defaults.set(setupVersionCompleted, forKey: Key.setupVersion) } }
    var needsSetup: Bool { setupVersionCompleted < AppState.currentSetupVersion }

    /// This copy's build number (CFBundleVersion), and the one setup last ran on.
    static let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    var lastSeenBuild: String? { defaults.string(forKey: Key.lastSeenBuild) }
    /// True on the first launch of a new build while `replaySetupOnEveryUpdate` is on.
    var shouldReplaySetupForUpdate: Bool {
        AppState.replaySetupOnEveryUpdate && !AppState.currentBuild.isEmpty && lastSeenBuild != AppState.currentBuild
    }
    /// Called when setup is finished or skipped, so it does not replay again until the next build.
    func markSetupSeenForThisBuild() { defaults.set(AppState.currentBuild, forKey: Key.lastSeenBuild) }

    // About the reader (empty string means "not answered").
    @Published var profileSchool: String { didSet { defaults.set(profileSchool, forKey: Key.school) } }
    @Published var profileExpertise: String { didSet { defaults.set(profileExpertise, forKey: Key.expertise) } }
    @Published var profileFields: [String] { didSet { defaults.set(profileFields, forKey: Key.fields) } }
    @Published var profileLength: String { didSet { defaults.set(profileLength, forKey: Key.length) } }

    var profilePayload: ProfilePayload? {
        let p = ProfilePayload(school: profileSchool.isEmpty ? nil : profileSchool,
                               expertise: profileExpertise.isEmpty ? nil : profileExpertise,
                               fields: profileFields.isEmpty ? nil : profileFields,
                               length: profileLength.isEmpty ? nil : profileLength)
        return p.isEmpty ? nil : p
    }

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
            Key.copyFallback: true,
            Key.onboarded: false,
            Key.setupVersion: 0,
        ])
        researchMode = defaults.bool(forKey: Key.researchMode)
        let saved = defaults.string(forKey: Key.endpoint) ?? AppState.defaultEndpoint
        endpoint = saved.contains("YOUR-SITE") || saved.trimmingCharacters(in: .whitespaces).isEmpty ? AppState.defaultEndpoint : saved
        clientToken = defaults.string(forKey: Key.clientToken) ?? ""
        copyFallbackEnabled = defaults.bool(forKey: Key.copyFallback)
        hasOnboarded = defaults.bool(forKey: Key.onboarded)
        setupVersionCompleted = defaults.integer(forKey: Key.setupVersion)
        profileSchool = defaults.string(forKey: Key.school) ?? ""
        profileExpertise = defaults.string(forKey: Key.expertise) ?? ""
        profileFields = defaults.stringArray(forKey: Key.fields) ?? []
        profileLength = defaults.string(forKey: Key.length) ?? ""
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

    /// Recomputes the flask's face from permissions and mode, unless it is busy thinking.
    func refreshMood(noticed: Bool = false) {
        if mood == .thinking { return }
        if !accessibilityGranted && researchMode { mood = .needsAccess; return }
        mood = noticed ? .noticed : .idle
    }
}
