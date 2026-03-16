import SwiftUI

struct PermissionsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var permissions: [PermissionGroup] = []
    @State private var isLoading = false

    struct PermissionGroup: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let color: Color
        let entries: [PermissionEntry]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                GroupBox {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy & Permissions")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Review which apps have access to sensitive data and system features.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Button("Scan") {
                            Task { await scanPermissions() }
                        }
                        .controlSize(.regular)
                        .disabled(isLoading)
                    }
                    .padding(4)
                }

                if isLoading {
                    ProgressView("Scanning permissions...")
                        .padding(.top, 40)
                } else if permissions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                        Text("Click Scan to audit permissions")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(permissions) { group in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label {
                                    Text(group.name)
                                        .font(.system(size: 13, weight: .semibold))
                                } icon: {
                                    Image(systemName: group.icon)
                                        .foregroundStyle(group.color)
                                }
                                .padding(.bottom, 4)

                                ForEach(group.entries) { entry in
                                    HStack(spacing: 10) {
                                        Image(systemName: entry.icon)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)

                                        Text(entry.appName)
                                            .font(.system(size: 12))

                                        Spacer()

                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(entry.granted ? .green : .red)
                                                .frame(width: 6, height: 6)
                                            Text(entry.granted ? "Granted" : "Denied")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)

                                    if entry.id != group.entries.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding(4)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func scanPermissions() async {
        isLoading = true
        defer { isLoading = false }

        // Placeholder permission groups — will wire to Mole's permission scanning
        permissions = [
            PermissionGroup(
                name: "Full Disk Access",
                icon: "internaldrive",
                color: .blue,
                entries: []
            ),
            PermissionGroup(
                name: "Camera",
                icon: "camera",
                color: .orange,
                entries: []
            ),
            PermissionGroup(
                name: "Microphone",
                icon: "mic",
                color: .red,
                entries: []
            ),
            PermissionGroup(
                name: "Location",
                icon: "location",
                color: .green,
                entries: []
            ),
        ]
    }
}
