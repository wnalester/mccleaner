import Foundation

/// Runs every category's scan closure on a background thread, reporting which category
/// is currently being measured so the UI can show real progress instead of a blind spinner.
enum Scanner {
    static func scan(categories: [CleanupCategory], onProgress: @escaping (String) -> Void) async {
        for category in categories {
            onProgress(category.name)
            let items = await Task.detached(priority: .userInitiated) {
                category.scan()
            }.value
            await MainActor.run {
                category.items = items
                category.selectedIDs.removeAll()
            }
        }
    }
}
