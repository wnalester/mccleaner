import Foundation

enum EntitlementStatus: Equatable {
    case credits(remaining: Int)
    case subscriptionActive(until: Date)
    case lifetime
    case none
}

/// What paid for the cleanup that's about to run (or already ran) — captured right before
/// consuming, so DoneView can say something accurate afterward instead of a hardcoded price.
enum CleanBillingSummary: Equatable {
    case usedCredit(remainingAfter: Int)
    case subscription
    case lifetime
    case purchased(CleanPlan)
}

/// All local purchase/entitlement state, backed by UserDefaults. There's no account system —
/// this Mac's UserDefaults *is* the record. That's an accepted, standard tradeoff for a
/// no-login indie utility: a determined user could reset it by reinstalling, but that only
/// ever costs them value (losing unused credits), never grants extra value, so it isn't
/// something worth defending against here.
enum Entitlements {
    private static let defaults = UserDefaults.standard

    static var cleanCredits: Int {
        get { defaults.integer(forKey: "sdc_cleanCredits") }
        set { defaults.set(newValue, forKey: "sdc_cleanCredits") }
    }

    static var hasLifetimeAccess: Bool {
        get { defaults.bool(forKey: "sdc_hasLifetimeAccess") }
        set { defaults.set(newValue, forKey: "sdc_hasLifetimeAccess") }
    }

    static var subscriptionId: String? {
        get { defaults.string(forKey: "sdc_subscriptionId") }
        set { defaults.set(newValue, forKey: "sdc_subscriptionId") }
    }

    static var subscriptionActiveUntil: Date? {
        get { defaults.object(forKey: "sdc_subscriptionActiveUntil") as? Date }
        set { defaults.set(newValue, forKey: "sdc_subscriptionActiveUntil") }
    }

    /// What's currently usable, checked in priority order: a paid unlimited plan beats a credit.
    static func status() -> EntitlementStatus {
        #if QA_BUILD
        return .lifetime
        #else
        if hasLifetimeAccess { return .lifetime }
        if let until = subscriptionActiveUntil, until > Date() { return .subscriptionActive(until: until) }
        if cleanCredits > 0 { return .credits(remaining: cleanCredits) }
        return .none
        #endif
    }

    /// If we have a subscription on file but its cached expiry has passed, check with Stripe
    /// once before treating it as lapsed — it may simply have renewed and we just haven't
    /// heard about the new period yet. No-op (and no network call) in the common case where
    /// the cached expiry is still comfortably in the future.
    static func refreshSubscriptionIfNeeded() async {
        guard let subID = subscriptionId else { return }
        if let until = subscriptionActiveUntil, until > Date() { return }
        switch await PurchaseVerifier.checkSubscription(subscriptionID: subID) {
        case .active(let until):
            subscriptionActiveUntil = until
        case .inactive:
            subscriptionActiveUntil = nil
            subscriptionId = nil
        case .networkError:
            break // leave cached state as-is; try again next time
        }
    }

    /// Consumes exactly one unit of whatever is currently active. Call this once, right when
    /// a clean is actually about to run — never speculatively.
    static func consumeOne() {
        if hasLifetimeAccess { return }
        if let until = subscriptionActiveUntil, until > Date() { return }
        if cleanCredits > 0 { cleanCredits -= 1 }
    }

    /// Grants access after a verified Stripe payment.
    static func grant(plan: CleanPlan, subscriptionID: String?, subscriptionActiveUntilDate: Date?) {
        switch plan {
        case .single: cleanCredits += 1
        case .pack5: cleanCredits += 5
        case .lifetime: hasLifetimeAccess = true
        case .annual:
            subscriptionId = subscriptionID
            subscriptionActiveUntil = subscriptionActiveUntilDate
        }
    }
}
