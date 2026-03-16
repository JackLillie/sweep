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
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                    Text("Powered by ")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    + Text("[Mole](https://github.com/tw93/mole)")
                        .font(.system(size: 11))
                }
                .environment(\.openURL, OpenURLAction { url in
                    NSWorkspace.shared.open(url)
                    return .handled
                })
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
        }
    }
}
