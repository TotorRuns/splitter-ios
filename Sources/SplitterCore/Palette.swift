import Foundation

/// Colours for livesplit-core's semantic states (ahead/behind, gold, PB…), replacing the layout's
/// built-in colours so they meet Apple's contrast guidance and can avoid red–green pairings.
///
/// HIG: text up to 17 pt needs at least 4.5:1 contrast (WCAG AA); with Increase Contrast on,
/// aim higher (7:1 here). livesplit-core's default "behind, losing time" red is only 3.2:1.
public enum SplitColorScheme: String, CaseIterable, Identifiable, Sendable {
    /// Green ahead / red behind, as in LiveSplit, with the reds and greys lightened for contrast.
    case standard
    /// Blue ahead / orange behind (Okabe–Ito-style), distinguishable with red–green colour blindness.
    case colorBlindFriendly

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .standard: "Standard (green / red)"
        case .colorBlindFriendly: "Color-blind friendly (blue / orange)"
        }
    }
}

public struct Palette: Sendable {
    public var scheme: SplitColorScheme
    public var increasedContrast: Bool

    public init(scheme: SplitColorScheme = .standard, increasedContrast: Bool = false) {
        self.scheme = scheme
        self.increasedContrast = increasedContrast
    }

    /// The colour for a semantic state, or nil for `.Default` (use the normal text colour).
    public func color(for semantic: SemanticColor) -> RGBA? {
        let hi = increasedContrast
        switch (scheme, semantic) {
        case (_, .Default): return nil
        case (.standard, .AheadGainingTime): return hi ? RGBA(0.25, 0.95, 0.4) : RGBA(0.0, 0.8, 0.21)
        case (.standard, .AheadLosingTime): return hi ? RGBA(0.6, 0.95, 0.68) : RGBA(0.38, 0.82, 0.5)
        case (.standard, .BehindGainingTime): return hi ? RGBA(1.0, 0.62, 0.62) : RGBA(0.88, 0.45, 0.45)
        case (.standard, .BehindLosingTime): return hi ? RGBA(1.0, 0.5, 0.5) : RGBA(1.0, 0.33, 0.33)
        case (.standard, .BestSegment): return hi ? RGBA(1.0, 0.88, 0.3) : RGBA(1.0, 0.83, 0.0)
        case (.standard, .PersonalBest): return hi ? RGBA(0.55, 0.82, 1.0) : RGBA(0.3, 0.7, 1.0)
        case (.colorBlindFriendly, .AheadGainingTime): return hi ? RGBA(0.55, 0.82, 1.0) : RGBA(0.34, 0.71, 0.91)
        case (.colorBlindFriendly, .AheadLosingTime): return hi ? RGBA(0.75, 0.9, 1.0) : RGBA(0.6, 0.8, 0.95)
        case (.colorBlindFriendly, .BehindGainingTime): return hi ? RGBA(1.0, 0.82, 0.6) : RGBA(0.95, 0.72, 0.45)
        case (.colorBlindFriendly, .BehindLosingTime): return hi ? RGBA(1.0, 0.72, 0.35) : RGBA(0.98, 0.6, 0.15)
        case (.colorBlindFriendly, .BestSegment): return hi ? RGBA(1.0, 0.95, 0.55) : RGBA(1.0, 0.9, 0.35)
        case (.colorBlindFriendly, .PersonalBest): return hi ? RGBA(0.93, 0.75, 0.88) : RGBA(0.85, 0.6, 0.75)
        case (_, .NotRunning): return hi ? RGBA(0.8, 0.8, 0.8) : RGBA(0.67, 0.67, 0.67)
        case (_, .Paused): return hi ? RGBA(0.75, 0.75, 0.75) : RGBA(0.6, 0.6, 0.6)
        }
    }

    /// The minimum contrast this palette is designed to reach on the layout background.
    public var targetContrast: Double { increasedContrast ? 7 : 4.5 }
}

extension SemanticColor {
    /// What the colour means, for VoiceOver (HIG: don't convey information with colour alone).
    public var spokenDescription: String? {
        switch self {
        case .Default, .NotRunning: nil
        case .AheadGainingTime: "ahead, gaining time"
        case .AheadLosingTime: "ahead, losing time"
        case .BehindGainingTime: "behind, gaining time"
        case .BehindLosingTime: "behind, losing time"
        case .BestSegment: "best segment"
        case .Paused: "paused"
        case .PersonalBest: "personal best"
        }
    }

    /// Whether to show a gold-segment marker next to the time (a shape, not just a colour).
    public var isBestSegment: Bool { self == .BestSegment }
}

extension RGBA {
    /// WCAG relative luminance.
    public var relativeLuminance: Double {
        func channel(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// This colour composited over an opaque background.
    public func over(_ background: RGBA) -> RGBA {
        RGBA(r * a + background.r * (1 - a), g * a + background.g * (1 - a), b * a + background.b * (1 - a), 1)
    }

    /// WCAG contrast ratio against `background` (1…21).
    public func contrast(against background: RGBA) -> Double {
        let l1 = over(background).relativeLuminance, l2 = background.relativeLuminance
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}
