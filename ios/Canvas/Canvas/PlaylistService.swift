import CanvasGraphQL
import Foundation

struct PlaylistProgress {
    enum Status: String {
        case stop
        case inProgress = "in_progress"
        case paused
    }

    let displayed: Int
    let total: Int
    let status: Status
    let cronIntervalInHours: Int
}

struct PlaylistService {
    struct QuietHoursPayload {
        let enabled: Bool
        let timezone: String
    }

    struct ResumeResult {
        let message: String
        let wokeUp: Bool
    }

    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func start(canvasURL: URL, cronIntervalInHours: Int, quietHours: QuietHoursPayload? = nil) async throws -> String {
        let quietHoursInput = quietHours.map {
            CanvasGraphQL.QuietHoursInput(enabled: $0.enabled, timezone: $0.timezone)
        }
        let input = CanvasGraphQL.StartPlaylistInput(
            canvasUrl: canvasURL.absoluteString,
            cronIntervalInHours: String(cronIntervalInHours),
            quietHours: quietHoursInput.map { .init($0) } ?? .none
        )
        let mutation = CanvasGraphQL.StartPlaylistMutation(input: input)
        _ = try await GraphQLClient.client(for: baseURL).performAsync(mutation)
        return String(localized: "Playlist lancée.")
    }

    func getProgress() async throws -> PlaylistProgress? {
        let result = try await GraphQLClient.client(for: baseURL).fetchAsync(CanvasGraphQL.PlaylistProgressQuery())
        guard let progress = result.playlistProgress else { return nil }
        let status = PlaylistProgress.Status(rawValue: progress.status.rawValue) ?? .stop
        return PlaylistProgress(
            displayed: progress.displayed,
            total: progress.total,
            status: status,
            cronIntervalInHours: Int(progress.cronIntervalInHours) ?? 0
        )
    }

    func pause() async throws -> String {
        _ = try await GraphQLClient.client(for: baseURL).performAsync(CanvasGraphQL.PausePlaylistMutation())
        return String(localized: "Playlist en pause")
    }

    func resume() async throws -> ResumeResult {
        let data = try await GraphQLClient.client(for: baseURL).performAsync(CanvasGraphQL.ResumePlaylistMutation())
        let wokeUp = data.resumePlaylist.wokeUp
        let message = wokeUp
            ? String(localized: "Playlist reprise")
            : String(localized: "Reprise planifiée — le Canvas reprendra au prochain réveil (sous 24h)")
        return ResumeResult(message: message, wokeUp: wokeUp)
    }

    func updateInterval(cronIntervalInHours: Int) async throws -> String {
        let mutation = CanvasGraphQL.UpdatePlaylistIntervalMutation(
            cronIntervalInHours: String(cronIntervalInHours)
        )
        _ = try await GraphQLClient.client(for: baseURL).performAsync(mutation)
        return String(localized: "Intervalle mis à jour")
    }
}
