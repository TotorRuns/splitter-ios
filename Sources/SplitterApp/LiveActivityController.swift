#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import SplitterActivity
import SplitterCore

/// Keeps one Live Activity in step with the open attempt: started when the timer starts, updated
/// on every split or pause, ended on reset or when leaving the timer.
@MainActor
final class LiveActivityController {
    private typealias Attributes = SplitterActivityAttributes
    /// The activity is kept by id: `Activity` isn't Sendable, so each async call looks it up itself.
    private var activityID: String?

    func update(for session: TimerSession) {
        switch session.phase {
        case .notRunning:
            end(immediately: true)
        case .running, .paused, .ended:
            let content = ActivityContent(state: contentState(for: session), staleDate: nil)
            if let id = activityID {
                if session.phase == .ended {
                    // Leave the final time on the Lock Screen for a while, then let it go.
                    activityID = nil
                    Task.detached { await Self.find(id)?.end(content, dismissalPolicy: .after(.now + 15 * 60)) }
                } else {
                    Task.detached { await Self.find(id)?.update(content) }
                }
            } else if session.phase != .ended, ActivityAuthorizationInfo().areActivitiesEnabled {
                let attributes = Attributes(game: session.gameName, category: session.categoryName)
                activityID = (try? Activity.request(attributes: attributes, content: content, pushType: nil))?.id
            }
        }
    }

    func end(immediately: Bool) {
        guard let id = activityID else { return }
        activityID = nil
        let policy: ActivityUIDismissalPolicy = immediately ? .immediate : .default
        Task.detached { await Self.find(id)?.end(nil, dismissalPolicy: policy) }
    }

    /// Ends activities left behind if the app was killed mid-attempt.
    static func endStaleActivities() {
        Task.detached {
            for activity in Activity<Attributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private nonisolated static func find(_ id: String) -> Activity<Attributes>? {
        Activity<Attributes>.activities.first { $0.id == id }
    }

    private func contentState(for session: TimerSession) -> SplitterActivityAttributes.ContentState {
        let elapsed = session.elapsedRealTime
        let phase: SplitterActivityAttributes.Phase = switch session.phase {
        case .paused: .paused
        case .ended: .ended
        default: .running
        }
        return .init(splitName: session.currentSplitName,
                     splitNumber: session.currentSplitIndex + 1,
                     splitCount: session.segmentCount,
                     phase: phase,
                     timerStart: Date.now.addingTimeInterval(-elapsed),
                     elapsed: elapsed)
    }
}
#endif
