import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = Legal.hasAcceptedCurrentTerms ? .welcome : .termsGate
    @Published var categories: [CleanupCategory] = CategoryDefinitions.all()
    @Published var fullDiskAccessGranted: Bool = FullDiskAccess.isGranted()
    @Published var lastResults: [CleanupResult] = []
    @Published var showAdvancedAcknowledgement = false
    @Published var advancedAcknowledged = false
    /// Required before every single cleanup, regardless of risk tier — the user confirming
    /// they, personally, reviewed and chose what's about to be removed. Reset each time the
    /// confirmation sheet opens, so it's a fresh acknowledgment each run, not a one-time thing.
    @Published var responsibilityAcknowledged = false
    /// Bumped after anything changes local entitlement state, so views reading
    /// `Entitlements.status()` (a plain, non-Published enum) re-render when it does.
    @Published private var entitlementTick = 0
    /// What actually paid for the most recently completed cleanup — set right before
    /// `performClean()` runs, read by DoneView.
    @Published var lastCleanBilling: CleanBillingSummary?

    private var categoryObservers = Set<AnyCancellable>()

    init() {
        // Each CleanupCategory is its own ObservableObject; a change to one (e.g. toggling
        // a checkbox, which mutates its `selectedIDs`) does NOT by itself cause views that
        // only hold `AppState` to redraw, since `categories` (the array reference) never
        // changes. Forward every category's objectWillChange into AppState's own, so
        // anything reading AppState-level computed properties (hasAnySelection, footer
        // totals, the Review & Clean button's enabled state) updates immediately too.
        for category in categories {
            category.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &categoryObservers)
        }
    }

    var hasScanned: Bool { categories.contains { !$0.items.isEmpty } }

    var totalFoundSize: Int64 { categories.reduce(0) { $0 + $1.totalSize } }
    var totalSelectedSize: Int64 { categories.reduce(0) { $0 + $1.selectedSize } }
    var totalSelectedCount: Int { categories.reduce(0) { $0 + $1.selectedItems.count } }
    var hasAnySelection: Bool { totalSelectedCount > 0 }

    var categoriesWithSelections: [CleanupCategory] { categories.filter { !$0.selectedIDs.isEmpty } }
    var nonSafeSelections: [CleanupCategory] { categoriesWithSelections.filter { $0.tier != .safe } }

    func refreshFullDiskAccessStatus() {
        fullDiskAccessGranted = FullDiskAccess.isGranted()
    }

    func startScan() {
        for category in categories {
            category.items = []
            category.selectedIDs.removeAll()
            category.scanError = nil
        }
        advancedAcknowledged = false
        phase = .scanning(progressText: "Getting ready…")
        Task {
            await Scanner.scan(categories: categories) { [weak self] name in
                Task { @MainActor in self?.phase = .scanning(progressText: "Checking \(name)…") }
            }
            phase = .results
        }
    }

    var currentEntitlement: EntitlementStatus {
        _ = entitlementTick // establishes the dependency so SwiftUI re-evaluates this
        return Entitlements.status()
    }

    func requestClean() {
        guard hasAnySelection else { return }
        if !nonSafeSelections.isEmpty && !advancedAcknowledged {
            showAdvancedAcknowledgement = true
        }
        responsibilityAcknowledged = false
        phase = .confirming
        Task {
            await Entitlements.refreshSubscriptionIfNeeded()
            entitlementTick += 1
        }
    }

    /// Called when the user confirms the cleanup selection. If something's already usable
    /// (a credit, an active plan), spend it and clean immediately — no Stripe involved.
    /// Otherwise send them to pick a plan.
    func beginPayment() {
        let entitlement = currentEntitlement
        if entitlement == .none {
            phase = .paywall(paymentError: nil)
            return
        }
        lastCleanBilling = billingSummary(for: entitlement)
        Entitlements.consumeOne()
        entitlementTick += 1
        performClean()
    }

    private func billingSummary(for entitlement: EntitlementStatus) -> CleanBillingSummary? {
        switch entitlement {
        case .credits(let n): return .usedCredit(remainingAfter: max(0, n - 1))
        case .subscriptionActive: return .subscription
        case .lifetime: return .lifetime
        case .none: return nil
        }
    }

    func openPaymentLink(for plan: CleanPlan) {
        NSWorkspace.shared.open(plan.paymentLinkURL)
    }

    /// Handles the `mccleaner://payment-success?session_id=…` callback Stripe's hosted "thanks"
    /// page redirects to after checkout. Verifies server-side before ever running a clean —
    /// the app itself never sees or trusts a Stripe secret key.
    func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "mccleaner", url.host == "payment-success" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let sessionID = components.queryItems?.first(where: { $0.name == "session_id" })?.value,
              !sessionID.isEmpty else {
            phase = .paywall(paymentError: "Missing payment confirmation — please try again.")
            return
        }
        phase = .verifyingPayment
        Task {
            let result = await PurchaseVerifier.verify(sessionID: sessionID)
            switch result {
            case .verified(let plan, let subID, let until):
                Entitlements.grant(plan: plan, subscriptionID: subID, subscriptionActiveUntilDate: until)
                lastCleanBilling = .purchased(plan)
                Entitlements.consumeOne()
                entitlementTick += 1
                performClean()
            default:
                phase = .paywall(paymentError: result.userMessage)
            }
        }
    }

    func performClean() {
        phase = .cleaning(progressText: "Starting…")
        Task {
            let results = await Cleaner.clean(categories: categories) { [weak self] text in
                await MainActor.run { self?.phase = .cleaning(progressText: text) }
            }
            lastResults = results
            let freed = results.filter { $0.success }.reduce(Int64(0)) { $0 + $1.item.sizeBytes }
            let failures = results.filter { !$0.success }.count
            for category in categories {
                category.items.removeAll { item in results.contains { $0.success && $0.item.id == item.id } }
                category.selectedIDs.removeAll()
            }
            phase = .done(freedBytes: freed, failures: failures)
        }
    }

    func emptyTrashNow() {
        _ = Cleaner.emptyTrashViaFinder()
    }

    func startOver() {
        phase = .welcome
    }
}
