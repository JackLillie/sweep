import SwiftUI

struct StorageView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Disk usage bar
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label {
                                Text("Macintosh HD")
                                    .font(.system(size: 14, weight: .semibold))
                            } icon: {
                                Image(systemName: "internaldrive.fill")
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(String(format: "%.0f GB / %.0f GB",
                                        viewModel.systemInfo.diskUsed,
                                        viewModel.systemInfo.diskTotal))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        // Storage bar
                        GeometryReader { geo in
                            let used = viewModel.systemInfo.diskPercentage
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 24)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(storageGradient)
                                    .frame(width: max(0, geo.size.width * used), height: 24)
                            }
                        }
                        .frame(height: 24)

                        HStack {
                            Circle()
                                .fill(storageGradient)
                                .frame(width: 8, height: 8)
                            Text("Used")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer().frame(width: 16)
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 8, height: 8)
                            Text("Free — \(String(format: "%.0f GB", viewModel.systemInfo.diskFree))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }

                // Categories
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Storage Breakdown")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)

                        ForEach(storageCategories) { category in
                            HStack(spacing: 12) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(color(for: category.color))
                                    .frame(width: 24)

                                Text(category.name)
                                    .font(.system(size: 13))

                                Spacer()

                                Text(category.formattedSize)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)

                            if category.id != storageCategories.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(4)
                }

                // Tip
                GroupBox {
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tip")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Run Smart Clean to reclaim space from caches, logs, and temporary files.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var storageGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var storageCategories: [StorageCategory] {
        [
            StorageCategory(name: "Applications", size: 0, color: "blue", icon: "app.fill"),
            StorageCategory(name: "Developer", size: 0, color: "purple", icon: "hammer.fill"),
            StorageCategory(name: "Documents", size: 0, color: "orange", icon: "doc.fill"),
            StorageCategory(name: "System", size: 0, color: "gray", icon: "gearshape.fill"),
            StorageCategory(name: "Other", size: 0, color: "green", icon: "archivebox.fill"),
        ]
    }

    private func color(for name: String) -> Color {
        switch name {
        case "blue": .blue
        case "purple": .purple
        case "orange": .orange
        case "gray": .gray
        case "green": .green
        default: .secondary
        }
    }
}
