import XCTest
@testable import FoodAndFriends

final class ShoppingMathTests: XCTestCase {

    // MARK: - Reading amounts

    func testParse_wholeDecimalFractionAndMixed() {
        XCTAssertEqual(ShoppingMath.parse("2"), 2)
        XCTAssertEqual(ShoppingMath.parse("2.5"), 2.5)
        XCTAssertEqual(ShoppingMath.parse("1/2"), 0.5)
        XCTAssertEqual(ShoppingMath.parse("2 1/4"), 2.25)
    }

    func testParse_rangeBuysForTheTop() {
        XCTAssertEqual(ShoppingMath.parse("1-2"), 2)
        XCTAssertEqual(ShoppingMath.parse("3 to 4"), 4)
    }

    func testParse_wordsAreNotNumbers() {
        XCTAssertNil(ShoppingMath.parse("a pinch"))
        XCTAssertNil(ShoppingMath.parse(""))
        XCTAssertNil(ShoppingMath.parse("1/0"))
    }

    // MARK: - Printing amounts

    func testPrinted_setsFractionsTheWayARecipeDoes() {
        XCTAssertEqual(ShoppingMath.printed(2), "2")
        XCTAssertEqual(ShoppingMath.printed(0.5), "1/2")
        XCTAssertEqual(ShoppingMath.printed(2.5), "2 1/2")
        XCTAssertEqual(ShoppingMath.printed(0.75), "3/4")
        XCTAssertEqual(ShoppingMath.printed(1.0 / 3), "1/3")
        XCTAssertEqual(ShoppingMath.printed(1.99), "2")
        XCTAssertEqual(ShoppingMath.printed(14.9), "14.9")
    }

    // MARK: - Names

    func testShoppingName_dropsThePrep() {
        XCTAssertEqual(ShoppingMath.shoppingName("carrots, sliced"), "carrots")
        XCTAssertEqual(ShoppingMath.shoppingName("fresh thyme (or 1 tsp dried)"), "fresh thyme")
        XCTAssertEqual(ShoppingMath.shoppingName("Guinness"), "Guinness")
    }

    func testMergeKey_agreesSingularAndPlural() {
        XCTAssertEqual(ShoppingMath.mergeKey("onions, chopped"), ShoppingMath.mergeKey("onion, diced"))
        XCTAssertEqual(ShoppingMath.mergeKey("potatoes"), ShoppingMath.mergeKey("potato"))
        XCTAssertNotEqual(ShoppingMath.mergeKey("garlic"), ShoppingMath.mergeKey("ginger"))
    }

    func testNormalizedUnit_spellingsAgree() {
        XCTAssertEqual(ShoppingMath.normalizedUnit("lbs"), ShoppingMath.normalizedUnit("lb"))
        XCTAssertEqual(ShoppingMath.normalizedUnit("Tablespoons"), "tbsp")
        XCTAssertEqual(ShoppingMath.normalizedUnit(nil), "")
    }

    // MARK: - Aisles

    func testClassify_specificBeatsGeneral() {
        XCTAssertEqual(ShoppingAisle.classify("tomato paste"), .pantry)
        XCTAssertEqual(ShoppingAisle.classify("chicken stock"), .pantry)
        XCTAssertEqual(ShoppingAisle.classify("chicken thighs"), .meat)
        XCTAssertEqual(ShoppingAisle.classify("black pepper"), .spices)
        XCTAssertEqual(ShoppingAisle.classify("bell pepper"), .produce)
        XCTAssertEqual(ShoppingAisle.classify("Guinness"), .drinks)
    }

    func testClassify_wholeWordsNotFragments() {
        XCTAssertEqual(ShoppingAisle.classify("kale"), .produce)          // not "ale"
        XCTAssertEqual(ShoppingAisle.classify("garlic, minced"), .produce) // not "mince"
        XCTAssertEqual(ShoppingAisle.classify("eggplant"), .produce)       // not "egg"
        XCTAssertEqual(ShoppingAisle.classify("nutmeg"), .spices)          // not "nut"
        XCTAssertEqual(ShoppingAisle.classify("ricotta"), .dairy)          // not "rice"
        XCTAssertEqual(ShoppingAisle.classify("paper towels"), .other)
    }

