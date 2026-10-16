import Foundation
import FirebaseFirestore

struct RecipeStep: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var instruction: String
    var ingredientIds: [String]
    var orderIndex: Int
    /// The photograph of this step — one, set and changed only by the
    /// recipe's cook. Nil until there is one.
    var photoURL: String?

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

// MARK: - The house stew

extension Recipe {
    /// Classic Beef Stew — one of the design gallery's sample recipes.
    static func classicBeefStew(
        authorId: String,
        authorUsername: String?,
        authorProfileImageURL: String? = nil
    ) -> Recipe {
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

        return Recipe(
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
            authorUsername: authorUsername,
            authorProfileImageURL: authorProfileImageURL
        )

    }
}

extension Recipe {
    /// Beef & Guinness Stew, adapted from RecipeTin Eats
    /// (recipetineats.com/irish-beef-and-guinness-stew). Method in our own words.
    static func beefAndGuinnessStew(
        authorId: String,
        authorUsername: String?,
        authorProfileImageURL: String? = nil
    ) -> Recipe {
        let beef = Ingredient(name: "beef chuck, boneless, in 2\" chunks", quantity: "2.5", unit: "lb")
        let salt = Ingredient(name: "salt", quantity: "3/4", unit: "tsp")
        let pepper = Ingredient(name: "black pepper", quantity: "3/4", unit: "tsp")
        let oil = Ingredient(name: "olive oil", quantity: "2", unit: "tbsp")
        let garlic = Ingredient(name: "garlic, minced", quantity: "3", unit: "cloves")
        let onions = Ingredient(name: "onions, chopped", quantity: "2")
        let bacon = Ingredient(name: "bacon or pancetta, diced", quantity: "6", unit: "oz")
        let carrots = Ingredient(name: "carrots, in 1/2\" pieces", quantity: "3")
        let celery = Ingredient(name: "celery stalks, in 1\" pieces", quantity: "2", unit: "large")
        let flour = Ingredient(name: "flour", quantity: "3", unit: "tbsp")
        let guinness = Ingredient(name: "Guinness", quantity: "14.9", unit: "oz")
        let stock = Ingredient(name: "chicken stock", quantity: "3", unit: "cups")
        let tomatoPaste = Ingredient(name: "tomato paste", quantity: "4", unit: "tbsp")
        let bay = Ingredient(name: "bay leaves", quantity: "2")
        let thyme = Ingredient(name: "fresh thyme (or 1 tsp dried)", quantity: "3", unit: "sprigs")

        let all = [beef, salt, pepper, oil, garlic, onions, bacon, carrots, celery,
                   flour, guinness, stock, tomatoPaste, bay, thyme]

        let steps = [
            RecipeStep(instruction: "Pat the beef dry and season it with the salt and pepper.",
                       ingredientIds: [beef.id, salt.id, pepper.id], orderIndex: 0),
            RecipeStep(instruction: "Heat the oil in a heavy pot over high heat and brown the beef in batches. Set it aside.",
                       ingredientIds: [oil.id], orderIndex: 1),
            RecipeStep(instruction: "Drop to medium. Soften the garlic and onion for about 3 minutes, then add the bacon and cook until browned.",
                       ingredientIds: [garlic.id, onions.id, bacon.id], orderIndex: 2),
            RecipeStep(instruction: "Stir in the carrot and celery, then the flour, and cook for a minute.",
                       ingredientIds: [carrots.id, celery.id, flour.id], orderIndex: 3),
            RecipeStep(instruction: "Stir in the Guinness, stock and tomato paste until smooth. Add the bay and thyme.",
                       ingredientIds: [guinness.id, stock.id, tomatoPaste.id, bay.id, thyme.id], orderIndex: 4),
            RecipeStep(instruction: "Return the beef and its juices — the liquid should just cover it. Cover and simmer gently for 2 hours.",
                       orderIndex: 5),
            RecipeStep(instruction: "Uncover and simmer another 30–45 minutes, until the beef falls apart and the sauce thickens.",
                       orderIndex: 6),
            RecipeStep(instruction: "Skim the fat if you like, check the seasoning, and fish out the bay and thyme stems. Serve over mashed potatoes.",
                       orderIndex: 7),
        ]

        return Recipe(
            authorId: authorId,
            title: "Beef & Guinness Stew",
            description: "Beef braised slowly in Guinness with bacon, carrot and celery until it falls apart. Serve over mashed potatoes. Adapted from RecipeTin Eats.",
            ingredients: all,
            steps: steps,
            isPublic: false,
            servings: 6,
            prepTimeMinutes: 10,
            cookTimeMinutes: 180,
            tags: ["dinner", "stew", "beef", "irish"],
            authorUsername: authorUsername,
            authorProfileImageURL: authorProfileImageURL
        )
    }
}

// MARK: - Cooking for more, or fewer

extension Ingredient {
    /// The same ingredient for a different number of servings. Same id, so
    /// crossing off and the steps' ingredient lists still find it.
    func scaled(by factor: Double) -> Ingredient {
        guard abs(factor - 1) > 0.0001 else { return self }
        var copy = self
        copy.quantity = Self.scaledQuantity(quantity, by: factor)
        return copy
    }

    /// "2 1/4" × 2 → "4 1/2"; "1-2" × 2 → "2-4"; "750" × 1.5 → "1125".
    /// Anything that isn't a number — "a pinch", "to taste" — stays as written.
    static func scaledQuantity(_ quantity: String, by factor: Double) -> String {
        let text = quantity.trimmingCharacters(in: .whitespaces)
        for dash in ["-", "–", " to "] where text.contains(dash) {
            let ends = text.components(separatedBy: dash)
            guard ends.allSatisfy({ ShoppingMath.parse($0) != nil }) else { return quantity }
            return ends.map { scaledQuantity($0, by: factor) }.joined(separator: dash)
        }
        guard let value = ShoppingMath.parse(text) else { return quantity }
        let scaled = value * factor
        // Big amounts are weighed or poured, not spooned: whole numbers.
        if scaled >= 10 { return "\(Int(scaled.rounded()))" }
        return ShoppingMath.printed(scaled)
    }
}
