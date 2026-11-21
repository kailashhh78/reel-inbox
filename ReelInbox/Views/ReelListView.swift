import SwiftData
import SwiftUI

struct EmptyStateContent {
    let title: String
    let systemImage: String
    let message: String
}

/// A finite list of cards. No pagination, no infinite scroll, no autoplay.
struct ReelListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchRouter.self) private var router

    let reels: [Reel]
    let emptyState: EmptyStateContent

    var body: some View {
        Group {
            if reels.isEmpty {
                ContentUnavailableView(
                    emptyState.title,
                    systemImage: emptyState.systemImage,
                    description: Text(emptyState.message)
                )
            } else {
                List {
                    ForEach(reels) { reel in
                        ReelCard(reel: reel)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(reel)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    reel.setWatched(!reel.isWatched)
                                    router.save(modelContext)
                                } label: {
                                    Label(
                                        reel.isWatched ? "Unwatched" : "Watched",
                                        systemImage: reel.isWatched ? "arrow.uturn.backward" : "checkmark"
                                    )
                                }
                                .tint(Color.accentColor)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func delete(_ reel: Reel) {
        do {
            try ReelRepository.delete(reel, in: modelContext)
        } catch {
            router.alertMessage = "Couldn't delete: \(error.localizedDescription)"
        }
    }
}
