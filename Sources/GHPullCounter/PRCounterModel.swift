import Foundation
import SwiftUI

@MainActor
final class PRCounterModel: ObservableObject {
    @Published private(set) var counts: PRCounts?
    @Published private(set) var login: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var error: FetchError?
    @Published private(set) var weekRange = WeekRange.current()

    static let defaultIntervalMinutes = 15
    static let intervalKey = "refreshIntervalMinutes"

    private let client = GitHubClient()
    private var pollingTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?

    init() {
        startPolling()
    }

    var isAuthError: Bool {
        if case .auth = error { return true }
        return false
    }

    var githubSearchURL: URL {
        let query = "is:pr author:@me created:\(weekRange.startDaySearchTerm)..\(weekRange.lastDaySearchTerm)"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/pulls"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url!
    }

    func restartPolling() {
        startPolling()
    }

    func refreshNow() {
        fetchTask?.cancel()
        fetchTask = Task { await fetch() }
    }

    private var intervalSeconds: TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: Self.intervalKey)
        return TimeInterval((stored > 0 ? stored : Self.defaultIntervalMinutes) * 60)
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await fetch()
                // Wake up at the interval, or right after the week rolls over.
                let rollover = max(1, weekRange.end.timeIntervalSinceNow + 2)
                let nap = min(max(intervalSeconds, 5), rollover)
                try? await Task.sleep(for: .seconds(nap))
            }
        }
    }

    private func fetch() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        weekRange = WeekRange.current()
        do {
            let result = try await client.fetchCounts(week: weekRange)
            counts = result.counts
            login = result.login
            lastUpdated = Date()
            error = nil
        } catch let fetchError as FetchError {
            error = fetchError
        } catch {
            self.error = .message(error.localizedDescription)
        }
    }
}
