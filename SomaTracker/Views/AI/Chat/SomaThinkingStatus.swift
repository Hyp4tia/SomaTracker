import SwiftUI

struct SomaThinkingStatus: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .foregroundStyle(SomaColors.navy)
            Text("Soma is thinking...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
