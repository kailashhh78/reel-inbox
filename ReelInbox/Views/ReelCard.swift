import SwiftData
import SwiftUI
import UIKit

/// One saved link: sender, link, date, status, Watch and Delete buttons.
struct ReelCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchRouter.self) private var router
    @AppStorage(SettingsKey.loadPreviews) private var loadPreviews = false

    let reel: Reel
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        StatusBadge(isWatched: reel.isWatched)
                        Text(reel.kind.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        if reel.isSaved {
                            Image(systemName: "bookmark.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Saved")
                        }
                    }

                    Text(reel.sender.isEmpty ? "Unknown sender" : "From \(reel.sender)")
                        .font(.headline)
                        .foregroundStyle(reel.sender.isEmpty ? Color.secondary : Color.primary)

                    Text(reel.displayLink)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    if let title = reel.previewTitle, !title.isEmpty {
                        Text(title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if !reel.note.isEmpty {
                        Text(reel.note)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }

                    Text("Received \(reel.dateReceived.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                moreMenu
            }

            HStack(spacing: 8) {
                Button {
                    router.watch(reel, in: modelContext)
                } label: {
                    Label("Watch", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    reel.setWatched(!reel.isWatched)
                    router.save(modelContext)
                } label: {
                    Label(
                        reel.isWatched ? "Unwatched" : "Watched",
                        systemImage: reel.isWatched ? "arrow.uturn.backward" : "checkmark"
                    )
                    .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .tint(Color.primary)
                .accessibilityLabel(reel.isWatched ? "Mark as unwatched" : "Mark as watched")

                Button(role: .destructive) {
                    delete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Delete")
            }
            .font(.subheadline.weight(.semibold))
        }
        .cardStyle()
        .sheet(isPresented: $isEditing) {
            EditReelView(reel: reel)
        }
        .task(id: loadPreviews) {
            if loadPreviews {
                await LinkPreviewService.fetchPreviewIfNeeded(for: reel, context: modelContext)
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if loadPreviews, let data = reel.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
                .accessibilityHidden(true)
        }
    }

    private var moreMenu: some View {
        Menu {
            Button {
                reel.isSaved.toggle()
                router.save(modelContext)
            } label: {
                Label(reel.isSaved ? "Remove from Saved" : "Save", systemImage: reel.isSaved ? "bookmark.slash" : "bookmark")
            }
            Button {
                isEditing = true
            } label: {
                Label("Edit Sender & Note", systemImage: "pencil")
            }
            Button {
                UIPasteboard.general.string = reel.canonicalURL
            } label: {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                delete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("More actions")
    }

    private func delete() {
        do {
            try ReelRepository.delete(reel, in: modelContext)
        } catch {
            router.alertMessage = "Couldn't delete: \(error.localizedDescription)"
        }
    }
}

struct StatusBadge: View {
    let isWatched: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isWatched ? Color.secondary.opacity(0.5) : Color.accentColor)
                .frame(width: 7, height: 7)
            Text(isWatched ? "Watched" : "Unwatched")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isWatched ? Color.secondary : Color.accentColor)
        }
        .accessibilityElement(children: .combine)
    }
}
