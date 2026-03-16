import SwiftUI

struct MoleNotFoundView: View {
    let onCheckAgain: () -> Void

    @State private var copied = false

    private let installCommand = "brew install mole"

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Mole not found")
                    .font(.system(size: 22, weight: .bold))

                Text("Sweep needs Mole to clean, analyze, and monitor your Mac.\nInstall it via Homebrew to get started.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            GroupBox {
                HStack(spacing: 12) {
                    Text(installCommand)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)

                    Spacer()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(installCommand, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(4)
            }
            .frame(maxWidth: 340)

            Button("Check Again", action: onCheckAgain)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

            Link(destination: URL(string: "https://github.com/tw93/mole")!) {
                HStack(spacing: 4) {
                    Text("Learn more about Mole")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
