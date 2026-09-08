import SwiftUI

/// Shown when the user has no usable entitlement (no credits, no active plan). Lets them
/// buy one of the four paid options.
struct PlanPickerView: View {
    @EnvironmentObject var appState: AppState
    let paymentError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AppLogoImage(size: 64)

                VStack(spacing: 8) {
                    Text("Choose a plan").font(.appDisplay(.title2))
                    Text("Pick whichever fits how often you clean up.")
                        .font(.appBody(.body))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                }

                if let paymentError {
                    Label(paymentError, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                        .padding(12)
                        .frame(maxWidth: 480, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.1)))
                }

                VStack(spacing: 12) {
                    ForEach(CleanPlan.allCases) { plan in
                        planCard(plan)
                    }
                }
                .frame(maxWidth: 480)

                Text("Opens Stripe's secure checkout in your browser. You'll be brought back here automatically once it's done.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                Button("Cancel") { appState.phase = .results }
                    .padding(.top, 4)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func planCard(_ plan: CleanPlan) -> some View {
        Button {
            appState.openPaymentLink(for: plan)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title).font(.appDisplay(.headline, weight: .semibold))
                        if let badge = plan.badge {
                            Text(badge.uppercased())
                                .font(.appDisplay(.caption2))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.accent.opacity(0.15)))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    Text(plan.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Text(plan.priceLabel)
                    .font(.appDisplay(.title3))
                    .foregroundStyle(Theme.accent)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

struct VerifyingPaymentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(Theme.accent)
            Text("Confirming your payment…")
                .font(.appDisplay(.title2))
            Text("This only takes a moment.")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
