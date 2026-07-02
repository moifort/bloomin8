// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Window during which the device should not pull new images
public struct QuietHoursInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    enabled: Bool,
    end: GraphQLNullable<Int> = nil,
    start: GraphQLNullable<Int> = nil,
    timezone: Timezone
  ) {
    __data = InputDict([
      "enabled": enabled,
      "end": end,
      "start": start,
      "timezone": timezone
    ])
  }

  /// Whether the quiet window applies
  public var enabled: Bool {
    get { __data["enabled"] }
    set { __data["enabled"] = newValue }
  }

  /// Hour at which the quiet window ends, in [0, 23]. Defaults to 7.
  public var end: GraphQLNullable<Int> {
    get { __data["end"] }
    set { __data["end"] = newValue }
  }

  /// Hour at which the quiet window starts, in [0, 23]. Defaults to 23.
  public var start: GraphQLNullable<Int> {
    get { __data["start"] }
    set { __data["start"] = newValue }
  }

  /// IANA timezone used to evaluate the quiet window (e.g. Europe/Paris)
  public var timezone: Timezone {
    get { __data["timezone"] }
    set { __data["timezone"] = newValue }
  }
}
