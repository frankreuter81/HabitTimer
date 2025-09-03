import SwiftUI

@main
struct HabitTimerApp: App {
    @StateObject private var store = HabitStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear { HabitStore.shared = store }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.backfillSkippedSinceLastSeen()
                    }
                }
                .onOpenURL { url in
                    _ = store.handleDeepLink(url)
                }
        }
    }
}
