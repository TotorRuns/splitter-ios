#if canImport(SwiftUI)
import SwiftUI
import SplitterCore

/// Renders every component of a livesplit-core layout state natively.
/// The splits list takes the remaining height and scrolls; everything else sizes to fit.
struct LayoutStateView: View {
    var state: LayoutState
    var session: TimerSession

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.components.enumerated()), id: \.offset) { _, component in
                ComponentView(component: component, layout: state, session: session)
                if case .splits = component {} else {
                    Rectangle().fill(Color(state.separatorsColor)).frame(height: 0.5)
                }
            }
        }
        .foregroundStyle(Color(state.textColor))
        .background(GradientFill(gradient: state.background).ignoresSafeArea())
    }
}

struct ComponentView: View {
    var component: ComponentState
    var layout: LayoutState
    var session: TimerSession

    var body: some View {
        switch component {
        case .title(let title):
            TitleComponent(state: title, session: session)
        case .splits(let splits):
            SplitsComponent(state: splits, layout: layout, session: session)
        case .timer(let timer):
            TimerComponent(state: timer)
        case .keyValue(let kv):
            KeyValueComponent(state: kv)
        case .text(let text):
            TextComponent(state: text)
        case .blankSpace(let height):
            Color.clear.frame(height: height)
        case .separator:
            Rectangle().fill(Color(layout.separatorsColor)).frame(height: 1)
        case .unsupported:
            EmptyView()
        }
    }
}

struct TitleComponent: View {
    var state: TitleState
    var session: TimerSession

