import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showContent = false
    @State private var navigateToPreset: DancePreset?
    @State private var navigateToCategory: CategoryNavItem?
    @StateObject private var playerPool = AVPlayerPoolManager.shared

    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.38

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if showContent {
                    LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                        // Hero Banner — top of home, above presets
                        HStack {
                            Spacer()
                            HeroBannerView {
                                // Navigate to first trending preset
                                if let first = DancePreset.allPresets.first {
                                    navigateToPreset = first
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, Spacing.sm)

                        // Category rows
                        ForEach(DancePreset.categories) { category in
                            categoryRow(category)
                        }

                        // Bottom padding for tab bar + generating pill
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, Spacing.sm)
                    .transition(.opacity)
                } else {
                    skeletonRows
                }
            }
            .background(Color.bgPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Groove AI")
                        .font(.title3.bold())
                        .foregroundStyle(Color.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AppHeaderCoinPill()
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: DancePreset.self) { preset in
                DancePreviewView(preset: preset)
                    .toolbar(.hidden, for: .tabBar)
            }
            .navigationDestination(for: String.self) { value in
                if value.hasPrefix("upload-") {
                    let presetID = String(value.dropFirst(7))
                    if let preset = DancePreset.allPresets.first(where: { $0.id == presetID }) {
                        UploadView(preset: preset)
                            .toolbar(.hidden, for: .tabBar)
                    }
                }
            }
            .navigationDestination(item: $navigateToPreset) { preset in
                DancePreviewView(preset: preset)
                    .toolbar(.hidden, for: .tabBar)
            }
            .navigationDestination(item: $navigateToCategory) { item in
                CategorySwipeView(
                    category: item.category,
                    initialPreset: item.initialPreset
                )
                .toolbar(.hidden, for: .tabBar)
            }
        }
        // Fix 1: inject pool into environment for all descendant views
        .environment(\.playerPool, playerPool)
        .task {
            // BUG-001 fix: use .task for reliable state init
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(AppAnimation.cardTransition) {
                showContent = true
            }
        }
    }

    // MARK: - Category Row

    @ViewBuilder
    private func categoryRow(_ category: DancePreset.CategoryGroup) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                if category.id == "Trending" {
                    Text("🔥")
                }

                Spacer()

                Button {
                    if let first = category.presets.first {
                        navigateToCategory = CategoryNavItem(
                            category: category,
                            initialPreset: first
                        )
                    }
                } label: {
                    Text("See all →")
                        .font(.caption)
                        .foregroundStyle(Color.accentStart)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(category.presets) { preset in
                        NavigationLink(value: preset) {
                            DancePresetCard(preset: preset)
                                .frame(width: cardWidth)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Skeleton Shimmer

    private var skeletonRows: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Hero banner skeleton
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(Color.bgSecondary)
                    .frame(width: UIScreen.main.bounds.width * 0.75, height: 160)
                    .shimmer()
                Spacer()
            }

            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.bgSecondary)
                        .frame(width: 120, height: 20)
                        .padding(.horizontal, Spacing.lg)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .fill(Color.bgSecondary)
                                    .frame(width: cardWidth, height: 180)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                }
            }
        }
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.bgElevated.opacity(0.4),
                        .clear
                    ],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .clipped()
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Coins Pill

struct CoinsPillView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(Color.coinGold)
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.bgSecondary)
        .clipShape(Capsule())
    }
}

// MARK: - Category Navigation Item

struct CategoryNavItem: Identifiable, Hashable {
    let id: String
    let category: DancePreset.CategoryGroup
    let initialPreset: DancePreset

    init(category: DancePreset.CategoryGroup, initialPreset: DancePreset) {
        self.id = "\(category.id)-\(initialPreset.id)"
        self.category = category
        self.initialPreset = initialPreset
    }

    static func == (lhs: CategoryNavItem, rhs: CategoryNavItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
