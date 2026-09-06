//
//  FloatingActionDock.swift
//  SomaTracker
//
//  Floating action dock matching the user mockup with 4 quick tools:
//  Log/Edit, Photos, Share, and Bookmark.
//

import SwiftUI

struct FloatingActionDock: View {
    var isBookmarked: Bool = false
    var onLogTap: () -> Void
    var onPhotosTap: () -> Void
    var onShareTap: () -> Void
    var onBookmarkTap: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            // 1. Log / Edit
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onLogTap()
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color(.label))
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .accessibilityLabel("Log to Daily Tracker")

            // 2. Photos
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPhotosTap()
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color(.label))
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .accessibilityLabel("Add Photos")

            // 3. Share
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onShareTap()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color(.label))
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .accessibilityLabel("Share Entry")

            // 4. Bookmark
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onBookmarkTap()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(isBookmarked ? SomaColors.coral : Color(.label))
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .accessibilityLabel("Bookmark Meal")
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.92))
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(.separator).opacity(0.4), lineWidth: 0.8)
                )
        )
    }
}

#Preview {
    FloatingActionDock(
        isBookmarked: false,
        onLogTap: {},
        onPhotosTap: {},
        onShareTap: {},
        onBookmarkTap: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
