import Foundation
import FirebaseFirestore

enum ActivityType: String, Codable {
    case newRecipe
    case newMealPlan
    case recipeComment
    case recipeLike
    case mealPlanComment
    case mealPlanLike

    var actionDescription: String {
        switch self {
        case .newRecipe: return "shared a new recipe"
        case .newMealPlan: return "created a meal plan"
        case .recipeComment: return "commented on a recipe"
        case .recipeLike: return "liked a recipe"
        case .mealPlanComment: return "commented on a meal plan"
        case .mealPlanLike: return "liked a meal plan"
        }
    }

    var icon: String {
        switch self {
        case .newRecipe: return "fork.knife"
        case .newMealPlan: return "calendar"
        case .recipeComment, .mealPlanComment: return "bubble.right"
        case .recipeLike, .mealPlanLike: return "heart.fill"
        }
    }
}

struct Activity: Codable, Identifiable {
    @DocumentID var id: String?
    let type: ActivityType
    let authorId: String
    let createdAt: Date

    // Reference to content (populated based on type)
    var recipeId: String?
    var mealPlanId: String?
    var commentId: String?

    // Denormalized author info for feed display
    var authorUsername: String?
    var authorProfileImageURL: String?

    // Content preview data
    var contentTitle: String?
    var contentDescription: String?
    var contentImageURL: String?

    // For likes/comments - the original author
    var targetAuthorUsername: String?

    init(
        id: String? = nil,
        type: ActivityType,
        authorId: String,
        createdAt: Date = Date(),
        recipeId: String? = nil,
        mealPlanId: String? = nil,
        commentId: String? = nil,
        authorUsername: String? = nil,
        authorProfileImageURL: String? = nil,
        contentTitle: String? = nil,
        contentDescription: String? = nil,
        contentImageURL: String? = nil,
        targetAuthorUsername: String? = nil
    ) {
        self.id = id
        self.type = type
        self.authorId = authorId
        self.createdAt = createdAt
        self.recipeId = recipeId
        self.mealPlanId = mealPlanId
        self.commentId = commentId
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
        self.contentTitle = contentTitle
        self.contentDescription = contentDescription
        self.contentImageURL = contentImageURL
        self.targetAuthorUsername = targetAuthorUsername
    }

    var isRecipeActivity: Bool {
        switch type {
        case .newRecipe, .recipeComment, .recipeLike:
            return true
        default:
            return false
        }
    }

    var isMealPlanActivity: Bool {
        switch type {
        case .newMealPlan, .mealPlanComment, .mealPlanLike:
            return true
        default:
            return false
        }
    }
}
