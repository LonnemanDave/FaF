import Foundation
import FirebaseFirestore

enum RecipeServiceError: LocalizedError {
    case recipeNotFound
    case unauthorized
    case invalidData
    case duplicateRecipe(existingRecipe: Recipe)
    case variationExists
    case firestoreError(Error)

    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return "Recipe not found"
        case .unauthorized:
            return "You don't have permission to modify this recipe"
        case .invalidData:
            return "Invalid recipe data"
        case .duplicateRecipe:
            return "A recipe with this name already exists"
        case .variationExists:
            return "You already have a variation for this recipe"
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
    private let variationsSubcollection = "variations"

    @Published var userRecipes: [Recipe] = []
    @Published var friendsRecipes: [Recipe] = []
    @Published var globalRecipes: [Recipe] = []
    @Published var isLoading = false
    @Published var needsRefresh = false

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

        // Add to local cache
        userRecipes.insert(created, at: 0)

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

    func fetchGlobalRecipes(limit: Int = 50) async {
        do {
            let snapshot = try await db.collection(recipesCollection)
                .whereField("isPublic", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            globalRecipes = snapshot.documents.compactMap { doc in
                try? doc.data(as: Recipe.self)
            }
        } catch {
            print("Error fetching global recipes: \(error)")
            globalRecipes = []
        }
    }

    func fetchFriendsRecipes(friendIds: [String], limit: Int = 50) async {
        guard !friendIds.isEmpty else {
            friendsRecipes = []
            return
        }

        do {
            let batches = friendIds.chunked(into: 30)
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

            friendsRecipes = allRecipes
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
                .map { $0 }
        } catch {
            print("Error fetching friends recipes: \(error)")
            friendsRecipes = []
        }
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

        // Check for variations
        let variationsSnapshot = try await db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .order(by: "likeCount", descending: true)
            .limit(to: 1)
            .getDocuments()

        if let topVariationDoc = variationsSnapshot.documents.first,
           let topVariation = try? topVariationDoc.data(as: RecipeVariation.self) {
            // Promote the top variation to become the new base recipe
            var updatedRecipe = recipe
            updatedRecipe.authorId = topVariation.authorId
            updatedRecipe.authorUsername = topVariation.authorUsername
            updatedRecipe.authorProfileImageURL = topVariation.authorProfileImageURL
            updatedRecipe.ingredients = topVariation.ingredients
            updatedRecipe.steps = topVariation.steps
            updatedRecipe.updatedAt = Date()

            // Use batch write to atomically update recipe and delete variation
            // This ensures security rules see consistent data
            let batch = db.batch()

            let recipeRef = db.collection(recipesCollection).document(recipeId)
            try batch.setData(from: updatedRecipe, forDocument: recipeRef, merge: true)

            batch.deleteDocument(topVariationDoc.reference)

            try await batch.commit()

            // Delete activities for this recipe:
            // 1. Original owner's activity (User 1 created it)
            // 2. Promoted user's variation activity (since variation no longer exists)
            let activitiesSnapshot = try await db.collection(activitiesCollection)
                .whereField("recipeId", isEqualTo: recipeId)
                .getDocuments()

            for doc in activitiesSnapshot.documents {
                if let activity = try? doc.data(as: Activity.self) {
                    // Delete old owner's activities
                    if activity.authorId == recipe.authorId {
                        try await doc.reference.delete()
                    }
                    // Delete promoted user's variation activity (they'll get a new "owner" activity)
                    else if activity.authorId == topVariation.authorId {
                        try await doc.reference.delete()
                    }
                }
            }

            // Create single activity for the new owner
            let activity = Activity(
                type: .newRecipe,
                authorId: topVariation.authorId,
                createdAt: Date(),
                recipeId: recipeId,
                authorUsername: topVariation.authorUsername,
                authorProfileImageURL: topVariation.authorProfileImageURL,
                contentTitle: recipe.title,
                contentDescription: recipe.description,
                contentImageURL: recipe.firstImageURL
            )
            try db.collection(activitiesCollection).addDocument(from: activity)
        } else {
            // No variations - delete the recipe entirely
            try await db.collection(recipesCollection).document(recipeId).delete()

            // Delete associated feed activities
            let activitiesSnapshot = try await db.collection(activitiesCollection)
                .whereField("recipeId", isEqualTo: recipeId)
                .getDocuments()

            for doc in activitiesSnapshot.documents {
                try await doc.reference.delete()
            }
        }

        userRecipes.removeAll { $0.id == recipeId }

        // Clear caches so data refreshes with new ownership
        friendsRecipes.removeAll()
        globalRecipes.removeAll()

        // Signal that views should refresh
        needsRefresh = true

        // Clear feed cache so activities refresh
        FeedService.shared.clearCache()
    }

    // MARK: - Recipe Existence Check

    func recipeExists(title: String) async throws -> Recipe? {
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)

        let snapshot = try await db.collection(recipesCollection)
            .getDocuments()

        // Case-insensitive title match
        let matchingRecipe = snapshot.documents.compactMap { doc -> Recipe? in
            guard let recipe = try? doc.data(as: Recipe.self) else { return nil }
            return recipe.title.lowercased().trimmingCharacters(in: .whitespaces) == normalizedTitle ? recipe : nil
        }.first

        return matchingRecipe
    }

