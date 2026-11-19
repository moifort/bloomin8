import Apollo
import Foundation

/// Builds the Apollo clients of the app and the widget.
public enum CanvasGraphQLClient {
    /// ApolloClient pointing at `\(baseURL)/graphql`. Bloomin8 has no auth, so
    /// the default interceptor chain is enough. The server lives on the LAN:
    /// `timeout` keeps URLSession's 60 s default from leaving a caller hanging.
    public static func make(baseURL: URL, timeout: TimeInterval) -> ApolloClient {
        let url = baseURL.appendingPathComponent("graphql")
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
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

/// Parses the `DateTime`/`CanvasDate` scalars (ISO 8601, with or without
/// milliseconds: the device-facing dates have none).
public enum GraphQLDate {
    public static func parse(_ value: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value))
            ?? (try? Date.ISO8601FormatStyle().parse(value))
    }
}
