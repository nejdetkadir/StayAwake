import AppKit

@main
struct StayAwakeApp {
    @MainActor
    static func main() {
        // Single instance: the LaunchAgent and a manual launch must not create two menu bar icons.
        if let bundleID = Bundle.main.bundleIdentifier {
            let pid = ProcessInfo.processInfo.processIdentifier
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if others.contains(where: { $0.processIdentifier != pid }) { exit(0) }
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()  // NSApplication.delegate is weak; keep it alive for the run loop.
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
