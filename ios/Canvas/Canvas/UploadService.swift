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
                return "Endpoint d'upload invalide."
            case .invalidHTTPResponse:
                return "Reponse HTTP invalide."
            case .invalidPayload:
                return "Reponse upload invalide."
            case let .server(statusCode, message):
                return "Serveur \(statusCode): \(message)"
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

struct PlaylistService {
    struct ResponseEnvelope: Decodable {
        let status: Int?
        let message: String?
    }

    struct StartPlaylistPayload: Encodable {
        let canvasUrl: String
        let cronIntervalInHours: Int
    }

    enum PlaylistError: LocalizedError {
        case invalidHTTPResponse
        case server(statusCode: Int, message: String)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .invalidHTTPResponse:
                return "Reponse HTTP invalide."
            case let .server(statusCode, message):
                return "Serveur \(statusCode): \(message)"
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

    func start(canvasURL: URL, cronIntervalInHours: Int) async throws -> String {
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
                cronIntervalInHours: cronIntervalInHours
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
            return envelope?.message ?? "Playlist lancee."
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
                return "Reponse HTTP invalide."
            case let .server(statusCode, message):
                return "Serveur \(statusCode): \(message)"
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
            return envelope?.message ?? "Photos supprimees."
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw ImageError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }
}

struct CanvasStatusService {
    struct ResponseEnvelope: Decodable {
        struct LegacyPayload: Decodable {
            let percentage: Int
        }

        enum Payload: Decodable {
            case percentage(Int)
            case unavailable

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let rawPercentage = try? container.decode(Int.self) {
                    self = .percentage(rawPercentage)
                    return
                }
                if let rawStatus = try? container.decode(String.self), rawStatus == "battery-unavailable" {
                    self = .unavailable
                    return
                }
                if let legacyPayload = try? container.decode(LegacyPayload.self) {
                    self = .percentage(legacyPayload.percentage)
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
                return "Reponse HTTP invalide."
            case .invalidPayload:
                return "Reponse batterie invalide."
            case let .server(statusCode, message):
                return "Serveur \(statusCode): \(message)"
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
            case let .percentage(value):
                return value
            case .unavailable:
                return nil
            }
        }

        let decodedMessage = (try? JSONDecoder().decode(ResponseEnvelope.self, from: data))?.message
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw CanvasStatusError.server(statusCode: http.statusCode, message: decodedMessage ?? fallbackMessage)
    }
}
