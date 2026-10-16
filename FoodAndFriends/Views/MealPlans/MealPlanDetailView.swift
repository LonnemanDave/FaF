import SwiftUI

/// One menu, set out day by day: each day a chapter head, each meal a
/// stamped line with its recipe's time carried across. A meal with a recipe
/// opens it; the whole menu goes on the shopping list in one go.
struct MealPlanDetailView: View {
    let mealPlan: MealPlan

    @Environment(\.dismiss) var dismiss
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var aiService = AIService.shared
    @ObservedObject var userService = UserService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared
    @ObservedObject var shoppingService = ShoppingListService.shared

    @State private var showAIRecipeGenerator = false
    @State private var selectedMealForRecipe: PlannedMeal?
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isShopping = false
    @State private var shopNote: String?

    private var allRecipes: [Recipe] {
        recipeService.userRecipes + recipeService.friendsRecipes + recipeService.globalRecipes
    }

    private func recipe(for meal: PlannedMeal) -> Recipe? {
        guard let id = meal.recipeId else { return nil }
        return allRecipes.first { $0.id == id }
    }

    private var days: [(day: Date, meals: [PlannedMeal])] {
        Dictionary(grouping: mealPlan.meals) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, meals: $0.value.sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }) }
    }

    /// Meals that point at a recipe — what "Shop this menu" can put on the list.
    private var linkedMeals: [PlannedMeal] {
        mealPlan.meals.filter { $0.recipeId != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                PlateHeader(
                    title: mealPlan.name,
                    subtitle: "\(mealPlan.printedDates) · \(mealPlan.numberOfDays) \(mealPlan.numberOfDays == 1 ? "day" : "days")",
                    figure: "\(mealPlan.totalMeals) meals"
                )

                if let description = mealPlan.description, !description.isEmpty {
                    Text(description)
                        .font(.setting(15).italic())
                        .foregroundColor(Theme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                shopThisMenu

                ForEach(days, id: \.day) { day in
                    dayLeaf(day.day, meals: day.meals)
                }

                let unlinked = mealPlan.meals.count - linkedMeals.count
                if unlinked > 0 {
                    Text("\(unlinked) \(unlinked == 1 ? "meal isn't" : "meals aren't") written down as a recipe yet.")
                        .font(.setting(12).italic())
                        .foregroundColor(Theme.ink3)
                }
            }
            .padding(.top, Theme.spacingSM)
            .padding(.bottom, Theme.spacingXL)
            .page()
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .backLeaf()
        .plainToolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if mealPlan.authorId == userService.currentUser?.id {
                    MarginButton("Delete", destructive: true) { showDeleteConfirmation = true }
                } else if let planId = mealPlan.id {
                    ModerationMenu(
                        subject: ReportSubject(target: .mealPlan, targetId: planId, authorId: mealPlan.authorId,
                                               authorUsername: mealPlan.authorUsername, label: mealPlan.name),
                        onBlocked: { dismiss() }
                    )
                }
            }
        }
        .sheet(isPresented: $showAIRecipeGenerator) {
            if let meal = selectedMealForRecipe {
                AIRecipeGeneratorView(initialRecipeIdea: meal.displayName)
            } else {
                AIRecipeGeneratorView()
            }
        }
        .alert("Delete this menu?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteMealPlan() }
            }
        } message: {
            Text("\"\(mealPlan.name)\" is deleted for good and taken off your friends' table. This can't be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Shop this menu

    @ViewBuilder
    private var shopThisMenu: some View {
        if !linkedMeals.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    Task { await shop() }
                } label: {
                    if isShopping {
                        ProgressView().tint(Theme.ink)
                    } else {
                        Text("Shop this menu")
                    }
                }
                .buttonStyle(.pressOutline)
                .disabled(isShopping || userService.currentUser == nil)

                if let shopNote {
                    Text(shopNote.uppercased())
                        .smallCaps(9, weight: .semibold, tracking: 1.3)
                        .foregroundColor(shoppingService.lastError == nil ? Theme.herb : Theme.error)
                }
            }
        }
    }

    /// Every linked recipe's ingredients onto the list, merged — a recipe
    /// cooked twice this week goes on twice.
    private func shop() async {
        guard let user = userService.currentUser else { return }
        isShopping = true
        defer { isShopping = false }
        var added = 0
        for meal in linkedMeals {
            var found = recipe(for: meal)
            if found == nil, let id = meal.recipeId {
                found = try? await recipeService.fetchRecipe(id: id)
            }
            guard let recipe = found else { continue }
            await shoppingService.add(recipe.ingredients, from: recipe, author: user)
            added += 1
        }
        shopNote = shoppingService.lastError
            ?? (added == 0 ? "Couldn't find those recipes" : "\(added) \(added == 1 ? "recipe" : "recipes") on the shopping list")
    }

    // MARK: - A day

    private func dayLeaf(_ day: Date, meals: [PlannedMeal]) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        return VStack(alignment: .leading, spacing: 0) {
            ChapterHead(
                name: day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)),
                tally: isToday ? "TODAY" : nil
            )
            Rule(color: isToday ? Theme.accent : Theme.rule)
                .padding(.top, 6)
                .padding(.bottom, 2)

            ForEach(Array(meals.enumerated()), id: \.element.id) { position, meal in
                mealLine(meal)
                if position < meals.count - 1 {
                    DashedDivider()
                }
            }
        }
    }

    @ViewBuilder
    private func mealLine(_ meal: PlannedMeal) -> some View {
        if let recipe = recipe(for: meal) {
            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                mealRow(meal, title: recipe.title, figure: recipe.totalTimeMinutes?.printedMinutes)
            }
            .buttonStyle(.plain)
        } else {
            HStack(alignment: .firstTextBaseline) {
                mealRow(meal, title: meal.displayName, figure: nil, unlinked: true)
                if aiService.hasValidAPIKey {
                    MarginButton("Write it") {
                        selectedMealForRecipe = meal
                        showAIRecipeGenerator = true
                    }
                }
            }
        }
    }

    private func mealRow(_ meal: PlannedMeal, title: String, figure: String?, unlinked: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
            MealStamp(mealType: meal.mealType)
                .frame(width: 54, alignment: .leading)

            Text(title)
                .font(unlinked ? .setting(15).italic() : .plate(17, .semibold))
                .foregroundColor(unlinked ? Theme.ink2 : Theme.ink)
                .lineLimit(1)
                .layoutPriority(1)

            if let figure {
                DotLeader()
                Text(figure)
                    .font(.figure(13, .semibold))
                    .foregroundColor(Theme.accent)
                    .fixedSize()
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func deleteMealPlan() async {
        do {
            try await mealPlanService.deleteMealPlan(mealPlan)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - MealType Extension

extension MealType {
    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .snack: return 3
        }
    }
}

#Preview {
    NavigationStack {
        MealPlanDetailView(mealPlan: MealPlan(
            authorId: "123",
            name: "Sample Week",
            description: "A test meal plan",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: Date())!,
            meals: []
        ))
    }
}