    // MARK: - Merging recipes into a list

    private let stew = (id: Optional("stew"), title: "Stew")
    private let soup = (id: Optional("soup"), title: "Soup")

    func testMerge_sameThingSameUnitAddsUp() {
        let first = ShoppingMath.merge([Ingredient(name: "onions, chopped", quantity: "2")], from: stew, into: [])
        let both = ShoppingMath.merge([Ingredient(name: "onion, diced", quantity: "1")], from: soup, into: first)

        XCTAssertEqual(both.count, 1)
        XCTAssertEqual(both[0].quantity, 3)
        XCTAssertEqual(both[0].printedAmount, "3")
        XCTAssertEqual(both[0].sourceRecipeTitles, ["Stew", "Soup"])
    }

    func testMerge_unitSpellingsAgree() {
        let first = ShoppingMath.merge([Ingredient(name: "beef chuck", quantity: "2", unit: "lbs")], from: stew, into: [])
        let both = ShoppingMath.merge([Ingredient(name: "beef chuck", quantity: "1/2", unit: "lb")], from: soup, into: first)

        XCTAssertEqual(both.count, 1)
        XCTAssertEqual(both[0].quantity, 2.5)
        XCTAssertEqual(both[0].printedAmount, "2 1/2 lbs")
    }

    func testMerge_differentUnitsSitSideBySide() {
        let first = ShoppingMath.merge([Ingredient(name: "onions", quantity: "2")], from: stew, into: [])
        let both = ShoppingMath.merge([Ingredient(name: "onion", quantity: "1", unit: "large")], from: soup, into: first)

        XCTAssertEqual(both.count, 1)
        XCTAssertNil(both[0].quantity)
        XCTAssertEqual(both[0].printedAmount, "2 + 1 large")
    }

    func testMerge_addingMoreUnticksWhatsInTheCart() {
        var list = ShoppingMath.merge([Ingredient(name: "carrots", quantity: "3")], from: stew, into: [])
        list[0].isChecked = true
        let more = ShoppingMath.merge([Ingredient(name: "carrot", quantity: "2")], from: soup, into: list)

        XCTAssertFalse(more[0].isChecked)
        XCTAssertEqual(more[0].quantity, 5)
    }

    func testMerge_newLineIsFiledInItsAisle() {
        let list = ShoppingMath.merge([Ingredient(name: "tomato paste", quantity: "4", unit: "tbsp")], from: stew, into: [])
        XCTAssertEqual(list[0].category, ShoppingAisle.pantry.rawValue)
        XCTAssertEqual(list[0].name, "tomato paste")
    }

    // MARK: - Lists the earlier version wrote

    func testDecodesItemsWithoutTheNewerFields() throws {
        let json = #"{"name": "beef chuck, cubed", "quantity": 2, "unit": "lbs", "isChecked": false}"#
        let item = try JSONDecoder().decode(ShoppingItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.shoppingName, "beef chuck")
        XCTAssertEqual(item.printedAmount, "2 lbs")
        XCTAssertTrue(item.sourceRecipeTitles.isEmpty)
    }
}

final class KrogerStoreLinkTests: XCTestCase {

    func testStorePageLink_givesIdAndName() {
        let store = KrogerStoreLink.parse("https://www.kroger.com/stores/grocery/oh/springfield/main-street/014/00943")
        XCTAssertEqual(store?.id, "01400943")
        XCTAssertEqual(store?.name, "Kroger Main Street")
    }

    func testLinkWithoutScheme_andTrailingSlash() {
        XCTAssertEqual(KrogerStoreLink.parse("kroger.com/stores/grocery/oh/springfield/main-street/014/00943/")?.id, "01400943")
    }

