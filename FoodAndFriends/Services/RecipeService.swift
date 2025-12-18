import Foundation
import FirebaseFirestore

enum RecipeServiceError: LocalizedError {
    case recipeNotFound
    case unauthorized
    case invalidData
    case firestoreError(Error)

    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return "Recipe not found"
        case .unauthorized:
            return "You don't have permission to modify this recipe"
        case .invalidData:
            return "Invalid recipe data"
        case .firestoreError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class RecipeService: ObservableObject {
    static let shared = RecipeService()

    private let db = Firestore.firestore()
    private let recipesCollection = "recipes"
    private let activitiesCollection = "activities"

    @Published var userRecipes: [Recipe] = []
    @Published var isLoading = false

    private init() {}

    // MARK: - Create

    func createRecipe(_ recipe: Recipe, author: FAFUser) async throws -> Recipe {
        guard let authorId = author.id else {
            throw RecipeServiceError.invalidData
        }

        var newRecipe = recipe
        newRecipe.authorUsername = author.username
        newRecipe.authorProfileImageURL = author.profileImageURL

        let docRef = try db.collection(recipesCollection).addDocument(from: newRecipe)

        // Create activity for feed
        let activity = Activity(
            type: .newRecipe,
            authorId: authorId,
            createdAt: Date(),
            recipeId: docRef.documentID,
            authorUsername: author.username,
            authorProfileImageURL: author.profileImageURL,
            contentTitle: newRecipe.title,
            contentDescription: newRecipe.description,
            contentImageURL: newRecipe.firstImageURL
        )
        try db.collection(activitiesCollection).addDocument(from: activity)

        // Fetch and return created recipe
        guard let created = try await fetchRecipe(id: docRef.documentID) else {
            throw RecipeServiceError.recipeNotFound
        }
        return created
    }

    // MARK: - Read

    func fetchRecipe(id: String) async throws -> Recipe? {
        let doc = try await db.collection(recipesCollection).document(id).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: Recipe.self)
    }

    func fetchUserRecipes(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection(recipesCollection)
                .whereField("authorId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            userRecipes = snapshot.documents.compactMap { doc in
                try? doc.data(as: Recipe.self)
            }
        } catch {
            print("Error fetching user recipes: \(error)")
        }
    }

    func fetchRecipes(by userIds: [String], limit: Int = 20) async throws -> [Recipe] {
        guard !userIds.isEmpty else { return [] }

        // Batch into groups of 30 (Firestore whereIn limit)
        let batches = userIds.chunked(into: 30)
        var allRecipes: [Recipe] = []

        for batch in batches {
            let snapshot = try await db.collection(recipesCollection)
                .whereField("authorId", in: batch)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            let recipes = snapshot.documents.compactMap { doc in
                try? doc.data(as: Recipe.self)
            }
            allRecipes.append(contentsOf: recipes)
        }

        return allRecipes
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Update

    func updateRecipe(_ recipe: Recipe) async throws {
        guard let recipeId = recipe.id else {
            throw RecipeServiceError.recipeNotFound
        }

        var updatedRecipe = recipe
        updatedRecipe.updatedAt = Date()

        try db.collection(recipesCollection)
            .document(recipeId)
            .setData(from: updatedRecipe, merge: true)

        // Update local cache
        if let index = userRecipes.firstIndex(where: { $0.id == recipeId }) {
            userRecipes[index] = updatedRecipe
        }
    }

    // MARK: - Delete

    func deleteRecipe(_ recipe: Recipe) async throws {
        guard let recipeId = recipe.id else {
            throw RecipeServiceError.recipeNotFound
        }

        try await db.collection(recipesCollection).document(recipeId).delete()
        userRecipes.removeAll { $0.id == recipeId }
    }
}
