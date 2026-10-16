import Foundation
import FirebaseFirestore

/// The shopping list — one open list per cook, in `shoppingLists`.
///
/// The document shape is the one the earlier (unpushed) version of the app
/// wrote, Kroger fields and all, so a list it left behind still opens and
/// survives being edited here. Starting over archives the list rather than
/// deleting it.
struct ShoppingList: Codable, Identifiable {
    @DocumentID var id: String?
    var authorId: String
    var authorUsername: String?
    var authorProfileImageURL: String?
    var name: String
    var items: [ShoppingItem]
    var recipeIds: [String]
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        authorId: String,
        authorUsername: String? = nil,
        authorProfileImageURL: String? = nil,
        name: String = "Shopping list",
        items: [ShoppingItem] = [],
        recipeIds: [String] = [],
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
        self.name = name
        self.items = items
        self.recipeIds = recipeIds
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername)
        authorProfileImageURL = try container.decodeIfPresent(String.self, forKey: .authorProfileImageURL)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Shopping list"
        items = try container.decodeIfPresent([ShoppingItem].self, forKey: .items) ?? []
        recipeIds = try container.decodeIfPresent([String].self, forKey: .recipeIds) ?? []
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    var toGet: [ShoppingItem] { items.filter { !$0.isChecked } }
    var inTheCart: [ShoppingItem] { items.filter(\.isChecked) }
}

struct ShoppingItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// Numeric amount when the amounts could be added up; nil when they couldn't.
    var quantity: Double?
    var unit: String?
    /// The amount as printed — "2 1/2", or "2 + 1 large" when units didn't agree.
    var displayQuantity: String?
    /// The aisle, as `ShoppingAisle.rawValue`.
    var category: String?
    var isChecked: Bool = false
    var isManuallyAdded: Bool = false
    var sourceRecipeIds: [String] = []
    var sourceRecipeTitles: [String] = []

    // Written by the earlier version's Kroger matching. Kept so its lists
    // round-trip through this one without losing the product it found.
    var krogerProductId: String?
    var krogerProductName: String?
    var krogerProductAisle: String?
    var krogerProductSize: String?
    var krogerProductPrice: Double?
    var krogerProductQuantity: Int?
    var krogerProductImageURL: String?

    init(
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        displayQuantity: String? = nil,
        category: String? = nil,
        isManuallyAdded: Bool = false,
        sourceRecipeIds: [String] = [],
        sourceRecipeTitles: [String] = []
    ) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.displayQuantity = displayQuantity
        self.category = category
        self.isManuallyAdded = isManuallyAdded
        self.sourceRecipeIds = sourceRecipeIds
        self.sourceRecipeTitles = sourceRecipeTitles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        quantity = try c.decodeIfPresent(Double.self, forKey: .quantity)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        displayQuantity = try c.decodeIfPresent(String.self, forKey: .displayQuantity)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        isManuallyAdded = try c.decodeIfPresent(Bool.self, forKey: .isManuallyAdded) ?? false
        sourceRecipeIds = try c.decodeIfPresent([String].self, forKey: .sourceRecipeIds) ?? []
        sourceRecipeTitles = try c.decodeIfPresent([String].self, forKey: .sourceRecipeTitles) ?? []
        krogerProductId = try c.decodeIfPresent(String.self, forKey: .krogerProductId)
        krogerProductName = try c.decodeIfPresent(String.self, forKey: .krogerProductName)
        krogerProductAisle = try c.decodeIfPresent(String.self, forKey: .krogerProductAisle)
        krogerProductSize = try c.decodeIfPresent(String.self, forKey: .krogerProductSize)
        krogerProductPrice = try c.decodeIfPresent(Double.self, forKey: .krogerProductPrice)
        krogerProductQuantity = try c.decodeIfPresent(Int.self, forKey: .krogerProductQuantity)
        krogerProductImageURL = try c.decodeIfPresent(String.self, forKey: .krogerProductImageURL)
    }

    /// What goes in the cart, without the prep: "carrots, sliced" → "carrots".
    var shoppingName: String { ShoppingMath.shoppingName(name) }

    /// The amount as the list prints it: "2 1/2 lb", "3", "2 + 1 large".
    var printedAmount: String {
        let amount = displayQuantity ?? quantity.map(ShoppingMath.printed) ?? ""
        guard let unit, !unit.isEmpty, !amount.contains("+") else { return amount }
        return amount.isEmpty ? unit : "\(amount) \(unit)"
    }

    var aisle: ShoppingAisle { ShoppingAisle.classify(name) }
}