    var body: some View {
        HStack(spacing: 12) {
            RunIcon(id: state.icon, session: session, size: 44)
            VStack(alignment: state.isCentered ? .center : .leading, spacing: 2) {
                Text(state.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack {
                    Text(state.subtitle)
                    if !state.isCentered { Spacer(minLength: 8) }
                    if let attempts = state.attempts {
                        Text(attemptsText(attempts))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: state.isCentered ? .center : .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(state.textColor.map(Color.init) ?? .primary)
        .background(GradientFill(gradient: state.background))
        .accessibilityElement(children: .combine)
    }

    func attemptsText(_ attempts: UInt32) -> String {
        let noun = attempts == 1 ? "attempt" : "attempts"
        if let finished = state.finishedRuns { return "\(finished) of \(attempts) \(noun) finished" }
        return "\(attempts) \(noun)"
    }
}

struct SplitsComponent: View {
    var state: SplitsState
    var layout: LayoutState
    var session: TimerSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rows: [SplitRow] { state.splits.filter { !$0.isPlaceholder } }
    private var currentID: UInt64? { rows.first(where: \.isCurrentSplit)?.id }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let labels = state.columnLabels, !labels.isEmpty {
                        header(labels)
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                        if row.showSeparatorBefore {
                            Rectangle().fill(Color(layout.separatorsColor)).frame(height: 1)
                        }
                        SplitRowView(row: row, hasIcons: state.hasIcons, session: session)
                            .background {
                                if row.isCurrentSplit {
                                    GradientFill(gradient: state.currentSplitGradient)
                                } else {
                                    GradientFill(gradient: state.background, alternatingIndex: offset)
                                }
                            }
                            .id(row.id)
                        if state.showThinSeparators {
                            Rectangle().fill(Color(layout.thinSeparatorsColor)).frame(height: 0.5)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: currentID) { _, id in
                guard let id else { return }
                // HIG (Accessibility): honour Reduce Motion by not animating automatic scrolling.
                if reduceMotion {
                    proxy.scrollTo(id, anchor: .center)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func header(_ labels: [String]) -> some View {
        HStack {
            Spacer()
            ForEach(Array(labels.reversed().enumerated()), id: \.offset) { _, label in
                Text(label).frame(minWidth: 64, alignment: .trailing)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

struct SplitRowView: View {
    var row: SplitRow
    var hasIcons: Bool
    var session: TimerSession
    @Environment(\.splitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24

    // livesplit-core lists columns right-to-left.
    private var columns: [SplitColumn] { row.columns.reversed() }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // At the largest text sizes, put the times under the name so neither gets cut off.
                VStack(alignment: .leading, spacing: 4) {
                    nameLine
                    HStack(spacing: 16) {
                        Spacer(minLength: 0)
                        columnValues
                    }
                }
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 10) {
                    nameLine
                    columnValues
                }
            }
        }
        .font(.body)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(row.isCurrentSplit ? .isSelected : [])
        .accessibilityAddTraits(row.isGroupHeader ? .isHeader : [])
    }

    private var nameLine: some View {
        HStack(spacing: 10) {
            if hasIcons {
                RunIcon(id: row.icon, session: session, size: iconSize)
                    .frame(width: iconSize, height: iconSize)
            }
            Text(row.name)
                .fontWeight(row.isGroupHeader ? .semibold : nil)
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                .padding(.leading, row.isIndented ? 16 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var columnValues: some View {
        ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
            HStack(spacing: 3) {
                // A shape as well as a colour marks gold segments (HIG: don't rely on colour alone).
                if column.semanticColor.isBestSegment && !column.value.isEmpty {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .imageScale(.small)
                }
                Text(column.value)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(palette.swiftUIColor(column.semanticColor, fallback: column.visualColor) ?? .primary)
            .frame(minWidth: typeSize.isAccessibilitySize ? nil : columnWidth, alignment: .trailing)
        }
    }

    /// e.g. "Disc Dog, current split, 7:52, −1:05, ahead, gaining time".
    private var accessibilityText: String {
        var parts = [row.name.isEmpty ? "Split" : row.name]
        if row.isGroupHeader { parts.append("group") }
        if row.isCurrentSplit { parts.append("current split") }
        for column in columns where !column.value.isEmpty {
            parts.append(column.value)
            if let meaning = column.semanticColor.spokenDescription { parts.append(meaning) }
        }
        return parts.joined(separator: ", ")
    }
}

struct TimerComponent: View {
    var state: TimerState
    @Environment(\.splitPalette) private var palette
    // HIG (Typography/Accessibility): let the timer grow with the person's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var fractionSize: CGFloat = 38

    private var fill: LinearGradient {
        if let c = palette.color(for: state.semanticColor) {
            // Keep LiveSplit's top-to-bottom shading, using the accessible colour.
            let bottom = RGBA(c.r * 0.78, c.g * 0.78, c.b * 0.78, c.a)
            return LinearGradient(colors: [Color(c), Color(bottom)], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Color(state.topColor), Color(state.bottomColor)],
                              startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Spacer(minLength: 0)
            Text(state.time)
                .font(.system(size: timeSize, weight: .semibold, design: .rounded))
            Text(state.fraction)
                .font(.system(size: fractionSize, weight: .semibold, design: .rounded))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.3)
        .foregroundStyle(fill)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(GradientFill(gradient: state.background))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer")
        .accessibilityValue([state.time + state.fraction, state.semanticColor.spokenDescription]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct KeyValueComponent: View {
    var state: KeyValueState
    @Environment(\.splitPalette) private var palette

    var body: some View {
        HStack {
            Text(state.key)
                .foregroundStyle(state.keyColor.map(Color.init) ?? .primary)
            Spacer()
            HStack(spacing: 3) {
                if state.semanticColor?.isBestSegment == true {
                    Image(systemName: "star.fill").font(.caption2).imageScale(.small)
                }
                Text(state.value).monospacedDigit()
            }
            .foregroundStyle(palette.swiftUIColor(state.semanticColor, fallback: state.valueColor) ?? .primary)
        }
        .font(.subheadline)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(GradientFill(gradient: state.background))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.key)
        .accessibilityValue([state.value, state.semanticColor?.spokenDescription].compactMap { $0 }.joined(separator: ", "))
    }
}

struct TextComponent: View {
    var state: TextState

    var body: some View {
        HStack {
            if let right = state.right {
                Text(state.left)
                Spacer()
                Text(right).monospacedDigit()
            } else {
                Text(state.left).frame(maxWidth: .infinity)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(GradientFill(gradient: state.background))
    }
}
#endif
