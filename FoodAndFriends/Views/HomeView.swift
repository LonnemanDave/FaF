import SwiftUI

struct HomeView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared
    @ObservedObject var feedService = FeedService.shared

    @State private var selectedRecipe: Recipe?
    @State private var selectedMealPlan: MealPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FAFSpacing.xl) {
                    // Today's Meals Section
                    TodaysMealsCard(mealPlans: mealPlanService.userMealPlans)

                    // Quick Actions
                    QuickActionsSection()

                    // Recent Activity Preview
                    RecentActivitySection(
                        activities: Array(feedService.feedActivities.prefix(3)),
                        onSelectRecipe: { selectedRecipe = $0 },
                        onSelectMealPlan: { selectedMealPlan = $0 }
                    )

                    // My Recipes
                    MyRecipesSection(recipes: recipeService.userRecipes)
                }
                .padding(.vertical, FAFSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fafBackground.ignoresSafeArea())
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .navigationDestination(item: $selectedMealPlan) { mealPlan in
                // TODO: MealPlanDetailView when implemented
                Text("Meal Plan: \(mealPlan.name)")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            // TODO: Navigate to create recipe
                        } label: {
                            Label("New Recipe", systemImage: "fork.knife")
                        }
                        Button {
                            // TODO: Navigate to create meal plan
                        } label: {
                            Label("New Meal Plan", systemImage: "calendar.badge.plus")
                        }
                    } label: {
                        FAFIcon(.plus, size: 20, color: .fafCoral)
                    }
                }
            }
        }
    }
}

// MARK: - Today's Meals Card

struct TodaysMealsCard: View {
    let mealPlans: [MealPlan]

    private var todaysMeals: [PlannedMeal] {
        let today = Date()
        // Find active meal plan that includes today
        guard let activePlan = mealPlans.first(where: { plan in
            plan.startDate <= today && plan.endDate >= today
        }) else {
            return []
        }
        return activePlan.meals(for: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Today's Meals")
                .font(FAFTypography.h3)
                .foregroundColor(.fafTextPrimary)

            VStack(spacing: FAFSpacing.sm) {
                if todaysMeals.isEmpty {
                    EmptyTodayCard()
                } else {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        let meal = todaysMeals.first { $0.mealType == mealType }
                        MealRow(mealType: mealType, meal: meal)
                    }
                }
            }
            .padding(FAFSpacing.md)
            .background(Color.fafCardBackground)
            .cornerRadius(FAFRadius.md)
        }
        .padding(.horizontal, FAFSpacing.lg)
    }
}

struct EmptyTodayCard: View {
    var body: some View {
        VStack(spacing: FAFSpacing.sm) {
            FAFIcon(.calendar, size: 32, color: .fafGray)
            Text("No meals planned for today")
                .font(FAFTypography.body)
                .foregroundColor(.fafGray)
            Text("Create a meal plan to get started")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGrayLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FAFSpacing.lg)
    }
}

struct MealRow: View {
    let mealType: MealType
    let meal: PlannedMeal?

    var body: some View {
        HStack(spacing: FAFSpacing.sm) {
            Image(systemName: mealType.icon)
                .font(.system(size: 16))
                .foregroundColor(.fafCoral)
                .frame(width: 24)

            Text(mealType.displayName)
                .font(FAFTypography.bodyBold)
                .foregroundColor(.fafTextPrimary)
                .frame(width: 80, alignment: .leading)

            if let meal = meal {
                Text(meal.displayName)
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .lineLimit(1)
            } else {
                Text("Not planned")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGrayLight)
                    .italic()
            }

            Spacer()
        }
        .padding(.vertical, FAFSpacing.xs)
    }
}

// MARK: - Quick Actions

struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Quick Actions")
                .font(FAFTypography.h3)
                .foregroundColor(.fafTextPrimary)

            HStack(spacing: FAFSpacing.md) {
                DashboardActionButton(
                    title: "New Recipe",
                    icon: "fork.knife",
                    color: .fafCoral
                ) {
                    // TODO: Navigate to create recipe
                }

                DashboardActionButton(
                    title: "New Meal Plan",
                    icon: "calendar.badge.plus",
                    color: .fafSage
                ) {
                    // TODO: Navigate to create meal plan
                }
            }
        }
        .padding(.horizontal, FAFSpacing.lg)
    }
}

struct DashboardActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FAFSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title)
                    .font(FAFTypography.button)
                    .foregroundColor(.fafTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FAFSpacing.lg)
            .background(color.opacity(0.1))
            .cornerRadius(FAFRadius.md)
        }
    }
}

// MARK: - Recent Activity Section

