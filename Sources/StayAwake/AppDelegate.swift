import AppKit
import IOKit.pwr_mgt

private enum DefaultsKey {
    /// The mode the user last chose; re-applied on every launch.
    static let desiredAwake = "desiredOn"
    static let launchAtLogin = "launchAtLogin"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let defaults = UserDefaults.standard
    private var assertions: [IOPMAssertionID] = []
    private var timer: Timer?
    private var isBusy = false
    private var lastError: AwakeMode.Failure?
    private var hasPromptedForPermission = false
    private var isMenuOpen = false

    private var desiredAwake: Bool {
        get { defaults.bool(forKey: DefaultsKey.desiredAwake) }
        set { defaults.set(newValue, forKey: DefaultsKey.desiredAwake) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: [DefaultsKey.launchAtLogin: true])
        menu.delegate = self
        statusItem.menu = menu

        // First launch: adopt whatever mode the system is already in.
        if defaults.object(forKey: DefaultsKey.desiredAwake) == nil {
            desiredAwake = PowerStatus.current().isAwake
        }
        LaunchAgent.setEnabled(defaults.bool(forKey: DefaultsKey.launchAtLogin))
        apply(desiredAwake, persist: false)

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshIcon() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Power assertions

    /// Extra safety net while the app is running, on top of the pmset settings.
    private func holdAssertions(_ hold: Bool) {
        if hold, assertions.isEmpty {
            for type in [kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionTypePreventSystemSleep] {
                var id: IOPMAssertionID = 0
                let result = IOPMAssertionCreateWithName(
                    type as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "StayAwake keeps this Mac awake" as CFString,
                    &id
                )
                if result == kIOReturnSuccess { assertions.append(id) }
            }
        } else if !hold {
            assertions.forEach { IOPMAssertionRelease($0) }
            assertions.removeAll()
        }
    }

    // MARK: - Applying

    private func apply(_ awake: Bool, persist: Bool = true) {
        guard !isBusy else { return }
        if persist { desiredAwake = awake }
        holdAssertions(awake)
        isBusy = true
        refreshIcon()
        Task {
            let error = await Task.detached(priority: .userInitiated) { AwakeMode.apply(awake) }.value
            isBusy = false
            lastError = error
            refreshIcon()
            if isMenuOpen { rebuildMenu() }
            // Ask once per launch on its own, and every time the user toggles.
            if error == .noPermission, persist || !hasPromptedForPermission {
                requestPermission()
            }
        }
    }

    // MARK: - Permission

    /// Explains why the permission is needed, then shows the macOS administrator prompt.
    @objc private func requestPermission() {
        hasPromptedForPermission = true
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Allow StayAwake to change sleep settings?"
        alert.informativeText = """
            StayAwake uses pmset to turn sleep on and off. To do that without asking for your password \
            every time, it adds a rule that lets your account run /usr/bin/pmset as administrator.

            You'll be asked for your password once.
            """
        alert.addButton(withTitle: "Allow…")
        alert.addButton(withTitle: "Not Now")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        switch PermissionSetup.grant() {
        case .granted:
            lastError = nil
            apply(desiredAwake, persist: false)
        case .cancelled:
            break
        case .failed(let message):
            let failure = NSAlert()
            failure.alertStyle = .warning
            failure.messageText = "Couldn't set up the permission"
            failure.informativeText = message
            failure.runModal()
        }
    }

    // MARK: - Status item

    /// A problem worth showing in red: the last apply failed, or the system drifted from the
    /// chosen mode (e.g. pmset was changed by something else). Never reported while applying.
    private func problem(for status: PowerStatus) -> String? {
        if isBusy { return nil }
        if let lastError { return lastError.message }
        if status.isAwake != desiredAwake {
            return desiredAwake
                ? "Stay Awake is on, but the Mac can sleep"
                : "Stay Awake is off, but sleep is still disabled"
        }
        return nil
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let status = PowerStatus.current()
        let symbol: String
        let color: NSColor?
        let tooltip: String
        if isBusy {
            (symbol, color, tooltip) = ("hourglass", nil, "StayAwake: applying…")
        } else if let problem = problem(for: status) {
            (symbol, color, tooltip) = ("exclamationmark.triangle.fill", .systemRed, "StayAwake: \(problem)")
        } else if status.isAwake {
            (symbol, color, tooltip) = ("cup.and.saucer.fill", .systemGreen, "StayAwake: Mac will not sleep")
        } else {
            (symbol, color, tooltip) = ("cup.and.saucer", .systemGray, "StayAwake: normal sleep")
        }
        var image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        if let color {
            image = image?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color]))
            image?.isTemplate = false
        } else {
            image?.isTemplate = true  // Match the menu bar while a change is in progress.
        }
        button.image = image
        button.toolTip = tooltip
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        rebuildMenu()
        refreshIcon()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let status = PowerStatus.current()

        if isBusy {
            menu.addItem(infoItem("… Applying"))
        } else {
            let text = status.isAwake ? "● Awake: sleep and lid sleep are off" : "● Normal: Mac can sleep"
            let title = NSMutableAttributedString(string: text, attributes: [.font: NSFont.menuFont(ofSize: 0)])
            title.addAttribute(
                .foregroundColor,
                value: status.isAwake ? NSColor.systemGreen : NSColor.systemGray,
                range: NSRange(location: 0, length: 1)
            )
            menu.addItem(infoItem(title))
        }
        if let problem = problem(for: status) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.systemRed,
            ]
            menu.addItem(infoItem(NSAttributedString(string: "⚠︎ \(problem)", attributes: attributes)))
        }
        if lastError == .noPermission, !isBusy {
            let grant = NSMenuItem(title: "Grant Permission…", action: #selector(requestPermission), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        }
        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: "Stay Awake",
            action: isBusy ? nil : #selector(toggleAwake),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = status.isAwake ? .on : .off
        menu.addItem(toggle)
        if status.isAwake, !status.onAC {
            menu.addItem(infoItem("⚠︎ On battery: don't put the Mac in a bag with the lid closed"))
        }
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = defaults.bool(forKey: DefaultsKey.launchAtLogin) ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "Quit StayAwake", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        infoItem(NSAttributedString(string: title))
    }

    private func infoItem(_ title: NSAttributedString) -> NSMenuItem {
        let item = NSMenuItem(title: title.string, action: nil, keyEquivalent: "")
        if title.length > 0, !title.attributes(at: 0, effectiveRange: nil).isEmpty {
            item.attributedTitle = title
        }
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc private func toggleAwake() {
        apply(!PowerStatus.current().isAwake)
    }

    @objc private func toggleLaunchAtLogin() {
        let enabled = !defaults.bool(forKey: DefaultsKey.launchAtLogin)
        defaults.set(enabled, forKey: DefaultsKey.launchAtLogin)
        LaunchAgent.setEnabled(enabled)
    }

    /// Quitting leaves the pmset settings as they are, so the Mac stays in the chosen mode.
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
