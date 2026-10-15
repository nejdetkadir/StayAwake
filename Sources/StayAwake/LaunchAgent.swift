import Foundation

/// Starts the app at login through a per-user LaunchAgent.
enum LaunchAgent {
    static let label = "com.nejdetkadirbektas.stayawake"
    static var path: String { NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist" }

    static func propertyList(executablePath: String, bundleIdentifier: String?) -> [String: Any] {
        var plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        if let bundleIdentifier {
            // Shows the app's name instead of the label in System Settings > Login Items.
            plist["AssociatedBundleIdentifiers"] = [bundleIdentifier]
        }
        return plist
    }

    static func setEnabled(_ enabled: Bool) {
        let fm = FileManager.default
        guard enabled else {
            try? fm.removeItem(atPath: path)
            return
        }
        guard let executable = Bundle.main.executablePath else { return }
        let plist = propertyList(executablePath: executable, bundleIdentifier: Bundle.main.bundleIdentifier)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        else { return }
        // Skip unchanged writes so macOS doesn't post "Background Items Added" on every launch.
        if fm.contents(atPath: path) == data { return }
        try? fm.createDirectory(
            atPath: NSHomeDirectory() + "/Library/LaunchAgents",
            withIntermediateDirectories: true
        )
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}
