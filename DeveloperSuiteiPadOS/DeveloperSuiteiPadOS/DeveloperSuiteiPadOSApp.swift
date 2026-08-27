import SwiftUI

/// `AppViewModel.create()` is async (it awaits `MWiPadOSSerialPortProvider`'s
/// own async init before a `MedWandController` can exist — see
/// `AppViewModel.swift`), so the root scene holds an optional and shows a
/// brief loading state until it resolves. This runs once per app launch, not
/// per connect/disconnect cycle.
@main
struct DeveloperSuiteiPadOSApp: App {
    @State private var appViewModel: AppViewModel?

    var body: some Scene {
        WindowGroup {
            Group {
                if let appViewModel {
                    ContentView(appViewModel: appViewModel)
                } else {
                    ProgressView("Loading…")
                        .task {
                            appViewModel = await AppViewModel.create()
                        }
                }
            }
        }
    }
}
