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
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "VLMUI",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/VLMUI"
        ),
        .testTarget(
            name: "VLMUITests",
            dependencies: ["VLMUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
