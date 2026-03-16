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
        // Check for bundled mole inside app Resources
        if let resourcePath = Bundle.main.resourcePath {
            let bundledMole = resourcePath + "/mole/mole"
            if FileManager.default.isExecutableFile(atPath: bundledMole) {
                return bundledMole
            }
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

    func runMoleJSON<T: Decodable>(_ command: String, arguments: [String] = [], timeout: TimeInterval? = nil) async throws -> T {
        let stdout = try await runMoleProcess(command, arguments: arguments, timeout: timeout)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: Data(stdout.utf8))
        } catch {
            throw MoleBridgeError.parseError(error.localizedDescription)
        }
    }

    func runMoleText(_ command: String, arguments: [String] = [], timeout: TimeInterval? = nil, feedStdin: Bool = false) async throws -> String {
        let stdout = try await runMoleProcess(command, arguments: arguments, timeout: timeout, feedStdin: feedStdin)
        return stripANSI(stdout)
    }

    private func runMoleProcess(_ command: String, arguments: [String], timeout: TimeInterval? = nil, feedStdin: Bool = false) async throws -> String {
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

        // Feed stdin with newlines to pass interactive prompts
        if feedStdin {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            DispatchQueue.global().async {
                let newline = Data("\n".utf8)
                for _ in 0..<100 {
                    stdinPipe.fileHandleForWriting.write(newline)
                    Thread.sleep(forTimeInterval: 0.5)
                }
                stdinPipe.fileHandleForWriting.closeFile()
            }
        }

        let effectiveTimeout = timeout ?? timeoutSeconds

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
                deadline: .now() + effectiveTimeout,
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
        try await runMoleJSON("analyze", arguments: ["--json", path], timeout: 120)
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

    // MARK: - Smart Clean (Mole-backed)

    func scanForCleanables() async -> ([CleanSection], CleanSummary) {
        guard let output = try? await runMoleText("clean", arguments: ["--dry-run"], timeout: 120, feedStdin: true) else {
            return ([], CleanSummary())
        }
        return parseDryRunOutput(output)
    }

    func scanForCleanablesStreaming(onUpdate: @escaping @Sendable ([CleanSection], CleanSummary, String) -> Void) async -> ([CleanSection], CleanSummary) {
        guard let path = molePath else { return ([], CleanSummary()) }

        let process = Process()
        let stdoutPipe = Pipe()
        let stdinPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["clean", "--dry-run"]
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        process.standardInput = stdinPipe

        // Feed stdin
        DispatchQueue.global().async {
            let newline = Data("\n".utf8)
            for _ in 0..<200 {
                stdinPipe.fileHandleForWriting.write(newline)
                Thread.sleep(forTimeInterval: 0.3)
            }
            stdinPipe.fileHandleForWriting.closeFile()
        }

        do {
            try process.run()
        } catch {
            return ([], CleanSummary())
        }

        var sections: [CleanSection] = []
        var currentSection: CleanSection?
        var summary = CleanSummary()
        var buffer = ""
        var currentActivity = ""

        let handle = stdoutPipe.fileHandleForReading

        while process.isRunning || handle.availableData.count > 0 {
            let data = handle.availableData
            if data.isEmpty { break }

            guard let chunk = String(data: data, encoding: .utf8) else { continue }
            buffer += chunk

            while let newlineRange = buffer.range(of: "\n") {
                let rawLine = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
                buffer = String(buffer[newlineRange.upperBound...])

                let line = stripANSI(rawLine).trimmingCharacters(in: .whitespaces)
                if line.isEmpty { continue }

                // Section header
                if line.hasPrefix("➤") {
                    if let section = currentSection, !section.items.isEmpty {
                        sections.append(section)
                    }
                    let name = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                    currentSection = CleanSection(name: name)
                    currentActivity = "Scanning \(name)..."
                    onUpdate(sections, summary, currentActivity)
                    continue
                }

                // Cleanable item
                if line.hasPrefix("→") {
                    let content = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                    guard content.contains("dry") else { continue }

                    let parts = content.components(separatedBy: ",")
                    let name: String
                    let sizeText: String
                    let sizeBytes: Int64

                    if parts.count >= 2 {
                        name = parts[0].trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: " dry", with: "")
                        sizeText = parts[1].trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: " dry", with: "")
                        sizeBytes = parseHumanSize(sizeText)
                    } else {
                        name = content.replacingOccurrences(of: " dry", with: "")
                        sizeText = ""
                        sizeBytes = 0
                    }

                    if sizeBytes > 0 {
                        currentSection?.items.append(CleanItem(
                            name: name, size: sizeBytes, sizeText: sizeText
                        ))
                        // Update with current state
                        var allSections = sections
                        if let cs = currentSection, !cs.items.isEmpty {
                            allSections.append(cs)
                        }
                        onUpdate(allSections, summary, currentActivity)
                    }
                    continue
                }

                // Summary
                if line.contains("Potential space:") || line.contains("Space freed:") {
                    if let sizeMatch = line.range(of: #"[\d.]+[KMGTP]?B"#, options: .regularExpression) {
                        summary.totalSize = String(line[sizeMatch])
                    }
                    if let itemMatch = line.range(of: #"Items: (\d+)"#, options: .regularExpression) {
                        let numStr = line[itemMatch].components(separatedBy: " ").last ?? "0"
                        summary.itemCount = Int(numStr) ?? 0
                    }
                    if let catMatch = line.range(of: #"Categories: (\d+)"#, options: .regularExpression) {
                        let numStr = line[catMatch].components(separatedBy: " ").last ?? "0"
                        summary.categoryCount = Int(numStr) ?? 0
                    }
                }
            }
        }

        process.waitUntilExit()

        if let section = currentSection, !section.items.isEmpty {
            sections.append(section)
        }

        return (sections, summary)
    }

    func runClean() async throws -> String {
        try await runMoleText("clean", timeout: 300, feedStdin: true)
    }

    func runCleanStreaming(onActivity: @escaping @Sendable (String) -> Void) async throws -> String {
        guard let path = molePath else { throw MoleBridgeError.moleNotInstalled }

        let process = Process()
        let stdoutPipe = Pipe()
        let stdinPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["clean"]
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        process.standardInput = stdinPipe

        DispatchQueue.global().async {
            let newline = Data("\n".utf8)
            for _ in 0..<600 {
                stdinPipe.fileHandleForWriting.write(newline)
                Thread.sleep(forTimeInterval: 0.5)
            }
            stdinPipe.fileHandleForWriting.closeFile()
        }

        try process.run()

        var buffer = ""
        var lastActivity = ""
        let handle = stdoutPipe.fileHandleForReading

        while process.isRunning || handle.availableData.count > 0 {
            let data = handle.availableData
            if data.isEmpty { break }

            guard let chunk = String(data: data, encoding: .utf8) else { continue }
            buffer += chunk

            while let newlineRange = buffer.range(of: "\n") {
                let rawLine = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
                buffer = String(buffer[newlineRange.upperBound...])

                let line = stripANSI(rawLine).trimmingCharacters(in: .whitespaces)
                if line.isEmpty { continue }

                // Section headers
                if line.hasPrefix("➤") {
                    let name = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                    lastActivity = "Cleaning \(name)..."
                    onActivity(lastActivity)
                }

                // Completed items
                if line.hasPrefix("✓") {
                    let detail = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                    if !detail.isEmpty {
                        lastActivity = detail
                        onActivity(lastActivity)
                    }
                }

                // Summary line
                if line.contains("Space freed:") {
                    onActivity(line)
                }
            }
        }

        process.waitUntilExit()
        return stripANSI(buffer)
    }

    private func parseDryRunOutput(_ output: String) -> ([CleanSection], CleanSummary) {
        var sections: [CleanSection] = []
        var currentSection: CleanSection?
        var summary = CleanSummary()

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Section header: ➤ Category name
            if trimmed.hasPrefix("➤") {
                if let section = currentSection, !section.items.isEmpty {
                    sections.append(section)
                }
                let name = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
                currentSection = CleanSection(name: name)
                continue
            }

            // Cleanable item: → Name [N items], SIZE dry
            if trimmed.hasPrefix("→") {
                let content = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)

                // Skip lines that just say "would clean" with no size
                guard content.contains("dry") else {
                    // Still add items like "npm cache · would clean" as info
                    continue
                }

                // Parse: "User app cache 151 items, 5.64GB dry"
                let parts = content.components(separatedBy: ",")
                let name: String
                let sizeText: String
                let sizeBytes: Int64

                if parts.count >= 2 {
                    name = parts[0].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: " dry", with: "")
                    sizeText = parts[1].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: " dry", with: "")
                    sizeBytes = parseHumanSize(sizeText)
                } else {
                    name = content.replacingOccurrences(of: " dry", with: "")
                    sizeText = ""
                    sizeBytes = 0
                }

                // Skip 0-byte items
                if sizeBytes > 0 {
                    currentSection?.items.append(CleanItem(
                        name: name,
                        size: sizeBytes,
                        sizeText: sizeText
                    ))
                }
                continue
            }

            // Summary line: Potential space: 113.03GB | Items: 742 | Categories: 184
            if trimmed.contains("Potential space:") || trimmed.contains("Space freed:") {
                if let sizeMatch = trimmed.range(of: #"[\d.]+[KMGTP]?B"#, options: .regularExpression) {
                    summary.totalSize = String(trimmed[sizeMatch])
                }
                if let itemMatch = trimmed.range(of: #"Items: (\d+)"#, options: .regularExpression) {
                    let numStr = trimmed[itemMatch].components(separatedBy: " ").last ?? "0"
                    summary.itemCount = Int(numStr) ?? 0
                }
                if let catMatch = trimmed.range(of: #"Categories: (\d+)"#, options: .regularExpression) {
                    let numStr = trimmed[catMatch].components(separatedBy: " ").last ?? "0"
                    summary.categoryCount = Int(numStr) ?? 0
                }
            }
        }

        // Add last section
        if let section = currentSection, !section.items.isEmpty {
            sections.append(section)
        }

        return (sections, summary)
    }

    private func parseHumanSize(_ text: String) -> Int64 {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return 0 }

        let number: Double
        let multiplier: Double

        if cleaned.hasSuffix("TB") {
            number = Double(cleaned.dropLast(2)) ?? 0
            multiplier = 1_000_000_000_000
        } else if cleaned.hasSuffix("GB") {
            number = Double(cleaned.dropLast(2)) ?? 0
            multiplier = 1_000_000_000
        } else if cleaned.hasSuffix("Gi") {
            number = Double(cleaned.dropLast(2)) ?? 0
            multiplier = 1_073_741_824
        } else if cleaned.hasSuffix("MB") {
            number = Double(cleaned.dropLast(2)) ?? 0
            multiplier = 1_000_000
        } else if cleaned.hasSuffix("KB") {
            number = Double(cleaned.dropLast(2)) ?? 0
            multiplier = 1_000
        } else if cleaned.hasSuffix("B") {
            number = Double(cleaned.dropLast(1)) ?? 0
            multiplier = 1
        } else {
            number = Double(cleaned) ?? 0
            multiplier = 1
        }

        return Int64(number * multiplier)
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

}
