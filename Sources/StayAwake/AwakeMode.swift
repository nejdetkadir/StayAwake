import Foundation

/// Switches the system between "stay awake" and the user's original power settings.
/// Everything here blocks on `pmset`, so call it off the main thread.
enum AwakeMode {
    static let backupDirectory = NSHomeDirectory() + "/.stay-awake"
    static let backupPath = backupDirectory + "/pmset-backup.txt"

    /// Settings written to all profiles when enabling. Keys the Mac doesn't support are skipped by pmset.
    static let awakeSettings: [(key: String, value: String)] = [
        ("sleep", "0"), ("disksleep", "0"), ("standby", "0"), ("autopoweroff", "0"),
        ("powernap", "0"), ("tcpkeepalive", "1"), ("womp", "1"),
    ]

    /// Settings copied back from the backup when disabling.
    static let restoredKeys = [
        "sleep", "disksleep", "standby", "autopoweroff", "powernap", "tcpkeepalive", "womp", "autorestart",
    ]

    /// Used only when there is no usable backup.
    static let fallbackSettings: [[String]] = [
        ["-a", "sleep", "1"], ["-a", "disksleep", "10"], ["-a", "standby", "1"],
        ["-a", "powernap", "1"], ["-c", "autorestart", "0"],
    ]

    enum Failure: Error, Equatable {
        case noPermission
        case notApplied

        var message: String {
            switch self {
            case .noPermission: "StayAwake doesn't have permission to change sleep settings"
            case .notApplied: "Could not apply pmset settings"
            }
        }
    }

    /// Applies the requested mode. Returns nil on success.
    static func apply(_ awake: Bool) -> Failure? {
        guard Shell.privilegedPMSet(["-g"]) else { return .noPermission }
        let current = PowerStatus.current().isAwake
        if awake {
            if !current { enable() }
        } else if current || FileManager.default.fileExists(atPath: backupPath) {
            disable()
        }
        return PowerStatus.current().isAwake == awake ? nil : .notApplied
    }

    static func enable() {
        // Only back up while the Mac is not yet in awake mode. Otherwise the backup would hold
        // the "never sleep" values and disabling would never bring sleep back.
        let fm = FileManager.default
        if !fm.fileExists(atPath: backupPath), !PowerStatus.current().isAwake {
            let output = Shell.pmset(["-g", "custom"])
            if PMSetParser.isUsableBackup(PMSetParser.parseCustom(output)) {
                try? fm.createDirectory(atPath: backupDirectory, withIntermediateDirectories: true)
                try? output.write(toFile: backupPath, atomically: true, encoding: .utf8)
            }
        }
        for setting in awakeSettings {
            Shell.privilegedPMSet(["-a", setting.key, setting.value])
        }
        Shell.privilegedPMSet(["-c", "autorestart", "1"])
        Shell.privilegedPMSet(["disablesleep", "1"])
    }

    static func disable() {
        Shell.privilegedPMSet(["disablesleep", "0"])
        let text = (try? String(contentsOfFile: backupPath, encoding: .utf8)) ?? ""
        let backup = PMSetParser.parseCustom(text)
        if PMSetParser.isUsableBackup(backup) {
            for key in restoredKeys {
                for profile in PowerProfile.allCases {
                    // Only numeric values are restored; anything else is skipped.
                    if let value = backup[profile]?[key], Int(value) != nil {
                        Shell.privilegedPMSet([profile.rawValue, key, value])
                    }
                }
            }
        } else {
            fallbackSettings.forEach { Shell.privilegedPMSet($0) }
        }
        // Archive the backup only after a successful restore so a failed attempt can be retried.
        if FileManager.default.fileExists(atPath: backupPath), !PowerStatus.current().isAwake {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            try? FileManager.default.moveItem(
                atPath: backupPath,
                toPath: backupPath + ".restored-" + formatter.string(from: Date())
            )
        }
    }
}
