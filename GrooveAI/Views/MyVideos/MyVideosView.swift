import SwiftUI
import SwiftData

struct MyVideosView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \GeneratedVideo.createdAt, order: .reverse) private var videos: [GeneratedVideo]
    @State private var showCards = false
    @State private var selectedVideo: GeneratedVideo?

    // 3 columns for ~25% smaller thumbnails
    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed header — always visible
                HStack {
                    Text("My Videos")
                        .font(.title2.bold())
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if !completedVideos.isEmpty {
                        Text("\(completedVideos.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.bgSecondary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)

                if completedVideos.isEmpty {
                    emptyState
                } else {
                    videoGrid
                }
            }
            .background(Color.bgPrimary)
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .fullScreenCover(item: $selectedVideo) { video in
                CompletedVideoView(video: video) {
                    selectedVideo = nil
                    appState.selectedTab = .home
                }
            }
        }
    }

    private var completedVideos: [GeneratedVideo] {
        videos.filter { $0.status == "completed" }
    }

    private var videoGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(Array(completedVideos.enumerated()), id: \.element.id) { index, video in
                    VideoThumbnailCard(
                        danceName: video.danceName,
                        date: video.createdAt,
                        photoData: video.photoData,
                        onTap: { selectedVideo = video }
                    )
                    .contextMenu {
                        Button {
                            // Share
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            // Save
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }

                        Button(role: .destructive) {
                            // Delete
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .offset(y: showCards ? 0 : 12)
                    .opacity(showCards ? 1 : 0)
                    .animation(
                        AppAnimation.snappy.delay(Double(index) * 0.02),
                        value: showCards
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, 100) // tab bar + pill
        }
        .onAppear {
            withAnimation(AppAnimation.snappy.delay(0.05)) {
                showCards = true
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "film.stack",
                headline: "Your videos will live here",
                bodyText: "Pick a dance style, upload a photo, and make someone dance. Your creations show up here.",
                ctaLabel: "Browse Dance Styles →",
                ctaAction: { appState.selectedTab = .home }
            )
            Spacer()
        }
    }
}

#Preview {
    MyVideosView()
        .environment(AppState())
        .modelContainer(for: GeneratedVideo.self, inMemory: true)
}
