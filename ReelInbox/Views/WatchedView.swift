import SwiftData
import SwiftUI

/// Links you've already watched.
struct WatchedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchRouter.self) private var router

    @Query(
        filter: #Predicate<Reel> { $0.isWatched == true },
        sort: \Reel.dateReceived,
        order: .reverse
    )
    private var reels: [Reel]

    @State private var isConfirmingDelete = false

    private var deletableCount: Int {
        reels.filter { !$0.isSaved }.count
    }

    var body: some View {
        NavigationStack {
            ReelListView(
                reels: reels,
                emptyState: EmptyStateContent(
                    title: "Nothing watched yet",
                    systemImage: "checkmark.circle",
                    message: "Links move here after you watch them or mark them as watched."
                )
            )
            .navigationTitle("Watched")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Watched", systemImage: "trash")
                    }
                    .disabled(deletableCount == 0)
                }
            }
            .confirmationDialog(
                "Delete \(deletableCount) watched \(deletableCount == 1 ? "link" : "links")?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Watched", role: .destructive) {
                    do {
                        try ReelRepository.deleteAll(matching: ReelRepository.watchedUnsaved, in: modelContext)
                    } catch {
                        router.alertMessage = "Couldn't delete: \(error.localizedDescription)"
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Saved links are kept. This can't be undone.")
            }
        }
    }
}
