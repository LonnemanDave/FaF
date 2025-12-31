import SwiftUI

struct FeedLoadingView: View {
    var body: some View {
        VStack(spacing: FAFSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                ActivityCardSkeleton()
            }
        }
    }
}

struct ActivityCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            // Header skeleton
            HStack(spacing: FAFSpacing.sm) {
                Circle()
                    .fill(Color.fafGrayXLight)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.fafGrayXLight)
                        .frame(width: 100, height: 14)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.fafGrayXXLight)
                        .frame(width: 140, height: 12)
                }

                Spacer()
            }

            // Image skeleton
            RoundedRectangle(cornerRadius: FAFRadius.sm)
                .fill(Color.fafGrayXLight)
                .frame(height: 180)

            // Title skeleton
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.fafGrayXLight)
                    .frame(height: 18)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.fafGrayXXLight)
                    .frame(width: 200, height: 14)
            }

            // Timestamp skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.fafGrayXXLight)
                .frame(width: 60, height: 12)
        }
        .padding(FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
        .redacted(reason: .placeholder)
    }
}

#Preview {
    ScrollView {
        FeedLoadingView()
            .padding()
    }
    .background(Color.fafBackground)
}
