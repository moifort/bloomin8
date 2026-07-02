import CanvasGraphQL
import Foundation

struct PlaylistProgress {
    enum Status: String {
        case inProgress = "in_progress"
        case paused
        // Client-only decode fallback for enum values this app version doesn't know.
        case unknown
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
        var start: Int?
        var end: Int?
    }

    struct WakeUpResult {
        let message: String
        let wokeUp: Bool
    }

    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func start(canvasURL: URL, cronIntervalInHours: Int, quietHours: QuietHoursPayload? = nil) async throws -> WakeUpResult {
        let input = CanvasGraphQL.StartPlaylistInput(
            canvasUrl: canvasURL.absoluteString,
            cronIntervalInHours: String(cronIntervalInHours),
            quietHours: quietHours.map { .init(quietHoursInput($0)) } ?? .none
        )
        let mutation = CanvasGraphQL.StartPlaylistMutation(input: input)
        let data = try await GraphQLClient.client(for: baseURL).performAsync(mutation)
        let wokeUp = data.startPlaylist.wokeUp
        let message = wokeUp
            ? String(localized: "Playlist lancée.")
            : String(localized: "Playlist enregistrée — le Canvas la démarrera à son prochain réveil.")
        return WakeUpResult(message: message, wokeUp: wokeUp)
    }

    func getProgress() async throws -> PlaylistProgress? {
        let result = try await GraphQLClient.client(for: baseURL).fetchAsync(CanvasGraphQL.PlaylistProgressQuery())
        guard let progress = result.playlistProgress else { return nil }
        let status = PlaylistProgress.Status(rawValue: progress.status.rawValue) ?? .unknown
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

    func resume() async throws -> WakeUpResult {
        let data = try await GraphQLClient.client(for: baseURL).performAsync(CanvasGraphQL.ResumePlaylistMutation())
        let wokeUp = data.resumePlaylist.wokeUp
        let message = wokeUp
            ? String(localized: "Playlist reprise")
            : String(localized: "Reprise planifiée — le Canvas reprendra au prochain réveil (sous 24h)")
        return WakeUpResult(message: message, wokeUp: wokeUp)
    }

    func updateInterval(cronIntervalInHours: Int) async throws -> String {
        let mutation = CanvasGraphQL.UpdatePlaylistIntervalMutation(
            cronIntervalInHours: String(cronIntervalInHours)
        )
        _ = try await GraphQLClient.client(for: baseURL).performAsync(mutation)
        return String(localized: "Intervalle mis à jour")
    }

    func updateQuietHours(_ quietHours: QuietHoursPayload) async throws -> String {
        let mutation = CanvasGraphQL.UpdateQuietHoursMutation(input: quietHoursInput(quietHours))
        _ = try await GraphQLClient.client(for: baseURL).performAsync(mutation)
        return String(localized: "Mode nuit mis à jour")
    }

    private func quietHoursInput(_ payload: QuietHoursPayload) -> CanvasGraphQL.QuietHoursInput {
        CanvasGraphQL.QuietHoursInput(
            enabled: payload.enabled,
            end: payload.end.map { .some($0) } ?? .none,
            start: payload.start.map { .some($0) } ?? .none,
            timezone: payload.timezone
        )
    }
}
