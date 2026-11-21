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