    // MARK: - Variations

    func createVariation(for recipeId: String, variation: RecipeVariation, author: FAFUser) async throws {
        guard let authorId = author.id else {
            throw RecipeServiceError.invalidData
        }

        // Check if user already has a variation for this recipe
        let existingVariation = try await db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .whereField("authorId", isEqualTo: authorId)
            .getDocuments()

        if !existingVariation.documents.isEmpty {
            throw RecipeServiceError.variationExists
        }

        var newVariation = variation
        newVariation.authorUsername = author.username
        newVariation.authorProfileImageURL = author.profileImageURL

        try db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .addDocument(from: newVariation)

        // Create activity for feed
        if let recipe = try await fetchRecipe(id: recipeId) {
            let activity = Activity(
                type: .newRecipe,
                authorId: authorId,
                createdAt: Date(),
                recipeId: recipeId,
                authorUsername: author.username,
                authorProfileImageURL: author.profileImageURL,
                contentTitle: "\(recipe.title) (variation)",
                contentDescription: newVariation.notes,
                contentImageURL: recipe.firstImageURL
            )
            try db.collection(activitiesCollection).addDocument(from: activity)
        }
    }

    func fetchVariations(for recipeId: String, friendIds: [String] = [], limit: Int = 20) async throws -> [RecipeVariation] {
        let snapshot = try await db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .order(by: "likeCount", descending: true)
            .limit(to: limit)
            .getDocuments()

        var variations = snapshot.documents.compactMap { doc in
            try? doc.data(as: RecipeVariation.self)
        }

        // Sort: friends first, then by likeCount, then by date
        variations.sort { v1, v2 in
            let v1IsFriend = friendIds.contains(v1.authorId)
            let v2IsFriend = friendIds.contains(v2.authorId)

            if v1IsFriend != v2IsFriend {
                return v1IsFriend
            }
            if v1.likeCount != v2.likeCount {
                return v1.likeCount > v2.likeCount
            }
            return v1.createdAt > v2.createdAt
        }

        return variations
    }

    func updateVariation(_ variation: RecipeVariation, recipeId: String) async throws {
        guard let variationId = variation.id else {
            throw RecipeServiceError.recipeNotFound
        }

        var updatedVariation = variation
        updatedVariation.updatedAt = Date()

        try db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .document(variationId)
            .setData(from: updatedVariation, merge: true)
    }

    func deleteVariation(_ variation: RecipeVariation, recipeId: String) async throws {
        guard let variationId = variation.id else {
            throw RecipeServiceError.recipeNotFound
        }

        try await db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .document(variationId)
            .delete()
    }

    func likeVariation(_ variation: RecipeVariation, recipeId: String) async throws {
        guard let variationId = variation.id else {
            throw RecipeServiceError.recipeNotFound
        }

        try await db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .document(variationId)
            .updateData(["likeCount": FieldValue.increment(Int64(1))])
    }

    func promoteVariation(_ variation: RecipeVariation, recipe: Recipe, currentUser: FAFUser) async throws {
        guard let recipeId = recipe.id,
              let variationId = variation.id,
              let currentUserId = currentUser.id else {
            throw RecipeServiceError.invalidData
        }

        // Only the recipe owner can promote
        guard recipe.authorId == currentUserId else {
            throw RecipeServiceError.unauthorized
        }

        // 1. Create a variation from the current base recipe (owned by current owner)
        let ownerVariation = RecipeVariation(
            recipeId: recipeId,
            authorId: recipe.authorId,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            notes: "Original version",
            likeCount: 0,
            authorUsername: recipe.authorUsername,
            authorProfileImageURL: recipe.authorProfileImageURL
        )

        // 2. Update the base recipe with the variation's content and new owner
        var updatedRecipe = recipe
        updatedRecipe.authorId = variation.authorId
        updatedRecipe.authorUsername = variation.authorUsername
        updatedRecipe.authorProfileImageURL = variation.authorProfileImageURL
        updatedRecipe.ingredients = variation.ingredients
        updatedRecipe.steps = variation.steps
        updatedRecipe.updatedAt = Date()

        // Use batch write for atomic operations
        let batch = db.batch()

        // Add owner's current version as a variation
        let ownerVariationRef = db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .document()
        try batch.setData(from: ownerVariation, forDocument: ownerVariationRef)

        // Update recipe with new owner
        let recipeRef = db.collection(recipesCollection).document(recipeId)
        try batch.setData(from: updatedRecipe, forDocument: recipeRef, merge: true)

        // Delete the promoted variation
        let promotedVariationRef = db.collection(recipesCollection)
            .document(recipeId)
            .collection(variationsSubcollection)
            .document(variationId)
        batch.deleteDocument(promotedVariationRef)

        try await batch.commit()

        // 4. Create activity
        let activity = Activity(
            type: .newRecipe,
            authorId: variation.authorId,
            createdAt: Date(),
            recipeId: recipeId,
            authorUsername: variation.authorUsername,
            authorProfileImageURL: variation.authorProfileImageURL,
            contentTitle: "\(recipe.title) - promoted to official",
            contentDescription: "Variation was promoted to official recipe"
        )
        try db.collection(activitiesCollection).addDocument(from: activity)
    }

