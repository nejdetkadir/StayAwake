import AppKit

/// Installs the sudoers rule that lets StayAwake run `pmset` without a password,
/// using the standard macOS administrator prompt.
enum PermissionSetup {
    static let sudoersPath = "/etc/sudoers.d/stayawake"

    enum Outcome {
        case granted
        case cancelled
        case failed(String)
    }

    /// The shell script run as root. Returns nil for user names that are unsafe to embed.
    static func installScript(user: String) -> String? {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard !user.isEmpty, user.allSatisfy(allowed.contains) else { return nil }
        return """
            tmp=$(/usr/bin/mktemp) && \
            echo '\(user) ALL=(root) NOPASSWD: /usr/bin/pmset' > "$tmp" && \
            /usr/sbin/visudo -cf "$tmp" && \
            /usr/bin/install -m 0440 -o root -g wheel "$tmp" \(sudoersPath); \
            status=$?; /bin/rm -f "$tmp"; exit $status
            """
    }

    /// Escapes a string for use inside an AppleScript string literal.
    static func appleScriptLiteral(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Shows the administrator prompt and installs the rule. Blocks until the user responds.
    @MainActor
    static func grant() -> Outcome {
        guard let script = installScript(user: NSUserName()) else {
            return .failed("Unsupported user name: \(NSUserName())")
        }
        let source = """
            do shell script \(appleScriptLiteral(script)) \
            with prompt "StayAwake needs permission to change your Mac's sleep settings." \
            with administrator privileges
            """
        var errorInfo: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return .granted }
        if errorInfo[NSAppleScript.errorNumber] as? Int == -128 { return .cancelled }
        return .failed(errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error")
    }
}
