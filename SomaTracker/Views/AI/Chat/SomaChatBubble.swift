import SwiftUI

struct SomaChatBubble: View {
    let message: SomaChatMessage

    var body: some View {
        HStack {
            if message.author == .user { Spacer(minLength: 52) }

            VStack(alignment: .leading, spacing: 10) {
                if !message.photos.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(Array(message.photos.enumerated()), id: \.offset) { _, data in
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                if !message.title.isEmpty {
                    HStack(spacing: 7) {
                        if message.kind == .receipt {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(SomaColors.emerald)
                        }
                        Text(message.title)
                            .font(.headline)
                    }
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if message.calories > 0 {
                    HStack(spacing: 12) {
                        nutrient("\(message.calories)", "kcal")
                        nutrient(Int(message.proteinG.rounded()).description, "protein")
                        nutrient(Int(message.carbsG.rounded()).description, "carbs")
                        nutrient(Int(message.fatG.rounded()).description, "fat")
                    }
                } else if message.waterML > 0 {
                    Label("\(message.waterML) ml", systemImage: "drop.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SomaColors.aqua)
                }
            }
            .foregroundStyle(message.author == .user ? Color.white : Color.primary)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(message.author == .user ? SomaColors.navy : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))

            if message.author == .soma { Spacer(minLength: 52) }
        }
        .accessibilityElement(children: .combine)
    }

    private func nutrient(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