    func testSlugThatAlreadySaysKroger_isNotDoubled() {
        let store = KrogerStoreLink.parse("https://www.kroger.com/stores/grocery/oh/springfield/kroger-marketplace/014/00943")
        XCTAssertEqual(store?.name, "Kroger Marketplace")
    }

    func testDetailsLink_fallsBackToTheId() {
        let store = KrogerStoreLink.parse("https://www.kroger.com/stores/details/014/00943")
        XCTAssertEqual(store?.id, "01400943")
        XCTAssertEqual(store?.name, "Kroger store 01400943")
    }

    func testBareIds() {
        XCTAssertEqual(KrogerStoreLink.parse("01400943")?.id, "01400943")
        XCTAssertEqual(KrogerStoreLink.parse("014-00943")?.id, "01400943")
        XCTAssertEqual(KrogerStoreLink.parse("014/00943")?.id, "01400943")
    }

    func testNotAStore() {
        XCTAssertNil(KrogerStoreLink.parse(""))
        XCTAssertNil(KrogerStoreLink.parse("https://www.kroger.com/"))
        XCTAssertNil(KrogerStoreLink.parse("45501"))
    }
}

final class KrogerReadingTests: XCTestCase {

    func testSearchTerm_keepsWhatYoudTypeIntoTheStoresSearch() {
        XCTAssertEqual(KrogerReading.searchTerm("bacon or pancetta"), "bacon")
        XCTAssertEqual(KrogerReading.searchTerm("fresh thyme (or 1 tsp dried)"), "fresh thyme")
        XCTAssertEqual(KrogerReading.searchTerm("Beef chuck, boneless"), "beef chuck")
        XCTAssertEqual(KrogerReading.searchTerm("Guinness"), "guinness")
    }

    func testAisle_readsNumberedAislesAndDepartments() {
        XCTAssertEqual(KrogerReading.aisle(description: "AISLE 12", number: "12"), KrogerAisle(label: "Aisle 12", number: 12))
        XCTAssertEqual(KrogerReading.aisle(description: "AISLE 7", number: nil), KrogerAisle(label: "Aisle 7", number: 7))
        XCTAssertEqual(KrogerReading.aisle(description: "MEAT", number: nil), KrogerAisle(label: "Meat", number: nil))
        XCTAssertNil(KrogerReading.aisle(description: "  ", number: nil))
    }

    func testProduct_takesTheSalePriceTheFeaturedPhotoAndTheAisle() throws {
        let json = """
        {"data": [{
          "productId": "0008382000014", "description": "Guinness Draught Stout Beer", "brand": "Guinness",
          "aisleLocations": [{"description": "AISLE 18", "number": "18"}],
          "images": [
            {"perspective": "back", "sizes": [{"size": "medium", "url": "https://img/back.jpg"}]},
            {"perspective": "front", "featured": true, "sizes": [{"size": "xlarge", "url": "https://img/x.jpg"}, {"size": "medium", "url": "https://img/m.jpg"}]}
          ],
          "items": [{"size": "4 cans / 14.9 fl oz", "price": {"regular": 10.99, "promo": 8.99}, "inventory": {"stockLevel": "HIGH"}}]
        }]}
        """
        let raw = try JSONDecoder().decode(KrogerReading.Envelope<KrogerReading.RawProduct>.self, from: Data(json.utf8))
        let product = try XCTUnwrap(raw.data?.first.flatMap(KrogerReading.product))
        XCTAssertEqual(product.price, 8.99)
        XCTAssertEqual(product.regularPrice, 10.99)
        XCTAssertTrue(product.isOnSale)
        XCTAssertEqual(product.imageURL, "https://img/m.jpg")
        XCTAssertEqual(product.aisle, KrogerAisle(label: "Aisle 18", number: 18))
    }

    func testProduct_unpricedWhenTheStoreDoesntPriceIt() throws {
        let json = #"{"data": [{"productId": "1", "description": "Thing", "items": [{"price": {"regular": 0, "promo": 0}}]}]}"#
        let raw = try JSONDecoder().decode(KrogerReading.Envelope<KrogerReading.RawProduct>.self, from: Data(json.utf8))
        XCTAssertNil(raw.data?.first.flatMap(KrogerReading.product)?.price)
    }

