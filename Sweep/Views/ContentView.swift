import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .overview
    @ObservedObject var viewModel: AppViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if viewModel.moleAvailable {
                NavigationSplitView {
                    SidebarView(selection: $selectedItem)
                } detail: {
                    Group {
                        switch selectedItem {
                        case .overview:
                            OverviewView(viewModel: viewModel)
                        case .smartClean:
                            SmartCleanView(viewModel: viewModel)
                        case .applications:
                            ApplicationsView(viewModel: viewModel)
                        case .storage:
                            StorageView(viewModel: viewModel)
                        case .permissions:
                            PermissionsView(viewModel: viewModel)
                        case nil:
                            OverviewView(viewModel: viewModel)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                MoleNotFoundView {
                    Task { await viewModel.recheckMole() }
                }
            }
        }
        .task {
            await viewModel.checkMoleAvailability()
            if viewModel.moleAvailable {
                await viewModel.loadSystemInfo()
            }
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var systemInfo = SystemInfo()
    @Published var cleanSections: [CleanSection] = []
    @Published var cleanSummary = CleanSummary()
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var cleanResult: String?
    @Published var diskFreeBefore: Double = 0
    @Published var isLoading = true
    @Published var moleAvailable = true
    @Published var cleanPermissionsChecked = false
    @Published var hasScanned = false

    private let bridge = MoleBridge()

    func checkMoleAvailability() async {
        moleAvailable = await bridge.isAvailable
    }

    func recheckMole() async {
        moleAvailable = await bridge.recheckAvailability()
    }

    func loadSystemInfo() async {
        let status = await bridge.fetchStatus()
        systemInfo = SystemInfo(from: status)
        isLoading = false
    }

    @Published var scanActivity = ""
    private var scanTask: Task<Void, Never>?

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
        scanActivity = ""
    }

    func scanForCleanables() async {
        isScanning = true
        diskFreeBefore = systemInfo.diskFree
        scanActivity = "Starting scan..."

        let (sections, summary) = await bridge.scanForCleanablesStreaming { [weak self] liveSections, liveSummary, activity in
            Task { @MainActor in
                self?.cleanSections = liveSections
                self?.cleanSummary = liveSummary
                self?.scanActivity = activity
            }
        }

        cleanSections = sections
        cleanSummary = summary
        isScanning = false
    }

    @Published var cleanActivity = ""

    func runClean(deepClean: Bool = false) async {
        isCleaning = true
        cleanActivity = "Starting clean..."

        if deepClean {
            cleanActivity = "Requesting administrator access..."
            do {
                try await bridge.cacheSudo()
            } catch {
                // User cancelled the password prompt — continue with normal clean
            }
        }

        do {
            let result = try await bridge.runCleanStreaming { [weak self] activity in
                Task { @MainActor in
                    self?.cleanActivity = activity
                }
            }
            cleanResult = result
            cleanSections = []
            cleanSummary = CleanSummary()
            await loadSystemInfo()
        } catch {
            actionError = error.localizedDescription
        }
        isCleaning = false
    }

    @Published var actionError: String?

    func emptyTrash() async {
        do {
            try await bridge.emptyTrash()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func flushDNS() async {
        do {
            try await bridge.flushDNS()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func freeMemory() async {
        do {
            try await bridge.freeMemory()
        } catch {
            actionError = error.localizedDescription
        }
    }

    var totalCleanableSize: Int64 {
        cleanSections.reduce(0) { $0 + $1.totalSize }
    }

    var formattedCleanableSize: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableSize, countStyle: .file)
    }

    var hasCleanableItems: Bool {
        !cleanSections.isEmpty
    }

    // MARK: - Applications
    @Published var apps: [AppInfo] = []
    @Published var isLoadingApps = false
    @Published var appsScanned = false

    // MARK: - Storage
    @Published var storageCategories: [StorageCategory] = []
    @Published var largeFiles: [MoleAnalysis.Entry] = []
    @Published var isLoadingStorage = false
    @Published var storageScanned = false
    @Published var storageActivity = "Starting analysis..."
    @Published var drillDownEntries: [MoleAnalysis.Entry] = []
    @Published var drillDownPath: String?

    func loadStorage() async {
        isLoadingStorage = true
        storageCategories = []
        largeFiles = []

        let home = NSHomeDirectory()

        struct ScanTarget {
            let name: String
            let paths: [String]
            let color: String
            let icon: String
        }

        let targets: [ScanTarget] = [
            ScanTarget(name: "Applications", paths: ["/Applications"], color: "blue", icon: "app.fill"),
            ScanTarget(name: "Documents", paths: ["\(home)/Documents", "\(home)/Desktop"], color: "orange", icon: "doc.fill"),
            ScanTarget(name: "Downloads", paths: ["\(home)/Downloads"], color: "cyan", icon: "arrow.down.circle.fill"),
            ScanTarget(name: "Projects", paths: ["\(home)/Projects", "\(home)/Developer", "\(home)/GitHub", "\(home)/dev", "\(home)/repos"], color: "green", icon: "folder.fill"),
            ScanTarget(name: "Media", paths: ["\(home)/Movies", "\(home)/Music", "\(home)/Pictures"], color: "pink", icon: "photo.fill"),
            ScanTarget(name: "Developer & Libraries", paths: ["\(home)/Library"], color: "purple", icon: "hammer.fill"),
        ]

        for target in targets {
            storageActivity = "Analyzing \(target.name)..."
            var totalSize: Int64 = 0

            for path in target.paths {
                guard FileManager.default.fileExists(atPath: path) else { continue }
                if let analysis = try? await bridge.analyze(path: path) {
                    totalSize += analysis.entries.reduce(Int64(0)) { $0 + $1.size }

                    // Collect large files from each scan
                    let bigFiles = analysis.entries.filter { !$0.isDir && $0.size > 100_000_000 }
                    largeFiles.append(contentsOf: bigFiles)
                    largeFiles.sort { $0.size > $1.size }
                    if largeFiles.count > 20 { largeFiles = Array(largeFiles.prefix(20)) }
                }
            }

            if totalSize > 0 {
                storageCategories.append(StorageCategory(name: target.name, size: totalSize, color: target.color, icon: target.icon))
                storageCategories.sort { $0.size > $1.size }
            }
        }

        isLoadingStorage = false
        storageScanned = true
    }

    func drillDown(path: String) async {
        drillDownPath = path
        drillDownEntries = []
        if let analysis = try? await bridge.analyze(path: path) {
            drillDownEntries = analysis.entries.sorted { $0.size > $1.size }
        }
    }
}
