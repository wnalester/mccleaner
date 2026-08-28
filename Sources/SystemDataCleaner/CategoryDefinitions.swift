import Foundation

/// Shared scan helpers used by several category definitions below.
enum ScanHelpers {

    /// One CleanupItem per immediate child of `directory`, sized with `du`, biggest first.
    /// This is the workhorse for every plain "folder full of stuff" category.
    static func itemsFromChildren(of directory: String, action: CleanupAction = .trash) -> [CleanupItem] {
        immediateChildren(of: directory)
            .map { path -> CleanupItem in
                let size = diskUsageBytes(of: path)
                let name = (path as NSString).lastPathComponent
                return CleanupItem(id: path, displayName: name, path: path, sizeBytes: size, action: action)
            }
            .filter { $0.sizeBytes > 0 }
            .sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Reads a container's Data/Library/Caches size for every app container under
    /// ~/Library/Containers, one CleanupItem per container (named by its bundle id).
    static func sandboxedAppCaches() -> [CleanupItem] {
        let containersDir = "\(Paths.home)/Library/Containers"
        return immediateChildren(of: containersDir).compactMap { containerPath -> CleanupItem? in
            let cachesPath = "\(containerPath)/Data/Library/Caches"
            guard fileExists(cachesPath) else { return nil }
            let size = diskUsageBytes(of: cachesPath)
            guard size > 0 else { return nil }
            let bundleID = (containerPath as NSString).lastPathComponent
            return CleanupItem(id: cachesPath, displayName: bundleID, path: cachesPath, sizeBytes: size, action: .trash)
        }.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Every "Foo DeviceSupport" folder Xcode keeps for a version of iOS/watchOS/tvOS it's
    /// symbolicated crash logs against. Safe to delete; Xcode re-downloads on next device connect.
    static func deviceSupportItems() -> [CleanupItem] {
        let devDir = "\(Paths.home)/Library/Developer/Xcode"
        let supportDirs = ["iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport", "xrOS DeviceSupport"]
        return supportDirs.flatMap { itemsFromChildren(of: "\(devDir)/\($0)") }
            .sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Local Time Machine snapshots (APFS). These are point-in-time local-disk-only snapshots
    /// used to let Time Machine catch up once an external/network backup is reachable again —
    /// they are not themselves a backup destination. Sizes aren't reported by tmutil (snapshots
    /// share disk blocks with your live files), so we surface count + dates instead of bytes.
    static func timeMachineSnapshots() -> [CleanupItem] {
        let (output, status) = runShell("/usr/bin/tmutil", ["listlocalsnapshots", "/"])
        guard status == 0 else { return [] }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("com.apple.TimeMachine") }
            .compactMap { line -> CleanupItem? in
                // Format: com.apple.TimeMachine.2024-06-01-121314.local
                guard let dateRange = line.range(of: #"\d{4}-\d{2}-\d{2}-\d{6}"#, options: .regularExpression) else { return nil }
                let date = String(line[dateRange])
                return CleanupItem(id: "snapshot-\(date)", displayName: "Snapshot from \(date)", path: nil,
                                    sizeBytes: 0, action: .tmutilSnapshot(date: date))
            }
    }

    /// Every simulator device Xcode reports as "unavailable" (its runtime was deleted, e.g.
    /// after an Xcode update). `xcrun simctl delete unavailable` is Apple's own safe cleanup
    /// command for this — we never touch simulator files directly.
    static func unavailableSimulators() -> [CleanupItem] {
        let (output, status) = runShell("/usr/bin/xcrun", ["simctl", "list", "devices", "unavailable"])
        guard status == 0 else { return [] }
        let deviceLines = output.split(separator: "\n").filter { $0.contains("(unavailable") }
        guard !deviceLines.isEmpty else { return [] }
        // We can't cheaply attribute disk usage to only the unavailable devices without deeper
        // parsing of simctl's device list, so we report count only and let the cleanup action
        // (simctl's own command) do the real accounting.
        return [CleanupItem(id: "simctl-unavailable", displayName: "\(deviceLines.count) unavailable simulator device(s)",
                             path: nil, sizeBytes: 0, action: .simctlDeleteUnavailable)]
    }

    /// Human-friendly label for an iPhone/iPad backup folder using its Info.plist, falling
    /// back to the raw UDID folder name if the plist can't be read.
    static func backupItems() -> [CleanupItem] {
        let backupDir = "\(Paths.home)/Library/Application Support/MobileSync/Backup"
        return immediateChildren(of: backupDir).map { path -> CleanupItem in
            let size = diskUsageBytes(of: path)
            var name = (path as NSString).lastPathComponent
            let infoPlist = "\(path)/Info.plist"
            if let data = FileManager.default.contents(atPath: infoPlist),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                let device = plist["Device Name"] as? String
                let productName = plist["Product Name"] as? String
                let backupDate = plist["Last Backup Date"] as? Date
                var label = device ?? productName ?? name
                if let backupDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    label += " — \(formatter.string(from: backupDate))"
                }
                name = label
            }
            return CleanupItem(id: path, displayName: name, path: path, sizeBytes: size, action: .trash)
        }.filter { $0.sizeBytes > 0 }.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Finds a working `simctl` even when `xcode-select` points at Command Line Tools only
    /// (which don't ship simctl) but a full Xcode.app is installed somewhere.
    static func resolveSimctlPath() -> String? {
        let (xcrunOut, xcrunStatus) = runShell("/usr/bin/xcrun", ["--find", "simctl"])
        if xcrunStatus == 0 {
            let path = xcrunOut.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, fileExists(path) { return path }
        }
        let (mdOut, mdStatus) = runShell("/usr/bin/mdfind", ["kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"])
        if mdStatus == 0 {
            for line in mdOut.split(separator: "\n") {
                let candidate = "\(line)/Contents/Developer/usr/bin/simctl"
                if fileExists(candidate) { return candidate }
            }
        }
        return nil
    }

    /// Downloaded Xcode simulator runtime images (iOS/watchOS/tvOS/visionOS), each mounted as
    /// its own virtual disk under /Library/Developer/CoreSimulator/Volumes. `simctl runtime
    /// list -j` is the authoritative source for these — it's what actually knows the correct
    /// identifier to delete one with, unlike raw `diskutil`, which we confirmed cannot touch
    /// them at all (they live in a signed/protected "secure storage area"; diskutil fails with
    /// "-69772: A writable disk is required" no matter what).
    ///
    /// Whether one of these is "leftover junk" or "your actual dev environment" depends entirely
    /// on whether Xcode is installed and using it — so we cross-reference `simctl list devices`
    /// to report, per runtime, how many simulator devices actually use it, instead of guessing.
    static func simulatorPlatformRuntimeVolumes() -> [CleanupItem] {
        guard let simctlPath = resolveSimctlPath() else {
            // No working simctl anywhere on this Mac — we can still see the volumes on disk,
            // but with no Apple-supported way to identify or safely remove them, show them as
            // informational only rather than guess.
            let volumesDir = "/Library/Developer/CoreSimulator/Volumes"
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: volumesDir) else { return [] }
            return names.compactMap { name -> CleanupItem? in
                let mountPath = "\(volumesDir)/\(name)"
                let size = diskUsageBytes(of: mountPath)
                guard size > 0 else { return nil }
                return CleanupItem(id: mountPath, displayName: "\(name) — no Xcode found on this Mac to safely remove it",
                                    path: mountPath, sizeBytes: size, action: .trash, isActionable: false)
            }.sorted { $0.sizeBytes > $1.sizeBytes }
        }

        var deviceCountByRuntimeIdentifier: [String: Int] = [:]
        if let data = runShell(simctlPath, ["list", "devices", "-j"]).output.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let devices = obj["devices"] as? [String: [[String: Any]]] {
            for (identifier, list) in devices {
                deviceCountByRuntimeIdentifier[identifier] = list.count
            }
        }

        guard let data = runShell(simctlPath, ["runtime", "list", "-j"]).output.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return []
        }

        return obj.values.compactMap { entry -> CleanupItem? in
            guard let identifier = entry["identifier"] as? String,
                  let mountPath = entry["mountPath"] as? String,
                  let sizeBytes = entry["sizeBytes"] as? NSNumber,
                  let deletable = entry["deletable"] as? Bool else { return nil }

            let platformName = (mountPath as NSString).lastPathComponent.split(separator: "_").first.map(String.init) ?? mountPath
            let version = entry["version"] as? String ?? ""
            let runtimeIdentifier = entry["runtimeIdentifier"] as? String ?? ""
            let deviceCount = deviceCountByRuntimeIdentifier[runtimeIdentifier] ?? 0

            var label = "\(platformName) \(version)"
            label += deviceCount > 0
                ? " — used by \(deviceCount) simulator device(s) you've created"
                : " — installed, but no simulator devices use it right now"
            if !deletable {
                label += " (Xcode reports this one can't be removed right now)"
            }

            return CleanupItem(id: identifier, displayName: label, path: mountPath,
                                sizeBytes: sizeBytes.int64Value, action: .simctlDeleteRuntime(identifier: identifier),
                                isActionable: deletable)
        }.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// All Trash directories on the Mac: the user's own, plus one per mounted external volume.
    static func trashFolders() -> [CleanupItem] {
        var dirs = ["\(Paths.home)/.Trash"]
        if let volumes = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") {
            dirs += volumes.map { "/Volumes/\($0)/.Trashes" }
        }
        return dirs.compactMap { path -> CleanupItem? in
            guard fileExists(path) else { return nil }
            let size = diskUsageBytes(of: path)
            guard size > 0 else { return nil }
            return CleanupItem(id: path, displayName: path, path: path, sizeBytes: size, action: .emptyTrashDirect)
        }
    }
}

