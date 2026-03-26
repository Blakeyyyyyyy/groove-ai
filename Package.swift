// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrooveAI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GrooveAI", targets: ["GrooveAI"]),
    ],
    targets: [
        .target(
            name: "GrooveAI",
            path: "GrooveAI"
        ),
    ]
)
