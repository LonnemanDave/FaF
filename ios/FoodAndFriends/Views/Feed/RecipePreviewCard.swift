import SwiftUI

struct RecipePreviewCard: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            // Recipe Image
            if let imageURL = activity.contentImageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .background(Color.fafGrayXLight)
                    @unknown default:
                        imagePlaceholder
                    }
                }
                .frame(height: 180)
                .clipped()
                .cornerRadius(FAFRadius.sm)
            } else {
                imagePlaceholder
            }

            // Recipe Info
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                Text(activity.contentTitle ?? "Untitled Recipe")
                    .font(FAFTypography.h3)
                    .foregroundColor(.fafBlack)
                    .lineLimit(2)

                if let description = activity.contentDescription, !description.isEmpty {
                    Text(description)
                        .font(FAFTypography.body)
                        .foregroundColor(.fafGray)
                        .lineLimit(2)
                }
            }
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color.fafGrayXLight)
            .frame(height: 180)
            .overlay(
                FAFIcon(.fork, size: 32, color: .fafGray)
            )
            .cornerRadius(FAFRadius.sm)
    }
}

#Preview {
    RecipePreviewCard(activity: Activity(
        type: .newRecipe,
        authorId: "123",
        authorUsername: "chef_mike",
        contentTitle: "Perfect Pancakes",
        contentDescription: "Fluffy buttermilk pancakes that are perfect for Sunday brunch."
    ))
    .padding()
    .background(Color.fafOffWhite)
}
