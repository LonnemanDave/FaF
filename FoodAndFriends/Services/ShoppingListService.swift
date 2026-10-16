import Foundation
import FirebaseFirestore

/// Keeps the cook's open shopping list in step with Firestore.
///
/// One open list at a time: the newest list in `shoppingLists` that isn't
/// archived. Every change is applied here first, so a tick lands the moment
/// it's tapped, then written; the listener reconciles if the write fails.
@MainActor
final class ShoppingListService: ObservableObject {
    static let shared = ShoppingListService()

    private let db = Firestore.firestore()
    private let collection = "shoppingLists"
    private var listener: ListenerRegistration?

    /// The open list, or nil when there isn't one yet.
    @Published var list: ShoppingList?
    @Published var lastError: String?

    private init() {}

    // MARK: - Realtime

    func startListening(userId: String) {
        stopListening()
        listener = db.collection(collection)
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 5)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("Error listening to shopping list: \(error)")
                    return
                }
                self.list = snapshot?.documents
                    .compactMap { try? $0.data(as: ShoppingList.self) }
                    .first { !$0.isArchived }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        list = nil
    }

    // MARK: - Adding

    /// Adds a recipe's ingredients, merged into whatever's already on the list.
    /// Returns how many lines it touched.
    @discardableResult
    func add(_ ingredients: [Ingredient], from recipe: Recipe, author: FAFUser) async -> Int {
        guard !ingredients.isEmpty else { return 0 }
        var updated = list ?? newList(for: author)
        updated.items = ShoppingMath.merge(ingredients, from: (id: recipe.id, title: recipe.title), into: updated.items)
        if let id = recipe.id, !updated.recipeIds.contains(id) {
            updated.recipeIds.append(id)
        }
        await save(updated)
        return ingredients.count
    }

    /// A line written in by hand — "paper towels", "something for dessert" —
    /// optionally with the Kroger product already chosen for it.
    func addByHand(_ text: String, product: KrogerProduct? = nil, author: FAFUser) async {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var updated = list ?? newList(for: author)
        var item = ShoppingItem(name: name, category: ShoppingAisle.classify(name).rawValue)
        item.isManuallyAdded = true
        if let product { item.setKrogerProduct(product) }
        updated.items.append(item)
        await save(updated)
    }

    /// Whether a recipe's ingredients are on the list.
    func contains(_ recipe: Recipe) -> Bool {
        list?.items.contains { $0.sourceRecipeTitles.contains(recipe.title) } ?? false
    }

    /// Takes a recipe back off the list: its amounts come out, lines only it
    /// wanted go, and lines another recipe shares keep that recipe's share.
    /// `ingredients`: the amounts as they went on — scaled, if the recipe
    /// was cooked for more or fewer. Defaults to the recipe as written.
    func removeRecipe(titled title: String, ingredients: [Ingredient]? = nil) async {
        guard var updated = list else { return }
        let recipe = (RecipeService.shared.userRecipes
            + RecipeService.shared.friendsRecipes
            + RecipeService.shared.globalRecipes).first { $0.title == title }
        if let recipe {
            updated.items = ShoppingMath.remove(ingredients ?? recipe.ingredients, of: (id: recipe.id, title: title), from: updated.items)
            if let id = recipe.id { updated.recipeIds.removeAll { $0 == id } }
        }
        // Anything still naming it — a variation's ingredients, a recipe edited
        // since, or one that can't be found — is cleared by name.
        updated.items = ShoppingMath.removeSource((id: recipe?.id, title: title), from: updated.items)
        await save(updated)
    }

    // MARK: - Ticking off

    func toggle(_ item: ShoppingItem) async {
        guard var updated = list, let index = updated.items.firstIndex(where: { $0.id == item.id }) else { return }
        updated.items[index].isChecked.toggle()
        await save(updated)
    }

    func remove(_ item: ShoppingItem) async {
        guard var updated = list else { return }
        updated.items.removeAll { $0.id == item.id }
        await save(updated)
    }

    /// Takes everything in the cart off the list.
    func clearChecked() async {
        guard var updated = list else { return }
        updated.items.removeAll(where: \.isChecked)
        await save(updated)
    }

    /// Files the list away (archived, not deleted); the next add starts a fresh one.
    func startOver() async {
        guard var finished = list else { return }
        finished.isArchived = true
        list = nil
        guard !Self.isGallery, let id = finished.id else { return }
        do {
            try await db.collection(collection).document(id).updateData([
                "isArchived": true,
                "updatedAt": Date(),
            ])
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Kroger

    /// Matches every line still to get that hasn't got a product yet.
    /// Returns how many found a product and how many didn't.
    func matchAtKroger(locationId: String) async -> (matched: Int, missed: Int) {
        guard var updated = list else { return (0, 0) }
        let unmatched = updated.items.filter { !$0.isChecked && !$0.isMatchedAtKroger }
        guard !unmatched.isEmpty else { return (0, 0) }
        do {
            let found = try await KrogerService.shared.match(unmatched, at: locationId)
            for index in updated.items.indices {
                if let product = found[updated.items[index].id] {
                    updated.items[index].setKrogerProduct(product)
                }
            }
            await save(updated)
            return (found.count, unmatched.count - found.count)
        } catch {
            lastError = error.localizedDescription
            return (0, unmatched.count)
        }
    }

    /// Puts a different product against a line — or none.
    func choose(_ product: KrogerProduct?, for item: ShoppingItem) async {
        guard var updated = list, let index = updated.items.firstIndex(where: { $0.id == item.id }) else { return }
        updated.items[index].setKrogerProduct(product)
        await save(updated)
    }

    // MARK: - Writing

    private func newList(for author: FAFUser) -> ShoppingList {
        ShoppingList(
            authorId: author.id ?? "",
            authorUsername: author.username,
            authorProfileImageURL: author.profileImageURL
        )
    }

    /// Shows the change at once, then writes it — a new document the first
    /// time, the items array after that.
    private func save(_ updated: ShoppingList) async {
        var updated = updated
        updated.updatedAt = Date()
        list = updated
        lastError = nil
        guard !Self.isGallery else { return }

        do {
            if let id = updated.id {
                try await db.collection(collection).document(id).updateData([
                    "items": try updated.items.map { try Firestore.Encoder().encode($0) },
                    "recipeIds": updated.recipeIds,
                    "updatedAt": updated.updatedAt,
                ])
            } else {
                let ref = try db.collection(collection).addDocument(from: updated)
                list?.id = ref.documentID
            }
        } catch {
            print("Error saving shopping list: \(error)")
            lastError = error.localizedDescription
        }
    }

    private static var isGallery: Bool {
        #if DEBUG
        return DesignHarness.isOn
        #else
        return false
        #endif
    }
}
