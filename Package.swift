// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VLMUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VLMUI", targets: ["VLMUI"])
    ],
    dependencies: [
        // Add dependencies here if needed (e.g., MarkdownUI, etc.)
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "VLMUI",
            dependencies: [],
            path: "Sources/VLMUI"
        ),
        .testTarget(
            name: "VLMUITests",
            dependencies: ["VLMUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
