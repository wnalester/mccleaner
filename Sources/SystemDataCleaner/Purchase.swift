import Foundation

/// Fill these in once the Stripe side and the verification backend are deployed. Nothing
/// else in the payment flow needs to change — every other file reads through these two
/// constants.
enum PurchaseConfig {
    /// A Stripe Payment Link for a single one-time €1.99 charge. Create it in the Stripe
    /// Dashboard: Product "SDC Cleanup" → one-time price €1.99 → Payment Link. Set that
    /// Payment Link's "After payment" confirmation to redirect to:
    ///   <verifyBaseURL>/thanks?session_id={CHECKOUT_SESSION_ID}
    static let paymentLinkURL = URL(string: "https://buy.stripe.com/REPLACE_ME")!

    /// Base URL of the deployed verification backend (~/Projects/SDCPaymentBackend — a tiny
    /// Vercel serverless function, already deployed). It safely refuses every request until
    /// STRIPE_SECRET_KEY is set in the Vercel project's environment variables — see that
    /// project's README.md for the full Stripe + Vercel setup steps.
    static let verifyBaseURL = URL(string: "https://sdc-payment-backend.vercel.app")!

    static let priceLabel = "€1.99"
}

enum PurchaseVerificationResult {
    case verified
    case notPaid
    case alreadyRedeemed
    case wrongItem
    case networkError(String)

    var userMessage: String {
        switch self {
        case .verified: return ""
        case .notPaid: return "That payment hasn't gone through yet. If you completed checkout, wait a moment and try again."
        case .alreadyRedeemed: return "That payment was already used for an earlier cleanup — each €1.99 charge covers one cleanup run."
        case .wrongItem: return "That doesn't look like a payment for an SDC cleanup."
        case .networkError(let message): return "Couldn't verify the payment (\(message)). Check your connection and try again."
        }
    }
}

/// Talks to the verification backend so the app never has to hold a Stripe secret key
/// itself — that key only ever lives server-side. See PaymentBackend/api/verify-session.js.
enum PurchaseVerifier {
    static func verify(sessionID: String) async -> PurchaseVerificationResult {
        var request = URLRequest(url: PurchaseConfig.verifyBaseURL.appendingPathComponent("api/verify-session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["session_id": sessionID])
        request.timeoutInterval = 20

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            return .networkError(error.localizedDescription)
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .networkError("unreadable response from server")
        }
        if (obj["ok"] as? Bool) == true { return .verified }
        switch obj["error"] as? String {
        case "already_redeemed": return .alreadyRedeemed
        case "unexpected_price": return .wrongItem
        default: return .notPaid
        }
    }
}
