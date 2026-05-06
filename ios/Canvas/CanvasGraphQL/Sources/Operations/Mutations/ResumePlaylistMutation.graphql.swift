// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class ResumePlaylistMutation: GraphQLMutation {
  public static let operationName: String = "ResumePlaylist"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation ResumePlaylist { resumePlaylist { __typename playlistId wokeUp } }"#
    ))

  public init() {}

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("resumePlaylist", ResumePlaylist.self),
    ] }

    /// Resume a paused playlist and try to wake the device immediately.
    public var resumePlaylist: ResumePlaylist { __data["resumePlaylist"] }

    /// ResumePlaylist
    ///
    /// Parent Type: `PlaylistResumePayload`
    public struct ResumePlaylist: CanvasGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.PlaylistResumePayload }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("playlistId", CanvasGraphQL.PlaylistId.self),
        .field("wokeUp", Bool.self),
      ] }

      /// Identifier of the resumed playlist
      public var playlistId: CanvasGraphQL.PlaylistId { __data["playlistId"] }
      /// True if the BLOOMIN8 device acknowledged the wake-up call. False means it was unreachable and will catch up at its next scheduled pull.
      public var wokeUp: Bool { __data["wokeUp"] }
    }
  }
}
