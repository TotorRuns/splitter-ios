#if canImport(SwiftUI)
import SwiftUI
import UIKit
import SplitterCore

extension Color {
    init(_ c: RGBA) {
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    /// Splitter's blue accent (matches livesplit-core's current-split highlight).
    static let splitterAccent = Color(.sRGB, red: 0.2, green: 0.45, blue: 0.96, opacity: 1)
}

// MARK: Semantic colours

private struct SplitPaletteKey: EnvironmentKey {
    static let defaultValue = Palette()
}

extension EnvironmentValues {
    /// Colours for ahead/behind/gold states; set by the timer screen from the user's setting and
    /// the system Increase Contrast option.
    var splitPalette: Palette {
        get { self[SplitPaletteKey.self] }
        set { self[SplitPaletteKey.self] = newValue }
    }
}

extension Palette {
    /// The colour for a semantic state, falling back to livesplit-core's own colour (if any).
    func swiftUIColor(_ semantic: SemanticColor?, fallback: RGBA?) -> Color? {
        if let semantic, let c = color(for: semantic) { return Color(c) }
        return fallback.map(Color.init)
    }
}

/// Renders a livesplit-core gradient as a view background.
/// `alternatingIndex` picks the colour for alternating row backgrounds.
struct GradientFill: View {
    var gradient: SplitterCore.Gradient
    var alternatingIndex: Int = 0

    var body: some View {
        switch gradient {
        case .transparent, .other:
            Color.clear
        case .plain(let c):
            Color(c)
        case .vertical(let top, let bottom):
            LinearGradient(colors: [Color(top), Color(bottom)], startPoint: .top, endPoint: .bottom)
        case .horizontal(let left, let right):
            LinearGradient(colors: [Color(left), Color(right)], startPoint: .leading, endPoint: .trailing)
        case .alternating(let even, let odd):
            Color(alternatingIndex.isMultiple(of: 2) ? even : odd)
        }
    }
}

/// Prepares an image for use as a game icon: decodes anything UIKit can read (including HEIC
/// photos, which livesplit-core can't), scales it to fit 256 pt, and re-encodes it as PNG so
/// `.lss` files stay small.
enum GameIconImage {
    static let maxDimension: CGFloat = 256

    static func prepare(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.pngData()
    }
}

/// Image for a livesplit-core icon id, if the run has one.
struct RunIcon: View {
    var id: String
    var session: TimerSession
    var size: CGFloat

    var body: some View {
        if let data = session.iconData(id), let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
#endif
