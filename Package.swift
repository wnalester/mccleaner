// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SystemDataCleaner",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SystemDataCleaner",
            path: "Sources/SystemDataCleaner",
            resources: [.copy("Resources/AppIcon.png")]
        )
    ]
)
