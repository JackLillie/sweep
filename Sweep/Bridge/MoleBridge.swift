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

    func fetchStatus() async throws -> MoleStatus {
        try await runMoleJSON("status")
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

    // MARK: - System Info

    func fetchSystemInfo() -> SystemInfo {
        var info = SystemInfo()

        info.hostname = Host.current().localizedName ?? "Mac"

        let version = ProcessInfo.processInfo.operatingSystemVersion
        info.osVersion = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        if let model = runShell("/usr/sbin/sysctl", arguments: ["-n", "hw.model"]) {
            info.macModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let physMem = ProcessInfo.processInfo.physicalMemory
        info.memoryTotal = Double(physMem) / 1_073_741_824

        if let vmStat = runShell("/usr/bin/vm_stat", arguments: []) {
            info.memoryUsed = parseMemoryUsage(vmStat, totalGB: info.memoryTotal)
        }

        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            if let totalSize = attrs[.systemSize] as? Int64 {
                info.diskTotal = Double(totalSize) / 1_000_000_000
            }
            if let freeSize = attrs[.systemFreeSize] as? Int64 {
                let totalSize = (attrs[.systemSize] as? Int64) ?? 0
                info.diskUsed = Double(totalSize - freeSize) / 1_000_000_000
            }
        }

        if let topOutput = runShell("/usr/bin/top", arguments: ["-l", "1", "-n", "0", "-stats", "cpu"]) {
            info.cpuUsage = parseCPUUsage(topOutput)
        }

        let uptime = ProcessInfo.processInfo.systemUptime
        info.uptimeDays = Int(uptime) / 86400
        info.uptimeHours = (Int(uptime) % 86400) / 3600

        return info
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

    private func parseMemoryUsage(_ vmStatOutput: String, totalGB: Double) -> Double {
        let lines = vmStatOutput.components(separatedBy: "\n")
        var pagesActive: Double = 0
        var pagesWired: Double = 0
        var pagesCompressed: Double = 0

        for line in lines {
            if line.contains("Pages active") {
                pagesActive = extractPageCount(line)
            } else if line.contains("Pages wired") {
                pagesWired = extractPageCount(line)
            } else if line.contains("Pages occupied by compressor") {
                pagesCompressed = extractPageCount(line)
            }
        }

        let pageSize: Double = 16384
        let usedBytes = (pagesActive + pagesWired + pagesCompressed) * pageSize
        return usedBytes / 1_073_741_824
    }

    private func extractPageCount(_ line: String) -> Double {
        let parts = line.components(separatedBy: ":")
        guard parts.count >= 2 else { return 0 }
        let numStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: "")
        return Double(numStr) ?? 0
    }

    private func parseCPUUsage(_ topOutput: String) -> Double {
        let lines = topOutput.components(separatedBy: "\n")
        for line in lines {
            if line.contains("CPU usage") {
                let parts = line.components(separatedBy: ",")
                var totalUsage: Double = 0
                for part in parts {
                    if part.contains("user") || part.contains("sys") {
                        let numStr = part.trimmingCharacters(in: .whitespaces)
                            .components(separatedBy: "%").first?
                            .trimmingCharacters(in: .letters.union(.whitespaces).union(.punctuationCharacters)) ?? "0"
                        totalUsage += Double(numStr) ?? 0
                    }
                }
                return min(totalUsage / 100.0, 1.0)
            }
        }
        return 0
    }
}