    private func product(_ id: String, _ price: Double?, inStock: Bool = true) -> KrogerProduct {
        KrogerProduct(productId: id, name: id, brand: nil, size: nil, price: price, regularPrice: price,
                      aisle: nil, imageURL: nil, inStock: inStock)
    }

    func testBestMatch_prefersWhatThisStorePricesAndStocks() {
        XCTAssertEqual(KrogerReading.bestMatch([product("a", nil), product("b", 3, inStock: false), product("c", 4)])?.productId, "c")
        XCTAssertEqual(KrogerReading.bestMatch([product("a", nil), product("b", 3, inStock: false)])?.productId, "b")
        XCTAssertNil(KrogerReading.bestMatch([]))
    }

    func testStore_writesTheAddressOnOneLine() throws {
        let json = #"{"data": [{"locationId": "01400435", "name": "Kroger - Miami Township", "chain": "KROGER", "address": {"addressLine1": "6388 Branch Hill Guinea Pike", "city": "Loveland", "state": "OH", "zipCode": "45140"}}]}"#
        let raw = try JSONDecoder().decode(KrogerReading.Envelope<KrogerReading.RawLocation>.self, from: Data(json.utf8))
        let store = try XCTUnwrap(raw.data?.first.flatMap(KrogerReading.store))
        XCTAssertEqual(store.id, "01400435")
        XCTAssertEqual(store.address, "6388 Branch Hill Guinea Pike, Loveland, OH 45140")
    }
}

final class KrogerProductDetailTests: XCTestCase {

    func testShelfLocation_readsSideShelfAndBay() {
        XCTAssertEqual(KrogerReading.shelfLocation(side: "L", shelf: "3", bay: "13"), "Left side · shelf 3 · bay 13")
        XCTAssertEqual(KrogerReading.shelfLocation(side: "R", shelf: nil, bay: nil), "Right side")
        XCTAssertNil(KrogerReading.shelfLocation(side: nil, shelf: "", bay: nil))
    }

    func testProduct_keepsEveryPhotoLargestFirstAndCategories() throws {
        let json = """
        {"data": [{"productId": "1", "description": "Celery", "categories": ["Produce"],
          "aisleLocations": [{"description": "PRODUCE", "side": "L", "shelfNumber": "2"}],
          "images": [
            {"perspective": "back", "sizes": [{"size": "large", "url": "https://img/back-l.jpg"}]},
            {"perspective": "front", "featured": true, "sizes": [{"size": "medium", "url": "https://img/m.jpg"}, {"size": "xlarge", "url": "https://img/xl.jpg"}]}
          ]}]}
        """
        let raw = try JSONDecoder().decode(KrogerReading.Envelope<KrogerReading.RawProduct>.self, from: Data(json.utf8))
        let product = try XCTUnwrap(raw.data?.first.flatMap(KrogerReading.product))
        XCTAssertEqual(product.largeImageURLs, ["https://img/xl.jpg", "https://img/back-l.jpg"])
        XCTAssertEqual(product.categories, ["Produce"])
        XCTAssertEqual(product.shelfLocation, "Left side · shelf 2")
    }
}

final class ShoppingRemoveTests: XCTestCase {

    private let stew = (id: Optional("stew"), title: "Stew")
    private let soup = (id: Optional("soup"), title: "Soup")

    func testRemove_dropsLinesOnlyThatRecipeWanted() {
        let list = ShoppingMath.merge([Ingredient(name: "beef chuck", quantity: "2", unit: "lb")], from: stew, into: [])
        XCTAssertTrue(ShoppingMath.remove([Ingredient(name: "beef chuck", quantity: "2", unit: "lb")], of: stew, from: list).isEmpty)
    }

