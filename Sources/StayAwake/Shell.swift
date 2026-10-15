import Foundation

enum Shell {
    /// Runs a command synchronously and returns its exit code and combined stdout/stderr.
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> (code: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, "\(error)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Reads power settings; no privileges needed.
    static func pmset(_ args: [String]) -> String {
        run("/usr/bin/pmset", args).output
    }

    /// Changes power settings via `sudo -n`, which never prompts for a password:
    /// it fails immediately if the sudoers rule installed by `install.sh` is missing.
    @discardableResult
    static func privilegedPMSet(_ args: [String]) -> Bool {
        run("/usr/bin/sudo", ["-n", "/usr/bin/pmset"] + args).code == 0
    }
}
