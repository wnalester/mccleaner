import Foundation

enum Sizes {
    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

enum Paths {
    static var home: String { FileManager.default.homeDirectoryForCurrentUser.path }

    /// Resolves symlinks and standardizes a path so PathSafety checks can't be fooled
    /// by a symlink pointing somewhere outside the allowed root.
    static func resolve(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
}

/// Runs a shell command synchronously and returns (stdout, exitCode). Never throws;
/// callers treat a non-zero exit / empty output as "couldn't get this data" and move on.
/// stderr is discarded here — use `runShellCapturingStderr` when the failure reason matters
/// (e.g. anything we might need to explain back to the user).
@discardableResult
func runShell(_ launchPath: String, _ arguments: [String]) -> (output: String, status: Int32) {
    let result = runShellCapturingStderr(launchPath, arguments)
    return (result.stdout, result.status)
}

/// Same as `runShell`, but also captures stderr instead of discarding it. Use this for any
/// command whose failure message we might need to show or log — silently swallowing stderr
/// makes real failures (wrong password, a protected/sealed volume, etc.) indistinguishable
/// from each other, which is exactly the kind of thing worth surfacing accurately.
func runShellCapturingStderr(_ launchPath: String, _ arguments: [String]) -> (stdout: String, stderr: String, status: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe
    do {
        try process.run()
    } catch {
        return ("", "couldn't launch \(launchPath): \(error.localizedDescription)", -1)
    }
    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let stdout = String(data: outData, encoding: .utf8) ?? ""
    let stderr = String(data: errData, encoding: .utf8) ?? ""
    return (stdout, stderr, process.terminationStatus)
}

/// Size (in bytes) of everything under `path`, using `du` which reads APFS allocated
/// block sizes directly — much faster than a Swift FileManager enumeration for big trees.
func diskUsageBytes(of path: String) -> Int64 {
    guard FileManager.default.fileExists(atPath: path) else { return 0 }
    let (output, status) = runShell("/usr/bin/du", ["-sk", path])
    guard status == 0 else { return 0 }
    let firstField = output.split(separator: "\t").first ?? output.split(separator: " ").first ?? ""
    guard let kb = Int64(firstField.trimmingCharacters(in: .whitespaces)) else { return 0 }
    return kb * 1024
}

/// Lists immediate children of a directory (non-recursive), skipping hidden dotfiles
/// like .DS_Store that aren't meaningful cleanup targets on their own.
func immediateChildren(of directory: String) -> [String] {
    guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
    return entries
        .filter { $0 != ".DS_Store" }
        .map { (directory as NSString).appendingPathComponent($0) }
}

func fileExists(_ path: String) -> Bool {
    FileManager.default.fileExists(atPath: path)
}
