//
//  HomeView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct HomeView: View {
    @State private var showingSettings = false
    @State private var trendingContent: [TMDBSearchResult] = []
    @State private var popularMovies: [TMDBMovie] = []
    @State private var popularTVShows: [TMDBTVShow] = []
    @State private var nowPlayingMovies: [TMDBMovie] = []
    @State private var topRatedMovies: [TMDBMovie] = []
    @State private var topRatedTVShows: [TMDBTVShow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var heroContent: TMDBSearchResult?
    @State private var ambientColor: Color = Color.black
    @State private var hasLoadedContent = false
    
    @StateObject private var tmdbService = TMDBService.shared
    
    private let heroHeight: CGFloat = 500
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                homeContent
            }
        } else {
            NavigationView {
                homeContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var homeContent: some View {
        ZStack {
            ambientColor
                .ignoresSafeArea(.all)
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else {
                mainScrollView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !hasLoadedContent {
                loadContent()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading amazing content...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Connection Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry") {
                loadContent()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                heroSection
                contentSections
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            StretchyHeaderView(
                backdropURL: heroContent?.fullBackdropURL ?? heroContent?.fullPosterURL,
                isMovie: heroContent?.isMovie ?? true,
                headerHeight: heroHeight,
                minHeaderHeight: 300,
                onAmbientColorExtracted: { color in
                    ambientColor = color
                }
            )
            
            heroGradientOverlay
            heroContentInfo
        }
    }
    
    @ViewBuilder
    private var heroGradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: ambientColor.opacity(0.0), location: 0.0),
                .init(color: ambientColor.opacity(0.4), location: 0.2),
                .init(color: ambientColor.opacity(0.7), location: 0.6),
                .init(color: ambientColor.opacity(1), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
    
    @ViewBuilder
    private var heroContentInfo: some View {
        if let hero = heroContent {
            VStack(alignment: .center, spacing: 12) {
                HStack {
                    Text(hero.isMovie ? "Movie" : "TV Series")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.5))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    
                    if (hero.voteAverage ?? 0.0) > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", hero.voteAverage ?? 0.0))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.5))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
                
                Text(hero.displayTitle)
                    .font(.system(size: 25))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                if let overview = hero.overview, !overview.isEmpty {
                    Text(String(overview.prefix(100)) + (overview.count > 100 ? "..." : ""))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                HStack(spacing: 16) {
                    NavigationLink(destination: MediaDetailView(searchResult: hero)) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.subheadline)
                            Text("Watch Now")
                                .fontWeight(.semibold)
                        }
                        .frame(width: 140, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial.opacity(0.9))
                        )
                        .foregroundColor(.primary)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        // TODO: Add to watchlist
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.subheadline)
                            Text("Watchlist")
                                .fontWeight(.semibold)
                        }
                        .frame(width: 140, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var contentSections: some View {
        VStack(spacing: 0) {
            continueWatchingSection
            
            if !trendingContent.isEmpty {
                let filteredTrending = trendingContent.filter { $0.id != heroContent?.id }
                MediaSection(
                    title: "Trending This Week",
                    items: Array(filteredTrending.prefix(15)),
                    isLarge: true
                )
            }
            
            if !nowPlayingMovies.isEmpty {
                MediaSection(
                    title: "Now Playing",
                    items: nowPlayingMovies.prefix(15).map { $0.asSearchResult }
                )
            }
            
            if !popularMovies.isEmpty {
                MediaSection(
                    title: "Popular Movies",
                    items: popularMovies.prefix(15).map { $0.asSearchResult }
                )
            }
            
            if !popularTVShows.isEmpty {
                MediaSection(
                    title: "Popular TV Shows",
                    items: popularTVShows.prefix(15).map { $0.asSearchResult }
                )
            }
            
            if !topRatedMovies.isEmpty {
                MediaSection(
                    title: "Top Rated Movies",
                    items: topRatedMovies.prefix(15).map { $0.asSearchResult }
                )
            }
            
            if !topRatedTVShows.isEmpty {
                MediaSection(
                    title: "Top Rated TV Shows",
                    items: topRatedTVShows.prefix(15).map { $0.asSearchResult }
                )
            }
            
            Spacer(minLength: 50)
        }
        .background(Color.clear)
    }
    
    @ViewBuilder
    private var continueWatchingSection: some View {
        EmptyView()
        
        /*
         VStack(alignment: .leading, spacing: 16) {
         HStack {
         Text("ontinue Watching")
         .font(.title2)
         .fontWeight(.bold)
         .foregroundColor(.primary)
         
         Spacer()
         }
         .padding(.horizontal)
         
         ScrollView(.horizontal, showsIndicators: false) {
         LazyHStack(spacing: 12) {
         ForEach(0..<3, id: \.self) { _ in
         ContinueWatchingPlaceholder()
         }
         }
         .padding(.horizontal)
         }
         }
         .padding(.vertical, 24)
         */
    }
    
    private func loadContent() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                async let trending = tmdbService.getTrending()
                async let popularM = tmdbService.getPopularMovies()
                async let popularTV = tmdbService.getPopularTVShows()
                async let nowPlaying = tmdbService.getNowPlayingMovies()
                async let topRatedM = tmdbService.getTopRatedMovies()
                async let topRatedTV = tmdbService.getTopRatedTVShows()
                
                let (trendingResult, popularMoviesResult, popularTVResult, nowPlayingResult, topRatedMoviesResult, topRatedTVResult) = try await (trending, popularM, popularTV, nowPlaying, topRatedM, topRatedTV)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.trendingContent = trendingResult
                        self.popularMovies = popularMoviesResult
                        self.popularTVShows = popularTVResult
                        self.nowPlayingMovies = nowPlayingResult
                        self.topRatedMovies = topRatedMoviesResult
                        self.topRatedTVShows = topRatedTVResult
                        
                        self.heroContent = trendingResult.first { $0.backdropPath != nil } ?? trendingResult.first
                        self.isLoading = false
                        self.hasLoadedContent = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("Error loading content: \(error)")
                }
            }
        }
    }
}

struct MediaSection: View {
    let title: String
    let items: [TMDBSearchResult]
    let isLarge: Bool
    
    init(title: String, items: [TMDBSearchResult], isLarge: Bool = false) {
        self.title = title
        self.items = items
        self.isLarge = isLarge
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: isLarge ? 20 : 10) {
                    ForEach(items) { item in
                        if isLarge {
                            FeaturedCard(result: item, isLarge: true)
                        } else {
                            MediaCard(result: item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 24)
        .opacity(items.isEmpty ? 0 : 1)
    }
}

struct MediaCard: View {
    let result: TMDBSearchResult
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: result)) {
            VStack(alignment: .leading, spacing: 6) {
                KFImage(URL(string: result.fullPosterURL ?? ""))
                    .placeholder {
                        FallbackImageView(
                            isMovie: result.isMovie,
                            size: CGSize(width: 120, height: 180)
                        )
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 120, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.displayTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 3) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", result.voteAverage ?? 0.0))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(result.isMovie ? "Movie" : "TV")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContinueWatchingPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 120)
                
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue Watching")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Feature coming soon...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 200, alignment: .leading)
        }
    }
}
