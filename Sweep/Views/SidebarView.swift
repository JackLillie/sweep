import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavigationItem?

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(NavigationItem.allCases) { item in
                    Label {
                        Text(item.title)
                    } icon: {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.color)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                Divider()
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                    Text("Powered by Mole")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
}
