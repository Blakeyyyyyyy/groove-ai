import SwiftUI
import SwiftData

struct MyVideosView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \GeneratedVideo.createdAt, order: .reverse) private var videos: [GeneratedVideo]
    @State private var showCards = false
    @State private var selectedVideo: GeneratedVideo?

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if videos.filter({ $0.status == "completed" }).isEmpty {
                    emptyState
                } else {
                    videoGrid
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("My Videos")
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

    private var videoGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(Array(videos.filter({ $0.status == "completed" }).enumerated()), id: \.element.id) { index, video in
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
                    .offset(y: showCards ? 0 : 20)
                    .opacity(showCards ? 1 : 0)
                    .animation(
                        AppAnimation.cardTransition.delay(Double(index) * 0.04),
                        value: showCards
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, 100) // tab bar + pill
        }
        .onAppear {
            withAnimation(AppAnimation.cardTransition.delay(0.1)) {
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
