import SwiftUI
import DesignSystem

/// Sheet for entering a developer-issued grant code. Validation runs through
/// `SubscriptionService.redeem` — when it succeeds the upstream paywall
/// state flips to Pro and the parent dismisses.
struct RedeemCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var state: PaywallState

    @State private var code: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Code"), text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.go)
                        .onSubmit { Task { await submit() } }
                } header: {
                    Text(String(localized: "Have a code?"))
                } footer: {
                    Text(String(localized: "Codes are issued for testing, beta access, or as gifts. Each code can only be redeemed once."))
                }

                if let message = state.errorMessage {
                    Section {
                        Text(message)
                            .font(MiraTypography.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "Redeem a code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Redeem")) {
                        Task { await submit() }
                    }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isRedeeming)
                }
            }
            .task { isFocused = true }
            .onChange(of: state.didUnlockPro) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }

    private func submit() async {
        await state.redeem(code: code)
    }
}