struct RecentActivitySection: View {
    let activities: [Activity]
    var onSelectRecipe: ((Recipe) -> Void)?
    var onSelectMealPlan: ((MealPlan) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(FAFTypography.h3)
                    .foregroundColor(.fafTextPrimary)

                Spacer()

                if !activities.isEmpty {
                    Text("See All")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafCoral)
                }
            }

            if activities.isEmpty {
                EmptyActivityPreview()
            } else {
                VStack(spacing: FAFSpacing.sm) {
                    ForEach(activities) { activity in
                        CompactActivityCard(
                            activity: activity,
                            onSelectRecipe: onSelectRecipe,
                            onSelectMealPlan: onSelectMealPlan
                        )
                    }
                }
            }
        }
        .padding(.horizontal, FAFSpacing.lg)
    }
}

struct EmptyActivityPreview: View {
    var body: some View {
        VStack(spacing: FAFSpacing.sm) {
            FAFIcon(.friends, size: 32, color: .fafGray)
            Text("No recent activity")
                .font(FAFTypography.body)
                .foregroundColor(.fafGray)
            Text("Add friends to see their recipes")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGrayLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.md)
    }
}

struct CompactActivityCard: View {
    let activity: Activity
    var onSelectRecipe: ((Recipe) -> Void)?
    var onSelectMealPlan: ((MealPlan) -> Void)?

    @State private var isLoading = false

    var body: some View {
        Button {
            Task { await handleTap() }
        } label: {
            HStack(spacing: FAFSpacing.sm) {
                // Author avatar
                if let imageURL = activity.authorProfileImageURL,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            placeholderAvatar
                        @unknown default:
                            placeholderAvatar
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    placeholderAvatar
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(activity.authorUsername ?? "unknown")")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)

                    Text(activity.contentTitle ?? "Shared something")
                        .font(FAFTypography.bodyBold)
                        .foregroundColor(.fafTextPrimary)
                        .lineLimit(1)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(activity.createdAt.timeAgoDisplay())
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGrayLight)
                }
            }
            .padding(FAFSpacing.sm)
            .background(Color.fafCardBackground)
            .cornerRadius(FAFRadius.sm)
        }
        .buttonStyle(.plain)
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.fafGrayXLight)
            .frame(width: 36, height: 36)
            .overlay(
                FAFIcon(.profile, size: 16, color: .fafGray)
            )
    }

    private func handleTap() async {
        isLoading = true
        defer { isLoading = false }

        if activity.isRecipeActivity, let recipeId = activity.recipeId {
            do {
                if let recipe = try await RecipeService.shared.fetchRecipe(id: recipeId) {
                    onSelectRecipe?(recipe)
                }
            } catch {
                print("Error fetching recipe: \(error)")
            }
        } else if activity.isMealPlanActivity, let mealPlanId = activity.mealPlanId {
            do {
                if let mealPlan = try await MealPlanService.shared.fetchMealPlan(id: mealPlanId) {
                    onSelectMealPlan?(mealPlan)
                }
            } catch {
                print("Error fetching meal plan: \(error)")
            }
        }
    }
}

// MARK: - My Recipes Section

struct MyRecipesSection: View {
    let recipes: [Recipe]

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            HStack {
                Text("My Recipes")
                    .font(FAFTypography.h3)
                    .foregroundColor(.fafTextPrimary)

                Spacer()

                if !recipes.isEmpty {
                    Text("See All")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafCoral)
                }
            }
            .padding(.horizontal, FAFSpacing.lg)

            if recipes.isEmpty {
                EmptyRecipesPreview()
                    .padding(.horizontal, FAFSpacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FAFSpacing.md) {
                        ForEach(recipes.prefix(5)) { recipe in
                            CompactRecipeCard(recipe: recipe)
                        }
                    }
                    .padding(.horizontal, FAFSpacing.lg)
                }
            }
        }
    }
}

struct EmptyRecipesPreview: View {
    var body: some View {
        VStack(spacing: FAFSpacing.sm) {
            FAFIcon(.fork, size: 32, color: .fafGray)
            Text("No recipes yet")
                .font(FAFTypography.body)
                .foregroundColor(.fafGray)
            Text("Create your first recipe")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGrayLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.md)
    }
}

struct CompactRecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            // Recipe image
            Group {
                if let imageURL = recipe.firstImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            recipePlaceholder
                        @unknown default:
                            recipePlaceholder
                        }
                    }
                } else {
                    recipePlaceholder
                }
            }
            .frame(width: 120, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: FAFRadius.sm))

            Text(recipe.title)
                .font(FAFTypography.bodyBold)
                .foregroundColor(.fafTextPrimary)
                .lineLimit(1)

            if let time = recipe.totalTimeMinutes {
                Text("\(time) min")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
        }
        .frame(width: 120)
    }

    private var recipePlaceholder: some View {
        Rectangle()
            .fill(Color.fafGrayXLight)
            .overlay(
                FAFIcon(.fork, size: 24, color: .fafGray)
            )
    }
}

#Preview {
    HomeView()
}
