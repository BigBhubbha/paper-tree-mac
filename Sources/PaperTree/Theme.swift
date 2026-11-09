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

    // The flask buddy, in the green family (no third palette, no glow).
    static let flaskGlass  = Color(hex: 0xE6EBDA)
    static let flaskShine  = Color(hex: 0xF4F6EC)
    static let flaskLiquid = Color(hex: 0x8EA672)
    static let flaskDeep   = Color(hex: 0x6E8A55)
    static let flaskLine   = Color(hex: 0x506B39)
    static let cheek       = Color(hex: 0xB2432C).opacity(0.35)
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
    static let text        = "PTNewsreader-Regular"
    static let textMedium  = "PTNewsreader-Medium"
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
    static func text(_ size: CGFloat) -> Font { .custom(Typeface.text, size: size) }
    static func textMedium(_ size: CGFloat) -> Font { .custom(Typeface.textMedium, size: size) }
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
            .modifier(StampHover())
            .animation(Motion.snappy, value: pressed)
            .contentShape(Rectangle())
    }
}

/// A stamp lifts a hair toward you on hover, so it reads as something to press.
private struct StampHover: ViewModifier {
    @State private var hover = false
    func body(content: Content) -> some View {
        content
            .offset(x: hover ? -0.5 : 0, y: hover ? -1 : 0)
            .onHover { h in withAnimation(Motion.snappy) { hover = h } }
    }
}

/// Underlined text link, like ".under" on the site.
struct InkLinkButtonStyle: ButtonStyle {
    var color: Color = Palette.ink
    func makeBody(configuration: Configuration) -> some View {
        InkLink(label: configuration.label, pressed: configuration.isPressed, color: color)
    }
}

/// The underline draws a little thicker on hover and the ink turns red on press.
private struct InkLink<Label: View>: View {
    var label: Label
    var pressed: Bool
    var color: Color
    @State private var hover = false
    var body: some View {
        label
            .font(.ui(12.5))
            .foregroundColor(pressed ? Palette.red : color)
            .overlay(Rectangle().frame(height: hover ? 1.6 : 1)
                        .foregroundColor(pressed ? Palette.red : color.opacity(hover ? 1 : 0.8)).offset(y: 2), alignment: .bottom)
            .offset(y: pressed ? 0.5 : 0)
            .contentShape(Rectangle())
            .onHover { h in withAnimation(Motion.snappy) { hover = h } }
            .animation(Motion.snappy, value: pressed)
    }
}

/// An ink switch for the research mode toggle.
struct InkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(Motion.pick(Motion.snappy)) { configuration.isOn.toggle() }
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

/// A section head: roman IM Fell, then a thin ink rule across the column. The rule, not italics,
/// marks where a section starts.
struct SectionHead<Aside: View>: View {
    var title: String
    var size: CGFloat = 21
    @ViewBuilder var aside: Aside

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title).font(.fell(size)).tracking(0.2).foregroundColor(Palette.ink)
                aside
                Spacer(minLength: 0)
            }
            Rectangle().fill(Palette.ink.opacity(0.8)).frame(height: 0.8)
        }
    }
}

extension SectionHead where Aside == EmptyView {
    init(title: String, size: CGFloat = 21) {
        self.init(title: title, size: size) { EmptyView() }
    }
}
