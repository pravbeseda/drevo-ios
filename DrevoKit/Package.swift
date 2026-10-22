// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DrevoKit",
    // macOS only so that `swift test` runs on the host; the app is iOS-only.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DrevoKit", targets: ["DrevoKit"])
    ],
    // Warnings are made errors by the `swift test` command in AGENTS.md and CI, not by a setting here: Xcode 26 builds
    // a package dependency with -suppress-warnings, which conflicts with .treatAllWarnings(as: .error).
    targets: [
        .target(name: "DrevoKit"),
        .testTarget(name: "DrevoKitTests", dependencies: ["DrevoKit"]),
    ]
)
