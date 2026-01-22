import SwiftUI

struct ManualMealPlanCreatorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared

    @State private var planName = ""
    @State private var planDescription = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var meals: [PlannedMeal] = []

    @State private var showAddMeal = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var numberOfDays: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1
    }

    private var allRecipes: [Recipe] {
        recipeService.globalRecipes + recipeService.friendsRecipes + recipeService.userRecipes
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: FAFSpacing.lg) {
                    // Plan Details
                    detailsSection

                    // Date Range
                    dateRangeSection

                    // Meals
                    mealsSection

                    // Add Meal Button
                    addMealButton

                    // Save Button
                    if !meals.isEmpty {
                        saveButton
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
                        dismiss()
                    } label: {
                        FAFIcon(.close, size: 20, color: .fafGrayDark)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Create Meal Plan")
                        .font(FAFTypography.h3)
                        .foregroundColor(.fafTextPrimary)
                }
            }
            .sheet(isPresented: $showAddMeal) {
                AddMealSheet(
                    startDate: startDate,
                    endDate: endDate,
                    allRecipes: allRecipes,
                    onAdd: { meal in
                        meals.append(meal)
                    }
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Plan Details")
                .font(FAFTypography.label)
                .foregroundColor(.fafGrayDark)

            VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                TextField("Plan name (e.g., Weekly Meals)", text: $planName)
                    .font(FAFTypography.body)
                    .padding(FAFSpacing.md)
                    .background(Color.fafInputBackground)
                    .cornerRadius(FAFRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: FAFRadius.md)
                            .stroke(Color.fafDivider, lineWidth: 1)
                    )

                TextField("Description (optional)", text: $planDescription)
                    .font(FAFTypography.body)
                    .padding(FAFSpacing.md)
                    .background(Color.fafInputBackground)
                    .cornerRadius(FAFRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: FAFRadius.md)
                            .stroke(Color.fafDivider, lineWidth: 1)
                    )
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
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
                            // Remove meals outside date range
                            meals.removeAll { meal in
                                meal.date < newValue || meal.date > endDate
                            }
                        }
                }

                VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                    Text("End")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)

                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: endDate) { _, newValue in
                            // Remove meals outside date range
                            meals.removeAll { meal in
                                meal.date < startDate || meal.date > newValue
                            }
                        }
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

    // MARK: - Meals Section

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            HStack {
                Text("Meals")
                    .font(FAFTypography.label)
                    .foregroundColor(.fafGrayDark)

                Spacer()

                Text("\(meals.count) meal\(meals.count == 1 ? "" : "s")")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }

            if meals.isEmpty {
                VStack(spacing: FAFSpacing.sm) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 32))
                        .foregroundColor(.fafGrayLight)

                    Text("No meals added yet")
                        .font(FAFTypography.body)
                        .foregroundColor(.fafGray)

                    Text("Tap the button below to add meals to your plan")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGrayLight)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(FAFSpacing.xl)
            } else {
                // Group meals by date
                ForEach(groupedMealsByDate, id: \.key) { date, dateMeals in
                    ManualDayMealsCard(
                        date: date,
                        meals: dateMeals,
                        onDelete: { meal in
                            meals.removeAll { $0.id == meal.id }
                        }
                    )
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    private var groupedMealsByDate: [(key: Date, value: [PlannedMeal])] {
        let grouped = Dictionary(grouping: meals) { meal in
            Calendar.current.startOfDay(for: meal.date)
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // MARK: - Add Meal Button

    private var addMealButton: some View {
        Button {
            showAddMeal = true
        } label: {
            HStack(spacing: FAFSpacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Add Meal")
                    .font(FAFTypography.button)
            }
            .foregroundColor(.fafSage)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FAFSpacing.md)
            .background(Color.fafSage.opacity(0.1))
            .cornerRadius(FAFRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FAFRadius.md)
                    .stroke(Color.fafSage.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
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
            .background(planName.isEmpty ? Color.fafGray : Color.fafSage)
            .cornerRadius(FAFRadius.md)
        }
        .disabled(isSaving || planName.isEmpty)
    }

    // MARK: - Actions

    private func savePlan() async {
        guard let user = userService.currentUser else { return }

        isSaving = true
        defer { isSaving = false }

        let mealPlan = MealPlan(
            authorId: user.id ?? "",
            name: planName,
            description: planDescription.isEmpty ? nil : planDescription,
            startDate: startDate,
            endDate: endDate,
            meals: meals,
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

// MARK: - Manual Day Meals Card

struct ManualDayMealsCard: View {
    let date: Date
    let meals: [PlannedMeal]
    let onDelete: (PlannedMeal) -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            Text(formattedDate)
                .font(FAFTypography.bodyBold)
                .foregroundColor(.fafTextPrimary)

            ForEach(meals.sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }) { meal in
                HStack(spacing: FAFSpacing.md) {
                    Image(systemName: meal.mealType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.fafSage)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.displayName)
                            .font(FAFTypography.body)
                            .foregroundColor(.fafTextPrimary)
                            .lineLimit(1)

                        Text(meal.mealType.displayName)
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafGray)
                    }

                    Spacer()

                    Button {
                        onDelete(meal)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.fafGrayLight)
                    }
                }
                .padding(FAFSpacing.sm)
                .background(Color.fafBackgroundSecondary)
                .cornerRadius(FAFRadius.sm)
            }
        }
    }
}

