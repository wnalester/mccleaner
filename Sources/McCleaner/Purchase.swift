import Foundation

/// The five things a user can buy (or already gets for free). Prices/titles shown here are
/// what the UI displays; the actual charge amount lives in Stripe (the Payment Link), so if
/// these ever drift apart, Stripe's checkout page is the one that's actually charged.
enum CleanPlan: String, CaseIterable, Identifiable, Equatable {
    case single
    case pack5
    case annual
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return "Single Clean"
        case .pack5: return "5-Clean Pack"
        case .annual: return "Unlimited — Yearly"
        case .lifetime: return "Unlimited — Lifetime"
        }
    }

    var priceLabel: String {
        switch self {
        case .single: return "€1.99"
        case .pack5: return "€4.99"
        case .annual: return "€12.99/yr"
        case .lifetime: return "€24.99"
        }
    }

    var blurb: String {
        switch self {
        case .single: return "One cleanup, right now."
        case .pack5: return "Five cleanups, use them whenever you like — no expiry."
        case .annual: return "Unlimited cleanups for a year."
        case .lifetime: return "Unlimited cleanups, forever. Launch pricing — won't last."
        }
    }

    var badge: String? {
        switch self {
        case .annual: return "Best value"
        case .lifetime: return "Launch offer"
        default: return nil
        }
    }

    /// A Stripe Payment Link for this plan. Create one per plan in the Stripe Dashboard
    /// (Product → matching price → Payment Link) and replace each REPLACE_ME — see
    /// ~/Projects/McCleanerPaymentBackend/README.md for the full walkthrough, including which
    /// price ID env var on the backend has to match which plan.
    ///
    var paymentLinkURL: URL {
        switch self {
        case .single: return URL(string: "https://buy.stripe.com/3cI14n5h15WUb2Q7XO63K00")!
        case .pack5: return URL(string: "https://buy.stripe.com/4gM00j9xhadaef27XO63K01")!
        case .annual: return URL(string: "https://buy.stripe.com/aFa28r9xhdpm8UI7XO63K04")!
        case .lifetime: return URL(string: "https://buy.stripe.com/fZu4gz10Lclifj6a5W63K03")!
        }
    }
}

enum PurchaseConfig {
    /// Base URL of the deployed verification backend (~/Projects/McCleanerPaymentBackend).
    static let verifyBaseURL = URL(string: "https://api.mccleaner.tech")!
}

enum PurchaseVerificationResult {
    case verified(plan: CleanPlan, subscriptionID: String?, subscriptionActiveUntil: Date?)
    case notPaid
    case alreadyRedeemed
    case wrongItem
    case networkError(String)

    var userMessage: String {
        switch self {
        case .verified: return ""
        case .notPaid: return "That payment hasn't gone through yet. If you completed checkout, wait a moment and try again."
        case .alreadyRedeemed: return "That payment was already used."
        case .wrongItem: return "That doesn't look like a payment for an McCleaner plan."
        case .networkError(let message): return "Couldn't verify the payment (\(message)). Check your connection and try again."
        }
    }
}

enum SubscriptionCheckResult {
    case active(until: Date)
    case inactive
    case networkError(String)
}

/// Talks to the verification backend so the app never has to hold a Stripe secret key
/// itself — that key only ever lives server-side.
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
        if (obj["ok"] as? Bool) == true {
            guard let planRaw = obj["plan"] as? String, let plan = CleanPlan(rawValue: planRaw) else {
                return .networkError("server returned an unrecognized plan")
            }
            let subID = obj["subscriptionId"] as? String
            var until: Date? = nil
            if let epoch = obj["currentPeriodEnd"] as? NSNumber {
                until = Date(timeIntervalSince1970: epoch.doubleValue)
            }
            return .verified(plan: plan, subscriptionID: subID, subscriptionActiveUntil: until)
        }
        switch obj["error"] as? String {
        case "already_redeemed": return .alreadyRedeemed
        case "unexpected_price": return .wrongItem
        default: return .notPaid
        }
    }

    /// Re-checks an existing subscription's status — used when our locally-cached expiry
    /// date has passed, to distinguish "renewed" (new, later date) from "actually canceled."
    static func checkSubscription(subscriptionID: String) async -> SubscriptionCheckResult {
        var request = URLRequest(url: PurchaseConfig.verifyBaseURL.appendingPathComponent("api/check-subscription"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["subscription_id": subscriptionID])
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
        let active = (obj["active"] as? Bool) ?? false
        if active, let epoch = obj["currentPeriodEnd"] as? NSNumber {
            return .active(until: Date(timeIntervalSince1970: epoch.doubleValue))
        }
        return .inactive
    }
}
