import SwiftUI

struct ActivityCard: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            // Author Header
            ActivityAuthorHeader(activity: activity)

            // Content based on activity type
            switch activity.type {
            case .newRecipe:
                RecipePreviewCard(activity: activity)
            case .newMealPlan:
                MealPlanPreviewCard(activity: activity)
            case .recipeComment, .mealPlanComment:
                CommentActivityCard(activity: activity)
            case .recipeLike, .mealPlanLike:
                LikeActivityCard(activity: activity)
            }

            // Timestamp
            Text(activity.createdAt.timeAgoDisplay())
                .font(FAFTypography.caption)
                .foregroundColor(.fafGrayLight)
        }
        .padding(FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }
}

// MARK: - Activity Author Header

struct ActivityAuthorHeader: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: FAFSpacing.sm) {
            // Profile Image
            if let imageURL = activity.authorProfileImageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        placeholderAvatar
                    @unknown default:
                        placeholderAvatar
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                placeholderAvatar
            }

            // Username and action
            VStack(alignment: .leading, spacing: FAFSpacing.xxxs) {
                Text("@\(activity.authorUsername ?? "unknown")")
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafBlack)

                Text(activity.type.actionDescription)
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }

            Spacer()
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.fafGrayXLight)
            .frame(width: 40, height: 40)
            .overlay(
                FAFIcon(.profile, size: 20, color: .fafGray)
            )
    }
}

// MARK: - Comment Activity Card

struct CommentActivityCard: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: FAFSpacing.sm) {
            RoundedRectangle(cornerRadius: FAFRadius.xs)
                .fill(Color.fafCoralLight)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                if let targetAuthor = activity.targetAuthorUsername {
                    Text("on @\(targetAuthor)'s \(activity.isRecipeActivity ? "recipe" : "meal plan")")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                }

                if let title = activity.contentTitle {
                    Text(title)
                        .font(FAFTypography.bodyBold)
                        .foregroundColor(.fafBlack)
                        .lineLimit(1)
                }
            }
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafWhite)
        .cornerRadius(FAFRadius.sm)
    }
}

// MARK: - Like Activity Card

struct LikeActivityCard: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: FAFSpacing.sm) {
            Image(systemName: "heart.fill")
                .font(.system(size: 16))
                .foregroundColor(.fafCoral)

            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                if let targetAuthor = activity.targetAuthorUsername {
                    Text("@\(targetAuthor)'s \(activity.isRecipeActivity ? "recipe" : "meal plan")")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                }

                if let title = activity.contentTitle {
                    Text(title)
                        .font(FAFTypography.body)
                        .foregroundColor(.fafBlack)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafWhite)
        .cornerRadius(FAFRadius.sm)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: FAFSpacing.md) {
            ActivityCard(activity: Activity(
                type: .newRecipe,
                authorId: "123",
                authorUsername: "johndoe",
                contentTitle: "Grandma's Apple Pie",
                contentDescription: "A delicious homemade apple pie recipe passed down through generations."
            ))

            ActivityCard(activity: Activity(
                type: .newMealPlan,
                authorId: "123",
                authorUsername: "janedoe",
                contentTitle: "Healthy Week Plan",
                contentDescription: "Meal prep for a healthy week ahead"
            ))
        }
        .padding()
    }
    .background(Color.fafWhite)
}
