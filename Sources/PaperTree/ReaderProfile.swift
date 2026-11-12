// Who is reading. Asked once during setup (and editable in Settings), saved in UserDefaults,
// and sent with each explain request so the AI can pitch its words at the right level.
// Since 0.2.8 every answer is the reader's own words. The option lists below are only kept to
// turn answers saved by older builds (option ids) back into readable text.
import Foundation

struct ProfileOption: Identifiable, Hashable {
    let id: String
    let label: String
    /// Shorter handwritten form used on the tags.
    let short: String
}

enum ReaderProfile {
    // MARK: Older builds' options (read-only, for migration)

    static let schoolYears: [ProfileOption] = [
        .init(id: "middle", label: "Middle school", short: "middle school"),
        .init(id: "hs9", label: "High school, freshman", short: "9th"),
        .init(id: "hs10", label: "High school, sophomore", short: "10th"),
        .init(id: "hs11", label: "High school, junior", short: "11th"),
        .init(id: "hs12", label: "High school, senior", short: "12th"),
        .init(id: "ug1", label: "College, first year", short: "college yr 1"),
        .init(id: "ug2", label: "College, second year", short: "yr 2"),
        .init(id: "ug3", label: "College, third year", short: "yr 3"),
        .init(id: "ug4", label: "College, fourth year or later", short: "yr 4+"),
        .init(id: "grad", label: "Grad school", short: "grad school"),
        .init(id: "none", label: "Not in school", short: "not in school"),
    ]

    static let expertise: [ProfileOption] = [
        .init(id: "beginner", label: "Curious beginner", short: "curious beginner"),
        .init(id: "classes", label: "Took some science classes", short: "took some classes"),
        .init(id: "ra", label: "Undergrad researcher or RA", short: "undergrad researcher / RA"),
        .init(id: "grad", label: "Grad student", short: "grad student"),
        .init(id: "pro", label: "PI or professional scientist", short: "PI / professional"),
    ]

    static let fields: [ProfileOption] = [
        .init(id: "biology", label: "Biology", short: "biology"),
        .init(id: "chemistry", label: "Chemistry", short: "chemistry"),
        .init(id: "physics", label: "Physics", short: "physics"),
        .init(id: "csai", label: "CS and AI", short: "CS / AI"),
        .init(id: "medicine", label: "Medicine", short: "medicine"),
        .init(id: "psychology", label: "Psychology", short: "psychology"),
        .init(id: "earth", label: "Earth and climate", short: "earth & climate"),
        .init(id: "other", label: "Something else", short: "other"),
    ]

    static let lengths: [ProfileOption] = [
        .init(id: "shortest", label: "As short as possible", short: "shortest"),
        .init(id: "balanced", label: "Balanced", short: "balanced"),
        .init(id: "thorough", label: "A bit more thorough", short: "thorough"),
    ]

    static func label(_ id: String, in list: [ProfileOption]) -> String? {
        list.first(where: { $0.id == id })?.label
    }

    // MARK: Migration

    /// An answer saved by an older build is an option id ("hs11"); show its words instead.
    /// Anything that is not a known id is already the reader's own words and stays as it is.
    static func migrated(_ saved: String, from list: [ProfileOption]) -> String {
        label(saved, in: list) ?? saved
    }

    /// Older builds saved the fields as a list of ids. Turn it into a short sentence:
    /// ["biology", "chemistry", "csai"] becomes "Biology, chemistry and CS and AI".
    static func migratedFields(_ ids: [String]) -> String {
        let words = ids.enumerated().compactMap { i, id -> String? in
            guard let o = fields.first(where: { $0.id == id }) else {
                let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }
            if id == "csai" { return o.label }
            return i == 0 ? o.label : o.label.lowercased()
        }
        switch words.count {
        case 0: return ""
        case 1: return words[0]
        default: return words.dropLast().joined(separator: ", ") + " and " + words.last!
        }
    }

    // MARK: Their words

    /// Longest answer kept. A few sentences; enough to say who you are.
    static let maxAnswer = 300

    /// One tidy line: trimmed, inner newlines and runs of spaces folded to single spaces.
    static func tidy(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// The answer as sent: tidied and capped, or nil when blank.
    static func sendable(_ s: String) -> String? {
        let t = tidy(s)
        return t.isEmpty ? nil : String(t.prefix(maxAnswer))
    }

    /// A short quote of their words for a tag or summary: cut at a word near `limit`, with an ellipsis.
    static func quote(_ s: String, limit: Int) -> String? {
        let t = tidy(s)
        guard !t.isEmpty else { return nil }
        guard t.count > limit else { return t }
        let cut = t.prefix(limit)
        let atWord = cut.lastIndex(of: " ").map { cut[..<$0] } ?? cut
        return atWord.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:.")) + "\u{2026}"
    }
}

/// The four "about you" questions, worded to invite a sentence rather than a pick.
/// Setup asks them one per page; Settings opens the same field on the reader's label.
enum ReaderQuestion: Int, CaseIterable {
    case school, background, fields, length

    var title: String {
        switch self {
        case .school: return "Where are you in school?"
        case .background: return "Tell me about your science so far."
        case .fields: return "What do you like to read?"
        case .length: return "How should my notes read?"
        }
    }

    /// The line under the title.
    var invite: String {
        switch self {
        case .school: return "In your own words, so I can pitch my notes at your level."
        case .background: return "Classes, a lab, a job, or plain curiosity. Nobody else sees this."
        case .fields: return "Fields, topics, a paper you loved. Name as many as you like."
        case .length: return "Short and quick, or a little more thorough? You can change any of this in Settings."
        }
    }

    /// The typed label on the specimen tag.
    var tag: String {
        switch self {
        case .school: return "year in school"
        case .background: return "science background"
        case .fields: return "what you read"
        case .length: return "how my notes should read"
        }
    }

    /// The field name on the Settings label.
    var field: String {
        switch self {
        case .school: return "year"
        case .background: return "background"
        case .fields: return "reads"
        case .length: return "notes"
        }
    }

    /// Pencil words in the empty field.
    var placeholder: String {
        switch self {
        case .school: return "I'm a junior in high school\u{2026}"
        case .background: return "I took biology last year and\u{2026}"
        case .fields: return "Mostly plant biology, and\u{2026}"
        case .length: return "Short, please. Two or three sentences\u{2026}"
        }
    }

    /// The quiet hint under the field.
    var hint: String {
        switch self {
        case .school: return "a year, a grade, or wherever you are in school. Out of school counts too."
        case .background: return "a sentence or two is plenty"
        case .fields: return "anything from stomata to black holes"
        case .length: return "for example: two lines at most, or as much as it takes"
        }
    }

    var accessibilityName: String {
        switch self {
        case .school: return "Year in school"
        case .background: return "Science background"
        case .fields: return "What you read"
        case .length: return "How long notes should be"
        }
    }
}

/// What goes over the wire: the reader's own words, each optional. The explainer still accepts the
/// option ids older builds sent.
struct ProfilePayload: Encodable {
    let school: String?
    let expertise: String?
    let fields: String?
    let length: String?

    init(school: String, expertise: String, fields: String, length: String) {
        self.school = ReaderProfile.sendable(school)
        self.expertise = ReaderProfile.sendable(expertise)
        self.fields = ReaderProfile.sendable(fields)
        self.length = ReaderProfile.sendable(length)
    }

    var isEmpty: Bool { school == nil && expertise == nil && fields == nil && length == nil }
}
