// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Parameters required to (re)start the playlist and wake the device
public struct StartPlaylistInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    canvasUrl: CanvasUrl,
    cronIntervalInHours: Hour,
    quietHours: GraphQLNullable<QuietHoursInput> = nil
  ) {
    __data = InputDict([
      "canvasUrl": canvasUrl,
      "cronIntervalInHours": cronIntervalInHours,
      "quietHours": quietHours
    ])
  }

  /// Absolute URL of the BLOOMIN8 device on the local network
  public var canvasUrl: CanvasUrl {
    get { __data["canvasUrl"] }
    set { __data["canvasUrl"] = newValue }
  }

  /// Interval between two image displays, in hours (1–168)
  public var cronIntervalInHours: Hour {
    get { __data["cronIntervalInHours"] }
    set { __data["cronIntervalInHours"] = newValue }
  }

  /// Optional quiet-hours configuration
  public var quietHours: GraphQLNullable<QuietHoursInput> {
    get { __data["quietHours"] }
    set { __data["quietHours"] = newValue }
  }
}
