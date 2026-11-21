import SwiftData
import SwiftUI

/// Manual fallback: paste a link you copied from Instagram ("Copy link").
struct AddReelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var linkText = ""
    @State private var sender = ""
    @State private var note = ""
    @State private var errorMessage: String?

    private var detectedLink: InstagramLink? {
        InstagramLink.firstLink(in: linkText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://www.instagram.com/reel/…", text: $linkText, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1...4)

                    // PasteButton reads the clipboard only when you tap it,
                    // so iOS doesn't show a "Allow Paste" prompt.
                    PasteButton(payloadType: String.self) { strings in
                        guard let first = strings.first else { return }
                        Task { @MainActor in
                            linkText = first
                        }
                    }
                } header: {
                    Text("Instagram link")
                } footer: {
                    validationFooter
                }

                Section("From (optional)") {
                    TextField("Friend's name", text: $sender)
                        .textInputAutocapitalization(.words)
                }

                Section("Note (optional)") {
                    TextField("Why they sent it", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(detectedLink == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var validationFooter: some View {
        if linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("In Instagram, tap Share, then Copy link. Then paste it here.")
        } else if let link = detectedLink {
            Text("Detected \(link.kind.displayName.lowercased()): \(link.displayString)")
        } else {
            Text("This isn't an Instagram reel or post link.")
                .foregroundStyle(.red)
        }
    }

    private func add() {
        guard let link = detectedLink else { return }
        do {
            try ReelRepository.upsert(link: link, sender: sender, note: note, date: .now, in: modelContext)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
