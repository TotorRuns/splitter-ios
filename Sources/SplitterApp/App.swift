#if canImport(SwiftUI)
import SwiftUI
import SplitterCore

@main
struct SplitterApp: App {
    @State private var library = RunLibrary(directory: RunLibrary.defaultDirectory())

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
                .preferredColorScheme(.dark)
                .tint(.splitterAccent)
        }
    }
}
#endif