    // MARK: - Seed Data (Debug)

    func seedBeefStewRecipe(author: FAFUser) async throws {
        guard let authorId = author.id else {
            throw RecipeServiceError.invalidData
        }

        // Delete existing beef stew recipes by this author
        let existing = try await db.collection(recipesCollection)
            .whereField("authorId", isEqualTo: authorId)
            .whereField("title", isEqualTo: "Classic Beef Stew")
            .getDocuments()

        for doc in existing.documents {
            try await doc.reference.delete()
        }

        // Create ingredients with IDs we can reference
        let beefChuck = Ingredient(name: "beef chuck, cubed", quantity: "2", unit: "lbs")
        let potatoes = Ingredient(name: "potatoes, quartered", quantity: "4", unit: "medium")
        let carrots = Ingredient(name: "carrots, sliced", quantity: "3", unit: "large")
        let onion = Ingredient(name: "onion, diced", quantity: "1", unit: "large")
        let beefBroth = Ingredient(name: "beef broth", quantity: "4", unit: "cups")
        let tomatoPaste = Ingredient(name: "tomato paste", quantity: "2", unit: "tbsp")
        let garlic = Ingredient(name: "garlic, minced", quantity: "4", unit: "cloves")
        let thyme = Ingredient(name: "dried thyme", quantity: "1", unit: "tsp")
        let salt = Ingredient(name: "salt", quantity: "1", unit: "tsp")
        let pepper = Ingredient(name: "black pepper", quantity: "1/2", unit: "tsp")
        let oliveOil = Ingredient(name: "olive oil", quantity: "2", unit: "tbsp")
        let flour = Ingredient(name: "flour", quantity: "3", unit: "tbsp")

        let allIngredients = [beefChuck, potatoes, carrots, onion, beefBroth, tomatoPaste, garlic, thyme, salt, pepper, oliveOil, flour]

        // Create steps with per-step ingredients
        let steps = [
            RecipeStep(
                instruction: "Cut beef into 1-inch cubes and season with salt and pepper. Toss with flour to coat.",
                ingredientIds: [beefChuck.id, salt.id, pepper.id, flour.id],
                orderIndex: 0
            ),
            RecipeStep(
                instruction: "Heat olive oil in a large Dutch oven over medium-high heat. Brown beef in batches, about 3 minutes per side. Set aside.",
                ingredientIds: [oliveOil.id],
                orderIndex: 1
            ),
            RecipeStep(
                instruction: "Add onions and garlic to the pot, cook until softened, about 3 minutes.",
                ingredientIds: [onion.id, garlic.id],
                orderIndex: 2
            ),
            RecipeStep(
                instruction: "Stir in tomato paste and cook for 1 minute until darkened.",
                ingredientIds: [tomatoPaste.id],
                orderIndex: 3
            ),
            RecipeStep(
                instruction: "Add beef broth and thyme, scraping up any browned bits from the bottom.",
                ingredientIds: [beefBroth.id, thyme.id],
                orderIndex: 4
            ),
            RecipeStep(
                instruction: "Return beef to pot, bring to a boil, then reduce heat to low. Cover and simmer for 1 hour.",
                ingredientIds: [],
                orderIndex: 5
            ),
            RecipeStep(
                instruction: "Add potatoes and carrots, continue cooking covered for 30 minutes until vegetables are tender.",
                ingredientIds: [potatoes.id, carrots.id],
                orderIndex: 6
            ),
            RecipeStep(
                instruction: "Season with additional salt and pepper to taste. Serve hot with crusty bread.",
                ingredientIds: [],
                orderIndex: 7
            )
        ]

        let recipe = Recipe(
            authorId: authorId,
            title: "Classic Beef Stew",
            description: "A hearty, warming beef stew with tender chunks of beef, potatoes, and vegetables in a rich savory broth.",
            ingredients: allIngredients,
            steps: steps,
            isPublic: true,
            imageURLs: [],
            servings: 6,
            prepTimeMinutes: 20,
            cookTimeMinutes: 90,
            tags: ["dinner", "comfort food", "beef", "stew", "one-pot"],
            authorUsername: author.username,
            authorProfileImageURL: author.profileImageURL
        )

        _ = try await createRecipe(recipe, author: author)
        print("Beef stew recipe seeded successfully!")
    }
}
