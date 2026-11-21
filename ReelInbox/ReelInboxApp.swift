import SwiftData
import SwiftUI

@main
struct ReelInboxApp: App {
    private let containerResult: Result<ModelContainer, Error>

    init() {
        do {
            // Stored in the app's own private container on this device. No iCloud, no server.
            // `groupContainer: .none` keeps the database out of the shared App Group.
            // The Share Extension never opens it. It hands links over through PendingShareStore.
            let configuration = ModelConfiguration(
                "ReelInbox",
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: Reel.self, configurations: configuration)
            containerResult = .success(container)
        } catch {
            containerResult = .failure(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure(let error):
                StartupErrorView(error: error)
            }
        }
    }
}

private struct StartupErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't open your library", systemImage: "exclamationmark.triangle")
        } description: {
            Text("The local database failed to load: \(error.localizedDescription)\n\nTry restarting the app. If it keeps happening, delete and reinstall the app (this erases saved links).")
        }
    }
}
