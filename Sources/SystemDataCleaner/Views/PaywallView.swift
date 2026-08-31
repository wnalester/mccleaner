import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    let paymentError: String?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            AppLogoImage(size: 72)

            VStack(spacing: 8) {
                Text("One more step").font(.system(.title2, design: .rounded)).bold()
                Text("Cleaning up \(Sizes.format(appState.totalSelectedSize)) costs \(PurchaseConfig.priceLabel), charged once for this cleanup run.")
                    .font(.body)
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
                    .frame(maxWidth: 440, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.1)))
            }

            VStack(spacing: 10) {
                Button {
                    appState.openPaymentLink()
                } label: {
                    Text("Pay \(PurchaseConfig.priceLabel) with Stripe")
                        .font(.system(.headline, design: .rounded))
                        .padding(.horizontal, 20).padding(.vertical, 10)
                }
                .buttonStyle(.gradientProminent())

                Text("Opens Stripe's secure checkout in your browser. You'll be brought back here automatically once it's done.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button("Cancel") { appState.phase = .results }
                .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
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
                .font(.system(.title2, design: .rounded)).bold()
            Text("This only takes a moment.")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