// MARK: - Add Meal Sheet

struct AddMealSheet: View {
    @Environment(\.dismiss) var dismiss

    let startDate: Date
    let endDate: Date
    let allRecipes: [Recipe]
    let onAdd: (PlannedMeal) -> Void

    @State private var selectedDate: Date
    @State private var selectedMealType: MealType = .dinner
    @State private var useExistingRecipe = true
    @State private var selectedRecipe: Recipe?
    @State private var customMealName = ""
    @State private var searchText = ""

    init(startDate: Date, endDate: Date, allRecipes: [Recipe], onAdd: @escaping (PlannedMeal) -> Void) {
        self.startDate = startDate
        self.endDate = endDate
        self.allRecipes = allRecipes
        self.onAdd = onAdd
        _selectedDate = State(initialValue: startDate)
    }

    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return Array(allRecipes.prefix(10))
        }
        return allRecipes.filter { recipe in
            recipe.title.lowercased().contains(searchText.lowercased())
        }.prefix(10).map { $0 }
    }

    private var canAdd: Bool {
        if useExistingRecipe {
            return selectedRecipe != nil
        } else {
            return !customMealName.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: FAFSpacing.lg) {
                    // Date Selection
                    VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                        Text("Date")
                            .font(FAFTypography.label)
                            .foregroundColor(.fafGrayDark)

                        DatePicker("", selection: $selectedDate, in: startDate...endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FAFSpacing.lg)
                    .background(Color.fafCardBackground)
                    .cornerRadius(FAFRadius.lg)

                    // Meal Type Selection
                    VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                        Text("Meal Type")
                            .font(FAFTypography.label)
                            .foregroundColor(.fafGrayDark)

                        HStack(spacing: FAFSpacing.sm) {
                            ForEach(MealType.allCases, id: \.self) { mealType in
                                MealTypeChip(
                                    mealType: mealType,
                                    isSelected: selectedMealType == mealType
                                ) {
                                    selectedMealType = mealType
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FAFSpacing.lg)
                    .background(Color.fafCardBackground)
                    .cornerRadius(FAFRadius.lg)

                    // Recipe Selection
                    VStack(alignment: .leading, spacing: FAFSpacing.md) {
                        // Toggle
                        Picker("", selection: $useExistingRecipe) {
                            Text("Existing Recipe").tag(true)
                            Text("Custom Meal").tag(false)
                        }
                        .pickerStyle(.segmented)

                        if useExistingRecipe {
                            // Recipe Search
                            TextField("Search recipes...", text: $searchText)
                                .font(FAFTypography.body)
                                .padding(FAFSpacing.md)
                                .background(Color.fafInputBackground)
                                .cornerRadius(FAFRadius.md)

                            // Recipe List
                            ForEach(filteredRecipes) { recipe in
                                RecipeSelectionRow(
                                    recipe: recipe,
                                    isSelected: selectedRecipe?.id == recipe.id
                                ) {
                                    selectedRecipe = recipe
                                }
                            }

                            if filteredRecipes.isEmpty {
                                Text("No recipes found")
                                    .font(FAFTypography.body)
                                    .foregroundColor(.fafGray)
                                    .padding(FAFSpacing.md)
                            }
                        } else {
                            // Custom Meal Name
                            TextField("Meal name (e.g., Leftover night, Takeout)", text: $customMealName)
                                .font(FAFTypography.body)
                                .padding(FAFSpacing.md)
                                .background(Color.fafInputBackground)
                                .cornerRadius(FAFRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FAFRadius.md)
                                        .stroke(Color.fafDivider, lineWidth: 1)
                                )
                        }
                    }
                    .padding(FAFSpacing.lg)
                    .background(Color.fafCardBackground)
                    .cornerRadius(FAFRadius.lg)

                    // Add Button
                    Button {
                        addMeal()
                    } label: {
                        Text("Add Meal")
                            .font(FAFTypography.button)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FAFSpacing.md)
                            .background(canAdd ? Color.fafSage : Color.fafGray)
                            .cornerRadius(FAFRadius.md)
                    }
                    .disabled(!canAdd)
                }
                .padding(FAFSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fafBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.fafGray)
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Meal")
                        .font(FAFTypography.h3)
                        .foregroundColor(.fafTextPrimary)
                }
            }
        }
    }

    private func addMeal() {
        let meal = PlannedMeal(
            date: selectedDate,
            mealType: selectedMealType,
            recipeId: selectedRecipe?.id,
            customMealName: useExistingRecipe ? nil : customMealName,
            notes: nil,
            recipeTitle: selectedRecipe?.title ?? customMealName,
            recipeImageURL: selectedRecipe?.firstImageURL
        )
        onAdd(meal)
        dismiss()
    }
}

