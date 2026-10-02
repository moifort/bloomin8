import Apollo
import ApolloAPI
import Foundation

enum GraphQLClient {
    /// The server lives on the LAN: past a few seconds it is unreachable, and
    /// URLSession's 60 s default would leave the UI spinning for a minute.
    /// Covers the server's own 5 s wake-up timeout on start/resume.
    static let requestTimeout: TimeInterval = 15

    /// Build an ApolloClient pointing at `\(baseURL)/graphql`.
    /// Bloomin8 has no auth — the default interceptor chain is enough.
    static func client(for baseURL: URL) -> ApolloClient {
        let url = baseURL.appendingPathComponent("graphql")
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        let store = ApolloStore()
        let provider = DefaultInterceptorProvider(
            client: URLSessionClient(sessionConfiguration: configuration),
            store: store
        )
        let transport = RequestChainNetworkTransport(
            interceptorProvider: provider,
            endpointURL: url
        )
        return ApolloClient(networkTransport: transport, store: store)
    }
}

/// Parses the `DateTime` scalar (ISO 8601, with or without milliseconds).
enum GraphQLDate {
    static func parse(_ value: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value))
            ?? (try? Date.ISO8601FormatStyle().parse(value))
    }
}

/// Errors surfaced by GraphQL services. Keeps existing localized messages so
/// the UI strings (formerly produced by REST services) stay unchanged.
enum GraphQLServiceError: LocalizedError {
    case transport(Error)
    case server(message: String)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case let .transport(error):
            return error.localizedDescription
        case let .server(message):
            return String(localized: "Serveur: \(message)")
        case .invalidPayload:
            return String(localized: "Réponse GraphQL invalide.")
        }
    }
}

extension ApolloClient {
    /// Bridge Apollo's callback API to async/await for queries.
    func fetchAsync<Q: GraphQLQuery>(_ query: Q) async throws -> Q.Data {
        try await withCheckedThrowingContinuation { continuation in
            self.fetch(query: query, cachePolicy: .fetchIgnoringCacheCompletely) { result in
                continuation.resume(with: Self.unwrap(result))
            }
        }
    }

    /// Bridge Apollo's callback API to async/await for mutations.
    func performAsync<M: GraphQLMutation>(_ mutation: M) async throws -> M.Data {
        try await withCheckedThrowingContinuation { continuation in
            self.perform(mutation: mutation) { result in
                continuation.resume(with: Self.unwrap(result))
            }
        }
    }

    private static func unwrap<Data>(_ result: Result<GraphQLResult<Data>, Error>) -> Result<Data, Error> {
        switch result {
        case let .success(graphQLResult):
            if let first = graphQLResult.errors?.first {
                return .failure(GraphQLServiceError.server(message: first.message ?? "Unknown error"))
            }
            guard let data = graphQLResult.data else {
                return .failure(GraphQLServiceError.invalidPayload)
            }
            return .success(data)
        case let .failure(error):
            return .failure(GraphQLServiceError.transport(error))
        }
    }
}
