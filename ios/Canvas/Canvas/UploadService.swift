import Foundation

struct UploadService {
    struct ResponseEnvelope: Decodable {
        struct Payload: Decodable {
            let id: String
            let url: String
        }

        let status: Int?
        let message: String?
        let data: Payload?
    }

    enum UploadError: LocalizedError {
        case invalidEndpoint
        case invalidHTTPResponse
        case invalidPayload
        case server(statusCode: Int, message: String)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return String(localized: "Endpoint d'upload invalide.")
            case .invalidHTTPResponse:
                return String(localized: "Réponse HTTP invalide.")
            case .invalidPayload:
                return String(localized: "Réponse upload invalide.")
            case let .server(statusCode, message):
                return String(localized: "Serveur \(statusCode): \(message)")
            case let .transport(error):
                return error.localizedDescription
            }
        }
    }

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func uploadJPEG(_ jpegData: Data, orientation: String = "P") async throws -> String {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("upload"),
            resolvingAgainstBaseURL: false
        ) else {
            throw UploadError.invalidEndpoint
        }

        components.queryItems = [URLQueryItem(name: "orientation", value: orientation)]

        guard let url = components.url else {
            throw UploadError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jpegData
        request.timeoutInterval = 30
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UploadError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UploadError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ResponseEnvelope.self, from: data)
            guard let url = envelope?.data?.url else {
                throw UploadError.invalidPayload
            }
            return url
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw UploadError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }
}

struct PlaylistProgress {
    enum Status: String, Decodable {
        case stop
        case inProgress = "in-progress"
        case paused
    }

    let displayed: Int
    let total: Int
    let status: Status
}

struct PlaylistService {
    struct ResponseEnvelope: Decodable {
        let status: Int?
        let message: String?
    }

    struct ResumeResponseEnvelope: Decodable {
        struct ResumeData: Decodable {
            let wokeUp: Bool
        }

        let status: Int?
        let message: String?
        let data: ResumeData?
    }

    struct ResumeResult {
        let message: String
        let wokeUp: Bool
    }

    struct ProgressResponseEnvelope: Decodable {
        enum Payload: Decodable {
            case progress(ProgressData)
            case notFound

            struct ProgressData: Decodable {
                let displayed: Int
                let total: Int
                let status: PlaylistProgress.Status
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let data = try? container.decode(ProgressData.self) {
                    self = .progress(data)
                    return
                }
                if let raw = try? container.decode(String.self), raw == "playlist-not-found" {
                    self = .notFound
                    return
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Progress payload format is not supported."
                )
            }
        }

        let status: Int?
        let data: Payload?
    }

    struct QuietHoursPayload: Encodable {
        let enabled: Bool
        let timezone: String
    }

    struct StartPlaylistPayload: Encodable {
        let canvasUrl: String
        let cronIntervalInHours: Int
        let quietHours: QuietHoursPayload?
    }

    struct UpdateIntervalPayload: Encodable {
        let cronIntervalInHours: Int
    }

    enum PlaylistError: LocalizedError {
        case invalidHTTPResponse
        case server(statusCode: Int, message: String)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .invalidHTTPResponse:
                return String(localized: "Réponse HTTP invalide.")
            case let .server(statusCode, message):
                return String(localized: "Serveur \(statusCode): \(message)")
            case let .transport(error):
                return error.localizedDescription
            }
        }
    }

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func start(canvasURL: URL, cronIntervalInHours: Int, quietHours: QuietHoursPayload? = nil) async throws -> String {
        let endpoint = baseURL
            .appendingPathComponent("playlist")
            .appendingPathComponent("start")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            StartPlaylistPayload(
                canvasUrl: canvasURL.absoluteString,
                cronIntervalInHours: cronIntervalInHours,
                quietHours: quietHours
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlaylistError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PlaylistError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ResponseEnvelope.self, from: data)
            return envelope?.message ?? String(localized: "Playlist lancée.")
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw PlaylistError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }

    func getProgress() async throws -> PlaylistProgress? {
        let endpoint = baseURL
            .appendingPathComponent("playlist")
            .appendingPathComponent("progress")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlaylistError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PlaylistError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ProgressResponseEnvelope.self, from: data)
            guard let payload = envelope?.data else { return nil }
            switch payload {
            case let .progress(progressData):
                return PlaylistProgress(
                    displayed: progressData.displayed,
                    total: progressData.total,
                    status: progressData.status
                )
            case .notFound:
                return nil
            }
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw PlaylistError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }

    func pause() async throws -> String {
        let endpoint = baseURL
            .appendingPathComponent("playlist")
            .appendingPathComponent("pause")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlaylistError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PlaylistError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ResponseEnvelope.self, from: data)
            return envelope?.message ?? String(localized: "Playlist en pause")
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw PlaylistError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }

    func resume() async throws -> ResumeResult {
        let endpoint = baseURL
            .appendingPathComponent("playlist")
            .appendingPathComponent("resume")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlaylistError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PlaylistError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ResumeResponseEnvelope.self, from: data)
            let wokeUp = envelope?.data?.wokeUp ?? false
            let message = envelope?.message ?? (
                wokeUp
                    ? String(localized: "Playlist reprise")
                    : String(localized: "Reprise planifiée — le Canvas reprendra au prochain réveil (sous 24h)")
            )
            return ResumeResult(message: message, wokeUp: wokeUp)
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw PlaylistError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }

    func updateInterval(cronIntervalInHours: Int) async throws -> String {
        let endpoint = baseURL
            .appendingPathComponent("playlist")
            .appendingPathComponent("interval")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            UpdateIntervalPayload(cronIntervalInHours: cronIntervalInHours)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlaylistError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PlaylistError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ResponseEnvelope.self, from: data)
            return envelope?.message ?? String(localized: "Intervalle mis à jour")
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw PlaylistError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }
}

