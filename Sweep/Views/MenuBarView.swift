import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Sweep")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !viewModel.systemInfo.osVersion.isEmpty {
                    Text(viewModel.systemInfo.osVersion)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Quick stats
                VStack(spacing: 8) {
                    MenuBarStatRow(
                        icon: "cpu",
                        label: "CPU",
                        value: "\(Int(viewModel.systemInfo.cpuUsage * 100))%",
                        color: .blue
                    )

                    MenuBarStatRow(
                        icon: "memorychip",
                        label: "Memory",
                        value: String(format: "%.1f / %.0f GB", viewModel.systemInfo.memoryUsed, viewModel.systemInfo.memoryTotal),
                        color: .green
                    )

                    MenuBarStatRow(
                        icon: "internaldrive",
                        label: "Disk",
                        value: String(format: "%.0f GB free", viewModel.systemInfo.diskFree),
                        color: .orange
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider()

            // Quick actions
            VStack(spacing: 2) {
                MenuBarActionButton(icon: "sparkles", label: "Smart Clean", color: .purple) {
                    Task { await viewModel.scanForCleanables() }
                }

                MenuBarActionButton(icon: "trash", label: "Empty Trash", color: .red) {
                    Task { await viewModel.emptyTrash() }
                }

                MenuBarActionButton(icon: "memorychip", label: "Free Memory", color: .green) {
                    Task { await viewModel.freeMemory() }
                }

                MenuBarActionButton(icon: "network", label: "Flush DNS Cache", color: .blue) {
                    Task { await viewModel.flushDNS() }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)

            Divider()

            MenuBarActionButton(icon: "macwindow", label: "Show Main Window", color: .primary) {
                dismiss()
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

            Divider()

            MenuBarActionButton(icon: "power", label: "Quit Sweep", color: .primary) {
                NSApp.terminate(nil)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
        .frame(width: 280)
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
