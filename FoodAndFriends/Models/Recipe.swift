import Foundation
import FirebaseFirestore

struct RecipeStep: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var instruction: String
    var ingredientIds: [String]
    var orderIndex: Int

    init(instruction: String, ingredientIds: [String] = [], orderIndex: Int = 0) {
        self.id = UUID().uuidString
        self.instruction = instruction
        self.ingredientIds = ingredientIds
        self.orderIndex = orderIndex
    }
}

struct Recipe: Codable, Identifiable, Hashable {
    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    @DocumentID var id: String?
    var authorId: String
    var title: String
    var description: String
    var ingredients: [Ingredient]
    var steps: [RecipeStep]
    var instructions: [String]?  // Deprecated: kept for backward compatibility
    var isPublic: Bool
    var imageURLs: [String]
    var servings: Int?
    var prepTimeMinutes: Int?
    var cookTimeMinutes: Int?
    var tags: [String]
    let createdAt: Date
    var updatedAt: Date

    // Denormalized author info for feed display
    var authorUsername: String?
    var authorProfileImageURL: String?

    init(
        id: String? = nil,
        authorId: String,
        title: String,
        description: String = "",
        ingredients: [Ingredient] = [],
        steps: [RecipeStep] = [],
        instructions: [String]? = nil,
        isPublic: Bool = false,
        imageURLs: [String] = [],
        servings: Int? = nil,
        prepTimeMinutes: Int? = nil,
        cookTimeMinutes: Int? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        authorUsername: String? = nil,
        authorProfileImageURL: String? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.title = title
        self.description = description
        self.ingredients = ingredients
        self.steps = steps
        self.instructions = instructions
        self.isPublic = isPublic
        self.imageURLs = imageURLs
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
    }

    var totalTimeMinutes: Int? {
        guard let prep = prepTimeMinutes, let cook = cookTimeMinutes else {
            return prepTimeMinutes ?? cookTimeMinutes
        }
        return prep + cook
    }

    var firstImageURL: String? {
        imageURLs.first
    }

    func ingredients(for step: RecipeStep) -> [Ingredient] {
        ingredients.filter { step.ingredientIds.contains($0.id) }
    }

    var sortedSteps: [RecipeStep] {
        steps.sorted { $0.orderIndex < $1.orderIndex }
    }
}

// MARK: - Recipe Variation

struct RecipeVariation: Codable, Identifiable {
    @DocumentID var id: String?
    let recipeId: String
    let authorId: String
    var ingredients: [Ingredient]
    var steps: [RecipeStep]
    var notes: String
    var imageURL: String?
    var likeCount: Int
    let createdAt: Date
    var updatedAt: Date

    // Denormalized author info
    var authorUsername: String?
    var authorProfileImageURL: String?

    init(
        id: String? = nil,
        recipeId: String,
        authorId: String,
        ingredients: [Ingredient] = [],
        steps: [RecipeStep] = [],
        notes: String = "",
        imageURL: String? = nil,
        likeCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        authorUsername: String? = nil,
        authorProfileImageURL: String? = nil
    ) {
        self.id = id
        self.recipeId = recipeId
        self.authorId = authorId
        self.ingredients = ingredients
        self.steps = steps
        self.notes = notes
        self.imageURL = imageURL
        self.likeCount = likeCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
    }

    func ingredients(for step: RecipeStep) -> [Ingredient] {
        ingredients.filter { step.ingredientIds.contains($0.id) }
    }

    var sortedSteps: [RecipeStep] {
        steps.sorted { $0.orderIndex < $1.orderIndex }
    }
}

// MARK: - Ingredient

struct Ingredient: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var quantity: String
    var unit: String?

    init(name: String, quantity: String, unit: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    var displayString: String {
        if let unit = unit, !unit.isEmpty {
            return "\(quantity) \(unit) \(name)"
        }
        return "\(quantity) \(name)"
    }
}
