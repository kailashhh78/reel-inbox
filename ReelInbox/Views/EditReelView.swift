import SwiftData
import SwiftUI

struct EditReelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchRouter.self) private var router

    @Bindable var reel: Reel

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    Text(reel.displayLink)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Section("From") {
                    TextField("Friend's name", text: $reel.sender)
                        .textInputAutocapitalization(.words)
                }
                Section("Note") {
                    TextField("Note", text: $reel.note, axis: .vertical)
                        .lineLimit(1...6)
                }
                Section {
                    Toggle("Saved", isOn: $reel.isSaved)
                    Toggle("Watched", isOn: Binding(
                        get: { reel.isWatched },
                        set: { reel.setWatched($0) }
                    ))
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        reel.sender = reel.sender.trimmingCharacters(in: .whitespacesAndNewlines)
                        reel.note = reel.note.trimmingCharacters(in: .whitespacesAndNewlines)
                        router.save(modelContext)
                        dismiss()
                    }
                }
            }
        }
    }
}
