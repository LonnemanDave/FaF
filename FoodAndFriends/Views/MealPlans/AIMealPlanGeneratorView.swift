import SwiftUI

struct AIMealPlanGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var aiService = AIService.shared
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var preferences = MealPlanPreferences.default
    @State private var specialRequests = ""

    @State private var showPreferences = false
    @State private var showError = false
    @State private var errorMessage = ""

    @State private var generatedPlan: GeneratedMealPlan?
    @State private var linkedRecipes: [String: Recipe] = [:]  // recipeName -> Recipe
    @State private var missingRecipes: Set<String> = []

    @State private var isSaving = false

    var numberOfDays: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: FAFSpacing.lg) {
                    if generatedPlan == nil {
                        // Setup Phase
                        headerSection
                        dateRangeSection
                        preferencesSection
                        specialRequestsSection
                        generateButton
                    } else {
                        // Review Phase
                        planReviewSection
                    }
                }
                .padding(FAFSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fafBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if generatedPlan != nil {
                            // Go back to setup
                            generatedPlan = nil
                            linkedRecipes = [:]
                            missingRecipes = []
                        } else {
                            dismiss()
                        }
                    } label: {
                        if generatedPlan != nil {
                            HStack(spacing: FAFSpacing.xxs) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.fafGray)
                        } else {
                            FAFIcon(.close, size: 20, color: .fafGrayDark)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(generatedPlan == nil ? "AI Meal Planner" : "Review Plan")
                        .font(FAFTypography.h3)
                        .foregroundColor(.fafTextPrimary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showPreferences) {
                MealPlanPreferencesView(preferences: $preferences)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: FAFSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.fafSage.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.fafSage)
            }

            VStack(spacing: FAFSpacing.xs) {
                Text("Plan Your Meals")
                    .font(FAFTypography.h2)
                    .foregroundColor(.fafTextPrimary)

                Text("Claude will create a personalized meal plan based on your preferences.")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Date Range")
                .font(FAFTypography.label)
                .foregroundColor(.fafGrayDark)

            HStack(spacing: FAFSpacing.md) {
                VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                    Text("Start")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)

                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: startDate) { _, newValue in
                            if endDate < newValue {
                                endDate = newValue
                            }
                        }
                }

                VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                    Text("End")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)

                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                }

                Spacer()
            }

            Text("\(numberOfDays) day\(numberOfDays == 1 ? "" : "s")")
                .font(FAFTypography.bodyBold)
                .foregroundColor(.fafSage)
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            HStack {
                Text("Preferences")
                    .font(FAFTypography.label)
                    .foregroundColor(.fafGrayDark)

                Spacer()

                Button {
                    showPreferences = true
                } label: {
                    Text("Edit")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafSage)
                }
            }

            VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                if !preferences.dietaryRestrictions.isEmpty {
                    PreferenceSummaryRow(
                        icon: "leaf",
                        label: "Dietary",
                        value: preferences.dietaryRestrictions.map { $0.displayName }.joined(separator: ", ")
                    )
                }

                if !preferences.cuisinePreferences.isEmpty {
                    PreferenceSummaryRow(
                        icon: "globe",
                        label: "Cuisines",
                        value: preferences.cuisinePreferences.joined(separator: ", ")
                    )
                }

                if !preferences.allergens.isEmpty {
                    PreferenceSummaryRow(
                        icon: "exclamationmark.triangle",
                        label: "Avoid",
                        value: preferences.allergens.joined(separator: ", ")
                    )
                }

                PreferenceSummaryRow(
                    icon: "person",
                    label: "Skill",
                    value: preferences.cookingSkillLevel.displayName
                )

                PreferenceSummaryRow(
                    icon: "fork.knife",
                    label: "Meals",
                    value: preferences.mealTypes.map { $0.displayName }.joined(separator: ", ")
                )

                if preferences.quickMealsPreferred {
                    PreferenceSummaryRow(
                        icon: "clock",
                        label: "Quick",
                        value: "Under 30 min preferred"
                    )
                }
            }

            if preferences == .default {
                Text("Using default preferences. Tap Edit to customize.")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Special Requests Section

    private var specialRequestsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Special Requests (optional)")
                .font(FAFTypography.label)
                .foregroundColor(.fafGrayDark)

            TextField("e.g., Easy meals Monday, fancy dinner Saturday, use up the chicken in my fridge...", text: $specialRequests, axis: .vertical)
                .font(FAFTypography.body)
                .lineLimit(3...6)
                .padding(FAFSpacing.md)
                .background(Color.fafInputBackground)
                .cornerRadius(FAFRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.md)
                        .stroke(Color.fafDivider, lineWidth: 1)
                )

            Text("Tell Claude about your week - busy days, special occasions, ingredients to use up, or any other context.")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await generatePlan() }
        } label: {
            HStack(spacing: FAFSpacing.sm) {
                if aiService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                }
                Text(aiService.isLoading ? "Generating..." : "Generate Meal Plan")
                    .font(FAFTypography.button)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FAFSpacing.md)
            .background(Color.fafSage)
            .cornerRadius(FAFRadius.md)
        }
        .disabled(aiService.isLoading || preferences.mealTypes.isEmpty)
    }

    // MARK: - Plan Review Section

    private var planReviewSection: some View {
        VStack(spacing: FAFSpacing.lg) {
            if let plan = generatedPlan {
                // Plan Header
                VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                    Text(plan.name)
                        .font(FAFTypography.h2)
                        .foregroundColor(.fafTextPrimary)

                    if let description = plan.description {
                        Text(description)
                            .font(FAFTypography.body)
                            .foregroundColor(.fafGray)
                    }

                    HStack(spacing: FAFSpacing.md) {
                        Label("\(numberOfDays) days", systemImage: "calendar")
                        Label("\(plan.meals.count) meals", systemImage: "fork.knife")
                    }
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FAFSpacing.lg)
                .background(Color.fafCardBackground)
                .cornerRadius(FAFRadius.lg)

                // Missing recipes warning
                if !missingRecipes.isEmpty {
                    HStack(spacing: FAFSpacing.sm) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.fafOrange)

                        Text("\(missingRecipes.count) recipe\(missingRecipes.count == 1 ? "" : "s") need to be created")
                            .font(FAFTypography.body)
                            .foregroundColor(.fafTextPrimary)

                        Spacer()
                    }
                    .padding(FAFSpacing.md)
                    .background(Color.fafOrange.opacity(0.1))
                    .cornerRadius(FAFRadius.md)
                }

                // Meals by Day
                ForEach(groupedMeals.keys.sorted(), id: \.self) { dateString in
                    if let meals = groupedMeals[dateString] {
                        DayMealsCard(
                            dateString: dateString,
                            meals: meals,
                            linkedRecipes: linkedRecipes,
                            missingRecipes: missingRecipes
                        )
                    }
                }

                // Save Button
                Button {
                    Task { await savePlan() }
                } label: {
                    HStack(spacing: FAFSpacing.sm) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSaving ? "Saving..." : "Save Meal Plan")
                            .font(FAFTypography.button)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FAFSpacing.md)
                    .background(Color.fafSage)
                    .cornerRadius(FAFRadius.md)
                }
                .disabled(isSaving)
            }
        }
    }

    private var groupedMeals: [String: [GeneratedPlannedMeal]] {
        guard let plan = generatedPlan else { return [:] }
        return Dictionary(grouping: plan.meals, by: { $0.date })
    }

    // MARK: - Actions

    private func generatePlan() async {
        do {
            let plan = try await aiService.generateMealPlan(
                preferences: preferences,
                startDate: startDate,
                endDate: endDate,
                specialRequests: specialRequests.isEmpty ? nil : specialRequests
            )

            generatedPlan = plan

            // Try to link existing recipes
            await linkExistingRecipes(plan: plan)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func linkExistingRecipes(plan: GeneratedMealPlan) async {
        let allRecipes = recipeService.globalRecipes + recipeService.friendsRecipes + recipeService.userRecipes

        for meal in plan.meals {
            let recipeName = meal.recipeName.lowercased()

            // Try to find a matching recipe
            if let match = allRecipes.first(where: { recipe in
                recipe.title.lowercased().contains(recipeName) ||
                recipeName.contains(recipe.title.lowercased())
            }) {
                linkedRecipes[meal.recipeName] = match
            } else {
                missingRecipes.insert(meal.recipeName)
            }
        }
    }

    private func savePlan() async {
        guard let plan = generatedPlan,
              let user = userService.currentUser else { return }

        isSaving = true
        defer { isSaving = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Convert generated meals to PlannedMeal objects
        let plannedMeals: [PlannedMeal] = plan.meals.compactMap { genMeal in
            guard let date = dateFormatter.date(from: genMeal.date),
                  let mealType = MealType(rawValue: genMeal.mealType) else { return nil }

            let linkedRecipe = linkedRecipes[genMeal.recipeName]

            return PlannedMeal(
                date: date,
                mealType: mealType,
                recipeId: linkedRecipe?.id,
                customMealName: linkedRecipe == nil ? genMeal.recipeName : nil,
                notes: genMeal.notes,
                recipeTitle: linkedRecipe?.title ?? genMeal.recipeName,
                recipeImageURL: linkedRecipe?.firstImageURL
            )
        }

        let mealPlan = MealPlan(
            authorId: user.id ?? "",
            name: plan.name,
            description: plan.description,
            startDate: startDate,
            endDate: endDate,
            meals: plannedMeals,
            authorUsername: user.username,
            authorProfileImageURL: user.profileImageURL
        )

        do {
            _ = try await mealPlanService.createMealPlan(mealPlan, author: user)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Preference Summary Row

struct PreferenceSummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: FAFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.fafSage)
                .frame(width: 20)

            Text(label)
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(FAFTypography.bodySmall)
                .foregroundColor(.fafTextPrimary)
                .lineLimit(1)

            Spacer()
        }
    }
}

// MARK: - Day Meals Card

struct DayMealsCard: View {
    let dateString: String
    let meals: [GeneratedPlannedMeal]
    let linkedRecipes: [String: Recipe]
    let missingRecipes: Set<String>

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "EEEE, MMM d"
        return displayFormatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text(formattedDate)
                .font(FAFTypography.h3)
                .foregroundColor(.fafTextPrimary)

            ForEach(meals, id: \.recipeName) { meal in
                PlannedMealRow(
                    meal: meal,
                    linkedRecipe: linkedRecipes[meal.recipeName],
                    isMissing: missingRecipes.contains(meal.recipeName)
                )
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }
}

// MARK: - Planned Meal Row

struct PlannedMealRow: View {
    let meal: GeneratedPlannedMeal
    let linkedRecipe: Recipe?
    let isMissing: Bool

    var body: some View {
        HStack(spacing: FAFSpacing.md) {
            // Meal type icon
            VStack {
                Image(systemName: mealTypeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(.fafSage)

                Text(meal.mealType.capitalized)
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
            .frame(width: 60)

            // Recipe info
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                HStack(spacing: FAFSpacing.xs) {
                    Text(meal.recipeName)
                        .font(FAFTypography.body)
                        .foregroundColor(.fafTextPrimary)
                        .lineLimit(1)

                    if linkedRecipe != nil {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .foregroundColor(.fafSage)
                    } else if isMissing {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.fafOrange)
                    }
                }

                if let notes = meal.notes {
                    Text(notes)
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Recipe image or placeholder
            if let recipe = linkedRecipe, let imageURL = recipe.firstImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.fafGrayXLight
                }
                .frame(width: 44, height: 44)
                .cornerRadius(FAFRadius.sm)
            }
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafBackgroundSecondary)
        .cornerRadius(FAFRadius.md)
    }

    private var mealTypeIcon: String {
        switch meal.mealType.lowercased() {
        case "breakfast": return "sunrise"
        case "lunch": return "sun.max"
        case "dinner": return "moon"
        case "snack": return "leaf"
        default: return "fork.knife"
        }
    }
}

#Preview {
    AIMealPlanGeneratorView()
}
