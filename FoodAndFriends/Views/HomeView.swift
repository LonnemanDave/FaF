import SwiftUI

/// Home — the journal's title page. The cook's name set as the book's own,
/// today's menu, the figures, the recipe box set as an index, and what
/// friends have been cooking. Recipes, Menus and the Table are one tap in.
struct HomeView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared
    @ObservedObject var feedService = FeedService.shared
    @ObservedObject var moderation = ModerationService.shared
    @EnvironmentObject private var router: TabRouter

    @State private var selectedRecipe: Recipe?
    @State private var selectedMealPlan: MealPlan?
    @State private var showCreateRecipe = false
    @State private var showCreateMenu = false
    @State private var openingId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    plate
                    today
                    figures
                    recipeBox
                    table
                }
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .navigationDestination(item: $selectedMealPlan) { mealPlan in
                MealPlanDetailView(mealPlan: mealPlan)
            }
            .sheet(isPresented: $showCreateRecipe) {
                CreateRecipeView()
            }
            .sheet(isPresented: $showCreateMenu) {
                ManualMealPlanCreatorView()
            }
        }
    }

    // MARK: - Plate

    /// The title page: double rule, the cook's name as the book's title,
    /// what the book is set underneath.
    private var plate: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 12)

            HStack(alignment: .firstTextBaseline) {
                Text(cookName)
                    .font(.plate(32))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: Theme.spacingSM)

                Menu {
                    Button {
                        showCreateRecipe = true
                    } label: {
                        Label("New recipe", systemImage: "fork.knife")
                    }
                    Button {
                        showCreateMenu = true
                    } label: {
                        Label("New menu", systemImage: "calendar.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Theme.ink)
                        .frame(width: 36, height: 36, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Add to the journal")
            }

            Text(edition.uppercased())
                .smallCaps(10, weight: .medium, tracking: 1.4)
                .foregroundColor(Theme.ink2)
                .padding(.top, 4)

            Rule()
                .padding(.top, 12)
        }
        .padding(.top, Theme.spacingSM)
    }

    /// Whose journal this is — the title itself.
    private var cookName: String {
        guard let user = userService.currentUser else { return "The Kitchen" }
        if let name = user.displayName, !name.isEmpty { return name }
        return user.username
    }

    /// The line under the title — what the book is, and how thick it is.
    private var edition: String {
        let count = recipeService.userRecipes.count
        guard count > 0 else { return "A cook's journal · first edition" }
        return "A cook's journal · \(count) \(count == 1 ? "recipe" : "recipes")"
    }

    // MARK: - Today

    /// The menu that covers today, compared by day so its last day still counts.
    private var activePlan: MealPlan? {
        let calendar = Calendar.current
        let now = Date()
        return mealPlanService.userMealPlans.first { plan in
            calendar.compare(now, to: plan.startDate, toGranularity: .day) != .orderedAscending
                && calendar.compare(now, to: plan.endDate, toGranularity: .day) != .orderedDescending
        }
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(
                title: "Today",
                figure: Date().formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
            )
            .padding(.bottom, 2)

            if let plan = activePlan {
                let meals = plan.meals(for: Date())
                ForEach(MealType.allCases, id: \.self) { type in
                    todayLine(type: type, meal: meals.first { $0.mealType == type })
                    if type != MealType.allCases.last {
                        DashedDivider()
                    }
                }

                Button {
                    selectedMealPlan = plan
                } label: {
                    marginLink("The week's menu")
                }
                .buttonStyle(.plain)
            } else {
                // Nothing planned is the usual day, not an empty page — one
                // line, the same weight as any other, with planning in the margin.
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
                    Text("Nothing planned")
                        .font(.setting(15).italic())
                        .foregroundColor(Theme.ink2)
                    Spacer(minLength: Theme.spacingSM)
                    MarginButton("Plan a menu") { showCreateMenu = true }
                }
                .padding(.vertical, 11)
            }
        }
    }

    private func todayLine(type: MealType, meal: PlannedMeal?) -> some View {
        let recipe = meal.flatMap(recipe(for:))
        return Button {
            if let meal { open(meal) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
                MealStamp(mealType: type)
                    .frame(width: 54, alignment: .leading)

                if let meal {
                    Text(meal.displayName)
                        .font(type == .dinner ? .plate(18, .semibold) : .setting(16))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if let minutes = recipe?.totalTimeMinutes {
                        DotLeader()
                        Text(minutes.printedMinutes)
                            .font(.figure(13, .semibold))
                            .foregroundColor(Theme.accent)
                            .fixedSize()
                    } else {
                        Spacer(minLength: 0)
                    }

                    if openingId == meal.id {
                        ProgressView().tint(Theme.ink3).scaleEffect(0.7)
                    }
                } else {
                    Text("Not planned")
                        .font(.setting(15).italic())
                        .foregroundColor(Theme.ink3)
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(meal?.recipeId == nil)
    }

    private func recipe(for meal: PlannedMeal) -> Recipe? {
        guard let id = meal.recipeId else { return nil }
        return (recipeService.userRecipes + recipeService.friendsRecipes.unblocked + recipeService.globalRecipes.unblocked)
            .first { $0.id == id }
    }

    /// Opens the meal's recipe — from what's already loaded, or fetched if it isn't.
    private func open(_ meal: PlannedMeal) {
        if let recipe = recipe(for: meal) {
            selectedRecipe = recipe
            return
        }
        guard let id = meal.recipeId else { return }
        openingId = meal.id
        Task {
            defer { openingId = nil }
            selectedRecipe = try? await recipeService.fetchRecipe(id: id)
        }
    }

    // MARK: - Figures

    private var figures: some View {
        Figures(items: [
            (label: "Recipes", value: "\(recipeService.userRecipes.count)"),
            (label: "Menus", value: "\(mealPlanService.userMealPlans.count)"),
            (label: "Friends", value: "\(userService.currentUser?.friends.count ?? 0)"),
        ])
    }

    // MARK: - The recipe box

    private var recipeBox: some View {
        let recipes = Array(recipeService.userRecipes.prefix(5))
        return VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "The recipe box", figure: "\(recipeService.userRecipes.count)")
                .padding(.bottom, 2)

            if recipes.isEmpty {
                BlankLeaf(
                    note: "No recipes written down yet.",
                    action: (label: "Write one", run: { showCreateRecipe = true })
                )
            } else {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    Button {
                        selectedRecipe = recipe
                    } label: {
                        IndexEntry(
                            title: recipe.title,
                            subtitle: recipe.description.isEmpty ? nil : recipe.description,
                            figure: recipe.totalTimeMinutes?.printedMinutes ?? "—",
                            serifTitle: true,
                            mark: String(format: "%02d", index + 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if index < recipes.count - 1 {
                        DashedDivider()
                    }
                }

                Button {
                    router.selection = .recipes
                } label: {
                    marginLink("All recipes")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - The table

    /// What friends have been cooking — the latest three, not your own.
    private var table: some View {
        let latest = Array(
            feedService.feedActivities.unblocked
                .filter { $0.authorId != userService.currentUser?.id }
                .prefix(3)
        )
        return VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "At the table")
                .padding(.bottom, 2)

            if latest.isEmpty {
                BlankLeaf(note: "When friends write down a recipe, it turns up here.")
            } else {
                ForEach(Array(latest.enumerated()), id: \.element.id) { index, activity in
                    tableLine(activity)
                    if index < latest.count - 1 {
                        DashedDivider()
                    }
                }
            }
        }
    }

    private func tableLine(_ activity: Activity) -> some View {
        Button {
            open(activity)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Monogram(
                    name: activity.authorUsername ?? "?",
                    imageURL: activity.authorProfileImageURL,
                    size: 34
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.contentTitle ?? "Something new")
                        .font(.plate(16, .semibold))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                    Text("@\(activity.authorUsername ?? "someone") · \(activity.type.actionDescription)")
                        .font(.setting(12))
                        .foregroundColor(Theme.ink3)
                        .lineLimit(1)
                }

                Spacer(minLength: Theme.spacingSM)

                if openingId == activity.id {
                    ProgressView().tint(Theme.ink3).scaleEffect(0.7)
                } else {
                    Text(activity.createdAt.timeAgoDisplay())
                        .font(.figure(11, .medium))
                        .foregroundColor(Theme.ink3)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func open(_ activity: Activity) {
        openingId = activity.id
        Task {
            defer { openingId = nil }
            if activity.isRecipeActivity, let id = activity.recipeId {
                selectedRecipe = try? await recipeService.fetchRecipe(id: id)
            } else if activity.isMealPlanActivity, let id = activity.mealPlanId {
                selectedMealPlan = try? await mealPlanService.fetchMealPlan(id: id)
            }
        }
    }

    // MARK: - Margin

    /// A "turn the page" link set small and flush right under a section.
    private func marginLink(_ title: String) -> some View {
        HStack(spacing: 4) {
            Spacer()
            Text(title.uppercased())
                .smallCaps(10, weight: .semibold, tracking: 1.3)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(Theme.ink2)
        .padding(.top, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    HomeView()
        .environmentObject(TabRouter())
}
