import Foundation
import FirebaseFirestore

enum MealPlanServiceError: LocalizedError {
    case mealPlanNotFound
    case unauthorized
    case invalidData
    case firestoreError(Error)

    var errorDescription: String? {
        switch self {
        case .mealPlanNotFound:
            return "Meal plan not found"
        case .unauthorized:
            return "You don't have permission to modify this meal plan"
        case .invalidData:
            return "Invalid meal plan data"
        case .firestoreError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class MealPlanService: ObservableObject {
    static let shared = MealPlanService()

    private let db = Firestore.firestore()
    private let mealPlansCollection = "mealPlans"
    private let activitiesCollection = "activities"

    @Published var userMealPlans: [MealPlan] = []
    @Published var isLoading = false

    private init() {}

    // MARK: - Create

    func createMealPlan(_ mealPlan: MealPlan, author: FAFUser) async throws -> MealPlan {
        guard let authorId = author.id else {
            throw MealPlanServiceError.invalidData
        }

        var newMealPlan = mealPlan
        newMealPlan.authorUsername = author.username
        newMealPlan.authorProfileImageURL = author.profileImageURL

        let docRef = try db.collection(mealPlansCollection).addDocument(from: newMealPlan)

        // Create activity for feed
        let activity = Activity(
            type: .newMealPlan,
            authorId: authorId,
            createdAt: Date(),
            mealPlanId: docRef.documentID,
            authorUsername: author.username,
            authorProfileImageURL: author.profileImageURL,
            contentTitle: newMealPlan.name,
            contentDescription: newMealPlan.description
        )
        try db.collection(activitiesCollection).addDocument(from: activity)

        // Fetch and return created meal plan
        guard let created = try await fetchMealPlan(id: docRef.documentID) else {
            throw MealPlanServiceError.mealPlanNotFound
        }
        return created
    }

    // MARK: - Read

    func fetchMealPlan(id: String) async throws -> MealPlan? {
        let doc = try await db.collection(mealPlansCollection).document(id).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: MealPlan.self)
    }

    func fetchUserMealPlans(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection(mealPlansCollection)
                .whereField("authorId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            userMealPlans = snapshot.documents.compactMap { doc in
                try? doc.data(as: MealPlan.self)
            }
        } catch {
            print("Error fetching user meal plans: \(error)")
        }
    }

    func fetchMealPlans(by userIds: [String], limit: Int = 20) async throws -> [MealPlan] {
        guard !userIds.isEmpty else { return [] }

        // Batch into groups of 30 (Firestore whereIn limit)
        let batches = userIds.chunked(into: 30)
        var allMealPlans: [MealPlan] = []

        for batch in batches {
            let snapshot = try await db.collection(mealPlansCollection)
                .whereField("authorId", in: batch)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            let mealPlans = snapshot.documents.compactMap { doc in
                try? doc.data(as: MealPlan.self)
            }
            allMealPlans.append(contentsOf: mealPlans)
        }

        return allMealPlans
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Update

    func updateMealPlan(_ mealPlan: MealPlan) async throws {
        guard let mealPlanId = mealPlan.id else {
            throw MealPlanServiceError.mealPlanNotFound
        }

        var updatedMealPlan = mealPlan
        updatedMealPlan.updatedAt = Date()

        try db.collection(mealPlansCollection)
            .document(mealPlanId)
            .setData(from: updatedMealPlan, merge: true)

        // Update local cache
        if let index = userMealPlans.firstIndex(where: { $0.id == mealPlanId }) {
            userMealPlans[index] = updatedMealPlan
        }
    }

    // MARK: - Delete

    func deleteMealPlan(_ mealPlan: MealPlan) async throws {
        guard let mealPlanId = mealPlan.id else {
            throw MealPlanServiceError.mealPlanNotFound
        }

        try await db.collection(mealPlansCollection).document(mealPlanId).delete()
        userMealPlans.removeAll { $0.id == mealPlanId }
    }
}
