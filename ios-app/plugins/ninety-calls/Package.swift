// swift-tools-version: 5.9
import PackageDescription

// v8.32: + Google WebRTC (stasel/WebRTC, prebuilt xcframework M150) — the app's own call audio (NinetyRTC.swift)
// v8.69: + LiveKit Swift SDK 2.17.0 (its own LK-prefixed WebRTC, no clash) — calls through our LiveKit server (NinetyLK.swift)
let package = Package(
    name: "NinetyCalls",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "NinetyCalls", targets: ["NinetyCallsPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0"),
        .package(url: "https://github.com/stasel/WebRTC.git", exact: "150.0.0"),
        .package(url: "https://github.com/livekit/client-sdk-swift.git", exact: "2.17.0")
    ],
    targets: [
        .target(
            name: "NinetyCallsPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "WebRTC", package: "WebRTC"),
                .product(name: "LiveKit", package: "client-sdk-swift")
            ],
            path: "ios/Sources/NinetyCallsPlugin")
    ]
)
