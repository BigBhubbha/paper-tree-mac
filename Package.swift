// swift-tools-version:5.9
// Paper Tree for Mac: a menu bar agent app with a lab flask buddy.
import Foundation
import PackageDescription

/// Prebuilt sherpa-onnx (Kokoro voices), fetched by scripts/fetch_local_ai_libs.sh.
let sherpaLib = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Vendor/sherpa-onnx/lib").path

let package = Package(
    name: "PaperTree",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Built-in updater. Keep this pinned to the same version CI downloads sign_update from.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        // llama.cpp (MIT), the on-device writer. A prebuilt universal framework with Metal built in.
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b12428/llama-b12428-xcframework.zip",
            checksum: "43d69839495547c9f449698b4ae29070a11b6b21ce71aa392e15bfa0b0128e1d"
        ),
        // sherpa-onnx's C API (Apache 2.0), for Kokoro. Header only; the dylib is linked from Vendor.
        .systemLibrary(name: "CSherpaOnnx", path: "Sources/CSherpaOnnx"),
        .executableTarget(
            name: "PaperTree",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                "llama",
                "CSherpaOnnx",
            ],
            path: "Sources/PaperTree",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreText"),
                .linkedFramework("ServiceManagement"),
                .unsafeFlags(["-L", sherpaLib]),
            ]
        )
    ]
)
