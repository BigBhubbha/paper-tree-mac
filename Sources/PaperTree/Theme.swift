// Design tokens shared with the Paper Tree landing site:
// warm paper, ink, a green pen, a red pen, and a yellow marker.
import AppKit
import SwiftUI
import CoreText

enum Palette {
    static let paper      = Color(hex: 0xEFE6D2)
    static let paper2     = Color(hex: 0xF6EFDF)
    static let sheet      = Color(hex: 0xF8F3E6)
    static let ink        = Color(hex: 0x24211B)
    static let ink2       = Color(hex: 0x4A443A)
    static let ink3       = Color(hex: 0x776F60)
    static let pencil     = Color(hex: 0x8F887B)
    static let green      = Color(hex: 0x506B39)
    static let red        = Color(hex: 0xB2432C)
    static let marker     = Color(hex: 0xF6EA3D)
    static let rule       = Color(hex: 0x24211B).opacity(0.14)
    static let grid       = Color(hex: 0x506B39).opacity(0.07)

    // Buddy colors (mint flask, pink-lavender halo).
    static let mintGlass  = Color(hex: 0xD9F3E1)
    static let mintLight  = Color(hex: 0xC4ECD0)
    static let mint       = Color(hex: 0x9FDDB4)
    static let mintDeep   = Color(hex: 0x6FBF8E)
    static let mintLine   = Color(hex: 0x4F9A6C)
    static let haloPink   = Color(hex: 0xF4C4E4)
    static let haloLilac  = Color(hex: 0xDCCBF6)
    static let blush      = Color(hex: 0xF5A9C8)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// Typefaces bundled in Contents/Resources/Fonts. If a font failed to load,
/// SwiftUI falls back to the system font, so nothing breaks.
enum Typeface {
    static let fell        = "IM_FELL_English_Roman"
    static let fellItalic  = "IM_FELL_English_Italic"
    static let text        = "PTNewsreader-Regular"
    static let textMedium  = "PTNewsreader-Medium"
    static let textItalic  = "PTNewsreader-Italic"
    static let ui          = "PTHanken-Regular"
    static let uiBold      = "PTHanken-SemiBold"
    static let hand        = "Kalam-Regular"
    static let type        = "SpecialElite-Regular"

    static func registerBundledFonts() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }
        for url in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    static func fell(_ size: CGFloat) -> Font { .custom(Typeface.fell, size: size) }
    static func fellItalic(_ size: CGFloat) -> Font { .custom(Typeface.fellItalic, size: size) }
    static func text(_ size: CGFloat) -> Font { .custom(Typeface.text, size: size) }
    static func textMedium(_ size: CGFloat) -> Font { .custom(Typeface.textMedium, size: size) }
    static func textItalic(_ size: CGFloat) -> Font { .custom(Typeface.textItalic, size: size) }
    static func ui(_ size: CGFloat) -> Font { .custom(Typeface.ui, size: size) }
    static func uiBold(_ size: CGFloat) -> Font { .custom(Typeface.uiBold, size: size) }
    static func hand(_ size: CGFloat) -> Font { .custom(Typeface.hand, size: size) }
    static func typewriter(_ size: CGFloat) -> Font { .custom(Typeface.type, size: size) }
}

/// Faint paper grain, generated once at launch so we ship no texture image.
enum PaperGrain {
    static let image: NSImage = {
        let size = 160
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
        var seed: UInt32 = 0x9E3779B9
        func next() -> UInt32 { seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5; return seed }
        if let data = rep.bitmapData {
            for i in 0..<(size * size) {
                let v = next()
                let alpha = UInt8((v & 0xFF) % 26)          // 0 to 10 percent
                data[i * 4 + 0] = UInt8(Double(0x59) * Double(alpha) / 255)
                data[i * 4 + 1] = UInt8(Double(0x47) * Double(alpha) / 255)
                data[i * 4 + 2] = UInt8(Double(0x2E) * Double(alpha) / 255)
                data[i * 4 + 3] = alpha                        // premultiplied brown specks
            }
        }
        let img = NSImage(size: NSSize(width: size, height: size))
        img.addRepresentation(rep)
        return img
    }()
}

/// A sheet of field-journal paper: warm fill, grain, soft drop shadow.
struct PaperSheet: View {
    var corner: CGFloat = 6
    var graph: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Palette.sheet)
            .overlay(
                Image(nsImage: PaperGrain.image)
                    .resizable(resizingMode: .tile)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .allowsHitTesting(false)
            )
            .overlay(graph ? AnyView(GraphPaper().clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))) : AnyView(EmptyView()))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Palette.ink.opacity(0.16), lineWidth: 0.75)
            )
    }
}

/// Lab-notebook graph paper, very faint.
struct GraphPaper: View {
    var step: CGFloat = 12
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            var x: CGFloat = 0
            while x <= size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)); x += step }
            var y: CGFloat = 0
            while y <= size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)); y += step }
            ctx.stroke(p, with: .color(Palette.grid), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

/// The landing site's "stamp" button: ink block with an offset green shadow.
struct StampButtonStyle: ButtonStyle {
    var compact = false
    var quiet = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.uiBold(compact ? 12 : 13))
            .foregroundColor(quiet ? Palette.ink : Palette.paper2)
            .padding(.horizontal, compact ? 10 : 13)
            .padding(.vertical, compact ? 6 : 8)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(quiet ? Palette.paper2 : Palette.ink)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Palette.ink.opacity(quiet ? 0.8 : 0), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Palette.green)
                    .offset(x: pressed ? 1 : 3, y: pressed ? 1 : 3)
            )
            .offset(x: pressed ? 2 : 0, y: pressed ? 2 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .contentShape(Rectangle())
    }
}

/// Underlined text link, like ".under" on the site.
struct InkLinkButtonStyle: ButtonStyle {
    var color: Color = Palette.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(12.5))
            .foregroundColor(configuration.isPressed ? Palette.red : color)
            .overlay(Rectangle().frame(height: 1).foregroundColor(configuration.isPressed ? Palette.red : color.opacity(0.8)).offset(y: 2), alignment: .bottom)
            .contentShape(Rectangle())
    }
}

/// An ink switch for the research mode toggle.
struct InkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 10) {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule(style: .continuous)
                        .fill(configuration.isOn ? Palette.green : Palette.paper)
                        .overlay(Capsule(style: .continuous).strokeBorder(Palette.ink, lineWidth: 1.2))
                        .frame(width: 42, height: 24)
                    Circle()
                        .fill(configuration.isOn ? Palette.paper2 : Palette.ink)
                        .frame(width: 16, height: 16)
                        .padding(.horizontal, 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
