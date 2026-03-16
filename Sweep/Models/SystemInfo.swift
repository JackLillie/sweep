import Foundation

struct SystemInfo {
    var hostname: String = ""
    var macModel: String = ""
    var osVersion: String = ""
    var cpuUsage: Double = 0
    var memoryUsed: Double = 0
    var memoryTotal: Double = 0
    var diskUsed: Double = 0
    var diskTotal: Double = 0
    var uptimeDays: Int = 0
    var uptimeHours: Int = 0
    var uptime: String = ""
    var healthScore: Int = 0
    var healthScoreMsg: String = ""
    var networkDown: Double = 0
    var networkUp: Double = 0
    var batteryPercent: Double = 0
    var batteryStatus: String = ""
    var hasBattery: Bool = false
    var cpuTemp: Double = 0

    var memoryPercentage: Double {
        guard memoryTotal > 0 else { return 0 }
        return memoryUsed / memoryTotal
    }

    var diskPercentage: Double {
        guard diskTotal > 0 else { return 0 }
        return diskUsed / diskTotal
    }

    var diskFree: Double {
        diskTotal - diskUsed
    }

    init() {}

    init(from status: MoleStatus) {
        hostname = status.host.replacingOccurrences(of: ".local", with: "")
        macModel = status.hardware.model
        osVersion = status.hardware.osVersion
        uptime = status.uptime
        healthScore = status.healthScore
        healthScoreMsg = status.healthScoreMsg

        // CPU: mole gives 0-100, views use 0-1
        cpuUsage = status.cpu.usage / 100.0

        // Memory: mole gives bytes, views use GB
        memoryUsed = Double(status.memory.used) / 1_073_741_824
        memoryTotal = Double(status.memory.total) / 1_073_741_824

        // Disk: use first non-external disk
        if let disk = status.disks.first(where: { !$0.external }) ?? status.disks.first {
            diskUsed = Double(disk.used) / 1_000_000_000
            diskTotal = Double(disk.total) / 1_000_000_000
        }

        // Parse uptime string (e.g. "3d 12h 45m") into days/hours
        let parts = status.uptime.components(separatedBy: " ")
        for part in parts {
            if part.hasSuffix("d"), let n = Int(part.dropLast()) { uptimeDays = n }
            if part.hasSuffix("h"), let n = Int(part.dropLast()) { uptimeHours = n }
        }

        // Network: sum all interfaces
        networkDown = status.network.reduce(0) { $0 + $1.rxRateMbs }
        networkUp = status.network.reduce(0) { $0 + $1.txRateMbs }

        // Battery
        if let battery = status.batteries.first {
            hasBattery = true
            batteryPercent = battery.percent
            batteryStatus = battery.status
        }

        cpuTemp = status.thermal.cpuTemp
    }
}

struct CleanableItem: Identifiable {
    let id = UUID()
    let name: String
    let category: CleanableCategory
    let size: Int64
    let path: String
    var isSelected: Bool = true

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum CleanableCategory: String, CaseIterable {
    case systemCache = "System Cache"
    case userCache = "User Cache"
    case logs = "Logs"
    case trash = "Trash"
    case downloads = "Old Downloads"
    case xcode = "Xcode Derived Data"

    var icon: String {
        switch self {
        case .systemCache: "cpu"
        case .userCache: "person.circle"
        case .logs: "doc.text"
        case .trash: "trash"
        case .downloads: "arrow.down.circle"
        case .xcode: "hammer"
        }
    }

    var color: String {
        switch self {
        case .systemCache: "blue"
        case .userCache: "purple"
        case .logs: "orange"
        case .trash: "red"
        case .downloads: "green"
        case .xcode: "indigo"
        }
    }
}

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let size: Int64
    let path: String
    let lastOpened: Date?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var daysSinceLastOpened: Int? {
        guard let lastOpened else { return nil }
        return Calendar.current.dateComponents([.day], from: lastOpened, to: Date()).day
    }
}

struct StorageCategory: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64
    let color: String
    let icon: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct PermissionEntry: Identifiable {
    let id = UUID()
    let appName: String
    let permission: String
    let granted: Bool
    let icon: String
}