struct ImageService {
    struct ResponseEnvelope: Decodable {
        let status: Int?
        let message: String?
    }

    enum ImageError: LocalizedError {
        case invalidHTTPResponse
        case server(statusCode: Int, message: String)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .invalidHTTPResponse:
                return String(localized: "Réponse HTTP invalide.")
            case let .server(statusCode, message):
                return String(localized: "Serveur \(statusCode): \(message)")
            case let .transport(error):
                return error.localizedDescription
            }
        }
    }

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func deleteAll() async throws -> String {
        let endpoint = baseURL.appendingPathComponent("images")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ImageError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ImageError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ResponseEnvelope.self, from: data)
            return envelope?.message ?? String(localized: "Photos supprimées.")
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw ImageError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }
}

struct CanvasStatusService {
    struct BatteryData: Decodable {
        let percentage: Int
        let lastFullChargeDate: String?
        let lastPullDate: String?
    }

    struct ResponseEnvelope: Decodable {
        enum Payload: Decodable {
            case batteryData(BatteryData)
            case unavailable

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()

                if let batteryData = try? container.decode(BatteryData.self) {
                    self = .batteryData(batteryData)
                    return
                }

                if let rawPercentage = try? container.decode(Int.self) {
                    self = .batteryData(BatteryData(percentage: rawPercentage, lastFullChargeDate: nil, lastPullDate: nil))
                    return
                }

                if let rawStatus = try? container.decode(String.self), rawStatus == "battery-unavailable" {
                    self = .unavailable
                    return
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Battery payload format is not supported."
                )
            }
        }

        let status: Int?
        let message: String?
        let data: Payload?
    }

    enum CanvasStatusError: LocalizedError {
        case invalidHTTPResponse
        case invalidPayload
        case server(statusCode: Int, message: String)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .invalidHTTPResponse:
                return String(localized: "Réponse HTTP invalide.")
            case .invalidPayload:
                return String(localized: "Réponse batterie invalide.")
            case let .server(statusCode, message):
                return String(localized: "Serveur \(statusCode): \(message)")
            case let .transport(error):
                return error.localizedDescription
            }
        }
    }

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func getBatteryReport() async throws -> Int? {
        let endpoint = baseURL
            .appendingPathComponent("canvas")
            .appendingPathComponent("battery")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CanvasStatusError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CanvasStatusError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ResponseEnvelope.self, from: data)
            guard let decodedEnvelope = envelope else {
                throw CanvasStatusError.invalidPayload
            }
            guard let payload = decodedEnvelope.data else {
                return nil
            }
            switch payload {
            case let .batteryData(data):
                return data.percentage
            case .unavailable:
                return nil
            }
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw CanvasStatusError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }

    func getBatteryData() async throws -> BatteryData? {
        let endpoint = baseURL
            .appendingPathComponent("canvas")
            .appendingPathComponent("battery")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CanvasStatusError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CanvasStatusError.invalidHTTPResponse
        }

        if (200 ..< 300).contains(http.statusCode) {
            let envelope = try? JSONDecoder().decode(ResponseEnvelope.self, from: data)
            guard let decodedEnvelope = envelope else {
                throw CanvasStatusError.invalidPayload
            }
            guard let payload = decodedEnvelope.data else {
                return nil
            }
            switch payload {
            case let .batteryData(batteryData):
                return batteryData
            case .unavailable:
                return nil
            }
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw CanvasStatusError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }
}
