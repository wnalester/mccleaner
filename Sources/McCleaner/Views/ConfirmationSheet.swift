import SwiftUI

struct ConfirmationSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var selections: [CleanupCategory] { appState.categoriesWithSelections }
    private var nonSafe: [CleanupCategory] { appState.nonSafeSelections }

    /// Items that don't go through Trash at all — permanent the moment you confirm.
    private var irreversibleItems: [(CleanupCategory, CleanupItem)] {
        selections.flatMap { category in
            category.selectedItems.compactMap { item -> (CleanupCategory, CleanupItem)? in
                switch item.action {
                case .trash: return nil
                default: return (category, item)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm cleanup").font(.appDisplay(.title2))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("You're about to clean:").font(.appDisplay(.headline, weight: .semibold))
                        ForEach(selections) { category in
                            HStack {
                                Circle().fill(tierColor(category.tier)).frame(width: 8, height: 8)
                                Text(category.name)
                                Spacer()
                                Text("\(category.selectedIDs.count) item(s) — \(Sizes.format(category.selectedSize))")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                        Divider()
                        HStack {
                            Text("Total").bold()
                            Spacer()
                            Text(Sizes.format(appState.totalSelectedSize)).bold().foregroundStyle(Theme.accent)
                        }
                        HStack {
                            Text("Using").foregroundStyle(.secondary)
                            Spacer()
                            Text(usingLabel).bold()
                        }
                        .font(.subheadline)
                    }
                    .cardStyle(padding: 14, corner: 12)

                    Text("Scanning and browsing always stay free — this is the only screen where anything is used or charged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !irreversibleItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("These are permanent — not moved to Trash", systemImage: "exclamationmark.octagon.fill")
                                .font(.appDisplay(.headline, weight: .semibold))
                                .foregroundStyle(.red)
                            ForEach(Array(irreversibleItems.enumerated()), id: \.offset) { _, pair in
                                Text("• \(pair.1.displayName) (\(pair.0.name))")
                                    .font(.caption)
                            }
                            Text("Everything else you selected will be moved to the Trash, so it's recoverable until you empty it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.08)))
                    }

                    if !nonSafe.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Please read before continuing", systemImage: "exclamationmark.triangle.fill")
                                .font(.appDisplay(.headline, weight: .semibold))
                                .foregroundStyle(.orange)
                            ForEach(nonSafe) { category in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name).font(.subheadline).bold()
                                    Text(category.ifYouDeleteIt).font(.caption)
                                }
                            }
                            Toggle(isOn: $appState.advancedAcknowledged) {
                                Text("I've read the above and I understand what I'm about to remove.")
                                    .font(.subheadline)
                            }
                            .toggleStyle(.checkbox)
                            .padding(.top, 4)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.08)))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Divider()
                Toggle(isOn: $appState.responsibilityAcknowledged) {
                    Text("I chose everything above myself. I understand McCleaner and its developer are not responsible for any data loss or damage from this cleanup, and that this charge is final once the cleanup runs.")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
            }

            HStack {
                Button("Cancel") { appState.phase = .results }
                Spacer()
                Button {
                    appState.beginPayment()
                } label: {
                    Text(confirmButtonLabel)
                        .font(.appDisplay(.body))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
                .buttonStyle(.gradientProminent(enabled: canConfirm))
                .disabled(!canConfirm)
            }
        }
        .padding(24)
        .frame(width: 520, height: 620)
    }

    private var entitlement: EntitlementStatus { appState.currentEntitlement }

    private var usingLabel: String {
        switch entitlement {
        case .credits(let n): return "1 of \(n) remaining credit\(n == 1 ? "" : "s")"
        case .subscriptionActive: return "Your annual plan"
        case .lifetime: return "Lifetime plan"
        case .none: return "Choose a plan next"
        }
    }

    private var confirmButtonLabel: String {
        switch entitlement {
        case .credits(let n): return "Clean Now — Uses 1 of \(n) Credit\(n == 1 ? "" : "s")"
        case .subscriptionActive: return "Clean Now — Included in Your Plan"
        case .lifetime: return "Clean Now — Included (Lifetime)"
        case .none: return "Continue — Choose a Plan"
        }
    }

    private var canConfirm: Bool {
        appState.responsibilityAcknowledged && (nonSafe.isEmpty || appState.advancedAcknowledged)
    }

    private func tierColor(_ tier: RiskTier) -> Color {
        switch tier {
        case .safe: return .green
        case .caution: return .orange
        case .advanced: return .red
        }
    }
}