// MARK: - Meal Type Chip

struct MealTypeChip: View {
    let mealType: MealType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FAFSpacing.xxs) {
                Image(systemName: mealType.icon)
                    .font(.system(size: 16))
                Text(mealType.displayName)
                    .font(FAFTypography.caption)
            }
            .foregroundColor(isSelected ? .white : .fafTextPrimary)
            .padding(.horizontal, FAFSpacing.md)
            .padding(.vertical, FAFSpacing.sm)
            .background(isSelected ? Color.fafSage : Color.fafBackgroundSecondary)
            .cornerRadius(FAFRadius.md)
        }
    }
}

// MARK: - Recipe Selection Row

struct RecipeSelectionRow: View {
    let recipe: Recipe
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FAFSpacing.md) {
                // Recipe image
                if let imageURL = recipe.firstImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.fafGrayXLight
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(FAFRadius.sm)
                } else {
                    ZStack {
                        Color.fafGrayXLight
                        Image(systemName: "fork.knife")
                            .font(.system(size: 16))
                            .foregroundColor(.fafGray)
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(FAFRadius.sm)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.title)
                        .font(FAFTypography.body)
                        .foregroundColor(.fafTextPrimary)
                        .lineLimit(1)

                    if let time = recipe.totalTimeMinutes {
                        Text("\(time) min")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafGray)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.fafSage)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundColor(.fafGrayLight)
                }
            }
            .padding(FAFSpacing.sm)
            .background(isSelected ? Color.fafSage.opacity(0.1) : Color.fafBackgroundSecondary)
            .cornerRadius(FAFRadius.md)
        }
    }
}

#Preview {
    ManualMealPlanCreatorView()
}
