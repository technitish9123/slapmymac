import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @State private var hoveredButton: String?

    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Toggles Group
            togglesCard

            // MARK: - Actions Group
            actionsCard
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)),
            removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top))
        ))
        .alert("Reset Statistics?", isPresented: Bindable(appState).showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appState.resetStats()
            }
        } message: {
            Text("This will reset your session and total slap counts to zero. This cannot be undone.")
        }
    }

    // MARK: - Toggles Card

    private var togglesCard: some View {
        VStack(spacing: 0) {
            settingsRow(
                icon: "dock.rectangle",
                iconTint: Color(red: 0.55, green: 0.62, blue: 0.18),
                title: "Show in Dock",
                toggle: Bindable(appState).showInDock
            )

            Divider()
                .padding(.leading, 46)

            settingsRow(
                icon: "arrow.right.circle",
                iconTint: Color(red: 0.55, green: 0.72, blue: 0.20),
                title: "Launch at Login",
                toggle: $launchAtLogin
            )
            .onChange(of: launchAtLogin) { _, newValue in
                LaunchAtLogin.toggle(newValue)
            }

            Divider()
                .padding(.leading, 46)

            VStack(alignment: .leading, spacing: 0) {
                settingsRow(
                    icon: "waveform.path.ecg",
                    iconTint: Color(red: 0.78, green: 0.60, blue: 0.15),
                    title: "Dynamic Mode",
                    toggle: Bindable(appState).dynamicMode
                )

                Text("Volume scales with slap force")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 46)
                    .padding(.bottom, 10)
                    .padding(.top, -4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Settings Row

    private func settingsRow(
        icon: String,
        iconTint: Color,
        title: String,
        toggle binding: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconTint.gradient)
                )

            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .tint(iconTint)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 0) {
            // Open Custom Sounds
            Button {
                openCustomSoundsFolder()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.orange.gradient)
                        )

                    Text("Open Custom Sounds")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hoveredButton == "customSounds" ? Color.primary.opacity(0.04) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredButton = hovering ? "customSounds" : nil
                }
            }

            Divider()
                .padding(.leading, 46)

            // Reset Statistics
            Button {
                appState.showResetConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red.gradient)
                        )

                    Text("Reset Statistics")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hoveredButton == "reset" ? Color.red.opacity(0.04) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredButton = hovering ? "reset" : nil
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func openCustomSoundsFolder() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let customDir = appSupport.appendingPathComponent("SlapMyMac/CustomSounds")

        try? FileManager.default.createDirectory(
            at: customDir, withIntermediateDirectories: true
        )

        NSWorkspace.shared.open(customDir)
    }
}
