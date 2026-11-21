import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case inbox
    case saved
    case watched
    case settings
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.returnToInbox) private var returnToInbox = true

    @State private var selection: AppTab = .inbox
    @State private var router = WatchRouter()
    @State private var wasInBackground = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Inbox", systemImage: "tray", value: AppTab.inbox) {
                InboxView()
            }
            Tab("Saved", systemImage: "bookmark", value: AppTab.saved) {
                SavedView()
            }
            Tab("Watched", systemImage: "checkmark.circle", value: AppTab.watched) {
                WatchedView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .sheet(item: $router.safariItem) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $router.playerReel) { reel in
            FocusedPlayerView(reel: reel)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { router.alertMessage != nil },
                set: { if !$0 { router.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(router.alertMessage ?? "")
        }
        .task {
            router.runImport(modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                wasInBackground = true
            case .active:
                router.runImport(modelContext)
                if wasInBackground && returnToInbox {
                    // Coming back from Instagram (or anywhere else) lands on the Inbox.
                    selection = .inbox
                }
                wasInBackground = false
            default:
                break
            }
        }
        // Applied last so the tabs, sheets, and full-screen cover all receive it.
        .environment(router)
    }
}
