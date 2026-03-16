import SwiftUI

struct OverviewView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back")
                            .font(.system(size: 28, weight: .bold))
                        Text(viewModel.systemInfo.hostname)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(viewModel.systemInfo.osVersion)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(viewModel.systemInfo.macModel)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 4)

                // Gauges row
                HStack(spacing: 16) {
                    GaugeCard(
                        title: "CPU",
                        value: viewModel.systemInfo.cpuUsage,
                        subtitle: "\(Int(viewModel.systemInfo.cpuUsage * 100))% used",
                        color: gaugeColor(viewModel.systemInfo.cpuUsage)
                    )

                    GaugeCard(
                        title: "Memory",
                        value: viewModel.systemInfo.memoryPercentage,
                        subtitle: String(format: "%.1f / %.0f GB", viewModel.systemInfo.memoryUsed, viewModel.systemInfo.memoryTotal),
                        color: gaugeColor(viewModel.systemInfo.memoryPercentage)
                    )

                    GaugeCard(
                        title: "Storage",
                        value: viewModel.systemInfo.diskPercentage,
                        subtitle: String(format: "%.0f GB free", viewModel.systemInfo.diskFree),
                        color: gaugeColor(viewModel.systemInfo.diskPercentage)
                    )
                }

                // Uptime
                GroupBox {
                    HStack {
                        Label {
                            Text("System Uptime")
                                .font(.system(size: 13, weight: .medium))
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                        Text(uptimeString)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                // Quick actions
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            QuickActionButton(
                                title: "Smart Clean",
                                icon: "sparkles",
                                color: .purple
                            ) {
                                Task { await viewModel.scanForCleanables() }
                            }

                            QuickActionButton(
                                title: "Empty Trash",
                                icon: "trash",
                                color: .red
                            ) {
                                // TODO: Wire to bridge
                            }

                            QuickActionButton(
                                title: "Flush DNS",
                                icon: "network",
                                color: .blue
                            ) {
                                // TODO: Wire to bridge
                            }

                            QuickActionButton(
                                title: "Free Memory",
                                icon: "memorychip",
                                color: .green
                            ) {
                                // TODO: Wire to bridge
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var uptimeString: String {
        let d = viewModel.systemInfo.uptimeDays
        let h = viewModel.systemInfo.uptimeHours
        if d > 0 {
            return "\(d)d \(h)h"
        }
        return "\(h)h"
    }

    private func gaugeColor(_ value: Double) -> Color {
        if value < 0.5 { return .green }
        if value < 0.8 { return .orange }
        return .red
    }
}

// MARK: - Gauge Card

struct GaugeCard: View {
    let title: String
    let value: Double
    let subtitle: String
    let color: Color

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                Gauge(value: value) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                } currentValueLabel: {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .gaugeStyle(.accessoryCircular)
                .tint(color)
                .scaleEffect(1.4)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.primary.opacity(0.04) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
