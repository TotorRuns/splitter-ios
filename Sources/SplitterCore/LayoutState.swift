import Foundation

// Decodable mirror of livesplit-core's layout state JSON (`Layout.stateAsJson`).
// Only the parts the app renders are modelled; unknown components decode as `.unsupported`.

public struct RGBA: Decodable, Equatable, Sendable {
    public var r, g, b, a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        r = try c.decode(Double.self)
        g = try c.decode(Double.self)
        b = try c.decode(Double.self)
        a = try c.decode(Double.self)
    }

    public static let clear = RGBA(0, 0, 0, 0)
    public static let white = RGBA(1, 1, 1, 1)
}

/// `"Transparent"`, `{"Plain": c}`, `{"Vertical": [c, c]}`, `{"Horizontal": [c, c]}`, `{"Alternating": [c, c]}`.
public enum Gradient: Decodable, Equatable, Sendable {
    case transparent
    case plain(RGBA)
    case vertical(RGBA, RGBA)
    case horizontal(RGBA, RGBA)
    case alternating(RGBA, RGBA)
    /// Layout backgrounds may also be images; we fall back to the default background for those.
    case other

    private enum Keys: String, CodingKey { case Plain, Vertical, Horizontal, Alternating }

    public init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self = s == "Transparent" ? .transparent : .other
            return
        }
        let c = try decoder.container(keyedBy: Keys.self)
        if let p = try c.decodeIfPresent(RGBA.self, forKey: .Plain) {
            self = .plain(p)
        } else if let v = try c.decodeIfPresent([RGBA].self, forKey: .Vertical), v.count == 2 {
            self = .vertical(v[0], v[1])
        } else if let h = try c.decodeIfPresent([RGBA].self, forKey: .Horizontal), h.count == 2 {
            self = .horizontal(h[0], h[1])
        } else if let a = try c.decodeIfPresent([RGBA].self, forKey: .Alternating), a.count == 2 {
            self = .alternating(a[0], a[1])
        } else {
            self = .other
        }
    }
}

public enum SemanticColor: String, Decodable, Sendable {
    case Default, AheadGainingTime, AheadLosingTime, BehindLosingTime, BehindGainingTime
    case BestSegment, NotRunning, Paused, PersonalBest

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SemanticColor(rawValue: raw) ?? .Default
    }
}

public struct LayoutState: Decodable, Sendable {
    public var components: [ComponentState]
    public var background: Gradient
    public var textColor: RGBA
    public var separatorsColor: RGBA
    public var thinSeparatorsColor: RGBA

    enum CodingKeys: String, CodingKey {
        case components, background
        case textColor = "text_color"
        case separatorsColor = "separators_color"
        case thinSeparatorsColor = "thin_separators_color"
    }

    public static func decode(_ json: String) throws -> LayoutState {
        try JSONDecoder().decode(LayoutState.self, from: Data(json.utf8))
    }
}

public enum ComponentState: Decodable, Sendable {
    case title(TitleState)
    case splits(SplitsState)
    case timer(TimerState)
    case keyValue(KeyValueState)
    case separator
    case blankSpace(height: Double)
    case text(TextState)
    case unsupported(String)

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    private struct BlankSpace: Decodable { var size: Double? }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        guard let key = c.allKeys.first else {
            self = .unsupported("empty")
            return
        }
        switch key.stringValue {
        case "Title": self = .title(try c.decode(TitleState.self, forKey: key))
        case "Splits": self = .splits(try c.decode(SplitsState.self, forKey: key))
        case "Timer": self = .timer(try c.decode(TimerState.self, forKey: key))
        case "KeyValue": self = .keyValue(try c.decode(KeyValueState.self, forKey: key))
        case "Separator": self = .separator
        case "BlankSpace":
            self = .blankSpace(height: (try? c.decode(BlankSpace.self, forKey: key).size) ?? 24)
        case "Text": self = .text(try c.decode(TextState.self, forKey: key))
        default: self = .unsupported(key.stringValue)
        }
    }
}

public struct TitleState: Decodable, Sendable {
    public var background: Gradient
    public var textColor: RGBA?
    public var icon: String
    /// Abbreviations, longest last.
    public var line1: [String]
    public var line2: [String]
    public var isCentered: Bool
    public var finishedRuns: UInt32?
    public var attempts: UInt32?

    enum CodingKeys: String, CodingKey {
        case background, icon, line1, line2, attempts
        case textColor = "text_color"
        case isCentered = "is_centered"
        case finishedRuns = "finished_runs"
    }

