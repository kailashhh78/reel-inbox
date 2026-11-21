import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(WatchRouter.self) private var router
    @Environment(InstagramWebSession.self) private var instagram
    @State private var isConfirmingLogout = false

    @AppStorage(SettingsKey.openMode) private var openMode: OpenMode = .instagramApp
    @AppStorage(SettingsKey.markWatchedOnOpen) private var markWatchedOnOpen = true
    @AppStorage(SettingsKey.returnToInbox) private var returnToInbox = true
    @AppStorage(SettingsKey.loadPreviews) private var loadPreviews = false

    @Query private var allReels: [Reel]

    @State private var groupStatus: AppGroupDiagnostics.Status = .checking
    @State private var pendingCount = 0
    @State private var isConfirmingErase = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Log Out of Instagram…", role: .destructive) {
                        isConfirmingLogout = true
                    }
                } header: {
                    Text("Messages")
                } footer: {
                    Text("Messages shows Instagram's official website, limited to your chats. You log in on Instagram's own page; Reel Inbox never reads or stores your password. The feed, Reels, Explore, Stories and profiles are blocked, and a reel tapped in a chat opens alone. Swiping to the next one is blocked.")
                }

                Section {
                    Picker("Open reels in", selection: $openMode) {
                        ForEach(OpenMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                } header: {
                    Text("Shared reels")
                } footer: {
                    Text(openMode.explanation)
                }

                Section {
                    Toggle("Mark as watched when opened", isOn: $markWatchedOnOpen)
                    Toggle("Return to Shared when I come back", isOn: $returnToInbox)
                } footer: {
                    Text("When you come back from the Instagram app, Reel Inbox opens on your Shared list instead of the last tab you used. Messages is left as it was.")
                }

                Section {
                    Toggle("Show link previews", isOn: $loadPreviews)
                } footer: {
                    Text("Off by default. When on, Apple's LinkPresentation reads the public title and thumbnail from instagram.com. When off, this app only goes online when you tap Watch.")
                }

                Section("Library") {
                    LabeledContent("Links stored", value: "\(allReels.count)")
                    LabeledContent("Unwatched", value: "\(allReels.filter { !$0.isWatched }.count)")
                    LabeledContent("Saved", value: "\(allReels.filter { $0.isSaved }.count)")
                    Button("Erase All Data…", role: .destructive) {
                        isConfirmingErase = true
                    }
                    .disabled(allReels.isEmpty && pendingCount == 0)
                }

                Section {
                    LabeledContent("App Group") {
                        groupStatusLabel
                    }
                    LabeledContent("Waiting to import", value: "\(pendingCount)")
                    Button("Import Shared Links Now") {
                        router.runImport(modelContext)
                        refreshDiagnostics()
                    }
                } header: {
                    Text("Share Extension")
                } footer: {
                    Text(shareExtensionFooter)
                }

                Section("Help") {
                    NavigationLink("How to add reels") { HowToShareView() }
                    NavigationLink("What this app can and can't do") { LimitationsView() }
                }

                Section {
                    Text("No accounts, no Instagram login, no analytics, no tracking, no ads, no servers. Your links stay on this iPhone, and deleting the app deletes them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Settings")
            .task { refreshDiagnostics() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { refreshDiagnostics() }
            }
            .confirmationDialog(
                "Log out of Instagram?",
                isPresented: $isConfirmingLogout,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) { instagram.logOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes Instagram's login cookies and website data from this app. Your saved links stay.")
            }
            .confirmationDialog(
                "Erase all data?",
                isPresented: $isConfirmingErase,
                titleVisibility: .visible
            ) {
                Button("Erase Everything", role: .destructive) { eraseAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes every link, including Saved and Watched ones, and any links still waiting to import. This can't be undone.")
            }
        }
    }

    @ViewBuilder
    private var groupStatusLabel: some View {
        switch groupStatus {
        case .checking:
            ProgressView()
        case .ok:
            Label("Working", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .clipboardFallback:
            Label("Using clipboard", systemImage: "doc.on.clipboard")
                .foregroundStyle(.orange)
        case .failed(let reason):
            Label(reason, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.trailing)
        }
    }

    private var shareExtensionFooter: String {
        switch groupStatus {
        case .clipboardFallback:
            return "This copy of the app was signed without an App Group (common when sideloading with a free Apple ID). Sharing still works: the extension passes the link through the clipboard, and Reel Inbox picks it up when you open it. Open Reel Inbox right after sharing, and tap Allow Paste if asked. To skip that prompt, go to iOS Settings > Apps > Reel Inbox > Paste from Other Apps > Allow."
        default:
            let renamed = AppGroup.isRenamed ? " (renamed by the signing tool; configured: \(AppGroup.configuredIdentifier))" : ""
            return "Links you share from Instagram wait in a shared folder on this iPhone until Reel Inbox opens. App Group: \(AppGroup.identifier)\(renamed)"
        }
    }

    private func refreshDiagnostics() {
        groupStatus = AppGroupDiagnostics.check()
        pendingCount = PendingShareStore.pendingCount()
    }

    private func eraseAll() {
        do {
            try ReelRepository.deleteAll(matching: nil, in: modelContext)
            if AppGroup.containerURL != nil {
                try PendingShareStore.removeAll()
            }
        } catch {
            router.alertMessage = "Couldn't erase everything: \(error.localizedDescription)"
        }
        refreshDiagnostics()
    }
}

enum AppGroupDiagnostics {
    enum Status: Equatable {
        case checking
        case ok
        case clipboardFallback
        case failed(String)
    }

    /// Writes and removes a probe file in the shared container to prove it's usable.
    static func check() -> Status {
        guard let container = AppGroup.containerURL else {
            return .clipboardFallback
        }
        let probe = container.appendingPathComponent(".probe-\(UUID().uuidString)")
        do {
            try Data("ok".utf8).write(to: probe, options: [.atomic])
            try FileManager.default.removeItem(at: probe)
            return .ok
        } catch {
            return .failed("Not writable")
        }
    }
}
