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

    func start() async throws -> String {
        let endpoint = baseURL
            .appendingPathComponent("playlist")
            .appendingPathComponent("start")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

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
