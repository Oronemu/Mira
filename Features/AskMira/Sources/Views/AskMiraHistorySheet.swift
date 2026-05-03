import SwiftUI
import CoreKit
import DesignSystem

/// Chat history sheet shown from the trailing toolbar button on the
/// AskMira screen. Lists past conversations newest-first and lets the
/// user open, rename, or delete them. A "New chat" shortcut in the
/// top-right resets the active conversation.
public struct AskMiraHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    private let chats: [AskMiraChatSnapshot]
    private let activeChatID: UUID?
    private let onOpen: (UUID) -> Void
    private let onNewChat: () -> Void
    private let onDelete: (UUID) -> Void
    private let onRename: (UUID, String) -> Void

    @State private var renameTarget: AskMiraChatSnapshot?
    @State private var renameDraft: String = ""
    @State private var pendingDeletion: AskMiraChatSnapshot?

    public init(
        chats: [AskMiraChatSnapshot],
        activeChatID: UUID?,
        onOpen: @escaping (UUID) -> Void,
        onNewChat: @escaping () -> Void,
        onDelete: @escaping (UUID) -> Void,
        onRename: @escaping (UUID, String) -> Void
    ) {
        self.chats = chats
        self.activeChatID = activeChatID
        self.onOpen = onOpen
        self.onNewChat = onNewChat
        self.onDelete = onDelete
        self.onRename = onRename
    }

    public var body: some View {
        MiraSheetChrome(moodLevels: [3, 4], intensity: 0.4) {
            NavigationStack {
                content
                    .navigationTitle(Text("Chats"))
                    .toolbarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(MiraPalette.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Close"))
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                onNewChat()
                                dismiss()
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("New chat"))
                        }
                    }
            }
        }
        .miraSheet([.large])
        .alert(
            Text("Rename chat"),
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )
        ) {
            TextField(String(localized: "Title"), text: $renameDraft)
            Button(String(localized: "Save")) {
                if let target = renameTarget {
                    onRename(target.id, renameDraft)
                }
                renameTarget = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                renameTarget = nil
            }
        }
        .confirmationDialog(
            Text("Delete chat?"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                if let target = pendingDeletion {
                    onDelete(target.id)
                }
                pendingDeletion = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("This conversation will be permanently removed.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if chats.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(chats) { chat in
                        ChatRow(
                            chat: chat,
                            isActive: chat.id == activeChatID,
                            onOpen: {
                                onOpen(chat.id)
                                dismiss()
                            },
                            onRename: {
                                renameDraft = chat.title
                                renameTarget = chat
                            },
                            onDelete: {
                                pendingDeletion = chat
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(MiraPalette.secondaryText)
            Text("No conversations yet")
                .font(MiraTypography.headline)
                .foregroundStyle(MiraPalette.primaryText)
            Text("Start asking to begin a new chat.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct ChatRow: View {
    let chat: AskMiraChatSnapshot
    let isActive: Bool
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                accent
                VStack(alignment: .leading, spacing: 4) {
                    Text(chat.title)
                        .font(.system(.body, design: .serif).weight(.medium))
                        .foregroundStyle(MiraPalette.primaryText)
                        .lineLimit(1)

                    if let preview = chat.lastMessagePreview, !preview.isEmpty {
                        Text(preview)
                            .font(.system(size: 13))
                            .foregroundStyle(MiraPalette.secondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                Text(dateLabel(for: chat.updatedAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label(String(localized: "Rename"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var accent: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(isActive ? MiraPalette.mood(level: 4) : Color.clear)
            .frame(width: 3)
    }

    private func dateLabel(for date: Date) -> String {
        let now = Date()
        // Guard against chats whose updatedAt lands a few ms in the future
        // due to write/read races — RelativeDateTimeFormatter renders those
        // as "-5 мин" in Russian abbreviated style.
        let effective = min(date, now)
        let delta = now.timeIntervalSince(effective)
        if delta < 7 * 24 * 3600 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: effective, relativeTo: now)
        } else {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            df.locale = .autoupdatingCurrent
            return df.string(from: effective)
        }
    }
}
