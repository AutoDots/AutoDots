// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AutoDots",
    platforms: [
       .macOS(.v13) // Platform declaration (can be adjusted if needed for Linux-specific targets)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
        // 🍃 An expressive, performant, and extensible templating language built for Swift.
        .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        // 👇 COMMENTED OUT MathCat-Swift DEPENDENCY - Linking against system libmathcat instead 👇
        .package(url: "https://github.com/AutoDots/MathCat-Swift.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                // 👇 COMMENTED OUT MathCat-Swift PRODUCT DEPENDENCY 👇
                 .product(name: "MathCat", package: "MathCat-Swift"),
            ],
            swiftSettings: swiftSettings, // Placed BEFORE linkerSettings as required
            linkerSettings: [
                .linkedLibrary("libmathcat_c"), // Links against libmathcat.so (or .a) - Linux compatible
                .unsafeFlags(["-L/usr/local/lib"]) // Adds /usr/local/lib to linker search paths - Linux compatible
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings // Placed BEFORE other settings for consistency
        )
    ],
    swiftLanguageModes: [.v5]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }