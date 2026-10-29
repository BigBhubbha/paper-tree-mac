// Who is reading. Asked once during setup (and editable in Settings), saved in UserDefaults,
// and sent with each explain request so the AI can pitch its words at the right level.
import Foundation

struct ProfileOption: Identifiable, Hashable {
    let id: String
    let label: String
    /// Shorter handwritten form used on the tags.
    let short: String
}

enum ReaderProfile {
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
}

/// What goes over the wire. Every field is optional; the server ignores unknown values.
struct ProfilePayload: Encodable {
    let school: String?
    let expertise: String?
    let fields: [String]?
    let length: String?

    var isEmpty: Bool { school == nil && expertise == nil && (fields ?? []).isEmpty && length == nil }
}
