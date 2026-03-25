import SwiftUI
import ServiceManagement

// MARK: - Design Tokens

private enum Theme {
    static let panelWidth: CGFloat = 400
    static let cornerRadius: CGFloat = 16
    static let cardRadius: CGFloat = 12
    static let sectionSpacing: CGFloat = 16
    static let horizontalPadding: CGFloat = 18

    // Olive/earthy palette inspired by SlapMac
    static let accent = Color(red: 0.55, green: 0.62, blue: 0.18)          // Olive green #8D9E2E
    static let accentLight = Color(red: 0.55, green: 0.62, blue: 0.18).opacity(0.20)
    static let violet = Color(red: 0.65, green: 0.72, blue: 0.25)          // Lighter olive hover
    static let enabledGreen = Color(red: 0.55, green: 0.72, blue: 0.20)    // Bright olive green
    static let warmTint = Color(red: 0.12, green: 0.13, blue: 0.10)        // Dark earthy bg
    static let cardFill = Color.white.opacity(0.04)
    static let cardBorder = Color.white.opacity(0.06)
    static let subtleShadow = Color.black.opacity(0.2)

    static let sliderBlue = Color(red: 0.55, green: 0.62, blue: 0.18)      // Olive for sensitivity
    static let sliderGreen = Color(red: 0.55, green: 0.72, blue: 0.20)     // Green for volume
    static let sliderOrange = Color(red: 0.78, green: 0.60, blue: 0.15)    // Warm amber for cooldown

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary = Color.white.opacity(0.35)
}

