import SwiftUI

struct MealPlanDetailView: View {
    let mealPlan: MealPlan

    @Environment(\.dismiss) var dismiss
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var aiService = AIService.shared
    @ObservedObject var userService = UserService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared

    @State private var showAIRecipeGenerator = false
    @State private var selectedMealForRecipe: PlannedMeal?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var allRecipes: [Recipe] {
        recipeService.globalRecipes + recipeService.friendsRecipes + recipeService.userRecipes
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: FAFSpacing.lg) {
                // Header
                headerSection

                // Meals by Day
                ForEach(groupedMealsByDate, id: \.key) { date, meals in
                    DaySection(
                        date: date,
                        meals: meals,
                        allRecipes: allRecipes,
                        onCreateRecipe: { meal in
                            selectedMealForRecipe = meal
                            showAIRecipeGenerator = true
                        }
                    )
                }
            }
            .padding(FAFSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fafBackground.ignoresSafeArea())
        .navigationTitle(mealPlan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Meal Plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.fafGray)
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
        .alert("Delete Meal Plan?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteMealPlan() }
            }
        } message: {
            Text("This will permanently delete \"\(mealPlan.name)\" and remove it from your feed. This cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func deleteMealPlan() async {
        isDeleting = true
        do {
            try await mealPlanService.deleteMealPlan(mealPlan)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isDeleting = false
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            if let description = mealPlan.description, !description.isEmpty {
                Text(description)
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
            }

            HStack(spacing: FAFSpacing.lg) {
                Label(dateRangeText, systemImage: "calendar")
                Label("\(mealPlan.numberOfDays) days", systemImage: "clock")
                Label("\(mealPlan.totalMeals) meals", systemImage: "fork.knife")
            }
            .font(FAFTypography.caption)
            .foregroundColor(.fafGray)

            // Missing recipes warning
            let missingCount = missingRecipesCount
            if missingCount > 0 {
                HStack(spacing: FAFSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.fafOrange)

                    Text("\(missingCount) recipe\(missingCount == 1 ? "" : "s") not linked")
                        .font(FAFTypography.bodySmall)
                        .foregroundColor(.fafTextPrimary)

                    Spacer()

                    if aiService.hasValidAPIKey {
                        Text("Tap to create")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafSage)
                    }
                }
                .padding(FAFSpacing.md)
                .background(Color.fafOrange.opacity(0.1))
                .cornerRadius(FAFRadius.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: mealPlan.startDate)) - \(formatter.string(from: mealPlan.endDate))"
    }

    private var missingRecipesCount: Int {
        mealPlan.meals.filter { $0.recipeId == nil }.count
    }

    private var groupedMealsByDate: [(key: Date, value: [PlannedMeal])] {
        let grouped = Dictionary(grouping: mealPlan.meals) { meal in
            Calendar.current.startOfDay(for: meal.date)
        }
        return grouped.sorted { $0.key < $1.key }
    }
}

// MARK: - Day Section

struct DaySection: View {
    let date: Date
    let meals: [PlannedMeal]
    let allRecipes: [Recipe]
    let onCreateRecipe: (PlannedMeal) -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            HStack {
                Text(formattedDate)
                    .font(FAFTypography.h3)
                    .foregroundColor(.fafTextPrimary)

                if isToday {
                    Text("Today")
                        .font(FAFTypography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, FAFSpacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.fafCoral)
                        .cornerRadius(FAFRadius.sm)
                }
            }

            ForEach(meals.sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }) { meal in
                MealPlanMealRow(
                    meal: meal,
                    linkedRecipe: findRecipe(for: meal),
                    onCreateRecipe: { onCreateRecipe(meal) }
                )
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    private func findRecipe(for meal: PlannedMeal) -> Recipe? {
        guard let recipeId = meal.recipeId else { return nil }
        return allRecipes.first { $0.id == recipeId }
    }
}

// MARK: - Meal Row

struct MealPlanMealRow: View {
    let meal: PlannedMeal
    let linkedRecipe: Recipe?
    let onCreateRecipe: () -> Void

    @ObservedObject var aiService = AIService.shared

    var body: some View {
        HStack(spacing: FAFSpacing.md) {
            // Meal type indicator
            VStack(spacing: FAFSpacing.xxs) {
                Image(systemName: meal.mealType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.fafSage)

                Text(meal.mealType.displayName)
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
            .frame(width: 60)

            // Recipe info
            if let recipe = linkedRecipe {
                // Linked recipe - make it tappable
                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                    linkedRecipeContent(recipe: recipe)
                }
                .buttonStyle(.plain)
            } else {
                // Missing recipe
                missingRecipeContent
            }
        }
        .padding(FAFSpacing.md)
        .background(Color.fafBackgroundSecondary)
        .cornerRadius(FAFRadius.md)
    }

    private func linkedRecipeContent(recipe: Recipe) -> some View {
        HStack(spacing: FAFSpacing.md) {
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                HStack(spacing: FAFSpacing.xs) {
                    Text(recipe.title)
                        .font(FAFTypography.body)
                        .foregroundColor(.fafTextPrimary)
                        .lineLimit(1)

                    Image(systemName: "link")
                        .font(.system(size: 12))
                        .foregroundColor(.fafSage)
                }

                if let time = recipe.totalTimeMinutes {
                    Text("\(time) min")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                }
            }

            Spacer()

            // Recipe image
            if let imageURL = recipe.firstImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.fafGrayXLight
                }
                .frame(width: 50, height: 50)
                .cornerRadius(FAFRadius.sm)
            }

            FAFIcon(.forward, size: 14, color: .fafGrayLight)
        }
    }

    private var missingRecipeContent: some View {
        HStack(spacing: FAFSpacing.md) {
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                Text(meal.displayName)
                    .font(FAFTypography.body)
                    .foregroundColor(.fafTextPrimary)
                    .lineLimit(1)

                Text("Recipe not linked")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafOrange)
            }

            Spacer()

            if aiService.hasValidAPIKey {
                Button(action: onCreateRecipe) {
                    HStack(spacing: FAFSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Create")
                            .font(FAFTypography.caption)
                    }
                    .foregroundColor(.fafSage)
                    .padding(.horizontal, FAFSpacing.md)
                    .padding(.vertical, FAFSpacing.xs)
                    .background(Color.fafSage.opacity(0.1))
                    .cornerRadius(FAFRadius.full)
                }
            }
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
