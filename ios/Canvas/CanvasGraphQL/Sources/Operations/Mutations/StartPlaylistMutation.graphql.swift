// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class StartPlaylistMutation: GraphQLMutation {
  public static let operationName: String = "StartPlaylist"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation StartPlaylist($input: StartPlaylistInput!) { startPlaylist(input: $input) { __typename playlistId wokeUp } }"#
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
      .field("startPlaylist", StartPlaylist.self, arguments: ["input": .variable("input")]),
    ] }

    /// Initialize the playlist with the given canvas URL and cron interval, then try to wake the device.
    public var startPlaylist: StartPlaylist { __data["startPlaylist"] }

    /// StartPlaylist
    ///
    /// Parent Type: `PlaylistWakeUpPayload`
    public struct StartPlaylist: CanvasGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.PlaylistWakeUpPayload }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("playlistId", CanvasGraphQL.PlaylistId.self),
        .field("wokeUp", Bool.self),
      ] }

      /// Identifier of the affected playlist
      public var playlistId: CanvasGraphQL.PlaylistId { __data["playlistId"] }
      /// True if the BLOOMIN8 device acknowledged the wake-up call. False means it was unreachable and will catch up at its next scheduled pull.
      public var wokeUp: Bool { __data["wokeUp"] }
    }
  }
}