// MARK: - Aisles

/// The store, in the order you walk it.
enum ShoppingAisle: String, CaseIterable, Comparable {
    case produce, meat, dairy, bakery, pantry, spices, frozen, drinks, other

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .meat: return "Meat & fish"
        case .dairy: return "Dairy & eggs"
        case .bakery: return "Bakery"
        case .pantry: return "Pantry"
        case .spices: return "Spices"
        case .frozen: return "Frozen"
        case .drinks: return "Beer & wine"
        case .other: return "Everything else"
        }
    }

    static func < (lhs: ShoppingAisle, rhs: ShoppingAisle) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    /// Words checked in order — the first aisle with a match wins, so the
    /// specific beats the general ("tomato paste" is pantry before "tomato"
    /// is produce; "chicken stock" is pantry before "chicken" is meat).
    ///
    /// A one-word rule matches the start of a word in the name, never the
    /// middle: "ale" is beer, "kale" isn't; "egg" is dairy, "eggplant" isn't
    /// caught by it. A rule with a space matches as a phrase.
    private static let rules: [(ShoppingAisle, [String])] = [
        (.frozen, ["frozen", "ice cream"]),
        (.produce, ["bell pepper", "eggplant", "green onion", "spring onion", "jalapeño"]),
        (.dairy, ["ricotta"]),
        (.pantry, ["stock", "broth", "paste", "canned", "crushed tomatoes", "diced tomatoes",
                   "tomato sauce", "flour", "sugar", "oil", "vinegar", "rice", "pasta", "noodle",
                   "beans", "lentil", "baking powder", "baking soda", "yeast", "honey", "syrup",
                   "chocolate", "cocoa", "vanilla", "oats", "breadcrumb", "soy sauce", "mustard",
                   "ketchup", "mayonnaise", "worcestershire", "cornstarch", "cornmeal", "nuts", "walnut",
                   "almond", "pecan", "peanut"]),
        (.drinks, ["guinness", "beer", "stout", "ale", "wine", "cider", "sherry", "brandy", "whiskey"]),
        (.spices, ["salt", "pepper", "peppercorn", "cumin", "paprika", "cinnamon", "nutmeg", "oregano",
                   "dried thyme", "dried basil", "dried oregano", "bay", "chili powder", "chilli powder",
                   "garlic powder", "onion powder", "cayenne", "turmeric", "coriander seed",
                   "garam masala", "curry powder", "ground cloves", "whole cloves", "allspice",
                   "seasoning", "red pepper flakes"]),
        (.dairy, ["milk", "buttermilk", "butter", "cream", "cheese", "yogurt", "yoghurt", "egg",
                  "parmesan", "mozzarella", "cheddar", "sour cream"]),
        (.meat, ["beef", "chuck", "steak", "chicken", "pork", "bacon", "pancetta", "speck", "ham",
                 "sausage", "lamb", "turkey", "fish", "salmon", "shrimp", "prawn", "tuna", "cod",
                 "short rib", "brisket", "thigh"]),
        (.bakery, ["bread", "baguette", "roll", "bun", "tortilla", "pita", "focaccia"]),
        (.produce, ["onion", "garlic", "carrot", "celery", "potato", "tomato", "lettuce", "spinach",
                    "kale", "zucchini", "squash", "mushroom", "lemon", "lime", "orange", "apple",
                    "banana", "berr", "avocado", "cucumber", "cabbage", "broccoli", "cauliflower",
                    "ginger", "shallot", "leek", "scallion", "parsley", "cilantro", "basil", "thyme",
                    "rosemary", "sage", "mint", "dill", "chive", "herb", "corn", "pea", "chili",
                    "chilli", "jalapeño"]),
    ]

    static func classify(_ name: String) -> ShoppingAisle {
        let lowered = name.lowercased()
        let words = lowered.split { !$0.isLetter && $0 != "ñ" }.map(String.init)
        for (aisle, rules) in rules {
            let hit = rules.contains { rule in
                rule.contains(" ") ? lowered.contains(rule) : words.contains { $0.hasPrefix(rule) }
            }
            if hit { return aisle }
        }
        return .other
    }
}

