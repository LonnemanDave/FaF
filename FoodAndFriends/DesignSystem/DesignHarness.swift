#if DEBUG
import Foundation
import UIKit

/// A way to look at the journal's pages without signing in.
///
/// Launch with `--design-gallery` and ContentView goes straight to the
/// chapters with a hand-set sample kitchen loaded — this week's menu, the
/// house stew, a few friends at the table — so layout and type can be
/// reviewed in both editions without touching anyone's account. Firestore
/// listeners and fetches stand down while it's on.
///
///   --design-gallery                  the chapters, opened at Home
///   --design-gallery --design-tab 1   …opened at Recipes (0–4, in thumb-index order)
///   --design-screen login             the sign-in page
///   --design-screen setup             profile setup (where white-on-white happened)
///   --design-screen recipe-form       writing a new recipe (also recipe-edit, menu-form,
///                                     ai-recipe, ai-menu, ai-settings, friends, add-friend, friend)
///
/// DEBUG only — none of this ships.
@MainActor
enum DesignHarness {
    /// A 4:3 test card for the cropper: warm bands and a grid, so the crop is easy to read.
    static var samplePhoto: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1200)).image { context in
            let colors: [UIColor] = [.systemOrange, .systemRed, .brown, .systemYellow]
            for (index, color) in colors.enumerated() {
                color.setFill()
                context.fill(CGRect(x: 0, y: CGFloat(index) * 300, width: 1600, height: 300))
            }
            UIColor.white.withAlphaComponent(0.6).setStroke()
            for x in stride(from: 0, through: 1600, by: 200) {
                context.cgContext.stroke(CGRect(x: CGFloat(x), y: 0, width: 0.5, height: 1200))
            }
            for y in stride(from: 0, through: 1200, by: 200) {
                context.cgContext.stroke(CGRect(x: 0, y: CGFloat(y), width: 1600, height: 0.5))
            }
        }
    }


    nonisolated static var isOn: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--design-gallery") || args.contains("--design-screen")
    }

    /// Which page to open on: "tabs" (default), "login", or "setup".
    nonisolated static var screen: String {
        value(after: "--design-screen") ?? "tabs"
    }

    nonisolated static var initialTab: Int {
        value(after: "--design-tab").flatMap(Int.init) ?? 0
    }

    private nonisolated static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    // MARK: - Setting the table

    /// Loads the sample kitchen into the shared services. Called once at launch.
    static func install() {
        guard isOn else { return }
        UserService.shared.currentUser = cook
        FriendService.shared.friends = friends
        RecipeService.shared.userRecipes = myRecipes
        RecipeService.shared.friendsRecipes = friendsRecipes
        RecipeService.shared.globalRecipes = myRecipes + friendsRecipes
        MealPlanService.shared.userMealPlans = [thisWeek, lastWeek]
        FeedService.shared.feedActivities = table
        ShoppingListService.shared.list = shoppingList
    }

    // MARK: - The list

    /// Tonight's stew on the list, half shopped, plus one line written in by hand.
    private static var shoppingList: ShoppingList {
        var items = ShoppingMath.merge(guinness.ingredients, from: (id: guinness.id, title: guinness.title), into: [])
        for name in ["onions", "beef chuck", "carrots", "salt"] {
            if let index = items.firstIndex(where: { $0.name.lowercased().contains(name) }) {
                items[index].isChecked = true
            }
        }
        var paper = ShoppingItem(name: "Crusty bread", category: ShoppingAisle.bakery.rawValue)
        paper.isManuallyAdded = true
        items.append(paper)
        return ShoppingList(id: "list", authorId: "cook", authorUsername: "david", name: "Shopping list",
                            items: items, recipeIds: ["guinness"], createdAt: day(0), updatedAt: day(0))
    }

    // MARK: - The cook and their friends

    static let cook: FAFUser = {
        var cook = FAFUser(
            id: "cook", email: "cook@example.com", username: "david", displayName: "David",
            location: "Home kitchen", friends: ["maria", "sam", "priya"],
            createdAt: day(-200), updatedAt: day(0)
        )
        cook.krogerLocationId = krogerStores[0].id
        cook.krogerStoreName = krogerStores[0].name
        return cook
    }()

    static let friends = [
        FAFUser(id: "maria", email: "m@example.com", username: "maria_cooks", displayName: "Maria",
                location: "Chicago, IL", createdAt: day(-90), updatedAt: day(-1)),
        FAFUser(id: "sam", email: "s@example.com", username: "sam.bakes", displayName: "Sam",
                location: "Portland, OR", createdAt: day(-60), updatedAt: day(-3)),
        FAFUser(id: "priya", email: "p@example.com", username: "priya", displayName: "Priya",
                location: "Austin, TX", createdAt: day(-30), updatedAt: day(-2)),
    ]

    // MARK: - The recipe box

    static let stew: Recipe = {
        var stew = Recipe.classicBeefStew(authorId: "cook", authorUsername: "david")
        stew.id = "stew"
        return stew
    }()

    /// Tonight's dinner.
    static let guinness: Recipe = {
        var recipe = Recipe.beefAndGuinnessStew(authorId: "cook", authorUsername: "david")
        recipe.id = "guinness"
        return recipe
    }()

    private static var myRecipes: [Recipe] {
        [
            guinness,
            stew,
            recipe("pancakes", "Buttermilk Pancakes", "Sunday's stack — tangy, tall and crisp at the edge.",
                   prep: 10, cook: 15, serves: 4, tags: ["breakfast"], [
                ("2", "cups", "flour"), ("2", "cups", "buttermilk"), ("2", "", "eggs"),
                ("3", "tbsp", "butter, melted"), ("2", "tsp", "baking powder"),
            ]),
            recipe("chicken", "Weeknight Chicken Thighs", "Skin-side down in a cold pan, then leave it alone.",
                   prep: 5, cook: 35, serves: 4, tags: ["dinner"], [
                ("6", "", "bone-in chicken thighs"), ("1", "", "lemon"), ("4", "cloves", "garlic"),
            ]),
            recipe("soup", "Roasted Tomato Soup", nil, prep: 15, cook: 45, serves: 6, tags: ["lunch"], [
                ("3", "lbs", "plum tomatoes"), ("1", "", "onion"), ("2", "cups", "stock"),
            ]),
            recipe("cookies", "Brown Butter Cookies", "Rest the dough overnight. It's worth it.",
                   prep: 20, cook: 12, serves: 24, tags: ["baking"], [
                ("1", "cup", "butter, browned"), ("2 1/4", "cups", "flour"), ("2", "cups", "chocolate chips"),
            ]),
        ]
    }

    private static var friendsRecipes: [Recipe] {
        [
            recipe("shakshuka", "Shakshuka", "Eggs in spiced tomato.", author: "maria", authorName: "maria_cooks",
                   prep: 10, cook: 25, serves: 2, tags: ["breakfast"], [
                ("6", "", "eggs"), ("1", "can", "crushed tomatoes"), ("1", "tsp", "cumin"),
            ]),
            recipe("focaccia", "No-Knead Focaccia", nil, author: "sam", authorName: "sam.bakes",
                   prep: 15, cook: 25, serves: 8, tags: ["baking"], [
                ("4", "cups", "flour"), ("2", "cups", "warm water"), ("1/2", "cup", "olive oil"),
            ]),
        ]
    }

    // MARK: - Menus

    private static var thisWeek: MealPlan {
        var meals: [PlannedMeal] = [
            PlannedMeal(date: day(0), mealType: .breakfast, recipeId: "pancakes", recipeTitle: "Buttermilk Pancakes"),
            PlannedMeal(date: day(0), mealType: .lunch, customMealName: "Leftover tomato soup"),
            PlannedMeal(date: day(0), mealType: .dinner, recipeId: "guinness", recipeTitle: "Beef & Guinness Stew"),
            PlannedMeal(date: day(1), mealType: .dinner, recipeId: "chicken", recipeTitle: "Weeknight Chicken Thighs"),
            PlannedMeal(date: day(2), mealType: .lunch, recipeId: "soup", recipeTitle: "Roasted Tomato Soup"),
            PlannedMeal(date: day(2), mealType: .dinner, customMealName: "Tacos"),
            PlannedMeal(date: day(3), mealType: .snack, recipeId: "cookies", recipeTitle: "Brown Butter Cookies"),
        ]
        meals.append(PlannedMeal(date: day(-1), mealType: .dinner, customMealName: "Pizza night"))
        return MealPlan(id: "this-week", authorId: "cook", name: "This Week",
                        description: "Guinness stew tonight, leftovers tomorrow.",
                        startDate: day(-1), endDate: day(5), meals: meals,
                        createdAt: day(-2), updatedAt: day(-1), authorUsername: "david")
    }

    private static var lastWeek: MealPlan {
        MealPlan(id: "last-week", authorId: "cook", name: "Soup Week",
                 startDate: day(-9), endDate: day(-3),
                 meals: [PlannedMeal(date: day(-8), mealType: .dinner, recipeId: "soup", recipeTitle: "Roasted Tomato Soup")],
                 createdAt: day(-10), updatedAt: day(-10), authorUsername: "david")
    }

    // MARK: - The table

    private static var table: [Activity] {
        [
            Activity(id: "a1", type: .newRecipe, authorId: "maria", createdAt: hoursAgo(3), recipeId: "shakshuka",
                     authorUsername: "maria_cooks", contentTitle: "Shakshuka", contentDescription: "Eggs in spiced tomato."),
            Activity(id: "a2", type: .newMealPlan, authorId: "priya", createdAt: hoursAgo(20), mealPlanId: "p-week",
                     authorUsername: "priya", contentTitle: "Meal Prep Sunday", contentDescription: "Five lunches, one afternoon."),
            Activity(id: "a3", type: .newRecipe, authorId: "sam", createdAt: hoursAgo(50), recipeId: "focaccia",
                     authorUsername: "sam.bakes", contentTitle: "No-Knead Focaccia"),
            Activity(id: "a4", type: .newRecipe, authorId: "cook", createdAt: hoursAgo(80), recipeId: "stew",
                     authorUsername: "david", contentTitle: "Classic Beef Stew",
                     contentDescription: "A hearty, warming beef stew."),
        ]
    }

    // MARK: - Kroger

    static let krogerStores = [
        KrogerStore(id: "00000001", name: "Kroger Marketplace", chain: "KROGER", address: "100 Main St, Springfield, OH 45501"),
        KrogerStore(id: "00000002", name: "Kroger", chain: "KROGER", address: "2200 Elm Ave, Springfield, OH 45503"),
    ]

    /// A pretend shelf: the same product for any search that names it.
    static func krogerProducts(for term: String) -> [KrogerProduct] {
        let shelf: [(String, String, String, Double, Double?, String, Int?)] = [
            ("celery", "Kroger Celery Hearts", "16 oz", 2.49, nil, "Produce", nil),
            ("thyme", "Fresh Thyme Clamshell", "0.75 oz", 2.99, nil, "Produce", nil),
            ("garlic", "Fresh Garlic Bulb", "1 each", 0.69, nil, "Produce", nil),
            ("bacon", "Kroger Hickory Smoked Bacon", "16 oz", 5.49, 6.49, "Meat", nil),
            ("chicken stock", "Swanson Chicken Broth", "32 fl oz", 2.79, nil, "Aisle 9", 9),
            ("flour", "Kroger All Purpose Flour", "5 lb", 2.99, nil, "Aisle 11", 11),
            ("olive oil", "Kroger Extra Virgin Olive Oil", "16.9 fl oz", 7.99, nil, "Aisle 8", 8),
            ("tomato paste", "Hunt's Tomato Paste", "6 oz", 0.99, nil, "Aisle 9", 9),
            ("bay", "McCormick Bay Leaves", "0.12 oz", 4.49, nil, "Aisle 10", 10),
            ("pepper", "McCormick Ground Black Pepper", "3 oz", 4.29, nil, "Aisle 10", 10),
            ("guinness", "Guinness Draught Stout Beer", "4 cans / 14.9 fl oz", 9.99, 10.99, "Aisle 18", 18),
            ("bread", "Kroger Bakery Crusty French Bread", "16 oz", 2.99, nil, "Bakery", nil),
        ]
        let lowered = term.lowercased()
        return shelf.filter { lowered.contains($0.0) }.map { item in
            KrogerProduct(productId: "p-\(item.0)", name: item.1, brand: nil, size: item.2,
                          price: item.3, regularPrice: item.4 ?? item.3,
                          aisle: KrogerAisle(label: item.5, number: item.6),
                          imageURL: nil, inStock: true)
        }
    }

    // MARK: - Helpers

    private static func recipe(
        _ id: String, _ title: String, _ description: String?,
        author: String = "cook", authorName: String = "david",
        prep: Int, cook: Int, serves: Int, tags: [String],
        _ ingredients: [(String, String, String)]
    ) -> Recipe {
        let items = ingredients.map { Ingredient(name: $0.2, quantity: $0.0, unit: $0.1.isEmpty ? nil : $0.1) }
        let steps = [RecipeStep(instruction: "Gather everything, then cook as written.",
                                ingredientIds: items.map(\.id), orderIndex: 0)]
        return Recipe(id: id, authorId: author, title: title, description: description ?? "",
                      ingredients: items, steps: steps, isPublic: true, servings: serves,
                      prepTimeMinutes: prep, cookTimeMinutes: cook, tags: tags,
                      createdAt: day(-14), authorUsername: authorName)
    }

    private nonisolated static func day(_ offset: Int) -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: offset, to: today)?.addingTimeInterval(12 * 3600) ?? today
    }

    private nonisolated static func hoursAgo(_ hours: Int) -> Date {
        Date().addingTimeInterval(-Double(hours) * 3600)
    }
}
#endif
