import Foundation

enum FetchError: LocalizedError, Equatable {
    case auth(String)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .auth(let detail):
            return "GitHub token unavailable or rejected. Run `gh auth login` in a terminal. (\(detail))"
        case .message(let text):
            return text
        }
    }
}

struct PRCounts: Equatable {
    var opened: Int
    var drafts: Int
    var merged: Int
}

struct GitHubClient {
    private let endpoint = URL(string: "https://api.github.com/graphql")!

    private static let searchQuery = """
    query($opened: String!, $merged: String!, $cursor: String) {
      opened: search(query: $opened, type: ISSUE, first: 100, after: $cursor) {
        issueCount
        nodes { ... on PullRequest { isDraft } }
        pageInfo { hasNextPage endCursor }
      }
      merged: search(query: $merged, type: ISSUE, first: 1) { issueCount }
      viewer { login }
    }
    """

    func fetchCounts(week: WeekRange) async throws -> (counts: PRCounts, login: String?) {
        let token = try await ghToken()
        let openedQuery = "is:pr author:@me created:\(week.startSearchTerm)..\(week.endSearchTerm)"
        let mergedQuery = "is:pr author:@me merged:\(week.startSearchTerm)..\(week.endSearchTerm)"

        var openedTotal = 0
        var mergedTotal = 0
        var drafts = 0
        var login: String?
        var cursor: String?
        var pages = 0

        while true {
            let response = try await send(opened: openedQuery, merged: mergedQuery, cursor: cursor, token: token)
            if let errors = response.errors, !errors.isEmpty {
                throw FetchError.message(errors.map(\.message).joined(separator: "; "))
            }
            guard let data = response.data, let opened = data.opened, let merged = data.merged else {
                throw FetchError.message("GitHub returned no data")
            }
            openedTotal = opened.issueCount
            mergedTotal = merged.issueCount
            login = data.viewer?.login
            drafts += (opened.nodes ?? []).filter { $0.isDraft == true }.count
            pages += 1
            if opened.pageInfo?.hasNextPage == true, let next = opened.pageInfo?.endCursor, pages < 10 {
                cursor = next
            } else {
                break
            }
        }

        return (PRCounts(opened: openedTotal, drafts: drafts, merged: mergedTotal), login)
    }

    private func send(opened: String, merged: String, cursor: String?, token: String) async throws -> GraphQLResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("GHPullCounter", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(
            GraphQLRequest(
                query: Self.searchQuery,
                variables: .init(opened: opened, merged: merged, cursor: cursor)
            )
        )
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        guard let http = httpResponse as? HTTPURLResponse else {
            throw FetchError.message("Invalid response from GitHub")
        }
        if http.statusCode == 401 {
            throw FetchError.auth("token rejected (HTTP 401)")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw FetchError.message("GitHub API error HTTP \(http.statusCode): \(body.prefix(300))")
        }
        return try JSONDecoder().decode(GraphQLResponse.self, from: data)
    }

    func ghToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let home = NSHomeDirectory()
                let attempts: [[String]] = [
                    ["/opt/homebrew/bin/gh", "auth", "token"],
                    ["/usr/local/bin/gh", "auth", "token"],
                    [home + "/.asdf/shims/gh", "auth", "token"],
                    ["/bin/zsh", "-l", "-c", "gh auth token"],
                    ["/bin/zsh", "-il", "-c", "gh auth token"],
                ]
                for attempt in attempts {
                    guard let result = Self.runProcess(attempt) else { continue }
                    let token = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    if result.code == 0, !token.isEmpty {
                        continuation.resume(returning: token)
                        return
                    }
                }
                continuation.resume(throwing: FetchError.auth("`gh auth token` failed"))
            }
        }
    }

    private static func runProcess(_ arguments: [String]) -> (code: Int32, stdout: String, stderr: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: arguments[0])
        process.arguments = Array(arguments.dropFirst())
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }
}

private struct GraphQLRequest: Encodable {
    struct Variables: Encodable {
        let opened: String
        let merged: String
        let cursor: String?
    }
    let query: String
    let variables: Variables
}

private struct GraphQLResponse: Decodable {
    struct GraphQLError: Decodable {
        let message: String
    }
    struct Connection: Decodable {
        struct Node: Decodable {
            let isDraft: Bool?
        }
        struct PageInfo: Decodable {
            let hasNextPage: Bool
            let endCursor: String?
        }
        let issueCount: Int
        let nodes: [Node]?
        let pageInfo: PageInfo?
    }
    struct Viewer: Decodable {
        let login: String
    }
    struct Payload: Decodable {
        let opened: Connection?
        let merged: Connection?
        let viewer: Viewer?
    }
    let data: Payload?
    let errors: [GraphQLError]?
}
