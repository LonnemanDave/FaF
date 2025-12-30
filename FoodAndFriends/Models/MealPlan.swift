import Foundation
import FirebaseFirestore

struct MealPlan: Codable, Identifiable, Hashable {
    static func == (lhs: MealPlan, rhs: MealPlan) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    @DocumentID var id: String?
    let authorId: String
    var name: String
    var description: String?
    var startDate: Date
    var endDate: Date
    var meals: [PlannedMeal]
    let createdAt: Date
    var updatedAt: Date

    // Denormalized author info for feed display
    var authorUsername: String?
    var authorProfileImageURL: String?

    init(
        id: String? = nil,
        authorId: String,
        name: String,
        description: String? = nil,
        startDate: Date,
        endDate: Date,
        meals: [PlannedMeal] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        authorUsername: String? = nil,
        authorProfileImageURL: String? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.meals = meals
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
    }

    var numberOfDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0 + 1
    }

    var totalMeals: Int {
        meals.count
    }

    func meals(for date: Date) -> [PlannedMeal] {
        meals.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

struct PlannedMeal: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var mealType: MealType
    var recipeId: String?
    var customMealName: String?
    var notes: String?

    // Denormalized recipe info for display
    var recipeTitle: String?
    var recipeImageURL: String?

    init(
        date: Date,
        mealType: MealType,
        recipeId: String? = nil,
        customMealName: String? = nil,
        notes: String? = nil,
        recipeTitle: String? = nil,
        recipeImageURL: String? = nil
    ) {
        self.date = date
        self.mealType = mealType
        self.recipeId = recipeId
        self.customMealName = customMealName
        self.notes = notes
        self.recipeTitle = recipeTitle
        self.recipeImageURL = recipeImageURL
    }

    var displayName: String {
        recipeTitle ?? customMealName ?? "Unnamed meal"
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .breakfast: return "sun.rise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "carrot"
        }
    }
}
