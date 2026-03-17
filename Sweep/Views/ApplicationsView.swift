import SwiftUI

struct ApplicationsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .size
    @State private var sortAscending = false
    @State private var appToUninstall: AppInfo?
    @State private var showUninstallConfirm = false

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case size = "Size"
    }

    var body: some View {
        Group {
            if viewModel.isLoadingApps {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning applications...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Scan to find installed applications")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Scan Applications") {
                        Task { await scanApps() }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("\(filteredApps.count) applications")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Picker("", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()

                        Button {
                            sortAscending.toggle()
                        } label: {
                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(sortAscending ? "Ascending" : "Descending")
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 16)
                    .padding(.vertical, 10)

                    Divider()

                    List(filteredApps) { app in
                        AppRow(app: app) {
                            appToUninstall = app
                            showUninstallConfirm = true
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("")
        .searchable(text: $searchText, prompt: "Filter applications")
        .onAppear {
            if !viewModel.appsScanned {
                viewModel.appsScanned = true
                Task { await scanApps() }
            }
        }
        .alert("Uninstall \(appToUninstall?.name ?? "")?", isPresented: $showUninstallConfirm) {
            Button("Cancel", role: .cancel) { appToUninstall = nil }
            Button("Uninstall", role: .destructive) {
                if let app = appToUninstall {
                    Task { await uninstallApp(app) }
                }
            }
        } message: {
            if let app = appToUninstall {
                Text("This will remove \(app.name) and its associated data (\(app.formattedSize)). This cannot be undone.")
            }
        }
    }

    private var filteredApps: [AppInfo] {
        let filtered = searchText.isEmpty ? viewModel.apps : viewModel.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }

        switch sortOrder {
        case .name:
            return filtered.sorted {
                sortAscending
                    ? $0.name.localizedCompare($1.name) == .orderedAscending
                    : $0.name.localizedCompare($1.name) == .orderedDescending
            }
        case .size:
            return filtered.sorted {
                sortAscending ? $0.size < $1.size : $0.size > $1.size
            }
        }
    }

    // MARK: - Scanning

    private func scanApps() async {
        viewModel.isLoadingApps = true

        let scanned = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let searchPaths = ["/Applications", "/Applications/Utilities"]
            var results: [AppInfo] = []

            // Batch mdls for all apps at once
            var allPaths: [(String, String)] = [] // (fullPath, itemName)
            for applicationsPath in searchPaths {
                guard let contents = try? fm.contentsOfDirectory(atPath: applicationsPath) else { continue }
                for item in contents where item.hasSuffix(".app") {
                    allPaths.append(("\(applicationsPath)/\(item)", item))
                }
            }

            let ownBundleID = Bundle.main.bundleIdentifier ?? "dev.jacklillie.Sweep"

            for (fullPath, item) in allPaths {
                let bundle = Bundle(path: fullPath)
                if bundle?.bundleIdentifier == ownBundleID { continue }

                let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? item.replacingOccurrences(of: ".app", with: "")

                // Size — use simpler/faster approach
                var size: Int64 = 0
                if let enumerator = fm.enumerator(
                    at: URL(fileURLWithPath: fullPath),
                    includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for case let url as URL in enumerator {
                        if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
                           let fileSize = values.totalFileAllocatedSize {
                            size += Int64(fileSize)
                        }
                    }
                }

                let bundleID = bundle?.bundleIdentifier ?? ""
                let icon = NSWorkspace.shared.icon(forFile: fullPath)

                results.append(AppInfo(
                    name: name,
                    bundleIdentifier: bundleID,
                    size: size,
                    path: fullPath,
                    lastOpened: nil,
                    icon: icon
                ))
            }

            return results
        }.value

        viewModel.apps = scanned
        viewModel.isLoadingApps = false
    }


    // MARK: - Uninstall

    private func uninstallApp(_ app: AppInfo) async {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let bundleID = app.bundleIdentifier

        // Paths to remove
        var pathsToRemove = [app.path]

        if !bundleID.isEmpty {
            let relatedPaths = [
                "\(home)/Library/Application Support/\(bundleID)",
                "\(home)/Library/Caches/\(bundleID)",
                "\(home)/Library/Preferences/\(bundleID).plist",
                "\(home)/Library/Logs/\(bundleID)",
                "\(home)/Library/HTTPStorages/\(bundleID)",
                "\(home)/Library/WebKit/\(bundleID)",
                "\(home)/Library/Saved Application State/\(bundleID).savedState",
            ]
            for path in relatedPaths where fm.fileExists(atPath: path) {
                pathsToRemove.append(path)
            }
        }

        var freedSize: Int64 = 0
        for path in pathsToRemove {
            if let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
                options: []
            ) {
                for case let url as URL in enumerator {
                    if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
                       let fileSize = values.totalFileAllocatedSize {
                        freedSize += Int64(fileSize)
                    }
                }
            }
            try? fm.removeItem(atPath: path)
        }

        // Refresh list
        viewModel.apps.removeAll { $0.id == app.id }
        appToUninstall = nil

        // Refresh system info
        await viewModel.loadSystemInfo()
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: AppInfo
    let onUninstall: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                Text(app.bundleIdentifier)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(app.formattedSize)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            if isHovering {
                HStack(spacing: 4) {
                    Button {
                        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Reveal in Finder")

                    Button(action: onUninstall) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Uninstall")
                }
            }
        }
        .padding(.vertical, 3)
        .onHover { isHovering = $0 }
    }
}
