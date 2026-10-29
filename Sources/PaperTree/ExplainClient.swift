// Talks to the Paper Tree backend. The app never holds an AI key:
// it posts {text, context, mode} to your server, and the server talks to Gemini.
import Foundation

enum ExplainMode: String, CaseIterable {
    case plain, simpler, detail

    var label: String {
        switch self {
        case .plain: return "Plain version"
        case .simpler: return "Simpler"
        case .detail: return "More detail"
        }
    }
}

/// One hard word from the highlight and what it means.
struct GlossaryTerm: Decodable, Hashable, Sendable {
    let term: String
    let meaning: String
}

/// What the explainer sends back: a short answer plus a few defined terms (may be empty).
struct Explanation: Sendable, Equatable {
    let text: String
    let terms: [GlossaryTerm]
}

struct ExplainError: Error {
    var title: String
    var detail: String
    var canOpenSettings: Bool = false
}

struct ExplainClient {
    var endpoint: String
    var token: String
    var configured: Bool

    static let maxTextChars = 1500
    static let maxContextChars = 1800

    private struct RequestBody: Encodable { let text: String; let context: String; let mode: String }
    private struct ResponseBody: Decodable { let text: String?; let terms: [GlossaryTerm]?; let error: String? }

    func explain(text: String, context: String, mode: ExplainMode) async throws -> Explanation {
        guard configured, let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ExplainError(title: "No explainer connected yet.",
                               detail: "Add your Paper Tree server address in Settings, then try again.",
                               canOpenSettings: true)
        }

        var request = URLRequest(url: url, timeoutInterval: 25)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PaperTree-Mac/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")", forHTTPHeaderField: "User-Agent")
        if !token.isEmpty { request.setValue(token, forHTTPHeaderField: "X-Paper-Tree-Token") }
        request.httpBody = try JSONEncoder().encode(RequestBody(
            text: String(text.prefix(ExplainClient.maxTextChars)),
            context: String(context.prefix(ExplainClient.maxContextChars)),
            mode: mode.rawValue))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ExplainError(title: "That took too long.", detail: "The explainer did not answer in time. Try again in a moment.")
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw ExplainError(title: "You look offline.", detail: "Paper Tree needs the internet to explain things.")
        } catch let error as URLError where error.code == .cannotFindHost || error.code == .cannotConnectToHost || error.code == .dnsLookupFailed {
            throw ExplainError(title: "I couldn't find the explainer.",
                               detail: "Check the server address in Settings.", canOpenSettings: true)
        } catch {
            throw ExplainError(title: "I couldn't reach the explainer.", detail: error.localizedDescription, canOpenSettings: true)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data)

        switch status {
        case 200:
            guard let text = decoded?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                throw ExplainError(title: "The explainer came back empty.", detail: "Try highlighting a little more of the sentence.")
            }
            let terms = (decoded?.terms ?? [])
                .filter { !$0.term.trimmingCharacters(in: .whitespaces).isEmpty && !$0.meaning.trimmingCharacters(in: .whitespaces).isEmpty }
                .prefix(4)
            return Explanation(text: text, terms: Array(terms))
        case 401, 403:
            throw ExplainError(title: "The explainer said no.",
                               detail: "Your server wants an app token. Add it in Settings.", canOpenSettings: true)
        case 404:
            throw ExplainError(title: "Wrong address.",
                               detail: "Nothing is answering at that address. It should end in /api/explain.", canOpenSettings: true)
        case 413, 400:
            throw ExplainError(title: "I couldn't use that highlight.",
                               detail: decoded?.error ?? "Try a shorter selection.")
        case 429:
            throw ExplainError(title: "The explainer is catching its breath.",
                               detail: "Too many requests at once. Try again in a minute.")
        default:
            throw ExplainError(title: "Something went wrong on the server.",
                               detail: decoded?.error ?? "Status \(status). Try again soon.")
        }
    }
}
