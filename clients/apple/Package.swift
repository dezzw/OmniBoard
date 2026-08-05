// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OmniBoardApple",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "OmniBoardKit", targets: ["OmniBoardKit"]),
        .executable(name: "OmniBoardApp", targets: ["OmniBoardApp"]),
        .executable(name: "OmniBoardKitSmoke", targets: ["OmniBoardKitSmoke"]),
    ],
    targets: [
        .target(
            name: "OmniBoardKit",
            path: "Sources/OmniBoardKit"
        ),
        .executableTarget(
            name: "OmniBoardApp",
            dependencies: ["OmniBoardKit"],
            path: "Sources/OmniBoardApp"
        ),
        // CLT-friendly checks (full XCTest needs Xcode.app).
        .executableTarget(
            name: "OmniBoardKitSmoke",
            dependencies: ["OmniBoardKit"],
            path: "Sources/OmniBoardKitSmoke"
        ),
    ]
)