    func testRemove_leavesTheOtherRecipesShare() {
        var list = ShoppingMath.merge([Ingredient(name: "onions", quantity: "2")], from: stew, into: [])
        list = ShoppingMath.merge([Ingredient(name: "onion", quantity: "1")], from: soup, into: list)
        let left = ShoppingMath.remove([Ingredient(name: "onions", quantity: "2")], of: stew, from: list)

        XCTAssertEqual(left.count, 1)
        XCTAssertEqual(left[0].quantity, 1)
        XCTAssertEqual(left[0].sourceRecipeTitles, ["Soup"])
    }

    func testRemove_mixedUnitsStayButStopNamingTheRecipe() {
        var list = ShoppingMath.merge([Ingredient(name: "onions", quantity: "2")], from: stew, into: [])
        list = ShoppingMath.merge([Ingredient(name: "onion", quantity: "1", unit: "large")], from: soup, into: list)
        let left = ShoppingMath.remove([Ingredient(name: "onions", quantity: "2")], of: stew, from: list)

        XCTAssertEqual(left.count, 1)
        XCTAssertEqual(left[0].sourceRecipeTitles, ["Soup"])
    }

    func testRemove_neverTouchesYourOwnLines() {
        var own = ShoppingItem(name: "Crusty bread")
        own.isManuallyAdded = true
        let list = ShoppingMath.merge([Ingredient(name: "carrots", quantity: "3")], from: stew, into: [own])
        let left = ShoppingMath.remove([Ingredient(name: "carrots", quantity: "3")], of: stew, from: list)
        XCTAssertEqual(left.map(\.name), ["Crusty bread"])
    }

    func testRemoveSource_withoutTheRecipe() {
        var list = ShoppingMath.merge([Ingredient(name: "carrots", quantity: "3")], from: stew, into: [])
        list = ShoppingMath.merge([Ingredient(name: "garlic", quantity: "2"), Ingredient(name: "carrots", quantity: "1")], from: soup, into: list)
        let left = ShoppingMath.removeSource(stew, from: list)

        XCTAssertEqual(Set(left.map(\.name)), ["carrots", "garlic"])
        XCTAssertTrue(left.allSatisfy { $0.sourceRecipeTitles == ["Soup"] })
    }
}

// MARK: - Scaling for more or fewer servings

final class IngredientScalingTests: XCTestCase {
    func testWholeAndFractions() {
        XCTAssertEqual(Ingredient.scaledQuantity("2 1/4", by: 2), "4 1/2")
        XCTAssertEqual(Ingredient.scaledQuantity("3/4", by: 0.5), "3/8")
        XCTAssertEqual(Ingredient.scaledQuantity("1", by: 1.5), "1 1/2")
        XCTAssertEqual(Ingredient.scaledQuantity("1/2", by: 0.5), "1/4")
    }

    func testBigAmountsRoundToWholeNumbers() {
        XCTAssertEqual(Ingredient.scaledQuantity("750", by: 1.5), "1125")
        XCTAssertEqual(Ingredient.scaledQuantity("500", by: 1.0 / 3), "167")
    }

    func testRangesScaleBothEnds() {
        XCTAssertEqual(Ingredient.scaledQuantity("1-2", by: 2), "2-4")
        XCTAssertEqual(Ingredient.scaledQuantity("2 to 3", by: 2), "4 to 6")
    }

    func testWordsStayAsWritten() {
        XCTAssertEqual(Ingredient.scaledQuantity("pinch", by: 2), "pinch")
        XCTAssertEqual(Ingredient.scaledQuantity("to taste", by: 3), "to taste")
        XCTAssertEqual(Ingredient.scaledQuantity("", by: 2), "")
    }

    func testScaledKeepsTheSameIngredient() {
        let salt = Ingredient(name: "kosher salt", quantity: "2 1/4", unit: "tsp")
        let doubled = salt.scaled(by: 2)
        XCTAssertEqual(doubled.id, salt.id)
        XCTAssertEqual(doubled.quantity, "4 1/2")
        XCTAssertEqual(doubled.unit, "tsp")
        XCTAssertEqual(salt.scaled(by: 1).quantity, "2 1/4")
    }
}
