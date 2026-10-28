// swift-tools-version:5.9
// Paper Tree for Mac: a menu bar agent app with a lab flask buddy.
import PackageDescription

let package = Package(
    name: "PaperTree",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PaperTree",
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
