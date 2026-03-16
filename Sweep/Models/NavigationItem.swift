import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case overview
    case smartClean
    case applications
    case storage
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .smartClean: "Smart Clean"
        case .applications: "Applications"
        case .storage: "Storage"
        case .permissions: "Permissions"
        }
    }

    var icon: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .smartClean: "sparkles"
        case .applications: "square.grid.2x2"
        case .storage: "internaldrive"
        case .permissions: "lock.shield"
        }
    }

    var color: Color {
        switch self {
        case .overview: .blue
        case .smartClean: .purple
        case .applications: .orange
        case .storage: .green
        case .permissions: .red
        }
    }
}
