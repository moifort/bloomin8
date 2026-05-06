// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class PlaylistProgressQuery: GraphQLQuery {
  public static let operationName: String = "PlaylistProgress"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query PlaylistProgress { playlistProgress { __typename displayed total status cronIntervalInHours } }"#
    ))

  public init() {}

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Query }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("playlistProgress", PlaylistProgress?.self),
    ] }

    /// Progress of the default playlist. Returns null when no playlist has been started yet.
    public var playlistProgress: PlaylistProgress? { __data["playlistProgress"] }

    /// PlaylistProgress
    ///
    /// Parent Type: `PlaylistProgress`
    public struct PlaylistProgress: CanvasGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.PlaylistProgress }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("displayed", Int.self),
        .field("total", Int.self),
        .field("status", GraphQLEnum<CanvasGraphQL.PlaylistStatus>.self),
        .field("cronIntervalInHours", CanvasGraphQL.Hour.self),
      ] }

      /// Number of images already shown in the current cycle
      public var displayed: Int { __data["displayed"] }
      /// Total number of images uploaded
      public var total: Int { __data["total"] }
      /// Current playlist status
      public var status: GraphQLEnum<CanvasGraphQL.PlaylistStatus> { __data["status"] }
      /// Interval between two image displays, in hours
      public var cronIntervalInHours: CanvasGraphQL.Hour { __data["cronIntervalInHours"] }
    }
  }
}
