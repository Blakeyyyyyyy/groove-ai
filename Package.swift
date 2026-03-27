// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrooveAI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GrooveAI", targets: ["GrooveAI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "GrooveAI",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ],
            path: "GrooveAI"
        ),
    ]
)
