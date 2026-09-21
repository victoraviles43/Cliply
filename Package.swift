// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Portapapeles",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Portapapeles", targets: ["Portapapeles"])],
    targets: [
        .executableTarget(
            name: "Portapapeles",
            path: ".",
            exclude: ["Info.plist", "README.md", "build-app.sh", "dist"],
            sources: ["MyApp.swift", "EmojiCatalog.swift"]
        )
    ]
)
