//
//  SwipeableJournalCardView.swift
//  SomaTracker
//
//  Native swipe-to-delete AI Journal card with full-swipe action and context menu.
//

import SwiftUI

struct AIMealJournalCardView: View {
    let entry: AIMealEntry

    private var hasValidVoiceAudio: Bool {
        guard let relPath = entry.voiceAudioRelativePath, !relPath.isEmpty else { return false }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = docs.appendingPathComponent(relPath).path
        guard FileManager.default.fileExists(atPath: path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > 1000 else { return false }
        return true
    }

    var body: some View {
        HStack(spacing: 14) {
            // Photo thumbnail or aesthetic navy badge
            ZStack {
                if let photoData = entry.photoDataList.first, let img = UIImage(data: photoData) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SomaColors.navy)
                        .frame(width: 76, height: 76)
                        .overlay(
                            Image(systemName: hasValidVoiceAudio ? "waveform" : "fork.knife")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        )
                }
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title.isEmpty ? "AI Log" : entry.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)

                    Spacer()

                    if hasValidVoiceAudio {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(SomaColors.iris)
                    }
                }

                if !entry.location.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                        Text(entry.location)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                }

                // Macronutrient lockup
                HStack(spacing: 8) {
                    Text("\(entry.calories) kcal")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(SomaColors.coral)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.tertiaryLabel))

                    Text("\(Int(entry.proteinG))g P")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SomaColors.iris)

                    if entry.carbsG > 0 {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(.tertiaryLabel))

                        Text("\(Int(entry.carbsG))g C")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(SomaColors.amber)
                    }

                    if entry.fatG > 0 {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(.tertiaryLabel))

                        Text("\(Int(entry.fatG))g F")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(SomaColors.emerald)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
}

struct SwipeableJournalCardView: View {
    let entry: AIMealEntry
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            AIMealJournalCardView(entry: entry)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Meal Entry", systemImage: "trash")
            }
        }
    }
}

