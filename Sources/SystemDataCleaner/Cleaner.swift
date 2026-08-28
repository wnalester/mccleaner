import Foundation

struct CleanupResult {
    let categoryName: String
    let item: CleanupItem
    let success: Bool
    let errorMessage: String?
}

enum Logger {
    private static var logPath: String {
        let dir = "\(Paths.home)/Library/Logs/SystemDataCleaner"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return "\(dir)/cleanup.log"
    }

    static func log(_ line: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(line)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath), let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }

    static var logFilePath: String { logPath }
}

/// Runs an authenticated shell command via AppleScript's "with administrator privileges",
/// which shows the user the standard macOS password prompt. `argument` is passed through
/// AppleScript's own `quoted form of` so we never have to hand-roll shell escaping. Returns
/// the real failure text (wrong/cancelled password vs. the command's own error) instead of
/// just a Bool, since those need very different explanations to the user.
func runAsAdmin(command: String, argument: String) -> Result<String, AdminError> {
    let escaped = argument.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let script = "do shell script \"\(command) \" & quoted form of \"\(escaped)\" with administrator privileges"
    let result = runShellCapturingStderr("/usr/bin/osascript", ["-e", script])
    if result.status == 0 {
        return .success(result.stdout)
    }
    let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    return .failure(AdminError(message: message.isEmpty ? "command exited with status \(result.status)" : message))
}

struct AdminError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

enum Cleaner {

    /// Executes every selected item across all categories, in order, reporting progress
    /// as it goes. Runs off the main actor since these are blocking filesystem/process calls.
    static func clean(categories: [CleanupCategory], onProgress: @escaping (String) async -> Void) async -> [CleanupResult] {
        var results: [CleanupResult] = []
        for category in categories {
            let selected = category.selectedItems
            for item in selected {
                await onProgress("\(category.name): \(item.displayName)")
                let result = await Task.detached(priority: .userInitiated) {
                    perform(item: item, categoryName: category.name, allowedRoots: category.allowedRoots)
                }.value
                results.append(result)
            }
        }
        return results
    }

    private static func perform(item: CleanupItem, categoryName: String, allowedRoots: [String]) -> CleanupResult {
        func ok() -> CleanupResult { CleanupResult(categoryName: categoryName, item: item, success: true, errorMessage: nil) }
        func fail(_ message: String) -> CleanupResult { CleanupResult(categoryName: categoryName, item: item, success: false, errorMessage: message) }

        switch item.action {
        case .trash:
            guard let path = item.path else { return fail("missing path") }
            guard PathSafety.isSafeToDelete(path, allowedRoots: allowedRoots) else {
                Logger.log("BLOCKED (failed safety check): \(path)")
                return fail("blocked by internal safety check")
            }
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                Logger.log("Moved to Trash: \(path)")
                return ok()
            } catch {
                Logger.log("FAILED to trash \(path): \(error.localizedDescription)")
                return fail(error.localizedDescription)
            }

        case .adminPermanentDelete:
            guard let path = item.path else { return fail("missing path") }
            guard PathSafety.isSafeToDelete(path, allowedRoots: allowedRoots) else {
                Logger.log("BLOCKED (failed safety check): \(path)")
                return fail("blocked by internal safety check")
            }
            switch runAsAdmin(command: "rm -rf", argument: path) {
            case .success:
                Logger.log("Permanently deleted (admin): \(path)")
                return ok()
            case .failure(let message):
                Logger.log("FAILED admin delete of \(path): \(message)")
                return fail(message.message)
            }

        case .emptyTrashDirect:
            guard let path = item.path, PathSafety.isKnownTrashDirectory(path) else {
                Logger.log("BLOCKED (not a recognized Trash folder): \(item.path ?? "nil")")
                return fail("blocked by internal safety check")
            }
            var lastError: String? = nil
            for child in immediateChildren(of: path) {
                do {
                    try FileManager.default.removeItem(atPath: child)
                } catch {
                    lastError = error.localizedDescription
                }
            }
            Logger.log("Emptied Trash folder: \(path)")
            return lastError == nil ? ok() : fail("some items couldn't be removed: \(lastError!)")

        case .tmutilSnapshot(let date):
            let (_, status) = runShell("/usr/bin/tmutil", ["deletelocalsnapshots", date])
            if status == 0 {
                Logger.log("Deleted Time Machine local snapshot: \(date)")
                return ok()
            }
            switch runAsAdmin(command: "tmutil deletelocalsnapshots", argument: date) {
            case .success:
                Logger.log("Deleted Time Machine local snapshot (admin): \(date)")
                return ok()
            case .failure(let message):
                Logger.log("FAILED to delete snapshot \(date): \(message)")
                return fail(message.message)
            }

        case .simctlDeleteUnavailable:
            let (_, status) = runShell("/usr/bin/xcrun", ["simctl", "delete", "unavailable"])
            if status == 0 {
                Logger.log("Ran: xcrun simctl delete unavailable")
                return ok()
            }
            return fail("simctl could not remove unavailable devices")

        case .simctlDeleteRuntime(let identifier):
            guard let simctlPath = ScanHelpers.resolveSimctlPath() else {
                return fail("no working simctl found (is Xcode still installed?)")
            }
            let result = runShellCapturingStderr(simctlPath, ["runtime", "delete", identifier])
            if result.status == 0 {
                Logger.log("Deleted simulator runtime via simctl: \(identifier)")
                return ok()
            }
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            Logger.log("FAILED simctl runtime delete \(identifier): \(message)")
            return fail(message.isEmpty ? "simctl could not remove this runtime" : message)
        }
    }

    /// Empties the user's main Trash via Finder (so it respects "Warn before emptying Trash"
    /// and any locked-item prompts, exactly like clicking Empty Trash yourself).
    static func emptyTrashViaFinder() -> Bool {
        let (_, status) = runShell("/usr/bin/osascript", ["-e", "tell application \"Finder\" to empty trash"])
        return status == 0
    }
}
