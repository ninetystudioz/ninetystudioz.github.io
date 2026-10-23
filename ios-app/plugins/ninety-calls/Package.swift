// swift-tools-version: 5.9
import PackageDescription

// v8.32: + Google WebRTC (stasel/WebRTC, prebuilt xcframework M150) — the app's own call audio (NinetyRTC.swift)
let package = Package(
    name: "NinetyCalls",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "NinetyCalls", targets: ["NinetyCallsPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0"),
        .package(url: "https://github.com/stasel/WebRTC.git", exact: "150.0.0")
    ],
    targets: [
        .target(
            name: "NinetyCallsPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "WebRTC", package: "WebRTC")
            ],
            path: "ios/Sources/NinetyCallsPlugin")
    ]
)
