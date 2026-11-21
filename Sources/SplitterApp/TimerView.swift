#if canImport(SwiftUI)
import SwiftUI
import UIKit
import SplitterCore

/// The main timer screen: layout on top, big split button and controls at the bottom.
struct TimerView: View {
    @State var session: TimerSession
    @Environment(RunLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var confirmingReset = false
    @State private var confirmingLeave = false
    @State private var editor: RunEditorSession?
    @State private var errorMessage: String?
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private var isActive: Bool { session.phase == .running || session.phase == .paused }

    var body: some View {
        VStack(spacing: 0) {
            // Redraw at display rate only while the clock is moving.
            TimelineView(.animation(minimumInterval: 1 / 30, paused: session.phase != .running)) { context in
                Group {
                    if let state = session.state {
                        LayoutStateView(state: state, session: session)
                    } else {
                        ContentUnavailableView("Couldn't render splits", systemImage: "exclamationmark.triangle",
                                               description: Text(session.lastError ?? ""))
                    }
                }
                .onChange(of: context.date) { _, _ in session.refresh() }
            }
            controls
        }
        .navigationTitle(session.categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isActive)
        .toolbar { toolbar }
        .onAppear { updateIdleTimer() }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            try? session.save()
            library.reload()
        }
        .onChange(of: session.phase) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { try? session.save() }
            session.refresh()
        }
        .confirmationDialog("Reset this attempt?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Save Times") { session.reset(saveTimes: true) }
            Button("Discard Times", role: .destructive) { session.reset(saveTimes: false) }
        } message: {
            Text("Saving adds the attempt to your history and updates best segments and your personal best.")
        }
        .confirmationDialog("An attempt is in progress", isPresented: $confirmingLeave, titleVisibility: .visible) {
            Button("Save Times and Leave") { session.reset(saveTimes: true); dismiss() }
            Button("Discard and Leave", role: .destructive) { session.reset(saveTimes: false); dismiss() }
        }
        .sheet(item: $editor) { editor in
            NavigationStack {
                RunEditorView(editor: editor, title: "Edit Splits") {
                    do { try session.apply(editor) } catch { errorMessage = error.localizedDescription }
                    self.editor = nil
                } onCancel: {
                    self.editor = nil
                }
            }
        }
        .alert("Something went wrong", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 10) {
            Button(action: splitTapped) {
                Text(primaryLabel)
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryTint)
            .disabled(session.phase == .ended)
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityHint("Starts the timer or splits the current segment")

            HStack(spacing: 10) {
                controlButton("Undo", systemImage: "arrow.uturn.backward", enabled: isActive || session.phase == .ended) {
                    session.undoSplit()
                }
                controlButton("Skip", systemImage: "forward.end", enabled: isActive) {
                    session.skipSplit()
                }
                controlButton(session.phase == .paused ? "Resume" : "Pause",
                              systemImage: session.phase == .paused ? "play" : "pause",
                              enabled: isActive) {
                    session.togglePause()
                }
                controlButton("Reset", systemImage: "stop", enabled: session.phase != .notRunning, role: .destructive) {
                    if session.resetWouldUpdateSplits { confirmingReset = true } else { session.reset(saveTimes: false) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func controlButton(_ title: String, systemImage: String, enabled: Bool,
                               role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role) {
            action()
            haptic(.light)
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.verticalCompact)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }

    private var primaryLabel: String {
        switch session.phase {
        case .notRunning: "Start"
        case .running: session.currentSplitIndex + 1 >= session.segmentCount ? "Finish" : "Split"
        case .paused: "Resume"
        case .ended: "Finished"
        }
    }

    private var primaryTint: Color {
        switch session.phase {
        case .notRunning: .green
        case .paused: .orange
        default: .splitterAccent
        }
    }

    private func splitTapped() {
        session.splitOrStart()
        haptic(.medium)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func updateIdleTimer() {
        // Keep the screen on during an attempt, like a physical timer.
        UIApplication.shared.isIdleTimerDisabled = isActive
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isActive {
            ToolbarItem(placement: .topBarLeading) {
                Button { confirmingLeave = true } label: { Label("Back", systemImage: "chevron.backward") }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Compare Against") {
                    Text(session.comparison)
                    Button { session.previousComparison() } label: { Label("Previous Comparison", systemImage: "chevron.left") }
                    Button { session.nextComparison() } label: { Label("Next Comparison", systemImage: "chevron.right") }
                }
                Button { session.toggleTimingMethod() } label: {
                    Label("Use \(session.timingMethod == .realTime ? "Game Time" : "Real Time")", systemImage: "clock.arrow.2.circlepath")
                }
                Divider()
                Button {
                    editor = session.makeEditor()
                } label: { Label("Edit Splits…", systemImage: "pencil") }
                .disabled(session.phase != .notRunning)
                if let url = session.fileURL {
                    ShareLink(item: url) { Label("Share .lss", systemImage: "square.and.arrow.up") }
                }
                Toggle(isOn: $hapticsEnabled) { Label("Haptics", systemImage: "hand.tap") }
            } label: {
                Label("Options", systemImage: "ellipsis.circle")
            }
        }
    }
}

private struct VerticalCompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            configuration.icon.font(.title3)
            configuration.title.font(.caption)
        }
    }
}

private extension LabelStyle where Self == VerticalCompactLabelStyle {
    static var verticalCompact: VerticalCompactLabelStyle { .init() }
}
#endif
