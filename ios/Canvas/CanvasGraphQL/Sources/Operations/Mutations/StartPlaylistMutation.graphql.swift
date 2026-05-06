// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class StartPlaylistMutation: GraphQLMutation {
  public static let operationName: String = "StartPlaylist"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation StartPlaylist($input: StartPlaylistInput!) { startPlaylist(input: $input) }"#
    ))

  public var input: StartPlaylistInput

  public init(input: StartPlaylistInput) {
    self.input = input
  }

  public var __variables: Variables? { ["input": input] }

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("startPlaylist", CanvasGraphQL.PlaylistId.self, arguments: ["input": .variable("input")]),
    ] }

    /// Initialize the playlist with the given canvas URL and cron interval, then wake the device.
    public var startPlaylist: CanvasGraphQL.PlaylistId { __data["startPlaylist"] }
  }
}
