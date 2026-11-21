import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case messages
    case inbox
    case saved
    case watched
    case settings
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.returnToInbox) private var returnToInbox = true

    @State private var selection: AppTab = .messages
    @State private var router = WatchRouter()
    @State private var instagram = InstagramWebSession()
    @State private var wasInBackground = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Messages", systemImage: "paperplane", value: AppTab.messages) {
                MessagesView()
            }
            Tab("Shared", systemImage: "tray", value: AppTab.inbox) {
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
        .fullScreenCover(item: $router.messagesMedia) { item in
            LockedReelView(link: item.link)
                .onAppear {
                    try? ReelRepository.recordWatchedFromMessages(item.link, in: modelContext)
                }
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
            connectMessages()
            router.runImport(modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                wasInBackground = true
            case .active:
                router.runImport(modelContext)
                if wasInBackground && returnToInbox && selection != .messages {
                    // Coming back from Instagram (or anywhere else) lands on the Shared list.
                    selection = .inbox
                }
                wasInBackground = false
            default:
                break
            }
        }
        // Applied last so the tabs, sheets, and full-screen covers all receive them.
        .environment(router)
        .environment(instagram)
    }

    /// Routes taps from the Messages web view into native screens.
    private func connectMessages() {
        let router = router
        instagram.onOpenMedia = { link in
            guard router.messagesMedia == nil else { return }
            if link.shortcode != nil {
                router.messagesMedia = MediaPresentation(link: link)
            } else {
                // /share/... links have no shortcode to lock onto.
                router.safariItem = SafariItem(url: link.canonicalURL)
            }
        }
        instagram.onOpenExternal = { url in
            guard router.safariItem == nil else { return }
            router.safariItem = SafariItem(url: url)
        }
    }
}
