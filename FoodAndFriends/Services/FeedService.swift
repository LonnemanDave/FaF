import Foundation
import FirebaseFirestore

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
    private let usersCollection = "users"

    private var feedListeners: [ListenerRegistration] = []
    private var currentUserId: String?

    @Published var feedActivities: [Activity] = []
    @Published var isLoading = false

    // Cache of user profile data for enriching activities
    private var userCache: [String: FAFUser] = [:]

    private init() {}

    // MARK: - Realtime Listeners

    func startListening(userId: String, friendIds: [String]) {
        stopListening()
        currentUserId = userId

        // Include user's own activities plus friends
        let allUserIds = friendIds + [userId]

        guard !allUserIds.isEmpty else {
            feedActivities = []
            return
        }

        // Batch into groups of 30 (Firestore whereIn limit)
        let batches = allUserIds.chunked(into: 30)
        var allActivities: [[Activity]] = Array(repeating: [], count: batches.count)

        for (index, batch) in batches.enumerated() {
            let listener = db.collection(activitiesCollection)
                .whereField("authorId", in: batch)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    if let error = error {
                        print("Error listening to feed: \(error)")
                        return
                    }

                    let activities = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: Activity.self)
                    } ?? []

                    allActivities[index] = activities

                    // Combine all batches and sort
                    self.feedActivities = allActivities
                        .flatMap { $0 }
                        .sorted { $0.createdAt > $1.createdAt }
                }
            feedListeners.append(listener)
        }
    }

    func updateFeedListener(userId: String, friendIds: [String]) {
        startListening(userId: userId, friendIds: friendIds)
    }

    func stopListening() {
        feedListeners.forEach { $0.remove() }
        feedListeners.removeAll()
        currentUserId = nil
        feedActivities = []
        userCache.removeAll()
    }

    // Legacy methods for backwards compatibility
    func fetchFeed(for user: FAFUser, limit: Int = 50) async {
        // Now handled by listeners, but keep for manual refresh
        guard let userId = user.id else { return }
        startListening(userId: userId, friendIds: user.friends)
    }

    func refreshFeed(for user: FAFUser) async {
        guard let userId = user.id else { return }
        userCache.removeAll()
        startListening(userId: userId, friendIds: user.friends)
    }

    func clearCache() {
        stopListening()
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
