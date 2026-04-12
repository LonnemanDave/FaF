import Foundation
import FirebaseFirestore

struct Recipe: Codable, Identifiable {
    @DocumentID var id: String?
    let authorId: String
    var title: String
    var description: String
    var ingredients: [Ingredient]
    var instructions: [String]
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
        instructions: [String] = [],
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
        self.instructions = instructions
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
}

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
