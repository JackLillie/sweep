import SwiftUI

@main
struct SweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 780, minHeight: 520)
                .onDisappear {
                    // Hide from dock when all windows are closed
                    DispatchQueue.main.async {
                        let hasVisible = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
                        if !hasVisible {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 900, height: 600)

        Settings {
            SettingsView()
        }

        MenuBarExtra("Sweep", systemImage: "sparkles", isInserted: $showMenuBarExtra) {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

}
