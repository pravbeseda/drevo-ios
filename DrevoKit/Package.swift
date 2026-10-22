// swift-tools-version: 6.2

import PackageDescription

let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "DrevoKit",
    // macOS only so that `swift test` runs on the host; the app is iOS-only.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DrevoKit", targets: ["DrevoKit"])
    ],
    targets: [
        .target(name: "DrevoKit", swiftSettings: strict),
        .testTarget(name: "DrevoKitTests", dependencies: ["DrevoKit"], swiftSettings: strict),
    ]
)