enum CategoryDefinitions {
    static func all() -> [CleanupCategory] {
        let home = Paths.home
        return [
            // MARK: Safe

            CleanupCategory(
                id: "user-caches", name: "App & User Caches", icon: "internaldrive",
                tier: .safe,
                shortDescription: "Temporary files apps store to speed themselves up.",
                whatItIs: "Every app on your Mac (browsers, Slack, Spotify, Xcode, etc.) is allowed to stash temporary files here to make itself load faster. None of it is anything you created.",
                whyThisTier: "macOS and every app expect this folder to be wiped at any time — they check for missing files and just rebuild them.",
                ifYouDeleteIt: "Nothing is lost. A few apps may feel slightly slower the very next time you open them while they rebuild their cache, then it's back to normal.",
                allowedRoots: ["\(home)/Library/Caches"],
                scan: { ScanHelpers.itemsFromChildren(of: "\(home)/Library/Caches") }
            ),
            CleanupCategory(
                id: "sandboxed-caches", name: "Sandboxed App Caches", icon: "shippingbox",
                tier: .safe,
                shortDescription: "Same idea as app caches, but for modern 'sandboxed' apps (Mail, Photos, App Store, etc.).",
                whatItIs: "Newer macOS apps run in their own sandboxed folder under ~/Library/Containers. Each keeps its own Caches folder there, separate from the main Caches folder above.",
                whyThisTier: "These are the exact same kind of disposable cache data as regular app caches — just stored in a different location because of how sandboxing works.",
                ifYouDeleteIt: "Nothing is lost. Only cache folders are touched — your Mail messages, Photos library, and app data are in separate, untouched folders.",
                allowedRoots: ["\(home)/Library/Containers"],
                scan: { ScanHelpers.sandboxedAppCaches() }
            ),
            CleanupCategory(
                id: "user-logs", name: "App & System Logs", icon: "doc.text",
                tier: .safe,
                shortDescription: "Text log files apps write for debugging purposes.",
                whatItIs: "Diagnostic text logs that apps and macOS write as they run, meant to help developers debug problems. You almost certainly never open these.",
                whyThisTier: "Logs are write-only diagnostic history. Removing old ones has no effect on how anything runs.",
                ifYouDeleteIt: "Nothing functional changes. If you're actively debugging a specific issue with Apple or a developer, they may ask you not to clear logs until it's resolved.",
                allowedRoots: ["\(home)/Library/Logs"],
                scan: {
                    immediateChildren(of: "\(home)/Library/Logs")
                        .filter { !$0.hasSuffix("/DiagnosticReports") }
                        .map { path in
                            let size = diskUsageBytes(of: path)
                            return CleanupItem(id: path, displayName: (path as NSString).lastPathComponent,
                                                path: path, sizeBytes: size, action: .trash)
                        }
                        .filter { $0.sizeBytes > 0 }
                        .sorted { $0.sizeBytes > $1.sizeBytes }
                }
            ),
            CleanupCategory(
                id: "diagnostic-reports", name: "Crash & Diagnostic Reports", icon: "exclamationmark.triangle",
                tier: .safe,
                shortDescription: "Saved crash reports from apps that have quit unexpectedly.",
                whatItIs: "Whenever an app crashes, macOS saves a detailed report about what went wrong. These pile up over months or years.",
                whyThisTier: "These are historical records only — nothing reads them after the fact unless you go looking, e.g. to send one to a developer.",
                ifYouDeleteIt: "Nothing is lost except the ability to look back at exactly why a past crash happened.",
                allowedRoots: ["\(home)/Library/Logs/DiagnosticReports"],
                scan: { ScanHelpers.itemsFromChildren(of: "\(home)/Library/Logs/DiagnosticReports") }
            ),
            CleanupCategory(
                id: "temp-files", name: "Temporary Files", icon: "clock.arrow.circlepath",
                tier: .safe,
                shortDescription: "Short-lived scratch files apps create while working, then usually forget to delete.",
                whatItIs: "macOS gives every app a scratch folder (your \"TMPDIR\") for files it only needs for a few minutes — exported PDFs mid-save, install packages being unzipped, and similar.",
                whyThisTier: "By definition these files are meant to be temporary. macOS itself periodically clears old ones.",
                ifYouDeleteIt: "Nothing is lost. If an app has a file open here right this second, it's simply skipped and left alone.",
                allowedRoots: [NSTemporaryDirectory()],
                scan: { ScanHelpers.itemsFromChildren(of: NSTemporaryDirectory()) }
            ),
            CleanupCategory(
                id: "dev-tool-caches", name: "Developer Tool Caches", icon: "hammer",
                tier: .safe,
                shortDescription: "Package-manager download caches (npm, pip, cargo, Go, Gradle, etc.).",
                whatItIs: "Command-line developer tools cache downloaded packages here so they don't re-download them every time. Only relevant if you write code.",
                whyThisTier: "Every one of these tools re-downloads a package automatically the moment it can't find it in cache — that's their whole design.",
                ifYouDeleteIt: "Nothing is lost. Your next build or install may take longer the first time, since packages re-download.",
                allowedRoots: ["\(home)/.npm", "\(home)/.cache", "\(home)/.cargo/registry/cache",
                               "\(home)/go/pkg/mod/cache/download", "\(home)/.gradle/caches"],
                scan: {
                    ["\(home)/.npm", "\(home)/.cache", "\(home)/.cargo/registry/cache",
                     "\(home)/go/pkg/mod/cache/download", "\(home)/.gradle/caches"]
                        .filter { fileExists($0) }
                        .map { path in
                            let size = diskUsageBytes(of: path)
                            return CleanupItem(id: path, displayName: path.replacingOccurrences(of: home, with: "~"),
                                                path: path, sizeBytes: size, action: .trash)
                        }
                        .filter { $0.sizeBytes > 0 }
                        .sorted { $0.sizeBytes > $1.sizeBytes }
                }
            ),
            CleanupCategory(
                id: "xcode-derived-data", name: "Xcode Derived Data", icon: "wrench.and.screwdriver",
                tier: .safe,
                shortDescription: "Xcode's build cache — intermediate build files for every project you've opened.",
                whatItIs: "Every time you build a project in Xcode, it stores compiled object files here to speed up the next build. It has nothing to do with your actual source code.",
                whyThisTier: "Xcode fully regenerates this the next time you build. Many developers clear it routinely to fix weird build glitches.",
                ifYouDeleteIt: "Nothing is lost. Your next build of each project will simply take longer, as a full rebuild instead of an incremental one.",
                allowedRoots: ["\(home)/Library/Developer/Xcode/DerivedData"],
                scan: { ScanHelpers.itemsFromChildren(of: "\(home)/Library/Developer/Xcode/DerivedData") }
            ),
            CleanupCategory(
                id: "simulator-caches", name: "Xcode Simulator Caches", icon: "iphone",
                tier: .safe,
                shortDescription: "Cache files used by the iOS/watchOS Simulator app.",
                whatItIs: "The Simulator app (for testing iPhone/iPad apps on your Mac) keeps its own cache folder, separate from the simulator devices themselves.",
                whyThisTier: "Purely a speed cache for the Simulator app; it gets rebuilt automatically.",
                ifYouDeleteIt: "Nothing is lost. The Simulator may take a little longer to boot a device the next time.",
                allowedRoots: ["\(home)/Library/Developer/CoreSimulator/Caches"],
                scan: { ScanHelpers.itemsFromChildren(of: "\(home)/Library/Developer/CoreSimulator/Caches") }
            ),
            CleanupCategory(
                id: "trash-folders", name: "Items Already in Your Trash", icon: "trash",
                tier: .safe,
                shortDescription: "Files you already deleted, sitting in Trash across your drives.",
                whatItIs: "Every disk (your main drive, and any external drive you've used) keeps its own Trash. Finder only shows you one merged view of all of them.",
                whyThisTier: "You already chose to delete these — this just finishes the job you started.",
                ifYouDeleteIt: "This one is different from the rest: emptying an already-selected Trash folder is permanent and immediate, exactly like Finder's \"Empty Trash\". It does not go through Trash again.",
                allowedRoots: ["\(home)/.Trash", "/Volumes"],
                scan: { ScanHelpers.trashFolders() }
            ),
            CleanupCategory(
                id: "system-caches-admin", name: "System-wide Caches (needs admin password)", icon: "lock.shield",
                tier: .safe,
                shortDescription: "The same kind of disposable app caches as above, but the system-wide copy used by all user accounts.",
                whatItIs: "Just like ~/Library/Caches, but the shared, system-wide version at /Library/Caches, owned by the system rather than your user account.",
                whyThisTier: "Functionally identical to your personal app caches — just needs your admin password because it's owned by the system, not you.",
                ifYouDeleteIt: "Nothing is lost, same as your personal caches. macOS asks for your password, and this is deleted immediately and permanently (not moved to Trash) because system-owned files can't be trashed.",
                allowedRoots: ["/Library/Caches"],
                scan: { ScanHelpers.itemsFromChildren(of: "/Library/Caches", action: .adminPermanentDelete) }
            ),

            // MARK: Caution

            CleanupCategory(
                id: "unavailable-simulators", name: "Unavailable Simulator Devices", icon: "iphone.slash",
                tier: .caution,
                shortDescription: "Leftover data for simulator devices whose iOS/watchOS version no longer exists.",
                whatItIs: "When Xcode updates and drops support for an old simulator runtime (say, iOS 15), the simulator devices you'd created for it become \"unavailable\" but their data sticks around.",
                whyThisTier: "Removed using Apple's own official cleanup command, not raw file deletion — very safe — but it's still deleting simulator device state, so it's one small step up from a pure cache.",
                ifYouDeleteIt: "You lose any custom simulator state (installed test apps, simulated data) for those old, no-longer-usable devices. You can always create fresh simulator devices at any time.",
                allowedRoots: ["\(home)/Library/Developer/CoreSimulator"],
                scan: { ScanHelpers.unavailableSimulators() }
            ),
            CleanupCategory(
                id: "device-support", name: "Old iOS/watchOS Device Support Files", icon: "cable.connector",
                tier: .caution,
                shortDescription: "Symbol files Xcode downloads so it can debug a physical iPhone/Apple Watch.",
                whatItIs: "To let you debug your app running on a real device, Xcode downloads a support package matching that exact OS version. These pile up as your devices update over the years.",
                whyThisTier: "Fully redownloaded by Xcode automatically — but only when you next plug in a matching device, which requires a network connection at that moment.",
                ifYouDeleteIt: "The next time you plug in a device running an OS version you deleted support for, Xcode will need to re-download a support package (a few hundred MB) before it can debug on that device.",
                allowedRoots: ["\(home)/Library/Developer/Xcode"],
                scan: { ScanHelpers.deviceSupportItems() }
            ),
            CleanupCategory(
                id: "tm-snapshots", name: "Time Machine Local Snapshots", icon: "clock.arrow.2.circlepath",
                tier: .caution,
                shortDescription: "Hourly local backups Time Machine keeps on this Mac's own disk while your backup drive isn't connected.",
                whatItIs: "Time Machine takes local, on-disk snapshots so it can catch up once your real backup drive (external disk or Time Capsule) is reconnected. These are not themselves your backup.",
                whyThisTier: "Safe as long as you have a real Time Machine backup drive (or another backup) elsewhere — these local snapshots are a convenience, not your only copy.",
                ifYouDeleteIt: "You lose the ability to restore to those specific in-between hourly moments until your backup drive reconnects and Time Machine catches up again. Your actual external Time Machine backups are untouched. This action cannot be undone (it does not go through Trash).",
                allowedRoots: [],
                scan: { ScanHelpers.timeMachineSnapshots() }
            ),
            CleanupCategory(
                id: "iphone-backups", name: "iPhone / iPad Backups", icon: "iphone.gen3",
                tier: .caution,
                shortDescription: "Full local backups of an iPhone or iPad made via Finder/iTunes.",
                whatItIs: "When you back up your iPhone or iPad to your Mac (instead of iCloud), the entire backup — photos, messages, app data, everything — is stored here.",
                whyThisTier: "Deleting one only matters if it's a backup you still need. An old backup of a phone you no longer own, or one you've since re-backed-up, is safe to remove.",
                ifYouDeleteIt: "That backup is gone. If it's your only backup of that device and you needed to restore it later, you would not be able to. Check the device name and date shown for each one before selecting it.",
                allowedRoots: ["\(home)/Library/Application Support/MobileSync/Backup"],
                scan: { ScanHelpers.backupItems() }
            ),

            // MARK: Advanced

            CleanupCategory(
                id: "photos-caches", name: "Photos App Preview Cache", icon: "photo.stack",
                tier: .advanced,
                shortDescription: "Regeneratable thumbnail/preview cache inside your Photos Library — NOT your actual photos.",
                whatItIs: "Inside your Photos Library package, macOS keeps a cache of resized preview images so Photos scrolls smoothly. Your actual original photos live in a completely separate part of the library that this never touches.",
                whyThisTier: "This is the one category where we're reaching inside a library package most people never look inside — so even though only cache folders are targeted, we want you to consciously opt in.",
                ifYouDeleteIt: "Photos will feel slower and show blurry thumbnails for a while as it regenerates previews. If you use \"Optimize Mac Storage\" for iCloud Photos, some previews may need to re-download from iCloud, which can take time and use bandwidth. Your original photos are never touched.",
                allowedRoots: ["\(home)/Pictures/Photos Library.photoslibrary/resources/caches",
                               "\(home)/Pictures/Photos Library.photoslibrary/resources/proxies"],
                scan: {
                    ["\(home)/Pictures/Photos Library.photoslibrary/resources/caches",
                     "\(home)/Pictures/Photos Library.photoslibrary/resources/proxies"]
                        .flatMap { ScanHelpers.itemsFromChildren(of: $0) }
                }
            ),
            CleanupCategory(
                id: "simulator-platform-runtimes", name: "Xcode Simulator Platform Runtimes", icon: "externaldrive.badge.exclamationmark",
                tier: .caution,
                shortDescription: "Whole virtual disks — one per OS (iOS/watchOS/tvOS/visionOS) — that Xcode uses to run simulators. Often the single biggest thing in System Data, but not automatically \"junk.\"",
                whatItIs: "To let developers test apps on virtual iPhones, Apple Watches, Apple TVs, and Vision Pros, Xcode installs each OS version as its own separate mini disk (visible in Disk Utility). Each item below tells you whether it's actually tied to simulator devices you've created, so you're not guessing.",
                whyThisTier: "These live in a signed, protected storage area Apple's own tools manage — a plain file delete can't touch them, and even the disk-partition-level tool (diskutil) is refused for the same reason. This app removes them the correct way, using Xcode's own \"simctl runtime delete\" command, the same mechanism Xcode itself uses. More importantly, unlike everything else in this app, these are often genuinely in active use for real development work, not disposable cache — only select a platform you're sure you don't need.",
                ifYouDeleteIt: "This is permanent the moment you confirm — it does not go through the Trash. Xcode has to fully redownload that OS version (several GB) the next time you need it, and any simulator devices built on it (shown per item above) would need to be re-created. If an item says no Xcode was found on this Mac, we can only show it, not remove it — reinstalling Xcode (even temporarily) would let you remove it properly.",
                allowedRoots: [],
                scan: { ScanHelpers.simulatorPlatformRuntimeVolumes() }
            ),
            CleanupCategory(
                id: "docker-vms", name: "Docker Desktop VM Disk Images", icon: "cube.box",
                tier: .advanced,
                shortDescription: "Docker's entire virtual machine disk — every image, container, and volume you've pulled or built.",
                whatItIs: "Docker Desktop runs a Linux virtual machine to run containers, and stores its entire virtual disk (all downloaded images, containers, and volumes) in one place here.",
                whyThisTier: "This can contain real, hard-to-reproduce work: database volumes, custom-built images, container state. It is not just a cache in the usual sense.",
                ifYouDeleteIt: "Every Docker image, container, and volume is gone — as if you'd freshly installed Docker. Consider running \"docker system prune\" from Docker Desktop first, which safely removes only unused data.",
                allowedRoots: ["\(home)/Library/Containers/com.docker.docker/Data/vms"],
                scan: { ScanHelpers.itemsFromChildren(of: "\(home)/Library/Containers/com.docker.docker/Data/vms") }
            ),
        ]
    }
}
