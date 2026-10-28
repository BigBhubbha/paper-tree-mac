// swift-tools-version:5.9
// Paper Tree for Mac: a menu bar agent app with a lab flask buddy.
import PackageDescription

let package = Package(
    name: "PaperTree",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Built-in updater. Keep this pinned to the same version CI downloads sign_update from.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        .executableTarget(
            name: "PaperTree",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/PaperTree",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreText"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
