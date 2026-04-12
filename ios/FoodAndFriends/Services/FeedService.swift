import Foundation
import FirebaseFirestore
import OSLog

enum FeedServiceError: LocalizedError {
    case noFriends
    case firestoreError(Error)

    var errorDescription: String? {
        switch self {
        case .noFriends:
            return "Add friends to see their activity"
        case .firestoreError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class FeedService: ObservableObject {
    static let shared = FeedService()

    private let db = Firestore.firestore()
    private let activitiesCollection = "activities"

    @Published var feedActivities: [Activity] = []
    @Published var isLoading = false

    private init() {}

    // MARK: - Feed Fetching

    func fetchFeed(for user: FAFUser, limit: Int = 50) async {
        guard let userId = user.id else { return }

        isLoading = true
        defer { isLoading = false }

        // Include user's own activities plus friends
        let allUserIds = user.friends + [userId]

        guard !allUserIds.isEmpty else {
            feedActivities = []
            return
        }

        do {
            // Batch into groups of 30 (Firestore whereIn limit)
            let batches = allUserIds.chunked(into: 30)
            var allActivities: [Activity] = []

            for batch in batches {
                let snapshot = try await db.collection(activitiesCollection)
                    .whereField("authorId", in: batch)
                    .order(by: "createdAt", descending: true)
                    .limit(to: limit)
                    .getDocuments()

                let activities = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Activity.self)
                }
                allActivities.append(contentsOf: activities)
            }

            // Sort merged results and limit
            feedActivities = Array(
                allActivities
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(limit)
            )
        } catch {
            Logger.feed.error("Failed to fetch feed: \(error.localizedDescription)")
            feedActivities = []
        }
    }

    func refreshFeed(for user: FAFUser) async {
        await fetchFeed(for: user)
    }

    // MARK: - Activity Creation Helpers

    func createRecipeActivity(recipe: Recipe, author: FAFUser) async throws {
        guard let authorId = author.id, let recipeId = recipe.id else { return }

        let activity = Activity(
            type: .newRecipe,
            authorId: authorId,
            createdAt: Date(),
            recipeId: recipeId,
            authorUsername: author.username,
            authorProfileImageURL: author.profileImageURL,
            contentTitle: recipe.title,
            contentDescription: recipe.description,
            contentImageURL: recipe.firstImageURL
        )

        try db.collection(activitiesCollection).addDocument(from: activity)
    }

    func createMealPlanActivity(mealPlan: MealPlan, author: FAFUser) async throws {
        guard let authorId = author.id, let mealPlanId = mealPlan.id else { return }

        let activity = Activity(
            type: .newMealPlan,
            authorId: authorId,
            createdAt: Date(),
            mealPlanId: mealPlanId,
            authorUsername: author.username,
            authorProfileImageURL: author.profileImageURL,
            contentTitle: mealPlan.name,
            contentDescription: mealPlan.description
        )

        try db.collection(activitiesCollection).addDocument(from: activity)
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
