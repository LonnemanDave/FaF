import Foundation

// MARK: - Claude API Request/Response Models

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContentBlock]
    let stopReason: String?
    let usage: ClaudeUsage?

    enum CodingKeys: String, CodingKey {
        case id, type, role, content
        case stopReason = "stop_reason"
        case usage
    }
}

struct ClaudeContentBlock: Codable {
    let type: String
    let text: String?
}

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct ClaudeErrorResponse: Codable {
    let type: String
    let error: ClaudeErrorDetail
}

struct ClaudeErrorDetail: Codable {
    let type: String
    let message: String
}

// MARK: - Generated Recipe Models

struct GeneratedRecipe: Codable {
    let title: String
    let description: String
    let servings: Int?
    let prepTimeMinutes: Int?
    let cookTimeMinutes: Int?
    let ingredients: [GeneratedIngredient]
    let steps: [GeneratedStep]
    let tags: [String]
}

struct GeneratedIngredient: Codable {
    let name: String
    let quantity: String
    let unit: String?
}

struct GeneratedStep: Codable {
    let instruction: String
    let ingredientNames: [String]
}

// MARK: - Generated Meal Plan Models

struct GeneratedMealPlan: Codable {
    let name: String
    let description: String?
    let meals: [GeneratedPlannedMeal]
}

struct GeneratedPlannedMeal: Codable {
    let date: String  // ISO8601 date string
    let mealType: String  // breakfast, lunch, dinner, snack
    let recipeName: String
    let notes: String?
}

// MARK: - Meal Plan Preferences

struct MealPlanPreferences: Codable, Equatable {
    var dietaryRestrictions: [DietaryRestriction]
    var cuisinePreferences: [String]
    var calorieGoal: CalorieGoal?
    var allergens: [String]
    var cookingSkillLevel: SkillLevel
    var mealTypes: [MealType]
    var quickMealsPreferred: Bool

    init(
        dietaryRestrictions: [DietaryRestriction] = [],
        cuisinePreferences: [String] = [],
        calorieGoal: CalorieGoal? = nil,
        allergens: [String] = [],
        cookingSkillLevel: SkillLevel = .intermediate,
        mealTypes: [MealType] = [.breakfast, .lunch, .dinner],
        quickMealsPreferred: Bool = false
    ) {
        self.dietaryRestrictions = dietaryRestrictions
        self.cuisinePreferences = cuisinePreferences
        self.calorieGoal = calorieGoal
        self.allergens = allergens
        self.cookingSkillLevel = cookingSkillLevel
        self.mealTypes = mealTypes
        self.quickMealsPreferred = quickMealsPreferred
    }

    static let `default` = MealPlanPreferences()
}

enum DietaryRestriction: String, Codable, CaseIterable, Identifiable {
    case vegetarian
    case vegan
    case glutenFree = "gluten-free"
    case dairyFree = "dairy-free"
    case keto
    case paleo
    case lowCarb = "low-carb"
    case lowSodium = "low-sodium"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .glutenFree: return "Gluten-Free"
        case .dairyFree: return "Dairy-Free"
        case .keto: return "Keto"
        case .paleo: return "Paleo"
        case .lowCarb: return "Low Carb"
        case .lowSodium: return "Low Sodium"
        }
    }
}

enum CalorieGoal: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low Calorie"
        case .moderate: return "Moderate"
        case .high: return "High Calorie"
        }
    }

    var description: String {
        switch self {
        case .low: return "Focus on lighter meals"
        case .moderate: return "Balanced portions"
        case .high: return "Hearty, filling meals"
        }
    }
}

enum SkillLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var description: String {
        switch self {
        case .beginner: return "Simple recipes with basic techniques"
        case .intermediate: return "More variety and some complex dishes"
        case .advanced: return "Challenging recipes and techniques"
        }
    }
}

// MARK: - Common Cuisine Options

enum CuisineType: String, CaseIterable, Identifiable {
    case american = "American"
    case italian = "Italian"
    case mexican = "Mexican"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case indian = "Indian"
    case thai = "Thai"
    case mediterranean = "Mediterranean"
    case french = "French"
    case korean = "Korean"
    case vietnamese = "Vietnamese"
    case greek = "Greek"
    case middleEastern = "Middle Eastern"
    case caribbean = "Caribbean"

    var id: String { rawValue }
}

// MARK: - Common Allergens

enum CommonAllergen: String, CaseIterable, Identifiable {
    case peanuts = "Peanuts"
    case treeNuts = "Tree Nuts"
    case milk = "Milk"
    case eggs = "Eggs"
    case wheat = "Wheat"
    case soy = "Soy"
    case fish = "Fish"
    case shellfish = "Shellfish"
    case sesame = "Sesame"

    var id: String { rawValue }
}
