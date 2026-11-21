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
        if let finished = state.finishedRuns { return "\(finished)/\(attempts)" }
        return "\(attempts)"
    }
}

struct SplitsComponent: View {
    var state: SplitsState
    var layout: LayoutState
    var session: TimerSession

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
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
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

    var body: some View {
        HStack(spacing: 10) {
            if hasIcons {
                RunIcon(id: row.icon, session: session, size: 24)
                    .frame(width: 24, height: 24)
            }
            Text(row.name)
                .fontWeight(row.isGroupHeader ? .semibold : nil)
                .lineLimit(1)
                .padding(.leading, row.isIndented ? 16 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            // livesplit-core lists columns right-to-left.
            ForEach(Array(row.columns.reversed().enumerated()), id: \.offset) { _, column in
                Text(column.value)
                    .monospacedDigit()
                    .foregroundStyle(Color(column.visualColor))
                    .lineLimit(1)
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
        .font(.body)
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }
}

struct TimerComponent: View {
    var state: TimerState

    var body: some View {
        let fill = LinearGradient(colors: [Color(state.topColor), Color(state.bottomColor)],
                                  startPoint: .top, endPoint: .bottom)
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Spacer(minLength: 0)
            Text(state.time)
                .font(.system(size: 64, weight: .semibold, design: .rounded))
            Text(state.fraction)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .foregroundStyle(fill)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(GradientFill(gradient: state.background))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer \(state.time)\(state.fraction)")
    }
}

struct KeyValueComponent: View {
    var state: KeyValueState

    var body: some View {
        HStack {
            Text(state.key)
                .foregroundStyle(state.keyColor.map(Color.init) ?? .primary)
            Spacer()
            Text(state.value)
                .monospacedDigit()
                .foregroundStyle(state.valueColor.map(Color.init) ?? .primary)
        }
        .font(.subheadline)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(GradientFill(gradient: state.background))
        .accessibilityElement(children: .combine)
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
