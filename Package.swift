// swift-tools-version: 5.9
// This Package.swift exists ONLY for SPM dependency resolution.
// The actual app target is defined in GrooveAI.xcodeproj.
// DO NOT define library/executable products here — they conflict with the .xcodeproj app target.
import PackageDescription

let package = Package(
    name: "GrooveAIDeps",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.0.0"),
    ]
)
