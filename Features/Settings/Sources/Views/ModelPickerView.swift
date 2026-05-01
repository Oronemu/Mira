import SwiftUI
import AIKit
import CoreKit
import DesignSystem
import Utilities

public struct ModelPickerView: View {
    @Environment(\.aiService) private var aiService
    @Environment(\.modelDownloadCoordinator) private var coordinator
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter

    @State private var state: ModelPickerState?
    @State private var currentIndex: Int = 0
    @State private var pendingDeletionID: String?

    private let reloadService: @Sendable () async -> Void

    public init(reloadService: @escaping @Sendable () async -> Void = {}) {
        self.reloadService = reloadService
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            AmbientBackground(moodLevels: [3], intensity: 0.55)

            Group {
                if let state {
                    VStack(spacing: 0) {
                        header
                        pager(state: state)
                        pageDots(total: state.catalog.count)
                            .padding(.top, 16)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .task {
            if state == nil {
                state = ModelPickerState(
                    coordinator: coordinator,
                    analyticsService: analyticsService,
                    crashReporter: crashReporter,
                    reloadService: reloadService
                )
                if let state, let index = state.catalog.firstIndex(where: { state.isCurrent($0) }) {
                    currentIndex = index
                }
            }
            await state?.refresh()
        }
        .confirmationDialog(
            "Delete this model?",
            isPresented: deletionPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeletionID,
                   let model = state?.catalog.first(where: { $0.id == id }),
                   let state {
                    Task { await state.remove(model) }
                }
                pendingDeletionID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletionID = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("On-device model")
                .font(MiraTypography.hero)
                .foregroundStyle(MiraPalette.primaryText)
            Text("Swipe to compare · tap to pick")
                .eyebrowStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Pager

    private func pager(state: ModelPickerState) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(state.catalog.enumerated()), id: \.element.id) { index, model in
                ModelCard(
                    model: model,
                    status: state.status(of: model),
                    isCurrent: state.isCurrent(model),
                    errorMessage: state.errors[model.id],
                    onSelect: { Task { await state.select(model) } },
                    onDownload: { state.download(model) },
                    onCancelDownload: { state.cancelActiveDownload() },
                    onDeleteRequest: { pendingDeletionID = model.id }
                )
                .tag(index)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .sensoryFeedback(.selection, trigger: currentIndex)
    }

    // MARK: - Page dots

    private func pageDots(total: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { idx in
                Capsule()
                    .fill(MiraPalette.primaryText.opacity(idx == currentIndex ? 0.8 : 0.18))
                    .frame(width: idx == currentIndex ? 20 : 6, height: 6)
                    .animation(.spring(duration: 0.3, bounce: 0.2), value: currentIndex)
            }
        }
    }

    private var deletionPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletionID != nil },
            set: { if !$0 { pendingDeletionID = nil } }
        )
    }
}

// MARK: - Model card

