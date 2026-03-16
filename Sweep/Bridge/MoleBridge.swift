import Foundation

enum MoleBridgeError: LocalizedError {
    case moleNotInstalled
    case commandFailed(exitCode: Int32, stderr: String)
    case parseError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .moleNotInstalled:
            "Mole binary not found"
        case .commandFailed(let code, let stderr):
            "Command failed (\(code)): \(stderr)"
        case .parseError(let detail):
            "Parse error: \(detail)"
        case .timeout:
            "Command timed out"
        }
    }
}

actor MoleBridge {

    private var molePath: String?
    private let timeoutSeconds: TimeInterval

    init(timeoutSeconds: TimeInterval = 30) {
        self.timeoutSeconds = timeoutSeconds
        self.molePath = nil
        self.molePath = findMoleBinary()
    }

    // MARK: - Binary Discovery

    private func findMoleBinary() -> String? {
        if let bundled = Bundle.main.path(forResource: "mole", ofType: nil) {
            return bundled
        }

        let brewPath = "/opt/homebrew/bin/mole"
        if FileManager.default.fileExists(atPath: brewPath) {
            return brewPath
        }

        let intelBrewPath = "/usr/local/bin/mole"
        if FileManager.default.fileExists(atPath: intelBrewPath) {
            return intelBrewPath
        }

        if let path = runShell("/usr/bin/which", arguments: ["mole"]) {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    var isAvailable: Bool {
        molePath != nil
    }

    func recheckAvailability() -> Bool {
        molePath = findMoleBinary()
        return isAvailable
    }

    // MARK: - Core Runners

    func runMoleJSON<T: Decodable>(_ command: String, arguments: [String] = []) async throws -> T {
        let stdout = try await runMoleProcess(command, arguments: arguments)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: Data(stdout.utf8))
        } catch {
            throw MoleBridgeError.parseError(error.localizedDescription)
        }
    }

    func runMoleText(_ command: String, arguments: [String] = []) async throws -> String {
        let stdout = try await runMoleProcess(command, arguments: arguments)
        return stripANSI(stdout)
    }

    private func runMoleProcess(_ command: String, arguments: [String]) async throws -> String {
        guard let path = molePath else {
            throw MoleBridgeError.moleNotInstalled
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = [command] + arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            let resumed = NSLock()
            var didResume = false

            func resumeOnce(with result: Result<String, Error>) {
                resumed.lock()
                defer { resumed.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let timeoutItem = DispatchWorkItem {
                process.terminate()
                resumeOnce(with: .failure(MoleBridgeError.timeout))
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeoutSeconds,
                execute: timeoutItem
            )

            process.terminationHandler = { _ in
                timeoutItem.cancel()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus != 0 {
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    resumeOnce(with: .failure(
                        MoleBridgeError.commandFailed(exitCode: process.terminationStatus, stderr: stderr)
                    ))
                    return
                }

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                resumeOnce(with: .success(stdout))
            }

            do {
                try process.run()
            } catch {
                timeoutItem.cancel()
                resumeOnce(with: .failure(MoleBridgeError.moleNotInstalled))
            }
        }
    }

    // MARK: - Convenience Commands

    func fetchStatus() async -> MoleStatus {
        (try? await runMoleJSON("status", arguments: ["--json"]) as MoleStatus) ?? MoleStatus()
    }

    func analyze(path: String) async throws -> MoleAnalysis {
        try await runMoleJSON("analyze", arguments: ["--json", path])
    }

    func cleanDryRun() async throws -> String {
        try await runMoleText("clean", arguments: ["--dry-run"])
    }

    func clean() async throws -> String {
        try await runMoleText("clean")
    }

    // MARK: - Quick Actions

    func emptyTrash() async throws {
        let trashPath = NSHomeDirectory() + "/.Trash"
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: trashPath) else { return }
        for item in contents {
            try fm.removeItem(atPath: trashPath + "/" + item)
        }
    }

    func flushDNS() async throws {
        let script = """
        do shell script "dscacheutil -flushcache && killall -HUP mDNSResponder" with administrator privileges
        """
        try runAppleScript(script)
    }

    func freeMemory() async throws {
        let script = """
        do shell script "sudo purge" with administrator privileges
        """
        try runAppleScript(script)
    }

    private func runAppleScript(_ source: String) throws {
        guard let script = NSAppleScript(source: source) else {
            throw MoleBridgeError.commandFailed(exitCode: -1, stderr: "Failed to create AppleScript")
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
            throw MoleBridgeError.commandFailed(exitCode: -1, stderr: message)
        }
    }

    // MARK: - Scanning

    func scanForCleanables() -> [CleanableItem] {
        var items: [CleanableItem] = []

        let cacheDir = NSHomeDirectory() + "/Library/Caches"
        if let size = directorySize(cacheDir) {
            items.append(CleanableItem(
                name: "User Cache",
                category: .userCache,
                size: size,
                path: cacheDir
            ))
        }

        let logsDir = NSHomeDirectory() + "/Library/Logs"
        if let size = directorySize(logsDir) {
            items.append(CleanableItem(
                name: "User Logs",
                category: .logs,
                size: size,
                path: logsDir
            ))
        }

        let derivedData = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
        if let size = directorySize(derivedData) {
            items.append(CleanableItem(
                name: "Xcode Derived Data",
                category: .xcode,
                size: size,
                path: derivedData
            ))
        }

        let trashDir = NSHomeDirectory() + "/.Trash"
        if let size = directorySize(trashDir) {
            items.append(CleanableItem(
                name: "Trash",
                category: .trash,
                size: size,
                path: trashDir
            ))
        }

        let systemCacheDir = "/Library/Caches"
        if let size = directorySize(systemCacheDir) {
            items.append(CleanableItem(
                name: "System Cache",
                category: .systemCache,
                size: size,
                path: systemCacheDir
            ))
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Legacy Command Runner

    func runMoleCommand(_ command: String, arguments: [String] = []) -> String? {
        guard let path = molePath else { return nil }
        return runShell(path, arguments: [command] + arguments)
    }

    // MARK: - Helpers

    private static let ansiPattern = try! NSRegularExpression(pattern: "\u{1B}\\[[0-9;]*[a-zA-Z]")

    private func stripANSI(_ string: String) -> String {
        let range = NSRange(string.startIndex..., in: string)
        return Self.ansiPattern.stringByReplacingMatches(in: string, range: range, withTemplate: "")
    }

    private func runShell(_ command: String, arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func directorySize(_ path: String) -> Int64? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return nil }

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return nil }

        var totalSize: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.totalFileAllocatedSize else { continue }
            totalSize += Int64(size)
        }

        return totalSize > 0 ? totalSize : nil
    }

}
