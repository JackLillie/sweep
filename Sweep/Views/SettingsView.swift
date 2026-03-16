import SwiftUI

struct SettingsView: View {
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = false
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("confirmBeforeClean") private var confirmBeforeClean = true

    var body: some View {
        TabView {
            Form {
                Section("General") {
                    Toggle("Scan automatically on launch", isOn: $autoScanOnLaunch)
                    Toggle("Show in menu bar", isOn: $showMenuBarExtra)
                    Toggle("Confirm before cleaning", isOn: $confirmBeforeClean)
                }

                Section("Mole") {
                    LabeledContent("Version") {
                        Text("Bundled with app")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Source") {
                        Link("github.com/tw93/mole", destination: URL(string: "https://github.com/tw93/mole")!)
                            .font(.system(size: 12))
                    }
                }

                Section("About") {
                    LabeledContent("Sweep") {
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("License") {
                        Text("MIT — Free forever")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 450, height: 300)
    }
}
