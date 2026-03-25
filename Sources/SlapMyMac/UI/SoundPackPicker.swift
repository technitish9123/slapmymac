import SwiftUI

struct SoundPackPicker: View {
    @Environment(AppState.self) private var appState
    @State private var hoveredPackID: String?

    private var selectedPack: SoundPack? {
        appState.soundPacks.first { $0.id == appState.selectedPackID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Collapsed Pill
            collapsedPill

            // MARK: - Expanded Dropdown
            if appState.showSoundPackDropdown {
                dropdownList
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top))
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.showSoundPackDropdown)
    }

    // MARK: - Collapsed Pill

    private var collapsedPill: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appState.showSoundPackDropdown.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedPack?.icon ?? "speaker.wave.2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.62, blue: 0.18))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(red: 0.55, green: 0.62, blue: 0.18).opacity(0.12))
                    )

                Text(selectedPack?.name ?? "Select Pack")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(appState.showSoundPackDropdown ? -180 : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appState.showSoundPackDropdown)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dropdown List

    private var dropdownList: some View {
        VStack(spacing: 2) {
            ForEach(appState.soundPacks) { pack in
                packRow(pack)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.top, 4)
    }

    // MARK: - Pack Row

    private func packRow(_ pack: SoundPack) -> some View {
        let isSelected = appState.selectedPackID == pack.id
        let isHovered = hoveredPackID == pack.id

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                appState.selectedPackID = pack.id
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appState.showSoundPackDropdown = false
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: pack.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color(red: 0.55, green: 0.62, blue: 0.18))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? Color(red: 0.55, green: 0.62, blue: 0.18) : Color(red: 0.55, green: 0.62, blue: 0.18).opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color(red: 0.55, green: 0.62, blue: 0.18) : .primary)

                    Text(pack.description)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.62, blue: 0.18))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? Color(red: 0.55, green: 0.62, blue: 0.18).opacity(0.1)
                            : isHovered ? Color.primary.opacity(0.04) : Color.clear
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredPackID = hovering ? pack.id : nil
            }
        }
    }
}
