// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class CanvasBatteryQuery: GraphQLQuery {
  public static let operationName: String = "CanvasBattery"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query CanvasBattery { canvasBattery { __typename percentage lastFullChargeDate lastPullDate } }"#
    ))

  public init() {}

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Query }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("canvasBattery", CanvasBattery?.self),
    ] }

    /// Latest battery report — null when no battery data has been recorded yet
    public var canvasBattery: CanvasBattery? { __data["canvasBattery"] }

    /// CanvasBattery
    ///
    /// Parent Type: `BatteryInfo`
    public struct CanvasBattery: CanvasGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.BatteryInfo }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("percentage", CanvasGraphQL.Percentage.self),
        .field("lastFullChargeDate", CanvasGraphQL.DateTime?.self),
        .field("lastPullDate", CanvasGraphQL.DateTime?.self),
      ] }

      /// Battery level as integer in [0, 100]
      public var percentage: CanvasGraphQL.Percentage { __data["percentage"] }
      /// When the device last reached 100% — null if never seen fully charged
      public var lastFullChargeDate: CanvasGraphQL.DateTime? { __data["lastFullChargeDate"] }
      /// Timestamp of the most recent pull from the device
      public var lastPullDate: CanvasGraphQL.DateTime? { __data["lastPullDate"] }
    }
  }
}