// MARK: - The arithmetic of a list

/// Pure functions for turning recipe ingredients into list lines — parsing
/// "2 1/4", agreeing "lbs" with "lb", and merging two recipes' onions.
enum ShoppingMath {

    /// "carrots, sliced" → "carrots"; "fresh thyme (or 1 tsp dried)" → "fresh thyme".
    static func shoppingName(_ name: String) -> String {
        var result = name
        if let paren = result.firstIndex(of: "(") { result = String(result[..<paren]) }
        if let comma = result.firstIndex(of: ",") { result = String(result[..<comma]) }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? name.trimmingCharacters(in: .whitespaces) : result
    }

    /// The key two lines merge on: lowercased, prep stripped, crudely singular.
    static func mergeKey(_ name: String) -> String {
        var key = shoppingName(name).lowercased()
        if key.hasSuffix("oes") { key = String(key.dropLast(2)) }        // potatoes → potato
        else if key.hasSuffix("ies") { key = String(key.dropLast(3)) + "y" } // berries → berry
        else if key.hasSuffix("s"), !key.hasSuffix("ss"), key.count > 3 { key = String(key.dropLast()) }
        return key
    }

    /// One spelling per unit, so "lbs" and "lb" add up.
    static func normalizedUnit(_ unit: String?) -> String {
        let u = (unit ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        switch u {
        case "lbs", "lb", "pound", "pounds": return "lb"
        case "oz", "ounce", "ounces": return "oz"
        case "tbsp", "tablespoon", "tablespoons", "tbs": return "tbsp"
        case "tsp", "teaspoon", "teaspoons": return "tsp"
        case "cup", "cups": return "cup"
        case "clove", "cloves": return "clove"
        case "g", "gram", "grams": return "g"
        case "kg", "kilogram", "kilograms": return "kg"
        case "ml": return "ml"
        case "sprig", "sprigs": return "sprig"
        case "can", "cans": return "can"
        default: return u
        }
    }

    /// "2" → 2, "2.5" → 2.5, "1/2" → 0.5, "2 1/4" → 2.25, "1-2" → 2 (buy for the top of the range).
    /// Nil for anything that isn't a number ("a pinch", "to taste").
    static func parse(_ quantity: String) -> Double? {
        let text = quantity.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        for dash in ["-", "–", " to "] where text.contains(dash) {
            return text.components(separatedBy: dash).compactMap { parse($0) }.max()
        }
        var total = 0.0
        for part in text.split(separator: " ") {
            if part.contains("/") {
                let pieces = part.split(separator: "/")
                guard pieces.count == 2, let n = Double(pieces[0]), let d = Double(pieces[1]), d != 0 else { return nil }
                total += n / d
            } else if let value = Double(part) {
                total += value
            } else {
                return nil
            }
        }
        return total
    }

    /// 2 → "2", 2.5 → "2 1/2", 0.75 → "3/4", 0.333… → "1/3"; anything else to one decimal.
    static func printed(_ value: Double) -> String {
        let whole = Int(value)
        let fraction = value - Double(whole)
        let fractions: [(Double, String)] = [(0, ""), (0.125, "1/8"), (0.25, "1/4"), (1.0 / 3, "1/3"),
                                             (0.375, "3/8"), (0.5, "1/2"), (0.625, "5/8"), (2.0 / 3, "2/3"),
                                             (0.75, "3/4"), (0.875, "7/8"), (1, "")]
        if let match = fractions.first(where: { abs($0.0 - fraction) < 0.02 }) {
            let wholePart = whole + (match.0 == 1 ? 1 : 0)
            switch (wholePart, match.1.isEmpty) {
            case (_, true): return "\(wholePart)"
            case (0, false): return match.1
            default: return "\(wholePart) \(match.1)"
            }
        }
        return String(format: "%.1f", value)
    }

    /// Takes a recipe back off a list — the reverse of `merge`. A line only
    /// that recipe wanted goes; a line another recipe shares keeps the other
    /// recipe's amount. When the amounts were in different units and couldn't
    /// be added up, they can't be taken apart either, so the line stays as it
    /// is and just stops naming this recipe.
    static func remove(
        _ ingredients: [Ingredient],
        of recipe: (id: String?, title: String),
        from items: [ShoppingItem]
    ) -> [ShoppingItem] {
        var result = items
        for ingredient in ingredients {
            let key = mergeKey(ingredient.name)
            guard let index = result.firstIndex(where: {
                mergeKey($0.name) == key && $0.sourceRecipeTitles.contains(recipe.title)
            }) else { continue }

            var line = result[index]
            line.sourceRecipeTitles.removeAll { $0 == recipe.title }
            if let id = recipe.id { line.sourceRecipeIds.removeAll { $0 == id } }

            if line.sourceRecipeTitles.isEmpty && !line.isManuallyAdded {
                result.remove(at: index)
                continue
            }
            if normalizedUnit(line.unit) == normalizedUnit(ingredient.unit),
               let have = line.quantity, let take = parse(ingredient.quantity) {
                let left = have - take
                if left > 0.001 {
                    line.quantity = left
                    line.displayQuantity = printed(left)
                }
            }
            result[index] = line
        }
        return result
    }

    /// When the recipe itself can't be found: drop the lines only it wanted,
    /// and stop naming it on the rest.
    static func removeSource(_ recipe: (id: String?, title: String), from items: [ShoppingItem]) -> [ShoppingItem] {
        items.compactMap { item in
            guard item.sourceRecipeTitles.contains(recipe.title) else { return item }
            var line = item
            line.sourceRecipeTitles.removeAll { $0 == recipe.title }
            if let id = recipe.id { line.sourceRecipeIds.removeAll { $0 == id } }
            return line.sourceRecipeTitles.isEmpty && !line.isManuallyAdded ? nil : line
        }
    }

    /// Folds a recipe's ingredients into a list. Lines for the same thing in
    /// the same unit add up; in different units they're printed side by side
    /// ("2 + 1 large"). A checked line that gets more added is unchecked —
    /// what's in the cart is no longer enough.
    static func merge(
        _ ingredients: [Ingredient],
        from recipe: (id: String?, title: String),
        into items: [ShoppingItem]
    ) -> [ShoppingItem] {
        var result = items
        for ingredient in ingredients {
            let key = mergeKey(ingredient.name)
            let unit = normalizedUnit(ingredient.unit)
            let amount = parse(ingredient.quantity)

            if let index = result.firstIndex(where: { mergeKey($0.name) == key }) {
                var line = result[index]
                let lineUnit = normalizedUnit(line.unit)
                if lineUnit == unit, let have = line.quantity, let add = amount {
                    line.quantity = have + add
                    line.displayQuantity = printed(have + add)
                } else {
                    let added = [ingredient.quantity, ingredient.unit ?? ""]
                        .joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    line.displayQuantity = [line.printedAmount, added]
                        .filter { !$0.isEmpty }.joined(separator: " + ")
                    line.quantity = nil
                    line.unit = nil
                }
                if let id = recipe.id, !line.sourceRecipeIds.contains(id) { line.sourceRecipeIds.append(id) }
                if !line.sourceRecipeTitles.contains(recipe.title) { line.sourceRecipeTitles.append(recipe.title) }
                line.isChecked = false
                result[index] = line
            } else {
                result.append(ShoppingItem(
                    name: shoppingName(ingredient.name),
                    quantity: amount,
                    unit: ingredient.unit?.isEmpty == true ? nil : ingredient.unit,
                    displayQuantity: amount.map(printed) ?? ingredient.quantity,
                    category: ShoppingAisle.classify(ingredient.name).rawValue,
                    sourceRecipeIds: recipe.id.map { [$0] } ?? [],
                    sourceRecipeTitles: [recipe.title]
                ))
            }
        }
        return result
    }
}
