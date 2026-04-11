// GrooveDanceSelectView.swift
// PAGE 3 — Dance style selection only (result moved to Screen 5)
// Per spec: subject confirmation strip, horizontal scroll carousel,
// badge color system, left-aligned headline, rigid haptic

import SwiftUI

struct GrooveDanceSelectView: View {
    @ObservedObject var state: GrooveOnboardingState
    let onNext: () -> Void

    // ── Onboarding presets (show more for carousel feel) ───────────────────────
    private let onboardingPresets: [DancePreset] = {
        let ids = ["big-guy", "boombastic", "cotton-eye-joe", "coco-channel", "trag"]
        return ids.compactMap { id in DancePreset.allPresets.first(where: { $0.id == id }) }
    }()

    @State private var selectedDanceId: String? = nil
    @State private var carouselAppeared = false

    var body: some View {
        ZStack {
            GrooveOnboardingTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 96) // below progress dots

                // ── Subject confirmation strip ─────────────────────────────────
                SubjectConfirmationStrip(subjectId: state.selectedSubjectId)
                    .opacity(carouselAppeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: carouselAppeared)

                Spacer().frame(height: 24)

                // ── Headline (left-aligned) ────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Now pick a dance")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.5)
                        .foregroundColor(.white)

                    Text("Tap one to see the magic")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(GrooveOnboardingTheme.textSecondary)
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 20)

                // ── 2x2 Dance grid ─────────────────────────────────────────────
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(onboardingPresets.prefix(4).enumerated()), id: \.element.id) { index, preset in
                        DanceCarouselCard(
                            preset: preset,
                            isSelected: selectedDanceId == preset.id
                        ) {
                            handleDanceTap(preset)
                        }
                        .opacity(carouselAppeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.04),
                            value: carouselAppeared
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                carouselAppeared = true
            }
        }
    }

    private func handleDanceTap(_ preset: DancePreset) {
        guard selectedDanceId == nil else { return }
        selectedDanceId = preset.id
        state.selectedDanceId = preset.id

        // Rigid haptic per spec ("click" feel)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        // Brief visual feedback then advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onNext()
        }
    }
}

// ─── Subject Confirmation Strip ──────────────────────────────────────────────

private struct SubjectConfirmationStrip: View {
    let subjectId: String

    private var label: String {
        switch subjectId {
        case "dog":    return "Your pet"
        case "person": return "Your person"
        default:       return "Your subject"
        }
    }

    private var thumbnailURL: String {
        let r2Base = "https://pub-7ff4cf5f3d0d431db23366638a4128e0.r2.dev/presets"
        if subjectId == "dog" {
            return "\(r2Base)/big-guy-V5-AI.mp4"
        } else {
            return "\(r2Base)/baby-boombastic.mp4"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rounded pet/subject thumbnail
            RemoteVideoThumbnail(urlString: thumbnailURL, cornerRadius: 16)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// ─── Dance Carousel Card ─────────────────────────────────────────────────────

private struct DanceCarouselCard: View {
    let preset: DancePreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Thumbnail
                ZStack(alignment: .topLeading) {
                    RemoteVideoThumbnail(
                        urlString: preset.videoURL ?? "",
                        cornerRadius: 16
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 174)

                    // Badge
                    if let badge = preset.badge {
                        Text(badge.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(badgeColor(for: badge))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(8)
                            .opacity(isSelected ? 0 : 1) // hide badge when selected
                            .animation(.easeOut(duration: 0.15), value: isSelected)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? GrooveOnboardingTheme.blueAccent : Color.clear,
                            lineWidth: isSelected ? 3 : 0
                        )
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

                // Dance name
                Text(preset.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func badgeColor(for badge: DancePreset.DanceBadge) -> Color {
        switch badge {
        case .trending: return GrooveOnboardingTheme.badgeTrending
        case .hot:      return GrooveOnboardingTheme.badgeHot
        case .fanFave:  return GrooveOnboardingTheme.badgeFanFave
        case .newDance: return GrooveOnboardingTheme.badgeNew
        }
    }
}
