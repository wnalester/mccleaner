// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "McCleaner",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "McCleaner",
            path: "Sources/McCleaner",
            resources: [
                .copy("Resources/AppIcon.png"),
                .copy("Resources/Fonts/BricolageGrotesque.ttf"),
                .copy("Resources/Fonts/HankenGrotesk.ttf"),
            ]
        )
    ]
)
