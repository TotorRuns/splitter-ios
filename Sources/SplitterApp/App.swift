#if canImport(SwiftUI)
import SwiftUI
import SplitterCore

@main
struct SplitterApp: App {
    @State private var library = RunLibrary(directory: RunLibrary.defaultDirectory())

    init() {
        // An attempt can't survive the app being closed, so neither should its Live Activity.
        LiveActivityController.endStaleActivities()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
                .tint(.splitterAccent)
        }
    }
}
#endif
