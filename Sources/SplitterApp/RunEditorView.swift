#if canImport(SwiftUI)
import SwiftUI
import PhotosUI
import SplitterCore

/// Edits game/category/attempts and the segment list, like Splitter's "Edit Run" window.
struct RunEditorView: View {
    var editor: RunEditorSession
    var title: String
    var onSave: () -> Void
    var onCancel: () -> Void

    @State private var iconItem: PhotosPickerItem?
    @State private var confirmingClear = false

    var body: some View {
        Form {
            if let state = editor.state {
                Section("Run") {
                    CommitField("Game", text: state.game) { editor.setGameName($0) }
                    CommitField("Category", text: state.category) { editor.setCategoryName($0) }
                    CommitField("Attempts", text: String(state.attempts), keyboard: .numberPad) {
                        editor.setAttemptCount($0)
                    }
                    CommitField("Start Offset", text: state.offset, keyboard: .numbersAndPunctuation) {
                        editor.setOffset($0)
                    }
                    PhotosPicker(selection: $iconItem, matching: .images) {
                        Label("Choose Game Icon…", systemImage: "photo")
                    }
                }

                Section {
                    ForEach(state.segments) { row in
                        SegmentEditorRow(row: row, editor: editor)
                    }
                    .onDelete { offsets in
                        guard state.segments.count - offsets.count >= 1 else { return }
                        for index in offsets.sorted(by: >) {
                            if let i = state.segments[index].segmentIndex { editor.removeSegment(i) }
                        }
                    }
                    .onMove { source, destination in
                        move(from: source, to: destination, count: state.segments.count)
                    }
                    Button {
                        editor.insertSegment(below: max(state.segments.count - 1, 0))
                    } label: {
                        Label("Add Segment", systemImage: "plus")
                    }
                } header: {
                    Text("Segments")
                } footer: {
                    Text("Times are personal-best split times (e.g. 1:23.45). \"Best\" is your best segment.")
                }

                Section {
                    Button("Clear History and Times…", role: .destructive) { confirmingClear = true }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: onSave).bold() }
        }
        .confirmationDialog("Clear all times?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear History Only", role: .destructive) { editor.clearHistory() }
            Button("Clear History and Times", role: .destructive) { editor.clearTimes() }
        } message: {
            Text("This removes attempt history, best segments and personal best times.")
        }
        .onChange(of: iconItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    editor.setGameIcon(data)
                }
            }
        }
    }

    /// SwiftUI moves arbitrary ranges; livesplit-core moves the selection one step at a time.
    private func move(from source: IndexSet, to destination: Int, count: Int) {
        guard let from = source.first, source.count == 1 else { return }
        let to = destination > from ? destination - 1 : destination
        var current = from
        while current != to {
            let up = to < current
            editor.moveSegment(current, up: up)
            current += up ? -1 : 1
        }
    }
}

private struct SegmentEditorRow: View {
    var row: RunEditorState.Row
    var editor: RunEditorSession

    var body: some View {
        let index = row.segmentIndex ?? 0
        VStack(alignment: .leading, spacing: 6) {
            CommitField("Name", text: row.name ?? "", showsLabel: false) { editor.renameSegment(index, to: $0) }
                .font(.body.weight(.medium))
            HStack {
                CommitField("Split", text: row.splitTime ?? "", keyboard: .numbersAndPunctuation, compact: true) {
                    editor.setSplitTime(index, $0)
                }
                CommitField("Best", text: row.bestSegmentTime ?? "", keyboard: .numbersAndPunctuation, compact: true) {
                    editor.setBestSegmentTime(index, $0)
                }
            }
            .font(.callout.monospacedDigit())
        }
        .padding(.vertical, 2)
    }
}

/// A text field that edits a local draft and commits it on submit / focus loss,
/// then shows whatever livesplit-core normalised it to.
private struct CommitField: View {
    var label: String
    var text: String
    var keyboard: UIKeyboardType = .default
    var showsLabel = true
    var compact = false
    /// Returns false when livesplit-core rejects the value (e.g. an unparseable time).
    var commit: (String) -> Bool

    @State private var draft = ""
    @FocusState private var focused: Bool

    init(_ label: String, text: String, keyboard: UIKeyboardType = .default,
         showsLabel: Bool = true, compact: Bool = false, commit: @escaping (String) -> Bool) {
        self.label = label
        self.text = text
        self.keyboard = keyboard
        self.showsLabel = showsLabel
        self.compact = compact
        self.commit = commit
    }

    init(_ label: String, text: String, keyboard: UIKeyboardType = .default,
         showsLabel: Bool = true, compact: Bool = false, commit: @escaping (String) -> Void) {
        self.init(label, text: text, keyboard: keyboard, showsLabel: showsLabel, compact: compact) { value -> Bool in
            commit(value)
            return true
        }
    }

    var body: some View {
        HStack {
            if showsLabel {
                Text(label).foregroundStyle(.secondary)
                    .frame(minWidth: compact ? 36 : 90, alignment: .leading)
            }
            TextField(label, text: $draft)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .default ? .sentences : .never)
                .multilineTextAlignment(showsLabel && !compact ? .trailing : .leading)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(apply)
        }
        .onAppear { draft = text }
        .onChange(of: text) { _, new in if !focused { draft = new } }
        .onChange(of: focused) { _, isFocused in if !isFocused { apply() } }
    }

    private func apply() {
        guard draft != text else { return }
        // Accepted values come back normalised through `text`; rejected ones revert.
        if !commit(draft) { draft = text }
    }
}
#endif