    public var title: String { line1.last ?? "" }
    public var subtitle: String { line2.last ?? "" }
}

public struct SplitColumn: Decodable, Sendable {
    public var value: String
    public var semanticColor: SemanticColor
    public var visualColor: RGBA

    enum CodingKeys: String, CodingKey {
        case value
        case semanticColor = "semantic_color"
        case visualColor = "visual_color"
    }
}

public struct SplitRow: Decodable, Sendable, Identifiable {
    public enum Kind: Sendable { case segment, groupHeader, placeholder }

    public var icon: String
    public var name: String
    public var columns: [SplitColumn]
    public var isCurrentSplit: Bool
    public var isIndented: Bool
    public var showSeparatorBefore: Bool
    /// livesplit-core's row index: the segment index for segment rows. Segment-group header
    /// rows and the filler rows that pad the list use values counting down from `UInt64.max`.
    public var rawIndex: UInt64
    public var sectionIndex: Int

    /// Unique per row (segment indexes and the high marker values never collide).
    public var id: UInt64 { rawIndex }
    /// The segment index, or nil for group headers and filler rows.
    public var index: Int? { rawIndex < UInt64(Int32.max) ? Int(rawIndex) : nil }

    public var kind: Kind {
        if index != nil { return .segment }
        return name.isEmpty && columns.isEmpty ? .placeholder : .groupHeader
    }
    public var isPlaceholder: Bool { kind == .placeholder }
    public var isGroupHeader: Bool { kind == .groupHeader }

    enum CodingKeys: String, CodingKey {
        case icon, name, columns, index
        case isCurrentSplit = "is_current_split"
        case isIndented = "is_indented"
        case showSeparatorBefore = "show_separator_before"
        case sectionIndex = "section_index"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        icon = (try? c.decode(String.self, forKey: .icon)) ?? ""
        name = try c.decode(String.self, forKey: .name)
        columns = try c.decode([SplitColumn].self, forKey: .columns)
        isCurrentSplit = (try? c.decode(Bool.self, forKey: .isCurrentSplit)) ?? false
        isIndented = (try? c.decode(Bool.self, forKey: .isIndented)) ?? false
        showSeparatorBefore = (try? c.decode(Bool.self, forKey: .showSeparatorBefore)) ?? false
        rawIndex = try c.decode(UInt64.self, forKey: .index)
        sectionIndex = (try? c.decode(Int.self, forKey: .sectionIndex)) ?? 0
    }
}

public struct SplitsState: Decodable, Sendable {
    public var background: Gradient
    /// Column labels, in the same (right-to-left) order as `SplitRow.columns`.
    public var columnLabels: [String]?
    public var splits: [SplitRow]
    public var hasIcons: Bool
    public var showThinSeparators: Bool
    public var currentSplitGradient: Gradient

    enum CodingKeys: String, CodingKey {
        case background, splits
        case columnLabels = "column_labels"
        case hasIcons = "has_icons"
        case showThinSeparators = "show_thin_separators"
        case currentSplitGradient = "current_split_gradient"
    }
}

public struct TimerState: Decodable, Sendable {
    public var background: Gradient
    public var time: String
    public var fraction: String
    public var semanticColor: SemanticColor
    public var topColor: RGBA
    public var bottomColor: RGBA
    public var height: Double

    enum CodingKeys: String, CodingKey {
        case background, time, fraction, height
        case semanticColor = "semantic_color"
        case topColor = "top_color"
        case bottomColor = "bottom_color"
    }
}

public struct KeyValueState: Decodable, Sendable {
    public var background: Gradient
    public var keyColor: RGBA?
    public var valueColor: RGBA?
    public var key: String
    public var value: String
    public var semanticColor: SemanticColor?

    enum CodingKeys: String, CodingKey {
        case background, key, value
        case keyColor = "key_color"
        case valueColor = "value_color"
        case semanticColor = "semantic_color"
    }
}

public struct TextState: Decodable, Sendable {
    public var background: Gradient
    public var left: String
    public var right: String?

    private struct Center: Decodable { var Center: String? }
    private struct Split: Decodable { var Split: [String]? }
    private enum Keys: String, CodingKey { case background, text }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        background = (try? c.decode(Gradient.self, forKey: .background)) ?? .transparent
        if let s = try? c.decode(Split.self, forKey: .text), let parts = s.Split, parts.count == 2 {
            left = parts[0]; right = parts[1]
        } else {
            left = (try? c.decode(Center.self, forKey: .text))?.Center ?? ""
            right = nil
        }
    }
}