// MARK: - Main View

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    @State private var dotCount: Int = 0
    @State private var animateSlapVisual: Bool = false
    @State private var isHoveringGear: Bool = false
    @State private var isHoveringQuit: Bool = false
    @State private var isHoveringReset: Bool = false
    @State private var isHoveringToggle: Bool = false
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.sectionSpacing) {
                // Extra top padding for native titlebar / traffic lights
                Color.clear.frame(height: 8)

                headerSection
                liveFeedbackCard
                soundPackSection
                slidersSection
                togglesSection
                footerSection
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .preferredColorScheme(.dark)
        .onAppear {
            appState.initialize()
            launchAtLogin = LaunchAtLogin.isEnabled
            startListeningDots()
        }
        .onChange(of: appState.showSlapAnimation) { _, isSlapping in
            if isSlapping { triggerSlapVisual() }
        }
    }

    // MARK: - Panel Background

    private var panelBackground: some View {
        ZStack {
            // Deep earthy dark background
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.08),
                    Color(red: 0.14, green: 0.15, blue: 0.10),
                    Color(red: 0.11, green: 0.12, blue: 0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Subtle glass overlay
            Rectangle().fill(.ultraThinMaterial).opacity(0.15)
        }
    }

    // MARK: - 1. Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            // Top bar
            HStack(alignment: .center) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                Text("SlapMyMac")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                // Gear button
                Button {
                    appState.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isHoveringGear ? Theme.accent : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(isHoveringGear ? Theme.accentLight : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringGear = $0 }
                .help("Settings")

                // Quit button
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isHoveringQuit ? Color.red : Color.gray.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(isHoveringQuit ? Color.red.opacity(0.10) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringQuit = $0 }
                .help("Quit SlapMyMac")
            }

            // Enable/Disable toggle pill
            enableTogglePill
        }
        .padding(.horizontal, Theme.horizontalPadding)
    }

    private var enableTogglePill: some View {
        @Bindable var state = appState

        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                appState.isEnabled.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                // Status dot
                Circle()
                    .fill(appState.isEnabled ? Theme.enabledGreen : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .shadow(
                        color: appState.isEnabled ? Theme.enabledGreen.opacity(0.6) : .clear,
                        radius: appState.isEnabled ? 6 : 0
                    )

                // Status text
                Group {
                    if appState.isEnabled {
                        Text("Listening" + String(repeating: ".", count: dotCount))
                            .contentTransition(.numericText())
                    } else {
                        Text("Paused")
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(appState.isEnabled ? .primary : .secondary)

                Spacer()

                // Toggle capsule
                Capsule()
                    .fill(appState.isEnabled ? Theme.enabledGreen : Color.gray.opacity(0.25))
                    .frame(width: 44, height: 26)
                    .overlay(alignment: appState.isEnabled ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .padding(.horizontal, 2)
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appState.isEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(appState.isEnabled
                          ? Theme.enabledGreen.opacity(0.08)
                          : Color.gray.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        appState.isEnabled
                            ? Theme.enabledGreen.opacity(0.25)
                            : Color.gray.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHoveringToggle ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHoveringToggle = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHoveringToggle)
    }

    // MARK: - 2. Live Feedback Card

    private var liveFeedbackCard: some View {
        VStack(spacing: 14) {
            ZStack {
                // Circular progress ring
                Circle()
                    .stroke(Color.gray.opacity(0.10), lineWidth: 6)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: appState.lastSlapForce)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.accent, Theme.violet, Theme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: appState.lastSlapForce)

                // Hand icon
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(
                        animateSlapVisual
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.violet],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                              )
                            : AnyShapeStyle(Color.secondary.opacity(0.35))
                    )
                    .scaleEffect(animateSlapVisual ? 1.3 : 1.0)
                    .rotationEffect(.degrees(animateSlapVisual ? -12 : 0))
                    .animation(.spring(response: 0.25, dampingFraction: 0.35), value: animateSlapVisual)
            }

            // Force readout
            if appState.lastSlapForce > 0 {
                Text("\(Int(appState.lastSlapForce * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            } else {
                Text("Ready")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            // Stat pills
            HStack(spacing: 10) {
                statPill(label: "Session", value: appState.sessionSlaps, icon: "bolt.fill")
                statPill(label: "Total", value: appState.totalSlapCount, icon: "sum")
            }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .padding(.horizontal, Theme.horizontalPadding)
    }

    private func statPill(label: String, value: Int, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.accent.opacity(0.7))

            Text(label + ":")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(formattedCount(value))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.07))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.gray.opacity(0.10), lineWidth: 0.5)
        )
    }

    // MARK: - 3. Sound Pack Section

    private var soundPackSection: some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Sound Pack")

            // Selected pack display / dropdown trigger
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    appState.showSoundPackDropdown.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    if let pack = appState.selectedPack {
                        Image(systemName: pack.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.accentLight)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(pack.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(pack.description)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(appState.showSoundPackDropdown ? -180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.showSoundPackDropdown)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(cardBackground)
            }
            .buttonStyle(.plain)

            // Expanded pack list
            if appState.showSoundPackDropdown {
                VStack(spacing: 2) {
                    ForEach(appState.soundPacks) { pack in
                        soundPackRow(pack)
                    }
                }
                .padding(6)
                .background(cardBackground)
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .padding(.horizontal, Theme.horizontalPadding)
    }

    private func soundPackRow(_ pack: SoundPack) -> some View {
        let isSelected = appState.selectedPackID == pack.id

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                appState.selectedPackID = pack.id
                appState.showSoundPackDropdown = false
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: pack.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? Theme.accent : Theme.accentLight)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(pack.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Theme.accent : .primary)
                    Text(pack.description)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Sliders Section

    private var slidersSection: some View {
        @Bindable var state = appState

        return VStack(spacing: 16) {
            sectionLabel("Controls")
                .padding(.horizontal, Theme.horizontalPadding)

            VStack(spacing: 14) {
                // Sensitivity
                sliderRow(
                    value: $state.sensitivity,
                    range: 0...1,
                    tint: Theme.sliderBlue,
                    icon: "gauge.medium",
                    leftLabel: "Butterfly",
                    rightLabel: "Full Send",
                    detail: String(format: "%.3fg", sensitivityToGForce(appState.sensitivity))
                )

                Divider().padding(.horizontal, 8).opacity(0.5)

                // Volume
                sliderRow(
                    value: $state.volume,
                    range: 0...1,
                    tint: Theme.sliderGreen,
                    icon: volumeIcon,
                    leftLabel: nil,
                    rightLabel: nil,
                    detail: "\(Int(appState.volume * 100))%"
                )

                Divider().padding(.horizontal, 8).opacity(0.5)

                // Cooldown
                sliderRow(
                    value: $state.cooldown,
                    range: 0.1...2.0,
                    tint: Theme.sliderOrange,
                    icon: "timer",
                    leftLabel: "Rapid fire",
                    rightLabel: "Dramatic pause",
                    detail: String(format: "%.1fs", appState.cooldown)
                )
            }
            .padding(14)
            .background(cardBackground)
            .padding(.horizontal, Theme.horizontalPadding)
        }
        .animation(.easeInOut(duration: 0.2), value: appState.volume)
        .animation(.easeInOut(duration: 0.2), value: appState.sensitivity)
        .animation(.easeInOut(duration: 0.2), value: appState.cooldown)
    }

    private func sliderRow(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        tint: Color,
        icon: String,
        leftLabel: String?,
        rightLabel: String?,
        detail: String
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 18)

                Slider(value: value, in: range)
                    .tint(tint)

                Text(detail)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint)
                    .frame(width: 46, alignment: .trailing)
                    .contentTransition(.numericText())
            }

            if let left = leftLabel, let right = rightLabel {
                HStack {
                    Text(left)
                    Spacer()
                    Text(right)
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.quaternary)
                .padding(.leading, 26)
                .padding(.trailing, 46)
            }
        }
    }

    // MARK: - 5. Toggles Section

    private var togglesSection: some View {
        @Bindable var state = appState

        return VStack(spacing: 0) {
            toggleRow(
                icon: "dock.rectangle",
                iconColor: Theme.sliderBlue,
                label: "Show in Dock",
                isOn: $state.showInDock
            )

            thinDivider

            toggleRow(
                icon: "arrow.right.circle",
                iconColor: Theme.sliderGreen,
                label: "Launch at Login",
                isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        LaunchAtLogin.toggle(newValue)
                    }
                )
            )

            thinDivider

            toggleRow(
                icon: "speaker.wave.2",
                iconColor: Theme.sliderOrange,
                label: "Enable Sound",
                isOn: Binding(
                    get: { appState.volume > 0 },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.volume = newValue ? 0.7 : 0
                        }
                    }
                )
            )

            thinDivider

            toggleRow(
                icon: "waveform.path.ecg",
                iconColor: Theme.violet,
                label: "Dynamic Mode",
                isOn: $state.dynamicMode,
                tooltip: "Volume scales with slap force"
            )
        }
        .padding(.vertical, 4)
        .background(cardBackground)
        .padding(.horizontal, Theme.horizontalPadding)
    }

    private func toggleRow(
        icon: String,
        iconColor: Color,
        label: String,
        isOn: Binding<Bool>,
        tooltip: String? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor.opacity(0.10))
                )

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            if let tip = tooltip {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                    .help(tip)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isOn.wrappedValue)
    }

    private var thinDivider: some View {
        Divider()
            .padding(.leading, 50)
            .opacity(0.4)
    }

    // MARK: - 6. Footer

    private var footerSection: some View {
        HStack {
            Text("v1.0.0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.quaternary)

            Spacer()

            Button {
                appState.resetStats()
            } label: {
                Text("Reset Stats")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isHoveringReset ? Theme.accent : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringReset = $0 }
        }
        .padding(.horizontal, Theme.horizontalPadding)
        .padding(.top, 2)
    }

    // MARK: - Shared Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(Theme.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    // MARK: - Helpers

    private var volumeIcon: String {
        if appState.volume == 0 { return "speaker.slash.fill" }
        if appState.volume < 0.33 { return "speaker.wave.1.fill" }
        if appState.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func sensitivityToGForce(_ value: Double) -> Double {
        // Map 0...1 sensitivity to approximate g-force threshold
        // Low sensitivity = high threshold (harder slap needed)
        let minG = 0.02
        let maxG = 0.15
        return minG + (1.0 - value) * (maxG - minG)
    }

    private func startListeningDots() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [appState] _ in
            Task { @MainActor in
                guard appState.isEnabled else {
                    dotCount = 0
                    return
                }
                withAnimation(.easeInOut(duration: 0.15)) {
                    dotCount = (dotCount % 3) + 1
                }
            }
        }
    }

    private func triggerSlapVisual() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
            animateSlapVisual = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                animateSlapVisual = false
            }
        }
    }

    private func formattedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
