import XCTest
@testable import FoodAndFriends

final class UserModelTests: XCTestCase {

    func testIsProfileComplete_withUsernameAndLocation_returnsTrue() {
        let user = FAFUser(email: "test@example.com", username: "testuser", location: "New York")
        XCTAssertTrue(user.isProfileComplete)
    }

    func testIsProfileComplete_withEmptyUsername_returnsFalse() {
        let user = FAFUser(email: "test@example.com", username: "", location: "New York")
        XCTAssertFalse(user.isProfileComplete)
    }

    func testIsProfileComplete_withEmptyLocation_returnsFalse() {
        let user = FAFUser(email: "test@example.com", username: "testuser", location: "")
        XCTAssertFalse(user.isProfileComplete)
    }

    func testDefaultFriendsArrayIsEmpty() {
        let user = FAFUser(email: "test@example.com", username: "testuser", location: "LA")
        XCTAssertTrue(user.friends.isEmpty)
    }
}

final class RecipeModelTests: XCTestCase {

    func testTotalTimeMinutes_withBothTimes_returnsSum() {
        let recipe = Recipe(authorId: "user1", title: "Pasta", prepTimeMinutes: 10, cookTimeMinutes: 20)
        XCTAssertEqual(recipe.totalTimeMinutes, 30)
    }

    func testTotalTimeMinutes_withOnlyPrepTime_returnsPrepTime() {
        let recipe = Recipe(authorId: "user1", title: "Salad", prepTimeMinutes: 15, cookTimeMinutes: nil)
        XCTAssertEqual(recipe.totalTimeMinutes, 15)
    }

    func testTotalTimeMinutes_withOnlyCookTime_returnsCookTime() {
        let recipe = Recipe(authorId: "user1", title: "Soup", prepTimeMinutes: nil, cookTimeMinutes: 30)
        XCTAssertEqual(recipe.totalTimeMinutes, 30)
    }

    func testTotalTimeMinutes_withNeitherTime_returnsNil() {
        let recipe = Recipe(authorId: "user1", title: "Unknown")
        XCTAssertNil(recipe.totalTimeMinutes)
    }

    func testFirstImageURL_returnsFirstElement() {
        let recipe = Recipe(authorId: "user1", title: "Test", imageURLs: ["url1", "url2"])
        XCTAssertEqual(recipe.firstImageURL, "url1")
    }

    func testFirstImageURL_emptyArray_returnsNil() {
        let recipe = Recipe(authorId: "user1", title: "Test")
        XCTAssertNil(recipe.firstImageURL)
    }
}

final class IngredientModelTests: XCTestCase {

    func testDisplayString_withUnit() {
        let ingredient = Ingredient(name: "Flour", quantity: "2", unit: "cups")
        XCTAssertEqual(ingredient.displayString, "2 cups Flour")
    }

    func testDisplayString_withoutUnit() {
        let ingredient = Ingredient(name: "Eggs", quantity: "3")
        XCTAssertEqual(ingredient.displayString, "3 Eggs")
    }

    func testDisplayString_withEmptyUnit() {
        let ingredient = Ingredient(name: "Salt", quantity: "1", unit: "")
        XCTAssertEqual(ingredient.displayString, "1 Salt")
    }
}

final class MealPlanModelTests: XCTestCase {

    func testNumberOfDays_sameDay_returnsOne() {
        let today = Date()
        let plan = MealPlan(authorId: "user1", name: "Today", startDate: today, endDate: today)
        XCTAssertEqual(plan.numberOfDays, 1)
    }

    func testNumberOfDays_oneWeek_returnsEight() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        let plan = MealPlan(authorId: "user1", name: "Week", startDate: start, endDate: end)
        XCTAssertEqual(plan.numberOfDays, 8)
    }

    func testTotalMeals_countsAllMeals() {
        let meals = [
            PlannedMeal(date: Date(), mealType: .breakfast),
            PlannedMeal(date: Date(), mealType: .lunch),
            PlannedMeal(date: Date(), mealType: .dinner)
        ]
        let plan = MealPlan(authorId: "user1", name: "Plan", startDate: Date(), endDate: Date(), meals: meals)
        XCTAssertEqual(plan.totalMeals, 3)
    }

    func testPlannedMealDisplayName_withRecipeTitle() {
        let meal = PlannedMeal(date: Date(), mealType: .lunch, recipeTitle: "Pasta")
        XCTAssertEqual(meal.displayName, "Pasta")
    }

    func testPlannedMealDisplayName_withCustomName() {
        let meal = PlannedMeal(date: Date(), mealType: .lunch, customMealName: "Leftovers")
        XCTAssertEqual(meal.displayName, "Leftovers")
    }

    func testPlannedMealDisplayName_noName_fallback() {
        let meal = PlannedMeal(date: Date(), mealType: .snack)
        XCTAssertEqual(meal.displayName, "Unnamed meal")
    }
}

final class MealTypeTests: XCTestCase {

    func testDisplayName_isCapitalized() {
        XCTAssertEqual(MealType.breakfast.displayName, "Breakfast")
        XCTAssertEqual(MealType.lunch.displayName, "Lunch")
        XCTAssertEqual(MealType.dinner.displayName, "Dinner")
        XCTAssertEqual(MealType.snack.displayName, "Snack")
    }

    func testCaseIterable_hasFourCases() {
        XCTAssertEqual(MealType.allCases.count, 4)
    }
}

final class ActivityModelTests: XCTestCase {

    func testIsRecipeActivity() {
        let recipe = Activity(type: .newRecipe, authorId: "user1")
        let comment = Activity(type: .recipeComment, authorId: "user1")
        let like = Activity(type: .recipeLike, authorId: "user1")
        let mealPlan = Activity(type: .newMealPlan, authorId: "user1")

        XCTAssertTrue(recipe.isRecipeActivity)
        XCTAssertTrue(comment.isRecipeActivity)
        XCTAssertTrue(like.isRecipeActivity)
        XCTAssertFalse(mealPlan.isRecipeActivity)
    }

    func testIsMealPlanActivity() {
        let mealPlan = Activity(type: .newMealPlan, authorId: "user1")
        let comment = Activity(type: .mealPlanComment, authorId: "user1")
        let like = Activity(type: .mealPlanLike, authorId: "user1")
        let recipe = Activity(type: .newRecipe, authorId: "user1")

        XCTAssertTrue(mealPlan.isMealPlanActivity)
        XCTAssertTrue(comment.isMealPlanActivity)
        XCTAssertTrue(like.isMealPlanActivity)
        XCTAssertFalse(recipe.isMealPlanActivity)
    }

    func testActivityTypeActionDescription() {
        XCTAssertEqual(ActivityType.newRecipe.actionDescription, "shared a new recipe")
        XCTAssertEqual(ActivityType.newMealPlan.actionDescription, "created a meal plan")
    }
}
