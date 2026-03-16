import SwiftUI

struct SmartCleanView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showCleanConfirm = false
    @State private var hasFullDiskAccess = false

    var body: some View {
        Group {
            if !viewModel.cleanPermissionsChecked {
                permissionsSetupView
            } else if viewModel.isScanning {
                scanningView
            } else if viewModel.isCleaning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cleaning...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.cleanResult != nil {
                cleanCompleteView
            } else if !viewModel.hasCleanableItems && !viewModel.hasScanned {
                emptyStateView
            } else if !viewModel.hasCleanableItems && viewModel.hasScanned {
                nothingFoundView
            } else {
                resultsView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("")
        .alert("Clean Selected Items?", isPresented: $showCleanConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task { await viewModel.runClean() }
            }
        } message: {
            Text("This will permanently remove \(viewModel.formattedCleanableSize) of files. This cannot be undone.")
        }
    }

    // MARK: - Scanning (Live)

    private var scanningView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.cleanSections) { section in
                    LiveScanSectionCard(section: section)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            GroupBox {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.scanActivity)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        if viewModel.totalCleanableSize > 0 {
                            Text("\(viewModel.formattedCleanableSize) found so far")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.purple)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: - Permissions Setup

    private var permissionsSetupView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.purple)

            VStack(spacing: 6) {
                Text("Smart Clean")
                    .font(.system(size: 18, weight: .semibold))
                Text("Sweep scans caches, logs, browser data, dev tools, and more.\nFor a thorough scan, grant Full Disk Access.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            permissionRow(
                icon: "lock.shield.fill",
                title: "Full Disk Access",
                granted: hasFullDiskAccess,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
            )
            .frame(maxWidth: 400)

            if hasFullDiskAccess {
                Button {
                    viewModel.cleanPermissionsChecked = true
                    viewModel.hasScanned = true
                    Task { await viewModel.scanForCleanables() }
                } label: {
                    Text("Scan")
                        .frame(minWidth: 100)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            } else {
                Text("Grant the permissions above in System Settings, then come back here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { checkFDA() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkFDA()
        }
    }

    private func checkFDA() {
        let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: tccPath)
    }

    private func permissionRow(icon: String, title: String, granted: Bool, settingsURL: String) -> some View {
        GroupBox {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(granted ? .green : .orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(granted ? "Granted" : "Required")
                        .font(.system(size: 11))
                        .foregroundStyle(granted ? .green : .secondary)
                }

                Spacer()

                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Open Settings") {
                        if let url = URL(string: settingsURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.purple)
            Text("Smart Clean")
                .font(.system(size: 18, weight: .semibold))
            Text("Scan for caches, logs, browser data, dev tools, and more.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                viewModel.hasScanned = true
                Task { await viewModel.scanForCleanables() }
            } label: {
                Text("Scan")
                    .frame(minWidth: 80)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var nothingFoundView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("Your Mac is clean")
                .font(.system(size: 18, weight: .semibold))
            Text("Nothing to clean up right now.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button("Scan Again") {
                Task { await viewModel.scanForCleanables() }
            }
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Clean Complete

    private var cleanCompleteView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("Clean Complete")
                .font(.system(size: 18, weight: .semibold))

            if viewModel.diskFreeBefore > 0 {
                let freed = viewModel.systemInfo.diskFree - viewModel.diskFreeBefore
                if freed > 0 {
                    Text(String(format: "%.1f GB freed", freed))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Button("Scan Again") {
                    viewModel.cleanResult = nil
                    Task { await viewModel.scanForCleanables() }
                }
                .controlSize(.regular)

                Button("Done") {
                    viewModel.cleanResult = nil
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary
                    GroupBox {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Text(viewModel.cleanSummary.totalSize.isEmpty ? viewModel.formattedCleanableSize : viewModel.cleanSummary.totalSize)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.purple)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(viewModel.formattedCleanableSize) can be cleaned")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(viewModel.cleanSections.count) categories · \(viewModel.cleanSummary.itemCount) items")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                    }

                    // Sections
                    ForEach(viewModel.cleanSections.indices, id: \.self) { sectionIndex in
                        CleanSectionView(section: $viewModel.cleanSections[sectionIndex])
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Divider()

            // Bottom bar
            HStack {
                Text("Total: \(viewModel.formattedCleanableSize)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Scan Again") {
                    Task { await viewModel.scanForCleanables() }
                }
                .controlSize(.regular)

                Button {
                    showCleanConfirm = true
                } label: {
                    Text("Clean")
                        .frame(minWidth: 60)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.totalCleanableSize == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Section View

struct CleanSectionView: View {
    @Binding var section: CleanSection
    @State private var isExpanded = true

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 12)

                        Image(systemName: section.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(section.color)
                            .frame(width: 20)

                        Text(section.name)
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        Text("\(section.items.count) items")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        Text(section.formattedSize)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()
                        .padding(.top, 8)

                    ForEach(section.items.indices, id: \.self) { itemIndex in
                        HStack(spacing: 10) {
                            Text(section.items[itemIndex].name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text(section.items[itemIndex].formattedSize)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Toggle("", isOn: $section.items[itemIndex].isSelected)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                        }
                        .padding(.vertical, 4)

                        if itemIndex < section.items.count - 1 {
                            Divider().padding(.leading, 4)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Live Scan Section Card

struct LiveScanSectionCard: View {
    let section: CleanSection
    @State private var isExpanded = false

    private let previewCount = 3

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: section.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(section.color)
                        .frame(width: 18)

                    Text(section.name)
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Text("\(section.items.count) items")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Text(section.formattedSize)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                let visibleItems = isExpanded ? section.items : Array(section.items.prefix(previewCount))

                ForEach(visibleItems) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(item.formattedSize)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                if section.items.count > previewCount {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Show less" : "+\(section.items.count - previewCount) more")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
    }
}
