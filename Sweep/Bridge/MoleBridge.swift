import Foundation

actor MoleBridge {

    /// Path to the embedded or installed mole binary.
    private var molePath: String?

    init() {
        self.molePath = findMoleBinary()
    }

    // MARK: - Binary Discovery

    private func findMoleBinary() -> String? {
        // 1. Check embedded in app bundle
        if let bundled = Bundle.main.path(forResource: "mole", ofType: nil) {
            return bundled
        }

        // 2. Check Homebrew (Apple Silicon)
        let brewPath = "/opt/homebrew/bin/mole"
        if FileManager.default.fileExists(atPath: brewPath) {
            return brewPath
        }

        // 3. Check Homebrew (Intel)
        let intelBrewPath = "/usr/local/bin/mole"
        if FileManager.default.fileExists(atPath: intelBrewPath) {
            return intelBrewPath
        }

        // 4. Try which
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

    // MARK: - System Info

    func fetchSystemInfo() -> SystemInfo {
        var info = SystemInfo()

        // Hostname
        info.hostname = Host.current().localizedName ?? "Mac"

        // macOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        info.osVersion = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        // Mac model
        if let model = runShell("/usr/sbin/sysctl", arguments: ["-n", "hw.model"]) {
            info.macModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Memory
        let physMem = ProcessInfo.processInfo.physicalMemory
        info.memoryTotal = Double(physMem) / 1_073_741_824 // GB

        if let vmStat = runShell("/usr/bin/vm_stat", arguments: []) {
            info.memoryUsed = parseMemoryUsage(vmStat, totalGB: info.memoryTotal)
        }

        // Disk
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            if let totalSize = attrs[.systemSize] as? Int64 {
                info.diskTotal = Double(totalSize) / 1_000_000_000
            }
            if let freeSize = attrs[.systemFreeSize] as? Int64 {
                let totalSize = (attrs[.systemSize] as? Int64) ?? 0
                info.diskUsed = Double(totalSize - freeSize) / 1_000_000_000
            }
        }

        // CPU usage (snapshot)
        if let topOutput = runShell("/usr/bin/top", arguments: ["-l", "1", "-n", "0", "-stats", "cpu"]) {
            info.cpuUsage = parseCPUUsage(topOutput)
        }

        // Uptime
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

    // MARK: - Mole Commands

    func runMoleCommand(_ command: String, arguments: [String] = []) -> String? {
        guard let path = molePath else { return nil }
        return runShell(path, arguments: [command] + arguments)
    }

    // MARK: - Helpers

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

        let pageSize: Double = 16384 // Apple Silicon default
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
