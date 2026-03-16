import SwiftUI

struct SmartCleanView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.bottom, 4)
                    Text("Scanning your Mac...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if viewModel.cleanableItems.isEmpty {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(.purple)
                        .padding(.bottom, 4)
                    Text("Ready to scan")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Find junk files, caches, and logs to clean up.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                        .padding(.bottom, 4)
                    Text("\(viewModel.formattedCleanableSize) can be cleaned")
                        .font(.system(size: 20, weight: .semibold))
                    Text("\(viewModel.cleanableItems.count) categories found")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Items list
            if !viewModel.cleanableItems.isEmpty {
                List {
                    ForEach(viewModel.cleanableItems.indices, id: \.self) { index in
                        CleanableItemRow(item: $viewModel.cleanableItems[index])
                    }
                }
                .listStyle(.inset)
            } else {
                Spacer()
            }

            Divider()

            // Bottom bar
            HStack {
                if !viewModel.cleanableItems.isEmpty {
                    Text("Selected: \(viewModel.formattedCleanableSize)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    if viewModel.cleanableItems.isEmpty {
                        Task { await viewModel.scanForCleanables() }
                    } else {
                        // TODO: Wire clean action to bridge
                    }
                } label: {
                    Text(viewModel.cleanableItems.isEmpty ? "Scan" : "Clean")
                        .frame(minWidth: 80)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isScanning)
            }
            .padding(16)
            .background(.bar)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct CleanableItemRow: View {
    @Binding var item: CleanableItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.icon)
                .font(.system(size: 16))
                .foregroundStyle(color(for: item.category))
                .frame(width: 28, height: 28)
                .background(color(for: item.category).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                Text(item.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(item.formattedSize)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            Toggle("", isOn: $item.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private func color(for category: CleanableCategory) -> Color {
        switch category.color {
        case "blue": .blue
        case "purple": .purple
        case "orange": .orange
        case "red": .red
        case "green": .green
        case "indigo": .indigo
        default: .gray
        }
    }
}
