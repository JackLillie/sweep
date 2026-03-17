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
                    openToPage(.smartClean)
                }

                MenuBarActionButton(icon: "square.grid.2x2", label: "Applications", color: .orange) {
                    openToPage(.applications)
                }

                MenuBarActionButton(icon: "internaldrive", label: "Storage", color: .green) {
                    openToPage(.storage)
                }

                MenuBarActionButton(icon: "lock.shield", label: "Permissions", color: .red) {
                    openToPage(.permissions)
                }

                MenuBarActionButton(icon: "network", label: "Flush DNS Cache", color: .blue) {
                    Task { await viewModel.flushDNS() }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)

            Divider()

            VStack(spacing: 2) {
                MenuBarActionButton(icon: "macwindow", label: "Show Main Window", color: .primary) {
                    openMainWindow()
                }

                MenuBarActionButton(icon: "power", label: "Quit Sweep", color: .primary) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .frame(width: 280)
    }

    private func openToPage(_ item: NavigationItem) {
        viewModel.selectedItem = item
        openMainWindow()
    }

    private func openMainWindow() {
        dismiss()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color.primary.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
