import SwiftUI

struct MealPlanPreviewCard: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: FAFSpacing.md) {
            // Calendar Icon
            RoundedRectangle(cornerRadius: FAFRadius.sm)
                .fill(Color.fafSageLight)
                .frame(width: 56, height: 56)
                .overlay(
                    FAFIcon(.calendar, size: 28, color: .fafSage)
                )

            // Meal Plan Info
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                Text(activity.contentTitle ?? "Untitled Meal Plan")
                    .font(FAFTypography.h4)
                    .foregroundColor(.fafBlack)
                    .lineLimit(2)

                if let description = activity.contentDescription, !description.isEmpty {
                    Text(description)
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Arrow indicator
            FAFIcon(.forward, size: 16, color: .fafGrayLight)
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafWhite)
        .cornerRadius(FAFRadius.sm)
    }
}

#Preview {
    MealPlanPreviewCard(activity: Activity(
        type: .newMealPlan,
        authorId: "123",
        authorUsername: "healthy_eater",
        contentTitle: "Mediterranean Week",
        contentDescription: "A week of delicious Mediterranean-inspired meals"
    ))
    .padding()
    .background(Color.fafOffWhite)
}
