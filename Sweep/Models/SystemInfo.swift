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
