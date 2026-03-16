import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .overview
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        Group {
            if viewModel.moleAvailable {
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
                    .contentMargins(.top, 0, for: .scrollContent)
                }
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
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
    @Published var cleanableItems: [CleanableItem] = []
    @Published var isScanning = false
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

    func scanForCleanables() async {
        isScanning = true
        let items = await bridge.scanForCleanables()
        cleanableItems = items
        isScanning = false
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
        cleanableItems.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var formattedCleanableSize: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableSize, countStyle: .file)
    }
}
