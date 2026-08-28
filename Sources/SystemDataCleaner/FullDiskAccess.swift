import Foundation
import AppKit

enum FullDiskAccess {
    /// Best-effort check: this system file is only readable when the app has been granted
    /// Full Disk Access. Not 100% authoritative, but it's the standard trick every utility
    /// like this uses, since Apple provides no direct API to ask "do I have FDA?".
    static func isGranted() -> Bool {
        let path = "/Library/Application Support/com.apple.TCC/TCC.db"
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        handle.closeFile()
        return true
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
