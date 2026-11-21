import SwiftUI

struct ShareView: View {
    @ObservedObject var model: ShareViewModel
    @FocusState private var senderFocused: Bool

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Reel Inbox")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { model.cancel() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { model.save() }
                            .disabled(!model.canSave)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView("Reading link…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready(let link):
            Form {
                Section(link.kind.displayName) {
                    Text(link.displayString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Section("From (optional)") {
                    TextField("Friend's name", text: $model.sender)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($senderFocused)
                        .onSubmit { model.save() }
                }
                Section("Note (optional)") {
                    TextField("Why they sent it", text: $model.note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .onAppear { senderFocused = true }

        case .invalid:
            ContentUnavailableView {
                Label("Not an Instagram link", systemImage: "link")
            } description: {
                Text("Reel Inbox only saves instagram.com reel and post links. In Instagram, open the reel, tap Share, then choose Reel Inbox.")
            } actions: {
                Button("Close") { model.cancel() }
                    .buttonStyle(.bordered)
            }

        case .saved(let viaClipboard):
            if viaClipboard {
                ContentUnavailableView(
                    "Almost saved",
                    systemImage: "doc.on.clipboard",
                    description: Text("Open Reel Inbox next to add it to your Inbox, and tap Allow Paste if asked. Don't copy anything else first.")
                )
            } else {
                ContentUnavailableView(
                    "Saved to Inbox",
                    systemImage: "checkmark.circle",
                    description: Text("Open Reel Inbox when you're ready to watch it.")
                )
            }

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't save", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Close") { model.cancel() }
                    .buttonStyle(.bordered)
            }
        }
    }
}
