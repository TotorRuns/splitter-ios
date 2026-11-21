#if canImport(WidgetKit) && canImport(ActivityKit) && os(iOS)
import SwiftUI
import WidgetKit
import ActivityKit
import SplitterActivity

@main
struct SplitterWidgets: WidgetBundle {
    var body: some Widget {
        SplitterLiveActivity()
    }
}

/// Lock Screen and Dynamic Island view of a running attempt.
struct SplitterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SplitterActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.splitName).font(.headline).lineLimit(1)
                        Text(context.state.progress).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimeText(state: context.state)
                        .font(.title2.weight(.semibold))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: context.state.phase == .paused ? "pause.fill" : "stopwatch")
                    .foregroundStyle(context.state.phase == .paused ? .orange : .green)
            } compactTrailing: {
                TimeText(state: context.state)
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "stopwatch").foregroundStyle(.green)
            }
        }
    }
}

private struct LockScreenView: View {
    var attributes: SplitterActivityAttributes
    var state: SplitterActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(state.splitName)
                    .font(.headline)
                    .lineLimit(1)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            TimeText(state: state)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(state.phase == .paused ? Color.orange : Color.white)
        }
        .padding(16)
        .foregroundStyle(.white)
    }

    private var statusText: String {
        switch state.phase {
        case .running: state.progress
        case .paused: "Paused · " + state.progress
        case .ended: "Finished"
        }
    }
}

/// Counts up by itself while running; a fixed time while paused or finished.
private struct TimeText: View {
    var state: SplitterActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.phase == .running {
                Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
            } else {
                Text(state.frozenTimeText)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private extension SplitterActivityAttributes {
    var subtitle: String { [game, category].filter { !$0.isEmpty }.joined(separator: " · ") }
}
#else
// Nothing to build outside iOS; this keeps `swift test` working on Linux and macOS.
enum SplitterWidgetsUnavailable {}
#endif
