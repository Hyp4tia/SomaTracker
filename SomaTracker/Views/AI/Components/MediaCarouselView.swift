//
//  MediaCarouselView.swift
//  SomaTracker
//
//  Swipeable photo carousel matching the user mockup with custom pagination dots.
//

import SwiftUI

struct MediaCarouselView: View {
    let photos: [Data]
    @State private var currentIndex: Int = 0

    private var effectiveCount: Int {
        max(1, photos.count)
    }

    var body: some View {
        VStack(spacing: 12) {
            if photos.count > 1 {
                // Multi-photo Carousel with Paging
                TabView(selection: $currentIndex) {
                    ForEach(0..<photos.count, id: \.self) { index in
                        if let uiImage = UIImage(data: photos[index]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .tag(index)
                        } else {
                            placeholderCard
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 280)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)

                // Pagination Dots
                HStack(spacing: 6) {
                    ForEach(0..<photos.count, id: \.self) { index in
                        Circle()
                            .fill(currentIndex == index ? SomaColors.navy : Color(.systemGray4))
                            .frame(width: currentIndex == index ? 6.5 : 5.5, height: currentIndex == index ? 6.5 : 5.5)
                            .animation(.snappy(duration: 0.2), value: currentIndex)
                    }
                }
                .padding(.top, 2)
            } else if let firstPhoto = photos.first, let uiImage = UIImage(data: firstPhoto) {
                // Single Photo Static Card (Zero gesture interception)
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            } else {
                // Placeholder Static Card (Zero gesture interception)
                placeholderCard
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            }
        }
    }

    private var placeholderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 10) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(SomaColors.navy.opacity(0.6))

                Text("AI Multimodal Log")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }
}

#Preview {
    MediaCarouselView(photos: [])
        .padding()
}
