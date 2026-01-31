import SwiftUI

@main
struct OhMyBugAppMain: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
    }
}
