import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .overview
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
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
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .task {
            await viewModel.loadSystemInfo()
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var systemInfo = SystemInfo()
    @Published var cleanableItems: [CleanableItem] = []
    @Published var isScanning = false
    @Published var isLoading = true

    private let bridge = MoleBridge()

    func loadSystemInfo() async {
        isLoading = true
        let info = await bridge.fetchSystemInfo()
        systemInfo = info
        isLoading = false
    }

    func scanForCleanables() async {
        isScanning = true
        let items = await bridge.scanForCleanables()
        cleanableItems = items
        isScanning = false
    }

    var totalCleanableSize: Int64 {
        cleanableItems.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var formattedCleanableSize: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableSize, countStyle: .file)
    }
}
