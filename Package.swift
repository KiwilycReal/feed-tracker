// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FeedTracker",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "FeedTrackerCore", targets: ["FeedTrackerCore"]),
        .executable(name: "feed-tracker-cli", targets: ["FeedTrackerCLI"])
    ],
    targets: [
        .target(
            name: "FeedTrackerCore"
        ),
        .executableTarget(
            name: "FeedTrackerCLI",
            dependencies: ["FeedTrackerCore"]
        ),
        .testTarget(
            name: "FeedTrackerCoreTests",
            dependencies: ["FeedTrackerCore"]
        )
    ]
)
