import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var hasFullDiskAccess = false
    @State private var hasMole = false
    @AppStorage("onboardingStep") private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                if step == 0 {
                    welcomeStep
                        .id("welcome")
                } else if !hasMole {
                    moleStep
                        .id("mole")
                } else {
                    fdaStep
                        .id("fda")
                }
            }
            .transition(.opacity)

            Spacer()

            // Progress dots
            HStack(spacing: 8) {
                let totalSteps = hasMole ? 2 : 3
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            checkMole()
            checkFDA()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkMole()
            checkFDA()
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            VStack(spacing: 8) {
                Text("Welcome to Sweep")
                    .font(.system(size: 24, weight: .bold))
                Text("A free, native macOS app for system maintenance.\nClean caches, manage storage, audit permissions, and more.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
            } label: {
                Text("Get Started")
                    .frame(minWidth: 120)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    // MARK: - Mole

    private var moleStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 42))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Install Mole")
                    .font(.system(size: 22, weight: .bold))
                Text("Sweep is powered by Mole, a system maintenance CLI.\nInstall it via Homebrew to get started.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            GroupBox {
                HStack(spacing: 12) {
                    Image(systemName: hasMole ? "checkmark.circle.fill" : "terminal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(hasMole ? .green : .secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mole CLI")
                            .font(.system(size: 13, weight: .medium))
                        Text(hasMole ? "Installed" : "brew install mole")
                            .font(.system(size: 11, design: hasMole ? .default : .monospaced))
                            .foregroundStyle(hasMole ? .green : .secondary)
                            .textSelection(.enabled)
                    }

                    Spacer()

                    if !hasMole {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew install mole", forType: .string)
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 400)

            if hasMole {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { step = 2 }
                } label: {
                    Text("Continue")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            } else {
                Text("Install Mole via Homebrew, then come back here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - FDA

    private var fdaStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Full Disk Access")
                    .font(.system(size: 22, weight: .bold))
                Text("Smart Clean, Storage, and Permissions need Full Disk Access\nto scan your system. Overview and Applications work without it.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            GroupBox {
                HStack(spacing: 12) {
                    Image(systemName: hasFullDiskAccess ? "checkmark.circle.fill" : "lock.shield.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(hasFullDiskAccess ? .green : .orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full Disk Access")
                            .font(.system(size: 13, weight: .medium))
                        Text(hasFullDiskAccess ? "Granted" : "Click +, find Sweep, and toggle it on")
                            .font(.system(size: 11))
                            .foregroundStyle(hasFullDiskAccess ? .green : .secondary)
                    }

                    Spacer()

                    if !hasFullDiskAccess {
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 400)

            Button {
                hasCompletedOnboarding = true
            } label: {
                Text(hasFullDiskAccess ? "Done" : "Continue Without")
                    .frame(minWidth: 120)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    // MARK: - Checks

    private func checkMole() {
        // Check bundled mole first
        if let resourcePath = Bundle.main.resourcePath {
            let bundled = resourcePath + "/mole/mole"
            if FileManager.default.isExecutableFile(atPath: bundled) {
                hasMole = true
                return
            }
        }
        let paths = ["/opt/homebrew/bin/mole", "/usr/local/bin/mole"]
        hasMole = paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func checkFDA() {
        let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: tccPath)
    }
}
