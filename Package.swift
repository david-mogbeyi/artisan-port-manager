// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ArtisanPortManager",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ArtisanPortManager", targets: ["ArtisanPortManager"])
    ],
    targets: [
        .executableTarget(
            name: "ArtisanPortManager",
            path: "ArtisanPortManager",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "ArtisanPortManagerTests",
            dependencies: ["ArtisanPortManager"],
            path: "Tests"
        )
    ]
)
