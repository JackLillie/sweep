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
                        statsGrid
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

    // MARK: - Stats Grid

    private var statsGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
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

            GridRow {
                InfoCard(
                    icon: "clock.fill",
                    iconColor: .blue,
                    title: "Uptime",
                    value: uptimeString
                )

                InfoCard(
                    icon: "arrow.up.arrow.down",
                    iconColor: .teal,
                    title: "Network",
                    value: String(format: "↓%.1f ↑%.1f MB/s", viewModel.systemInfo.networkDown, viewModel.systemInfo.networkUp)
                )

                if viewModel.systemInfo.hasBattery {
                    InfoCard(
                        icon: batteryIcon,
                        iconColor: batteryColor,
                        title: "Battery",
                        value: "\(Int(viewModel.systemInfo.batteryPercent))%",
                        subtitle: viewModel.systemInfo.batteryStatus
                    )
                } else {
                    InfoCard(
                        icon: "thermometer.medium",
                        iconColor: .orange,
                        title: "CPU Temp",
                        value: String(format: "%.0f°C", viewModel.systemInfo.cpuTemp)
                    )
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
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 8)

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

                Spacer(minLength: 0)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var subtitle: String = ""

    var body: some View {
        GroupBox {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(iconColor)
                    .frame(height: 36)

                Spacer(minLength: 0)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

