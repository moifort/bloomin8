// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class PausePlaylistMutation: GraphQLMutation {
  public static let operationName: String = "PausePlaylist"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation PausePlaylist { pausePlaylist }"#
    ))

  public init() {}

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("pausePlaylist", CanvasGraphQL.PlaylistId.self),
    ] }

    /// Pause an in-progress playlist so the device defers its next pull.
    public var pausePlaylist: CanvasGraphQL.PlaylistId { __data["pausePlaylist"] }
  }
}
