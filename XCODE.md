# Opening Paper Tree in Xcode (optional)

`build.sh` is the simplest path. Use Xcode if you want breakpoints or SwiftUI tinkering.

1. Open Xcode, File, Open, pick the `mac-app` folder (the one with `Package.swift`). Xcode opens it as a Swift package.
2. Choose the `PaperTree` scheme and "My Mac" as the destination. Press Run.
3. A plain package run starts the executable without the app bundle, so the icon, the bundled fonts, and `LSUIElement` are missing, and Accessibility permission gets attached to Xcode's helper instead of Paper Tree. That is fine for quick UI checks, but for real testing use `./build.sh --run`.

If you want a full Xcode app project:

1. File, New, Project, macOS, App. Name it Paper Tree, interface SwiftUI, language Swift.
2. Delete the generated `ContentView.swift` and `...App.swift`.
3. Drag everything in `Sources/PaperTree` into the project.
4. Drag `Resources/Fonts` in as a folder reference (blue folder) so it is copied to `Resources/Fonts`.
5. Use `Resources/AppIcon.iconset` images for the AppIcon in the asset catalog.
6. In the target's Info tab, add `Application is agent (UIElement)` = YES.
7. Signing & Capabilities: turn off App Sandbox (Accessibility and global mouse monitoring do not work inside the sandbox). Pick your personal team to get a stable signature, so the Accessibility permission survives rebuilds.
