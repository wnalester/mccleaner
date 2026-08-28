import Foundation

enum RiskTier: Int, Comparable, CaseIterable {
    case safe = 0
    case caution = 1
    case advanced = 2

    static func < (lhs: RiskTier, rhs: RiskTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Caution"
        case .advanced: return "Advanced"
        }
    }

    var emoji: String {
        switch self {
        case .safe: return "🟢"
        case .caution: return "🟡"
        case .advanced: return "🔴"
        }
    }

    var shortBlurb: String {
        switch self {
        case .safe: return "Regenerated automatically. Essentially always fine to clear."
        case .caution: return "Regenerable, but clearing it may cost you time, bandwidth, or re-syncing."
        case .advanced: return "Real data lives here. Only clear this if you understand exactly what it is."
        }
    }
}

/// How an item is actually removed when the user confirms cleanup.
enum CleanupAction {
    /// Move the file/folder to macOS Trash (recoverable until Trash is emptied). The default,
    /// used for every category we can.
    case trash
    /// Thin/delete a local Time Machine snapshot via tmutil. NOT trash-recoverable — once
    /// confirmed, it's gone immediately (that's how APFS snapshots work).
    case tmutilSnapshot(date: String)
    /// Permanently deletes via an authenticated ("sudo-style") shell command, prompting the
    /// user for their admin password. Used only for root-owned system paths that a normal
    /// Trash move can't touch. NOT trash-recoverable — clearly labelled as such in the UI.
    case adminPermanentDelete
    /// Runs `xcrun simctl delete unavailable` — removes leftover data for simulator devices
    /// whose runtime no longer exists. Not a raw file delete.
    case simctlDeleteUnavailable
    /// Removes a downloaded Xcode simulator runtime image via `simctl runtime delete
    /// <identifier>` — Apple's own supported mechanism for this. These runtimes live in a
    /// signed/protected "secure storage area" that a plain file delete or even
    /// `diskutil apfs deleteContainer` cannot touch (confirmed: diskutil fails with
    /// "-69772: A writable disk is required" on these). Not trash-recoverable.
    case simctlDeleteRuntime(identifier: String)
    /// Permanently empties one specific Trash directory (i.e. the item IS a Trash folder,
    /// so "cleaning" it means emptying it, not moving it to Trash again).
    case emptyTrashDirect
}

/// One concrete, on-disk thing found during a scan (a file, folder, or snapshot)
/// that belongs to a CleanupCategory.
struct CleanupItem: Identifiable, Hashable {
    let id: String            // stable key, usually the path or snapshot date
    let displayName: String
    let path: String?         // nil for things like TM snapshots that aren't a simple path
    let sizeBytes: Int64
    let action: CleanupAction
    /// False for items we can only show and explain but never let the user select — e.g. a
    /// simulator runtime volume found on a Mac with no working `simctl` to safely remove it.
    var isActionable: Bool = true

    static func == (lhs: CleanupItem, rhs: CleanupItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A category of "System Data" (e.g. "App Caches", "iPhone Backups").
/// Definitions are static; `items` + `totalSize` are filled in by the Scanner at runtime.
final class CleanupCategory: Identifiable, ObservableObject ,ConfigurableCategory {
    let id: String
    let name: String
    let icon: String
    let tier: RiskTier
    let shortDescription: String
    let whatItIs: String
    let whyThisTier: String
    let ifYouDeleteIt: String
    /// Roots this category is allowed to touch. Every produced CleanupItem's resolved
    /// path must live under one of these (safety net enforced by PathSafety).
    let allowedRoots: [String]
    /// Produces the concrete items for this category by scanning disk. Runs off the main thread.
    let scan: () -> [CleanupItem]

    /// True for categories we can size and explain but can't safely one-click delete
    /// (e.g. whole APFS volumes rather than plain files) — shown as informational with
    /// step-by-step manual instructions instead of checkboxes.
    let isManualOnly: Bool
    let manualInstructions: String?
    let manualButtonTitle: String?
    let manualAction: (() -> Void)?

    @Published var items: [CleanupItem] = []
    @Published var selectedIDs: Set<String> = []
    @Published var isExpanded: Bool = false
    @Published var scanError: String? = nil

    init(id: String, name: String, icon: String, tier: RiskTier,
         shortDescription: String, whatItIs: String, whyThisTier: String, ifYouDeleteIt: String,
         allowedRoots: [String], scan: @escaping () -> [CleanupItem],
         isManualOnly: Bool = false, manualInstructions: String? = nil,
         manualButtonTitle: String? = nil, manualAction: (() -> Void)? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tier = tier
        self.shortDescription = shortDescription
        self.whatItIs = whatItIs
        self.whyThisTier = whyThisTier
        self.ifYouDeleteIt = ifYouDeleteIt
        self.allowedRoots = allowedRoots
        self.scan = scan
        self.isManualOnly = isManualOnly
        self.manualInstructions = manualInstructions
        self.manualButtonTitle = manualButtonTitle
        self.manualAction = manualAction
    }

    var totalSize: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }
    var selectedSize: Int64 { items.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes } }
    var selectedItems: [CleanupItem] { items.filter { selectedIDs.contains($0.id) } }
    var allSelected: Bool { !items.isEmpty && selectedIDs.count == items.count }
    var someSelected: Bool { !selectedIDs.isEmpty && !allSelected }

    func toggleSelectAll() {
        if allSelected {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(items.map { $0.id })
        }
    }
}

/// Marker protocol kept tiny on purpose; lets other files extend category behavior later
/// without touching the core model.
protocol ConfigurableCategory: AnyObject {}

enum AppPhase: Equatable {
    case welcome
    case scanning(progressText: String)
    case results
    case confirming
    case cleaning(progressText: String)
    case done(freedBytes: Int64, failures: Int)
}
