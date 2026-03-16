import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .overview
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.moleAvailable {
                HStack(spacing: 0) {
                    SidebarView(selection: $selectedItem)
                        .frame(width: 200)

                    Divider()

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

    func runClean() async {
        isCleaning = true
        do {
            let result = try await bridge.runClean()
            cleanResult = result
            cleanSections = []
            cleanSummary = CleanSummary()
            // Refresh system info to show updated disk space
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
}
