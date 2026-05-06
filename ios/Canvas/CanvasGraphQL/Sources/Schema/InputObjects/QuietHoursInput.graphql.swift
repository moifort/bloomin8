// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Optional window during which the device should not pull. Currently start=23 / end=07 are hard-coded server-side; only enabled and timezone are honored.
public struct QuietHoursInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    enabled: Bool,
    timezone: Timezone
  ) {
    __data = InputDict([
      "enabled": enabled,
      "timezone": timezone
    ])
  }

  /// Whether the quiet window applies
  public var enabled: Bool {
    get { __data["enabled"] }
    set { __data["enabled"] = newValue }
  }

  /// IANA timezone used to evaluate the quiet window (e.g. Europe/Paris)
  public var timezone: Timezone {
    get { __data["timezone"] }
    set { __data["timezone"] = newValue }
  }
}
