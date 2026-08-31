import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .welcome
    @Published var categories: [CleanupCategory] = CategoryDefinitions.all()
    @Published var fullDiskAccessGranted: Bool = FullDiskAccess.isGranted()
    @Published var lastResults: [CleanupResult] = []
    @Published var showAdvancedAcknowledgement = false
    @Published var advancedAcknowledged = false

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

    func requestClean() {
        guard hasAnySelection else { return }
        if !nonSafeSelections.isEmpty && !advancedAcknowledged {
            showAdvancedAcknowledgement = true
        }
        phase = .confirming
    }

    /// Called when the user confirms the cleanup selection. Scanning and browsing are free;
    /// this is the one gate before anything is actually paid for.
    func beginPayment() {
        phase = .paywall(paymentError: nil)
    }

    func openPaymentLink() {
        NSWorkspace.shared.open(PurchaseConfig.paymentLinkURL)
    }

    /// Handles the `sdc://payment-success?session_id=…` callback Stripe's hosted "thanks"
    /// page redirects to after checkout. Verifies server-side before ever running a clean —
    /// the app itself never sees or trusts a Stripe secret key.
    func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "sdc", url.host == "payment-success" else { return }
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
            case .verified:
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
