import SwiftUI

struct OverviewView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var refreshTimer: Timer?

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        healthBadge
                        gaugesRow
                        infoRows
                        quickActions
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .scrollContentBackground(.hidden)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("")
        .onAppear { startRefresh() }
        .onDisappear { stopRefresh() }
        .alert("Action Failed", isPresented: showingError, presenting: viewModel.actionError) { _ in
            Button("OK") { viewModel.actionError = nil }
        } message: { error in
            Text(error)
        }
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(viewModel.systemInfo.hostname.isEmpty ? "Overview" : viewModel.systemInfo.hostname)
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            if !viewModel.systemInfo.macModel.isEmpty {
                Text("\(viewModel.systemInfo.macModel) · \(viewModel.systemInfo.osVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Health Score

    private var healthBadge: some View {
        GroupBox {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(healthColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text("\(viewModel.systemInfo.healthScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(healthColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("System Health")
                        .font(.system(size: 13, weight: .semibold))
                    Text(healthSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
    }

    private var healthColor: Color {
        let score = viewModel.systemInfo.healthScore
        if score >= 90 { return .green }
        if score >= 60 { return .orange }
        return .red
    }

    private var healthSubtitle: String {
        let msg = viewModel.systemInfo.healthScoreMsg
        if msg.isEmpty {
            let score = viewModel.systemInfo.healthScore
            if score >= 90 { return "Looking good" }
            if score >= 60 { return "Could be better" }
            return "Needs attention"
        }
        // mole returns e.g. "Good: Disk Almost Full" — strip the rating prefix since we show the score
        if let colonIndex = msg.firstIndex(of: ":") {
            let detail = msg[msg.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            if !detail.isEmpty { return detail }
        }
        return msg
    }

    // MARK: - Gauges

    private var gaugesRow: some View {
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
    }

    // MARK: - Info Rows

    private var infoRows: some View {
        VStack(spacing: 8) {
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
                .padding(.horizontal, 4)
            }

            GroupBox {
                HStack {
                    Label {
                        Text("Network")
                            .font(.system(size: 13, weight: .medium))
                    } icon: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(.teal)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Label(String(format: "%.2f MB/s", viewModel.systemInfo.networkDown), systemImage: "arrow.down")
                        Label(String(format: "%.2f MB/s", viewModel.systemInfo.networkUp), systemImage: "arrow.up")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
            }

            if viewModel.systemInfo.hasBattery {
                GroupBox {
                    HStack {
                        Label {
                            Text("Battery")
                                .font(.system(size: 13, weight: .medium))
                        } icon: {
                            Image(systemName: batteryIcon)
                                .foregroundStyle(batteryColor)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(Int(viewModel.systemInfo.batteryPercent))%")
                                .font(.system(size: 13, design: .monospaced))
                            if !viewModel.systemInfo.batteryStatus.isEmpty {
                                Text(viewModel.systemInfo.batteryStatus)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private var batteryIcon: String {
        let pct = viewModel.systemInfo.batteryPercent
        if viewModel.systemInfo.batteryStatus.lowercased().contains("charg") {
            return "battery.100.bolt"
        }
        if pct >= 75 { return "battery.100" }
        if pct >= 50 { return "battery.75" }
        if pct >= 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        let pct = viewModel.systemInfo.batteryPercent
        if pct >= 50 { return .green }
        if pct >= 20 { return .orange }
        return .red
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                    .padding(.top, 4)

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
                        Task { await viewModel.emptyTrash() }
                    }

                    QuickActionButton(
                        title: "Flush DNS",
                        icon: "network",
                        color: .blue
                    ) {
                        Task { await viewModel.flushDNS() }
                    }

                    QuickActionButton(
                        title: "Free Memory",
                        icon: "memorychip",
                        color: .green
                    ) {
                        Task { await viewModel.freeMemory() }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var uptimeString: String {
        if !viewModel.systemInfo.uptime.isEmpty {
            return viewModel.systemInfo.uptime
        }
        let d = viewModel.systemInfo.uptimeDays
        let h = viewModel.systemInfo.uptimeHours
        if d > 0 { return "\(d)d \(h)h" }
        return "\(h)h"
    }

    private func gaugeColor(_ value: Double) -> Color {
        if value < 0.5 { return .green }
        if value < 0.8 { return .orange }
        return .red
    }

    private func startRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                await viewModel.loadSystemInfo()
            }
        }
    }

    private func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
            VStack(spacing: 8) {
                Gauge(value: value) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .padding(.horizontal, 2)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(color)
                .scaleEffect(1.3)
                .padding(.top, 8)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(isHovering ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovering ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color.primary.opacity(0.04) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
