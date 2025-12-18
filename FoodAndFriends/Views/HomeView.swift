import SwiftUI

struct HomeView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared
    @ObservedObject var feedService = FeedService.shared

    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            Group {
                if !hasLoaded {
                    // Show loading state until first load completes
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: FAFSpacing.xl) {
                            // Today's Meals Section
                            TodaysMealsCard(mealPlans: mealPlanService.userMealPlans)

                            // Quick Actions
                            QuickActionsSection()

                            // Recent Activity Preview
                            RecentActivitySection(activities: Array(feedService.feedActivities.prefix(3)))

                            // My Recipes
                            MyRecipesSection(recipes: recipeService.userRecipes)
                        }
                        .padding(.vertical, FAFSpacing.lg)
                    }
                }
            }
            .background(Color.fafWhite)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
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
            .task {
                if !hasLoaded {
                    await loadData()
                    hasLoaded = true
                }
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private var greeting: String {
        if let user = userService.currentUser {
            return "Hi, \(user.username)"
        }
        return "Home"
    }

    private func loadData() async {
        guard let userId = userService.currentUser?.id else { return }

        async let recipesTask: () = recipeService.fetchUserRecipes(userId: userId)
        async let mealPlansTask: () = mealPlanService.fetchUserMealPlans(userId: userId)

        _ = await (recipesTask, mealPlansTask)

        // Load feed preview if we have a user
        if let user = userService.currentUser {
            await feedService.fetchFeed(for: user)
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
                .foregroundColor(.fafBlack)

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
            .background(Color.fafOffWhite)
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
                .foregroundColor(.fafBlack)
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
                .foregroundColor(.fafBlack)

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
                    .foregroundColor(.fafBlack)
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

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(FAFTypography.h3)
                    .foregroundColor(.fafBlack)

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
                        CompactActivityCard(activity: activity)
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
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }
}

struct CompactActivityCard: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: FAFSpacing.sm) {
            // Author avatar placeholder
            Circle()
                .fill(Color.fafGrayXLight)
                .frame(width: 36, height: 36)
                .overlay(
                    FAFIcon(.profile, size: 16, color: .fafGray)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(activity.authorUsername ?? "unknown")")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)

                Text(activity.contentTitle ?? "Shared something")
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafBlack)
                    .lineLimit(1)
            }

            Spacer()

            Text(activity.createdAt.timeAgoDisplay())
                .font(FAFTypography.caption)
                .foregroundColor(.fafGrayLight)
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.sm)
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
                    .foregroundColor(.fafBlack)

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
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }
}

struct CompactRecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            // Recipe image placeholder
            RoundedRectangle(cornerRadius: FAFRadius.sm)
                .fill(Color.fafGrayXLight)
                .frame(width: 120, height: 90)
                .overlay(
                    FAFIcon(.fork, size: 24, color: .fafGray)
                )

            Text(recipe.title)
                .font(FAFTypography.bodyBold)
                .foregroundColor(.fafBlack)
                .lineLimit(1)

            if let time = recipe.totalTimeMinutes {
                Text("\(time) min")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
        }
        .frame(width: 120)
    }
}

#Preview {
    HomeView()
}
