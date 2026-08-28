import Foundation

/// Last-line-of-defense safety net. Every single path we are about to move to the Trash
/// (or otherwise act on) must pass this check, independent of whatever CleanupCategory
/// produced it. This exists so a bug in one category's scan logic can never cause us to
/// touch something catastrophic like the user's home folder or a system directory.
enum PathSafety {

    /// Exact paths we will never act on, no matter what a category claims.
    private static var neverTouch: Set<String> {
        let home = Paths.home
        return [
            "/", "/System", "/Library", "/Applications", "/Users", "/private",
            "/private/var", home, "\(home)/Library", "\(home)/Documents",
            "\(home)/Desktop", "\(home)/Pictures", "\(home)/Music", "\(home)/Movies",
            "\(home)/Downloads", "\(home)/Public"
        ]
    }

    /// Returns true only if `path` resolves to somewhere strictly *inside* one of the
    /// category's declared allowed roots, and isn't one of the hard-blocked exact paths.
    static func isSafeToDelete(_ path: String, allowedRoots: [String]) -> Bool {
        let resolved = Paths.resolve(path)

        if neverTouch.contains(resolved) { return false }

        let matchesAllowedRoot = allowedRoots.contains { root in
            let resolvedRoot = Paths.resolve(root)
            guard resolved != resolvedRoot else { return false } // must be *inside*, not the root itself
            return resolved.hasPrefix(resolvedRoot + "/")
        }
        return matchesAllowedRoot
    }

    /// Narrow, explicit check used only by `.emptyTrashDirect`: the path must literally BE
    /// a Trash directory (the user's own, or a volume's), never merely something inside one.
    static func isKnownTrashDirectory(_ path: String) -> Bool {
        let resolved = Paths.resolve(path)
        if resolved == Paths.resolve("\(Paths.home)/.Trash") { return true }
        if resolved.hasPrefix("/Volumes/") && resolved.hasSuffix("/.Trashes") { return true }
        return false
    }
}
