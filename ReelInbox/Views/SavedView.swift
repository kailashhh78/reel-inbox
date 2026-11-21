import SwiftData
import SwiftUI

/// Links you chose to keep, watched or not.
struct SavedView: View {
    @Query(
        filter: #Predicate<Reel> { $0.isSaved == true },
        sort: \Reel.dateReceived,
        order: .reverse
    )
    private var reels: [Reel]

    var body: some View {
        NavigationStack {
            ReelListView(
                reels: reels,
                emptyState: EmptyStateContent(
                    title: "Nothing saved",
                    systemImage: "bookmark",
                    message: "Tap ••• on any link and choose Save to keep it here. Saved links aren't removed when you clear the inbox or delete watched links."
                )
            )
            .navigationTitle("Saved")
        }
    }
}
