import SwiftUI

struct MenuBarView: View {
    @State private var systemInfo = SystemInfo()
    @State private var isLoading = true

    private let bridge = MoleBridge()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Sweep")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(systemInfo.osVersion)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Quick stats
            VStack(spacing: 8) {
                MenuBarStatRow(
                    icon: "cpu",
                    label: "CPU",
                    value: "\(Int(systemInfo.cpuUsage * 100))%",
                    color: .blue
                )

                MenuBarStatRow(
                    icon: "memorychip",
                    label: "Memory",
                    value: String(format: "%.1f / %.0f GB", systemInfo.memoryUsed, systemInfo.memoryTotal),
                    color: .green
                )

                MenuBarStatRow(
                    icon: "internaldrive",
                    label: "Disk",
                    value: String(format: "%.0f GB free", systemInfo.diskFree),
                    color: .orange
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Quick actions
            VStack(spacing: 2) {
                MenuBarActionButton(icon: "sparkles", label: "Smart Clean", color: .purple) {
                    // TODO: Quick clean
                }

                MenuBarActionButton(icon: "trash", label: "Empty Trash", color: .red) {
                    // TODO: Empty trash
                }

                MenuBarActionButton(icon: "memorychip", label: "Free Memory", color: .green) {
                    // TODO: Purge memory
                }

                MenuBarActionButton(icon: "network", label: "Flush DNS Cache", color: .blue) {
                    // TODO: Flush DNS
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)

            Divider()

            // Open main window
            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title != "Sweep" || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Sweep")
                    Spacer()
                    Text("⌘O")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Sweep")
                    Spacer()
                    Text("⌘Q")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(width: 280)
        .task {
            let info = await bridge.fetchSystemInfo()
            systemInfo = info
            isLoading = false
        }
    }
}

// MARK: - Stat Row

struct MenuBarStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 12, design: .monospaced))
        }
    }
}

// MARK: - Action Button

struct MenuBarActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 12))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color.primary.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
