import SwiftData
import SwiftUI

/// Home screen: links you haven't watched yet, newest first.
struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchRouter.self) private var router

    @Query(
        filter: #Predicate<Reel> { $0.isWatched == false },
        sort: \Reel.dateReceived,
        order: .reverse
    )
    private var reels: [Reel]

    @State private var isAdding = false
    @State private var isConfirmingClear = false

    private var clearableCount: Int {
        reels.filter { !$0.isSaved }.count
    }

    var body: some View {
        NavigationStack {
            ReelListView(
                reels: reels,
                emptyState: EmptyStateContent(
                    title: "Inbox is empty",
                    systemImage: "tray",
                    message: "When a friend sends you a reel, open it in Instagram, tap Share, then choose Reel Inbox. You can also tap + to paste a link."
                )
            )
            .safeAreaInset(edge: .top, spacing: 0) {
                if let message = router.importErrorMessage {
                    ImportErrorBanner(message: message) {
                        router.runImport(modelContext)
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add Link", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Mark All as Watched", systemImage: "checkmark.circle") {
                            for reel in reels { reel.setWatched(true) }
                            router.save(modelContext)
                        }
                        .disabled(reels.isEmpty)

                        Button("Clear Inbox…", systemImage: "trash", role: .destructive) {
                            isConfirmingClear = true
                        }
                        .disabled(clearableCount == 0)
                    } label: {
                        Label("Inbox Options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "Delete \(clearableCount) unwatched \(clearableCount == 1 ? "link" : "links")?",
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear Inbox", role: .destructive) {
                    do {
                        try ReelRepository.deleteAll(matching: ReelRepository.unwatchedUnsaved, in: modelContext)
                    } catch {
                        router.alertMessage = "Couldn't clear the inbox: \(error.localizedDescription)"
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Links you've marked as Saved are kept. This can't be undone.")
            }
            .sheet(isPresented: $isAdding) {
                AddReelView()
            }
        }
    }
}

private struct ImportErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Shared links couldn't be imported")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try Again", action: retry)
                    .font(.footnote.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background)
    }
}
