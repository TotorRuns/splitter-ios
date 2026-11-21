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

    @State private var liveActivity = LiveActivityController()
    @State private var confirmingReset = false
    @State private var confirmingLeave = false
    @State private var editor: RunEditorSession?
    @State private var errorMessage: String?
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("splitColorScheme") private var colorSchemeChoice = SplitColorScheme.standard.rawValue
    @AppStorage("tapToSplit") private var tapToSplit = false
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var palette: Palette {
        Palette(scheme: SplitColorScheme(rawValue: colorSchemeChoice) ?? .standard,
                increasedContrast: systemContrast == .increased)
    }

    private var isActive: Bool { session.phase == .running || session.phase == .paused }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                // Landscape phone: splits on the left, controls in a column on the right.
                HStack(spacing: 0) {
                    layoutView
                    Rectangle().fill(separatorColor).frame(width: 0.5).ignoresSafeArea()
                    controls(columns: true)
                        .frame(width: 260)
                }
            } else {
                layoutView
                    // Controls sit below the layout; its background still extends to the screen edge (HIG: Layout).
                    .safeAreaInset(edge: .bottom, spacing: 0) { controls(columns: false) }
            }
        }
        .environment(\.splitPalette, palette)
        // LiveSplit layouts are designed for a dark background, so the timer stays dark even when
        // the rest of the app follows the system appearance.
        .preferredColorScheme(.dark)
        // The layout's title block already names the game and category.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isActive)
        .toolbar { toolbar }
        .onAppear { updateIdleTimer() }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            liveActivity.end(immediately: true)
            try? session.save()
            library.reload()
        }
        .onChange(of: session.phase) { _, _ in
            updateIdleTimer()
            liveActivity.update(for: session)
        }
        .onChange(of: session.splitIndex) { _, _ in liveActivity.update(for: session) }
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
        .alert("Couldn't Save Splits", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Layout

    private var layoutView: some View {
        // Redraw at display rate only while the clock is moving.
        TimelineView(.animation(minimumInterval: 1 / 30, paused: session.phase != .running)) { context in
            Group {
                if let state = session.state {
                    LayoutStateView(state: state, session: session)
                } else {
                    ContentUnavailableView("Couldn't Show Splits", systemImage: "exclamationmark.triangle",
                                           description: Text(session.lastError ?? ""))
                }
            }
            .onChange(of: context.date) { _, _ in session.refresh() }
        }
        .contentShape(Rectangle())
        // Optional: tap anywhere on the splits to split, so you can hit it without looking.
        .onTapGesture {
            guard tapToSplit, session.phase != .ended else { return }
            splitTapped()
        }
    }

    private var separatorColor: Color {
        session.state.map { Color($0.separatorsColor) } ?? Color(.separator)
    }

    // MARK: Controls

    /// - Parameter columns: lay the controls out for a narrow column beside the splits (landscape).
    private func controls(columns: Bool) -> some View {
        VStack(spacing: 10) {
            Button(action: splitTapped) {
                Text(primaryLabel)
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 72, maxHeight: columns ? .infinity : nil)
            }
            .primaryControlStyle()
            .tint(primaryTint)
            .disabled(session.phase == .ended)
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityHint("Starts the timer or splits the current segment")

            if columns {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow { undoButton; skipButton }
                    GridRow { pauseButton; resetButton }
                }
            } else {
                HStack(spacing: 10) { undoButton; skipButton; pauseButton; resetButton }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            // Same background as the layout above, so the screen reads as one surface.
            GradientFill(gradient: session.state?.background ?? .plain(RGBA(0.06, 0.06, 0.06, 1)))
                .ignoresSafeArea()
        }
        .overlay(alignment: columns ? .leading : .top) {
            if !columns { Rectangle().fill(separatorColor).frame(height: 0.5) }
        }
    }

    private var undoButton: some View {
        controlButton("Undo", systemImage: "arrow.uturn.backward", enabled: isActive || session.phase == .ended,
                      shortcut: KeyboardShortcut(.delete, modifiers: [])) {
            session.undoSplit()
        }
    }

    private var skipButton: some View {
        controlButton("Skip", systemImage: "forward.end", enabled: isActive,
                      shortcut: KeyboardShortcut(.rightArrow, modifiers: [])) {
            session.skipSplit()
        }
    }

    private var pauseButton: some View {
        controlButton(session.phase == .paused ? "Resume" : "Pause",
                      systemImage: session.phase == .paused ? "play" : "pause",
                      enabled: isActive, shortcut: KeyboardShortcut("p", modifiers: [])) {
            session.togglePause()
        }
    }

    private var resetButton: some View {
        controlButton("Reset", systemImage: "stop", enabled: session.phase != .notRunning, role: .destructive,
                      shortcut: KeyboardShortcut("r", modifiers: [])) {
            if session.resetWouldUpdateSplits { confirmingReset = true } else { session.reset(saveTimes: false) }
        }
    }

    private func controlButton(_ title: String, systemImage: String, enabled: Bool,
                               role: ButtonRole? = nil, shortcut: KeyboardShortcut,
                               action: @escaping () -> Void) -> some View {
        Button(role: role) {
            action()
            haptic(.light)
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.verticalCompact)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(SecondaryControlButtonStyle(isDestructive: role == .destructive))
        .disabled(!enabled)
        .keyboardShortcut(shortcut)
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
                Picker(selection: $colorSchemeChoice) {
                    ForEach(SplitColorScheme.allCases) { scheme in
                        Text(scheme.label).tag(scheme.rawValue)
                    }
                } label: {
                    Label("Split Colors", systemImage: "paintpalette")
                }
                .pickerStyle(.menu)
                Toggle(isOn: $tapToSplit) { Label("Tap Splits to Split", systemImage: "hand.point.up.left") }
                Toggle(isOn: $hapticsEnabled) { Label("Haptics", systemImage: "iphone.radiowaves.left.and.right") }
            } label: {
                Label("Options", systemImage: "ellipsis.circle")
            }
        }
    }
}

// MARK: Control styling

private extension View {
    // The timer's controls belong to the content layer, so they use standard bordered buttons on a
    // standard material rather than Liquid Glass. HIG (Materials): "Don't use Liquid Glass in the
    // content layer" and "use Liquid Glass effects sparingly". The navigation bar, a system
    // component, still adopts Liquid Glass automatically on iOS 26.
    func primaryControlStyle() -> some View { buttonStyle(.borderedProminent) }
}

/// Bordered button whose disabled state stays legible: the system style dims the label to near
/// black on the dark timer background, which reads as broken rather than unavailable.
private struct SecondaryControlButtonStyle: ButtonStyle {
    var isDestructive = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? (isDestructive ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tint)) : AnyShapeStyle(.secondary))
            .background(.fill.tertiary, in: .rect(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.6 : (isEnabled ? 1 : 0.7))
            .contentShape(.rect(cornerRadius: 14))
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
