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
    /// Optional "who is reading" hints. Older servers simply ignore it.
    var profile: ProfilePayload? = nil

    static let maxTextChars = 1500
    static let maxContextChars = 1800

    /// One connection pool for every request, so the TLS handshake to the explainer happens once
    /// and each highlight after that reuses the open connection.
    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 25
        c.httpMaximumConnectionsPerHost = 4
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    private static let warmLock = NSLock()
    private static var lastWarm = Date.distantPast

    /// Opens (or keeps alive) the connection to the explainer before a request needs it.
    /// Cheap and throttled, so it is fine to call on every highlight gesture.
    static func warmUp(endpoint: String) {
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https" else { return }
        warmLock.lock()
        let due = Date().timeIntervalSince(lastWarm) > 20
        if due { lastWarm = Date() }
        warmLock.unlock()
        guard due else { return }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        session.dataTask(with: request).resume()
    }

    private struct RequestBody: Encodable {
        let text: String; let context: String; let mode: String; let profile: ProfilePayload?; let stream: Bool?
    }
    private struct ResponseBody: Decodable { let text: String?; let terms: [GlossaryTerm]?; let error: String?; let status: Int? }
    private struct PartialBody: Decodable { let text: String? }

    /// Asks the explainer. With `onPartial`, the answer streams in: it is called with the answer so far
    /// as the words arrive, and the full explanation (with glossary) is returned at the end.
    /// Servers that do not stream just send the whole answer, which works the same way.
    func explain(text: String, context: String, mode: ExplainMode,
                 onPartial: (@MainActor (String) -> Void)? = nil) async throws -> Explanation {
        guard configured, let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ExplainError(title: "No explainer connected yet.",
                               detail: "Add your Paper Tree server address in Settings, then try again.",
                               canOpenSettings: true)
        }

        let streaming = onPartial != nil
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(streaming ? "text/event-stream, application/json" : "application/json", forHTTPHeaderField: "Accept")
        request.setValue("PaperTree-Mac/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")", forHTTPHeaderField: "User-Agent")
        if !token.isEmpty { request.setValue(token, forHTTPHeaderField: "X-Paper-Tree-Token") }
        request.httpBody = try JSONEncoder().encode(RequestBody(
            text: String(text.prefix(ExplainClient.maxTextChars)),
            context: String(context.prefix(ExplainClient.maxContextChars)),
            mode: mode.rawValue,
            profile: profile,
            stream: streaming ? true : nil))

        do {
            let (bytes, response) = try await ExplainClient.session.bytes(for: request)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            let contentType = http?.value(forHTTPHeaderField: "Content-Type") ?? ""

            if status == 200, contentType.contains("text/event-stream") {
                return try await readStream(bytes, onPartial: onPartial)
            }
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            return try finish(status: status, data: data)
        } catch let error as ExplainError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
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
    }

    /// Reads the server's events: "delta" carries the answer so far, "done" the full result,
    /// "error" a failure after streaming began. Our server sends one data line per event, so
    /// lines are handled as they come (the line reader skips the blank separator lines).
    private func readStream(_ bytes: URLSession.AsyncBytes, onPartial: (@MainActor (String) -> Void)?) async throws -> Explanation {
        var event = "message"
        for try await line in bytes.lines {
            if line.hasPrefix("event:") {
                event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                continue
            }
            guard line.hasPrefix("data:") else { continue }
            let payload = Data(line.dropFirst(5).trimmingCharacters(in: .whitespaces).utf8)
            switch event {
            case "delta":
                if let partial = try? JSONDecoder().decode(PartialBody.self, from: payload).text, !partial.isEmpty {
                    try Task.checkCancellation()
                    await onPartial?(partial)
                }
            case "done":
                return try finish(status: 200, data: payload)
            case "error":
                let status = (try? JSONDecoder().decode(ResponseBody.self, from: payload))?.status ?? 502
                return try finish(status: status == 200 ? 502 : status, data: payload)
            default:
                break
            }
            event = "message"
        }
        try Task.checkCancellation()
        throw ExplainError(title: "The answer got cut off.", detail: "The connection closed early. Try again.")
    }

    /// Turns a status code and JSON body into an explanation or a friendly error.
    private func finish(status: Int, data: Data) throws -> Explanation {
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
        case 504:
            throw ExplainError(title: "That took too long.",
                               detail: decoded?.error ?? "The AI was slow to answer. Try again in a moment.")
        default:
            throw ExplainError(title: "Something went wrong on the server.",
                               detail: decoded?.error ?? "Status \(status). Try again soon.")
        }
    }
}