private struct ModelCard: View {
    let model: LocalModel
    let status: ModelPickerState.ModelStatus
    let isCurrent: Bool
    let errorMessage: String?
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancelDownload: () -> Void
    let onDeleteRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heroBlock
            statsRow
            Divider().overlay(MiraPalette.primaryText.opacity(0.08))
            descriptionBlock
            highlightsBlock
            if let errorMessage {
                ErrorPill(errorMessage)
            }
            Spacer(minLength: 0)
            actionStack
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(MiraPalette.primaryText.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    // MARK: - Pieces

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("On-device").eyebrowStyle()
                Spacer()
                if isCurrent {
                    Label("In use", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MiraPalette.mood(level: 5))
                        .labelStyle(.titleAndIcon)
                }
            }
            Text(model.displayName)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            StatPill(label: "Size", value: formatBytes(model.sizeBytes), moodLevel: 2)
            StatPill(label: "RAM", value: "\(model.minimumRAMGB) GB+", moodLevel: 4)
        }
    }

    private var descriptionBlock: some View {
        // Catalog stores the English source string; route it through
        // LocalizedStringKey so it picks up the Russian translation from
        // the String Catalog instead of rendering verbatim.
        Text(LocalizedStringKey(model.description))
            .font(MiraTypography.entryBody)
            .foregroundStyle(MiraPalette.primaryText.opacity(0.88))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var highlightsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(model.highlights.enumerated()), id: \.offset) { idx, point in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(MiraPalette.mood(level: highlightColorLevel(for: idx)))
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    Text(LocalizedStringKey(point))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var actionStack: some View {
        VStack(spacing: 10) {
            if isSupported {
                primaryAction
                if isCurrent, case .ready = status {
                    Button(role: .destructive) { onDeleteRequest() } label: {
                        Text("Delete model")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                unsupportedBadge
            }
        }
    }

    private var unsupportedBadge: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.orange.opacity(0.85))
                Text("Not supported on this device")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background {
                Capsule().fill(Color.orange.opacity(0.12))
            }
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))

            Text(unsupportedReason)
                .font(.system(size: 12))
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unsupportedReason: LocalizedStringKey {
        let deviceGB = Double(DeviceMemoryProbe.physicalMemoryBytes) / 1_073_741_824.0
        let rounded = String(format: "%.1f", deviceGB)
        return "This device has \(rounded) GB of RAM. \(model.minimumRAMGB) GB are required."
    }

    private var feasibility: DeviceMemoryProbe.Feasibility {
        DeviceMemoryProbe.feasibility(
            requiredRAMGB: model.minimumRAMGB,
            weightsBytes: model.sizeBytes
        )
    }

    private var isSupported: Bool {
        if case .insufficientRAM = feasibility { return false }
        return true
    }

    // MARK: - Primary action

    @ViewBuilder
    private var primaryAction: some View {
        switch status {
        case .downloading(let fraction):
            downloadingButton(fraction: fraction)
        case .ready:
            if isCurrent {
                readyBadge
            } else {
                filledButton(
                    label: "Use \(model.displayName)",
                    systemImage: "checkmark",
                    action: onSelect
                )
            }
        case .notDownloaded:
            if isCurrent {
                filledButton(
                    label: "Download (\(formatBytes(model.sizeBytes)))",
                    systemImage: "arrow.down",
                    action: onDownload
                )
            } else {
                VStack(spacing: 8) {
                    filledButton(
                        label: "Use this model",
                        systemImage: "checkmark",
                        action: onSelect
                    )
                    Text("Download will start after selecting")
                        .eyebrowStyle()
                }
            }
        }
    }

    private func filledButton(label: LocalizedStringResource, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(MiraPalette.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            Capsule().fill(MiraPalette.mood(level: 4).opacity(0.3))
        }
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.impact(weight: .light), trigger: systemImage)
    }

    private func downloadingButton(fraction: Double) -> some View {
        Button(action: onCancelDownload) {
            HStack(spacing: 10) {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(MiraPalette.mood(level: 5))
                    .frame(maxWidth: .infinity)
                Text(String(format: "%.0f%%", fraction * 100))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.75))
                    .frame(width: 44, alignment: .trailing)
                Text("Cancel")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var readyBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MiraPalette.mood(level: 5))
            Text("Ready to use")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            Capsule().fill(MiraPalette.mood(level: 5).opacity(0.18))
        }
        .overlay(Capsule().strokeBorder(MiraPalette.mood(level: 5).opacity(0.35), lineWidth: 1))
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func highlightColorLevel(for index: Int) -> Int {
        // Cycles through the mood palette so highlight dots are varied but
        // predictable — 2 → 3 → 4 → 5 → 2 …
        [2, 3, 4, 5][index % 4]
    }
}

// MARK: - Stat pill

private struct StatPill: View {
    let label: LocalizedStringKey
    let value: String
    let moodLevel: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label).eyebrowStyle()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.88))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(MiraPalette.mood(level: moodLevel).opacity(0.18)))
    }
}
