// swift-tools-version:6.0

import PackageDescription

// Code shared by the app and the widget extension: configuration, App Group
// cache keys, GraphQL date parsing and the Apollo client factory.
let package = Package(
    name: "CanvasShared",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "CanvasShared", targets: ["CanvasShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apollographql/apollo-ios", exact: "1.18.0"),
    ],
    targets: [
        .target(
            name: "CanvasShared",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
            ]
        ),
    ]
)
