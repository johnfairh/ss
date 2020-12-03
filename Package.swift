// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "swift-sass",
    platforms: [
      .macOS("10.15")
    ],
    products: [
        .library(
            name: "EmbeddedSass",
            targets: ["EmbeddedSass"]),
    ],
    dependencies: [
      .package(
        name: "SwiftProtobuf",
        url: "https://github.com/apple/swift-protobuf.git",
        from: "1.13.0"),
      .package(
        name: "swift-nio",
        url: "https://github.com/apple/swift-nio.git",
        from: "2.25.0"),
    ],
    targets: [
      .target(
        name: "Sass",
        dependencies: []),
      .target(
        name: "EmbeddedSass",
        dependencies: [
          "SwiftProtobuf",
          "Sass",
          .product(name: "NIO", package: "swift-nio")
        ]),
      .testTarget(
        name: "EmbeddedSassTests",
        dependencies: ["EmbeddedSass"],
        exclude: ["dart-sass-embedded"]),
      .testTarget(
        name: "SassTests",
        dependencies: ["Sass"])
    ]
)
