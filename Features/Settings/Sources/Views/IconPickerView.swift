import SwiftUI
import UIKit
import CoreKit
import DesignSystem
import Utilities

/// Lets the user switch between the app's primary icon and its Pro
/// alternates. Reads the current selection from
/// `UIApplication.alternateIconName` so launching the screen always
/// reflects the system truth — no separate persistence.
public struct IconPickerView: View {
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter

    @State private var status: SubscriptionStatus = .unknown
    @State private var current: AppIconOption = .default
    @State private var pendingFailure: String?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3], intensity: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsHero(
                        title: "App icon",
                        subtitle: "Pick the look that fits your home screen"
                    )

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AppIconOption.allCases, id: \.self) { option in
                            IconCell(
                                option: option,
                                isSelected: option == current,
                                showsProBadge: option.isPro && !status.isPro
                            ) { tap(option) }
                        }
                    }

                    if let pendingFailure {
                        ErrorPill(pendingFailure)
                    }

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .collapsibleHeroTitle("App icon")
        .task {
            current = AppIconOption.from(
                alternateIconName: UIApplication.shared.alternateIconName
            )
            status = await subscriptionService.status
            for await snapshot in subscriptionService.statusUpdates {
                status = snapshot
            }
        }
    }

    private func tap(_ option: AppIconOption) {
        guard option != current else { return }
        if option.isPro && !status.isPro {
            paywallPresenter.present(.feature(.themesAndIcons))
            return
        }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
                current = option
                pendingFailure = nil
            } catch {
                pendingFailure = error.localizedDescription
            }
        }
    }
}

// MARK: - Cell

private struct IconCell: View {
    let option: AppIconOption
    let isSelected: Bool
    let showsProBadge: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    iconImage
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? MiraPalette.primaryText.opacity(0.85)
                                        : MiraPalette.primaryText.opacity(0.08),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        )

                    if showsProBadge {
                        ProBadge()
                            .scaleEffect(0.75)
                            .offset(x: 8, y: -8)
                    }
                }

                Text(option.displayName)
                    .font(MiraTypography.caption)
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    @ViewBuilder
    private var iconImage: some View {
        // `IconPreview-*` are dedicated Image Sets duplicated from each
        // .appiconset specifically so `UIImage(named:)` can find them —
        // the compiled `AppIcon-*` alternates aren't reachable this way.
        if let ui = UIImage(named: option.previewAssetName) {
            Image(uiImage: ui).resizable()
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MiraPalette.secondaryBackground)
                .overlay(
                    Image(systemName: "app.dashed")
                        .font(.system(size: 28))
                        .foregroundStyle(MiraPalette.secondaryText)
                )
        }
    }
}

private extension AppIconOption {
    var displayName: LocalizedStringKey {
        switch self {
        case .default: return "Default"
        case .neon:    return "Neon"
        case .rainy:   return "Rainy"
        case .stars:   return "Stars"
        case .sea:     return "Sea"
        }
    }
}
