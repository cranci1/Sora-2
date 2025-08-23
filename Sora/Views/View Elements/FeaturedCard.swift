//
//  FeaturedCard.swift
//  Sora
//
//  Created by Francesco on 17/08/25.
//

import SwiftUI
import Kingfisher

struct FeaturedCard: View {
    let result: TMDBSearchResult
    let isLarge: Bool
    
    init(result: TMDBSearchResult, isLarge: Bool = false) {
        self.result = result
        self.isLarge = isLarge
    }
    
    private var cardWidth: CGFloat {
        isLarge ? 250 : 140
    }
    
    private var cardHeight: CGFloat {
        isLarge ? 150 : 210
    }
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: result)) {
            if isLarge {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        KFImage(URL(string: result.fullBackdropURL ?? result.fullPosterURL ?? ""))
                            .placeholder {
                                FallbackImageView(
                                    isMovie: result.isMovie,
                                    size: CGSize(width: 250, height: 150)
                                )
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 250, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .clipped()
                        
                        // Overlay avec pilules mediatype et rating
                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: 8) {
                                    // Pilule mediatype
                                    Text(result.isMovie ? "Movie" : "TV Show")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Color(red: 0.62, green: 0.62, blue: 0.62).opacity(0.4)
                                        )
                                        .clipShape(Capsule())
                                    
                                    // Pilule rating
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                        Text(String(format: "%.1f", result.voteAverage ?? 0.0))
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Color(red: 0.62, green: 0.62, blue: 0.62).opacity(0.4)
                                    )
                                    .clipShape(Capsule())
                                }
                                Spacer()
                            }
                            .padding(.leading, 10)
                            .padding(.bottom, 10)
                        }
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Titre positionné sous l'image
                    HStack {
                        Spacer()
                            .frame(width: 8)  // Décalage de 8px à droite
                        
                        Text(result.displayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.top, 8)  // 8px en dessous de l'image
                }
                .contentShape(Rectangle())
            } else {
                // Design original pour les cartes non-large
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        KFImage(URL(string: result.fullBackdropURL ?? result.fullPosterURL ?? ""))
                            .placeholder {
                                FallbackImageView(
                                    isMovie: result.isMovie,
                                    size: CGSize(width: cardWidth, height: cardHeight * 0.75)
                                )
                            }
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight * 0.75)
                            .clipped()
                        
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.clear, location: 0.0),
                                .init(color: Color.black.opacity(0.3), location: 0.5),
                                .init(color: Color.black.opacity(0.7), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: cardHeight * 0.4)
                        
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", result.voteAverage ?? 0.0))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.displayTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text(result.isMovie ? "Movie" : "TV Show")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if !result.displayDate.isEmpty {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(result.displayDate.prefix(4)))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(width: cardWidth, alignment: .leading)
                    .padding(.top, 8)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
