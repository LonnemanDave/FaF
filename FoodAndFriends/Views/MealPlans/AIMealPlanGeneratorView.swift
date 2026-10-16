import SwiftUI

/// Asking Claude for a menu: the dates, the house rules, a note about the
/// week — then the draft, set out day by day the way a saved menu is, to be
/// read over before it goes in the journal.
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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingXL) {
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
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if generatedPlan != nil {
                        // Go back to setup
                        MarginButton("Back") {
                            generatedPlan = nil
                            linkedRecipes = [:]
                            missingRecipes = []
                        }
                    } else {
                        MarginButton("Cancel") { dismiss() }
                    }
                }
                if generatedPlan != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        MarginButton("Save") { Task { await savePlan() } }
                            .disabled(isSaving)
                            .opacity(isSaving ? 0.35 : 1)
                    }
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
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            PlateHeader(title: "Ask for a menu", subtitle: "Drafted by Claude, kept by you")

            Text("Say which days and how the week looks. Claude drafts a menu to your preferences, and you read it over before it goes in the journal.")
                .font(.setting(15).italic())
                .foregroundColor(Theme.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "Which days", figure: "\(numberOfDays) \(numberOfDays == 1 ? "day" : "days")")
                .padding(.bottom, Theme.spacingXS)

            MenuDateLine(label: "From", date: $startDate)
                .onChange(of: startDate) { _, newValue in
                    if endDate < newValue {
                        endDate = newValue
                    }
                }
            DashedDivider()
            MenuDateLine(label: "To", date: $endDate, earliest: startDate)
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack(spacing: Theme.spacingMD) {
                SectionHead(title: "Preferences")
                MarginButton("Change") { showPreferences = true }
            }

            VStack(alignment: .leading, spacing: 0) {
                if !preferences.dietaryRestrictions.isEmpty {
                    PreferenceLine(
                        label: "Diet",
                        value: preferences.dietaryRestrictions.map { $0.displayName }.joined(separator: ", ")
                    )
                }

                if !preferences.cuisinePreferences.isEmpty {
                    PreferenceLine(
                        label: "Cuisines",
                        value: preferences.cuisinePreferences.joined(separator: ", ")
                    )
                }

                if !preferences.allergens.isEmpty {
                    PreferenceLine(
                        label: "Keep out",
                        value: preferences.allergens.joined(separator: ", "),
                        valueColor: Theme.error
                    )
                }

                if let calorieGoal = preferences.calorieGoal {
                    PreferenceLine(label: "Portions", value: calorieGoal.displayName)
                }

                PreferenceLine(
                    label: "Cooking",
                    value: preferences.cookingSkillLevel.displayName
                )

                PreferenceLine(
                    label: "Meals",
                    value: preferences.mealTypes.isEmpty
                        ? "None chosen"
                        : preferences.mealTypes.map { $0.displayName }.joined(separator: ", "),
                    valueColor: preferences.mealTypes.isEmpty ? Theme.error : Theme.ink
                )

                if preferences.quickMealsPreferred {
                    PreferenceLine(
                        label: "Quick",
                        value: "Under 30 minutes, mostly"
                    )
                }
            }

            if preferences == .default {
                Text("The usual settings. Change them to suit the week.")
                    .font(.setting(12).italic())
                    .foregroundColor(Theme.ink3)
            }
        }
    }

    // MARK: - Special Requests Section

    private var specialRequestsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "About the week", figure: "Optional")

            FieldLine(
                label: "A note for Claude",
                text: $specialRequests,
                prompt: "Easy on Monday, something special Saturday, use up the chicken…",
                multiline: true
            )

            Text("Busy days, guests, an occasion, what's in the fridge — whatever should shape the menu.")
                .font(.setting(12).italic())
                .foregroundColor(Theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Button {
                Task { await generatePlan() }
            } label: {
                HStack(spacing: Theme.spacingSM) {
                    if aiService.isLoading {
                        ProgressView()
                            .tint(Theme.paper)
                    }
                    Text(aiService.isLoading ? "Writing the menu…" : "Ask for a menu")
                }
            }
            .buttonStyle(.press)
            .disabled(aiService.isLoading || preferences.mealTypes.isEmpty)

            if preferences.mealTypes.isEmpty {
                Text("Choose at least one meal in the preferences to ask for a menu.")
                    .font(.setting(12).italic())
                    .foregroundColor(Theme.ink3)
            } else if aiService.isLoading {
                Text("This can take a minute for a long week.")
                    .font(.setting(12).italic())
                    .foregroundColor(Theme.ink3)
            }
        }
    }

    // MARK: - Plan Review Section

    @ViewBuilder
    private var planReviewSection: some View {
        if let plan = generatedPlan {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                PlateHeader(
                    title: plan.name,
                    subtitle: "\(startDate.printed) – \(endDate.printed) · \(numberOfDays) \(numberOfDays == 1 ? "day" : "days")",
                    figure: "\(plan.meals.count) meals"
                )

                if let description = plan.description, !description.isEmpty {
                    Text(description)
                        .font(.setting(15).italic())
                        .foregroundColor(Theme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("A draft — nothing is saved until you put it in the journal.".uppercased())
                    .smallCaps(9, weight: .semibold, tracking: 1.3)
                    .foregroundColor(Theme.ink3)

                // Meals by Day
                ForEach(groupedMeals.keys.sorted(), id: \.self) { dateString in
                    if let meals = groupedMeals[dateString] {
                        DraftMenuDay(
                            dateString: dateString,
                            meals: meals,
                            linkedRecipes: linkedRecipes,
                            missingRecipes: missingRecipes
                        )
                    }
                }

                // Missing recipes note
                if !missingRecipes.isEmpty {
                    Text("\(missingRecipes.count) \(missingRecipes.count == 1 ? "dish isn't" : "dishes aren't") in your recipes yet. \(missingRecipes.count == 1 ? "It goes" : "They go") in by name, to write up later.")
                        .font(.setting(12).italic())
                        .foregroundColor(Theme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Save Button
                VStack(spacing: Theme.spacingMD) {
                    Button {
                        Task { await savePlan() }
                    } label: {
                        HStack(spacing: Theme.spacingSM) {
                            if isSaving {
                                ProgressView()
                                    .tint(Theme.paper)
                            }
                            Text(isSaving ? "Saving…" : "Put it in the journal")
                        }
                    }
                    .buttonStyle(.press)
                    .disabled(isSaving)

                    MarginButton("Start over") {
                        generatedPlan = nil
                        linkedRecipes = [:]
                        missingRecipes = []
                    }
                    .disabled(isSaving)
                }
                .padding(.top, Theme.spacingSM)
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
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Convert generated meals to PlannedMeal objects
        let plannedMeals: [PlannedMeal] = plan.meals.compactMap { genMeal in
            guard let date = dateFormatter.date(from: genMeal.date),
                  let mealType = MealType(rawValue: genMeal.mealType.lowercased()) else { return nil }

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

// MARK: - Date line

/// A date set as an index line — label, dot leader, the date — opening onto
/// the calendar when tapped. Like `DateLine`, but it can keep to a range, so
/// the last day of a menu can't come before the first.
private struct MenuDateLine: View {
    let label: String
    @Binding var date: Date
    var earliest: Date?
    @State private var open = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { open.toggle() }
            } label: {
                IndexEntry(
                    title: label,
                    figure: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                    figureColor: Theme.ink
                )
            }
            .buttonStyle(.plain)

            if open {
                picker
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Theme.accent)
                    .padding(.bottom, Theme.spacingSM)
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        if let earliest {
            DatePicker("", selection: $date, in: earliest..., displayedComponents: .date)
        } else {
            DatePicker("", selection: $date, displayedComponents: .date)
        }
    }
}

// MARK: - Preference line

/// One of the house rules, set as a ledger line: the label in small caps in
/// its own column, what it says beside it.
private struct PreferenceLine: View {
    let label: String
    let value: String
    var valueColor: Color = Theme.ink

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingMD) {
            Text(label.uppercased())
                .smallCaps(10, weight: .semibold, tracking: 1.3)
                .foregroundColor(Theme.ink3)
                .frame(width: 76, alignment: .leading)

            Text(value)
                .font(.setting(15))
                .foregroundColor(valueColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - A drafted day

/// One day of the drafted menu, set the way a saved menu sets it: the day
/// as a chapter head, each meal a stamped line underneath.
private struct DraftMenuDay: View {
    let dateString: String
    let meals: [GeneratedPlannedMeal]
    let linkedRecipes: [String: Recipe]
    let missingRecipes: Set<String>

    private var date: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    private var dayName: String {
        guard let date else { return dateString }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    /// Breakfast to snack, whatever order they came back in.
    private var orderedMeals: [GeneratedPlannedMeal] {
        meals.enumerated().sorted { lhs, rhs in
            let l = MealType(rawValue: lhs.element.mealType.lowercased())?.sortOrder ?? 9
            let r = MealType(rawValue: rhs.element.mealType.lowercased())?.sortOrder ?? 9
            return l == r ? lhs.offset < rhs.offset : l < r
        }
        .map(\.element)
    }

    var body: some View {
        let isToday = date.map { Calendar.current.isDateInToday($0) } ?? false
        VStack(alignment: .leading, spacing: 0) {
            ChapterHead(name: dayName, tally: isToday ? "TODAY" : nil)
            Rule(color: isToday ? Theme.accent : Theme.rule)
                .padding(.top, 6)
                .padding(.bottom, 2)

            ForEach(Array(orderedMeals.enumerated()), id: \.offset) { position, meal in
                DraftMealLine(
                    meal: meal,
                    linkedRecipe: linkedRecipes[meal.recipeName],
                    isMissing: missingRecipes.contains(meal.recipeName)
                )
                if position < orderedMeals.count - 1 {
                    DashedDivider()
                }
            }
        }
    }
}

/// One drafted meal: its stamp, the dish — in the serif when it's already a
/// recipe in the box, in italic when it's only a name so far — and the
/// cook's note underneath.
private struct DraftMealLine: View {
    let meal: GeneratedPlannedMeal
    let linkedRecipe: Recipe?
    let isMissing: Bool

    private var mealType: MealType? {
        MealType(rawValue: meal.mealType.lowercased())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
                Group {
                    if let mealType {
                        MealStamp(mealType: mealType)
                    } else {
                        Text(meal.mealType.uppercased())
                            .smallCaps(9, weight: .bold, tracking: 1.0)
                            .foregroundColor(Theme.ink2)
                            .lineLimit(1)
                    }
                }
                .frame(width: 54, alignment: .leading)

                Text(linkedRecipe?.title ?? meal.recipeName)
                    .font(linkedRecipe == nil ? .setting(15).italic() : .plate(17, .semibold))
                    .foregroundColor(linkedRecipe == nil ? Theme.ink2 : Theme.ink)
                    .lineLimit(2)
                    .layoutPriority(1)

                if let linkedRecipe {
                    DotLeader()
                    Text(linkedRecipe.totalTimeMinutes?.printedMinutes ?? "In the box")
                        .font(linkedRecipe.totalTimeMinutes == nil ? .setting(11).italic() : .figure(13, .semibold))
                        .foregroundColor(Theme.accent)
                        .fixedSize()
                } else {
                    Spacer(minLength: 0)
                    if isMissing {
                        Text("To write".uppercased())
                            .smallCaps(9, weight: .semibold, tracking: 1.2)
                            .foregroundColor(Theme.ink3)
                            .fixedSize()
                    }
                }
            }

            if let notes = meal.notes, !notes.isEmpty {
                Text(notes)
                    .font(.setting(12))
                    .foregroundColor(Theme.ink3)
                    .lineLimit(2)
                    .padding(.leading, 54 + Theme.spacingSM)
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AIMealPlanGeneratorView()
}
