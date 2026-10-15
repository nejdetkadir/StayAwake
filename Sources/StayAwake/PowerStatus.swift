import Foundation

/// A power source section in `pmset -g custom` output, with the flag used to write to it.
enum PowerProfile: String, CaseIterable, Sendable {
    case battery = "-b"
    case ac = "-c"
}

typealias PowerProfiles = [PowerProfile: [String: String]]

enum PMSetParser {
    /// Parses `pmset -g custom` output into per-profile key/value pairs.
    static func parseCustom(_ text: String) -> PowerProfiles {
        var result: PowerProfiles = [:]
        var current: PowerProfile?
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if !raw.hasPrefix(" "), !raw.hasPrefix("\t"), line.hasSuffix(":") {
                if line.hasPrefix("Battery") {
                    current = .battery
                } else if line.hasPrefix("AC") {
                    current = .ac
                } else {
                    current = nil  // e.g. "UPS Power:"
                }
                continue
            }
            let parts = fields(line)
            if let current, parts.count >= 2 {
                result[current, default: [:]][parts[0]] = parts[1]
            }
        }
        return result
    }

    /// A backup is only worth restoring if at least one profile has a numeric `sleep` value.
    static func isUsableBackup(_ profiles: PowerProfiles) -> Bool {
        profiles.values.contains { $0["sleep"].flatMap { Int($0) } != nil }
    }

    static func fields(_ line: String) -> [String] {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    }
}

struct PowerStatus: Equatable, Sendable {
    var sleepDisabledForIdle = false  // `sleep 0`
    var sleepDisabledForLid = false  // `SleepDisabled 1`
    var onAC = false

    var isAwake: Bool { sleepDisabledForIdle && sleepDisabledForLid }

    /// Builds a status from `pmset -g` and `pmset -g batt` output.
    init(settings: String, battery: String) {
        for raw in settings.components(separatedBy: "\n") {
            let parts = PMSetParser.fields(raw.trimmingCharacters(in: .whitespaces))
            guard parts.count >= 2 else { continue }
            switch parts[0] {
            case "sleep": sleepDisabledForIdle = parts[1] == "0"
            case "SleepDisabled": sleepDisabledForLid = parts[1] == "1"
            default: break
            }
        }
        onAC = battery.contains("AC Power")
    }

    static func current() -> PowerStatus {
        PowerStatus(settings: Shell.pmset(["-g"]), battery: Shell.pmset(["-g", "batt"]))
    }
}
