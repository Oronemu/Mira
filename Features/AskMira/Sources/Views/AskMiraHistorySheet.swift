import SwiftUI
import CoreKit
import DesignSystem

/// Chat history sheet shown from the trailing toolbar button on the
/// AskMira screen. Lists past conversations newest-first and lets the
/// user open, rename, or delete them. A "New chat" shortcut in the
/// top-right resets the active conversation.
///
/// A selection mode (mirroring the journal's bulk-delete) lets the user
/// tick several chats and remove them in one confirmed action.
public struct AskMiraHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    private let chats: [AskMiraChatSnapshot]
    private let activeChatID: UUID?
    private let onOpen: (UUID) -> Void
    private let onNewChat: () -> Void
    private let onDelete: (UUID) -> Void
    private let onDeleteChats: (Set<UUID>) -> Void
    private let onRename: (UUID, String) -> Void

    @State private var renameTarget: AskMiraChatSnapshot?
    @State private var renameDraft: String = ""
    @State private var pendingDeletion: AskMiraChatSnapshot?
    @State private var isSelectionMode = false
    @State private var selection: Set<UUID> = []
    @State private var showBulkDeleteConfirm = false

    public init(
        chats: [AskMiraChatSnapshot],
        activeChatID: UUID?,
        onOpen: @escaping (UUID) -> Void,
        onNewChat: @escaping () -> Void,
        onDelete: @escaping (UUID) -> Void,
        onDeleteChats: @escaping (Set<UUID>) -> Void,
        onRename: @escaping (UUID, String) -> Void
    ) {
        self.chats = chats
        self.activeChatID = activeChatID
        self.onOpen = onOpen
        self.onNewChat = onNewChat
        self.onDelete = onDelete
        self.onDeleteChats = onDeleteChats
        self.onRename = onRename
    }

    public var body: some View {
        MiraSheetChrome(moodLevels: [3, 4], intensity: 0.4) {
            NavigationStack {
                content
                    .navigationTitle(navigationTitle)
                    .toolbarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar { toolbarContent }
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
        .confirmationDialog(
            bulkDeleteTitle,
            isPresented: $showBulkDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                onDeleteChats(selection)
                exitSelection()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private var navigationTitle: Text {
        if isSelectionMode {
            return selection.isEmpty
                ? Text("Select chats")
                : Text("\(selection.count) selected")
        }
        return Text("Chats")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelectionMode {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Cancel")) {
                    exitSelection()
                }
                .foregroundStyle(MiraPalette.primaryText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if allSelected {
                        selection.removeAll()
                    } else {
                        selection = Set(chats.map(\.id))
                    }
                } label: {
                    Text(allSelected ? "Deselect All" : "Select All")
                        .foregroundStyle(MiraPalette.primaryText)
                }
            }

            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showBulkDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(selection.isEmpty ? MiraPalette.secondaryText.opacity(0.5) : Color.red)
                }
                .buttonStyle(.plain)
                .disabled(selection.isEmpty)
                .accessibilityLabel(Text("Delete selected"))
            }
        } else {
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

    private var allSelected: Bool {
        !chats.isEmpty && selection.count == chats.count
    }

    private var bulkDeleteTitle: Text {
        selection.count > 1
            ? Text("Delete selected chats?")
            : Text("Delete chat?")
    }

    private func exitSelection() {
        isSelectionMode = false
        selection.removeAll()
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    // MARK: - Content

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
                            isSelectionMode: isSelectionMode,
                            isSelected: selection.contains(chat.id),
                            onOpen: {
                                if isSelectionMode {
                                    toggle(chat.id)
                                } else {
                                    onOpen(chat.id)
                                    dismiss()
                                }
                            },
                            onEnterSelection: {
                                isSelectionMode = true
                                selection.insert(chat.id)
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
                .animation(.spring(duration: 0.25), value: isSelectionMode)
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
    let isSelectionMode: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onEnterSelection: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                if isSelectionMode {
                    checkbox
                        .padding(.top, 2)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    accent
                }
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
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                if isSelectionMode && isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MiraPalette.mood(level: 4), lineWidth: 1.5)
                }
            }
            .animation(.spring(duration: 0.25), value: isSelectionMode)
            .animation(.spring(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PressableCardStyle())
        .contextMenu {
            if !isSelectionMode {
                Button {
                    onEnterSelection()
                } label: {
                    Label(String(localized: "Select"), systemImage: "checkmark.circle")
                }
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
    }

    private var checkbox: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isSelected ? MiraPalette.mood(level: 4) : MiraPalette.secondaryText)
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
