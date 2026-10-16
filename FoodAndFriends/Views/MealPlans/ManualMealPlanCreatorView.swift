import SwiftUI

/// A menu set down by hand: a name, the days it runs, and the meals written
/// in one at a time — each day a chapter, each meal a stamped line.
struct ManualMealPlanCreatorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared

    @State private var planName = ""
    @State private var planDescription = ""
    // Whole days, from midnight: a menu runs over days, not hours.
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.date(
        byAdding: .day, value: 6, to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()
    @State private var meals: [PlannedMeal] = []

    @State private var showAddMeal = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var numberOfDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: endDate)
        ).day ?? 0
        return days + 1
    }

    /// Every recipe within reach, once each — your own public recipes are in
    /// both your box and everyone's, and a list can't hold one recipe twice.
    private var allRecipes: [Recipe] {
        var seen = Set<String>()
        return (recipeService.globalRecipes.unblocked + recipeService.friendsRecipes.unblocked + recipeService.userRecipes)
            .filter { recipe in
                guard let id = recipe.id else { return true }
                return seen.insert(id).inserted
            }
    }

    private var canSave: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty && !meals.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingXL) {
                    PlateHeader(title: "A new menu", subtitle: "Set down by hand")

                    detailsSection

                    dateRangeSection

                    mealsSection

                    saveSection
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
                    MarginButton("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MarginButton("Save") { Task { await savePlan() } }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.35)
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

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            FieldLine(label: "Name", text: $planName, prompt: "The week of the long braise")
            FieldLine(
                label: "A line about it",
                text: $planDescription,
                prompt: "What the week's for — optional",
                multiline: true
            )
        }
    }

    // MARK: - Dates

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "The days", figure: "\(numberOfDays) \(numberOfDays == 1 ? "day" : "days")")
                .padding(.bottom, Theme.spacingXS)

            // The two menus people actually make: tonight, or the week ahead.
            HStack(spacing: Theme.spacingLG) {
                MarginButton("Just today") { setDays(1) }
                MarginButton("A week") { setDays(7) }
                Spacer(minLength: 0)
            }
            .padding(.bottom, Theme.spacingSM)

            JournalDateLine(label: "Begins", date: $startDate)
                .onChange(of: startDate) { _, newValue in
                    if endDate < newValue {
                        endDate = newValue
                    }
                    trimMeals(from: newValue, to: endDate)
                }

            DashedDivider()

            JournalDateLine(label: "Ends", date: $endDate, from: startDate)
                .onChange(of: endDate) { _, newValue in
                    trimMeals(from: startDate, to: newValue)
                }
        }
    }

    /// From today, for this many days.
    private func setDays(_ count: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        withAnimation(.easeOut(duration: 0.15)) {
            startDate = today
            endDate = calendar.date(byAdding: .day, value: count - 1, to: today) ?? today
        }
    }

    /// Take out any meal that's fallen off the ends of the menu. Compared by
    /// day, so a meal isn't lost to the hour its date happens to carry.
    private func trimMeals(from start: Date, to end: Date) {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        meals.removeAll { meal in
            let day = calendar.startOfDay(for: meal.date)
            return day < first || day > last
        }
    }

    // MARK: - Meals

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            SectionHead(
                title: "The meals",
                figure: meals.isEmpty ? nil : "\(meals.count) \(meals.count == 1 ? "meal" : "meals")"
            )

            if meals.isEmpty {
                BlankLeaf(note: "Nothing on the menu yet.\nAdd a meal, a day at a time.")
            } else {
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

            Button(meals.isEmpty ? "Add the first meal" : "Add a meal") {
                showAddMeal = true
            }
            .buttonStyle(.pressOutline)
        }
    }

    private var groupedMealsByDate: [(key: Date, value: [PlannedMeal])] {
        let grouped = Dictionary(grouping: meals) { meal in
            Calendar.current.startOfDay(for: meal.date)
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // MARK: - Save

    private var saveSection: some View {
        VStack(spacing: Theme.spacingMD) {
            Button {
                Task { await savePlan() }
            } label: {
                if isSaving {
                    ProgressView().tint(Theme.paper)
                } else {
                    Text("Save the menu")
                }
            }
            .buttonStyle(.press)
            .disabled(!canSave)

            if !canSave && !isSaving {
                Text("A name and at least one meal, and it can be saved.")
                    .font(.setting(12).italic())
                    .foregroundColor(Theme.ink3)
            }
        }
    }

    // MARK: - Actions

    private func savePlan() async {
        guard canSave, let user = userService.currentUser else { return }

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

// MARK: - A day of the menu

/// One day as a chapter: the day's name, a rule, then its meals stamped in
/// order — breakfast down to the snack — each with a mark to take it out.
struct ManualDayMealsCard: View {
    let date: Date
    let meals: [PlannedMeal]
    let onDelete: (PlannedMeal) -> Void

    private var sortedMeals: [PlannedMeal] {
        meals.sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChapterHead(
                name: date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)),
                tally: "\(meals.count)"
            )
            Rule()
                .padding(.top, 6)
                .padding(.bottom, 2)

            ForEach(Array(sortedMeals.enumerated()), id: \.element.id) { position, meal in
                mealLine(meal)
                if position < sortedMeals.count - 1 {
                    DashedDivider()
                }
            }
        }
    }

    private func mealLine(_ meal: PlannedMeal) -> some View {
        let fromBox = meal.recipeId != nil
        return HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
            MealStamp(mealType: meal.mealType)
                .frame(width: 54, alignment: .leading)

            Text(meal.displayName)
                .font(fromBox ? .plate(17, .semibold) : .setting(15).italic())
                .foregroundColor(fromBox ? Theme.ink : Theme.ink2)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                onDelete(meal)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.ink3)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Take \(meal.displayName) off the menu")
        }
        .padding(.vertical, 7)
    }
}

// MARK: - Add a meal

/// Writing one meal into the menu: which day, which meal, and either a
/// recipe from the box or a few words of your own.
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

    private var trimmedCustomName: String {
        customMealName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        if useExistingRecipe {
            return selectedRecipe != nil
        } else {
            return !trimmedCustomName.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingXL) {
                    PlateHeader(
                        title: "Add a meal",
                        subtitle: "\(startDate.printed) – \(endDate.printed)"
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        SectionHead(title: "The day")
                            .padding(.bottom, Theme.spacingXS)
                        JournalDateLine(label: "On", date: $selectedDate, from: startDate, through: endDate)
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        SectionHead(title: "The meal")
                        IndexSelector(
                            options: MealType.allCases.map { (value: $0, label: $0.displayName) },
                            selection: $selectedMealType
                        )
                    }

                    recipeSection

                    Button("Add to the menu") {
                        addMeal()
                    }
                    .buttonStyle(.press)
                    .disabled(!canAdd)
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
                    MarginButton("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MarginButton("Add") { addMeal() }
                        .disabled(!canAdd)
                        .opacity(canAdd ? 1 : 0.35)
                }
            }
        }
    }

    // MARK: - What's cooked

    private var recipeSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            SectionHead(title: "What's cooked")

            IndexSelector(
                options: [(value: true, label: "A recipe"), (value: false, label: "In your own words")],
                selection: $useExistingRecipe
            )

            if useExistingRecipe {
                SearchLine(placeholder: "Find a recipe", text: $searchText)

                if filteredRecipes.isEmpty {
                    Text(allRecipes.isEmpty
                         ? "There are no recipes in the box yet."
                         : "Nothing in the box by that name.")
                        .font(.setting(13).italic())
                        .foregroundColor(Theme.ink3)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredRecipes.enumerated()), id: \.offset) { position, recipe in
                            RecipeSelectionRow(
                                recipe: recipe,
                                isSelected: selectedRecipe?.id == recipe.id
                            ) {
                                selectedRecipe = recipe
                            }
                            if position < filteredRecipes.count - 1 {
                                DashedDivider()
                            }
                        }
                    }
                    .plate()
                }
            } else {
                FieldLine(
                    label: "The meal",
                    text: $customMealName,
                    prompt: "Leftovers, takeout, dinner out"
                )
            }
        }
    }

    private func addMeal() {
        guard canAdd else { return }
        // Only the side that's showing counts — a recipe picked and then
        // abandoned for your own words mustn't ride along with them.
        let recipe = useExistingRecipe ? selectedRecipe : nil
        let meal = PlannedMeal(
            date: selectedDate,
            mealType: selectedMealType,
            recipeId: recipe?.id,
            customMealName: useExistingRecipe ? nil : trimmedCustomName,
            notes: nil,
            recipeTitle: recipe?.title ?? trimmedCustomName,
            recipeImageURL: recipe?.firstImageURL
        )
        onAdd(meal)
        dismiss()
    }
}

// MARK: - Choosing a recipe

/// One recipe in the picker, set as an index line: a box to tick, the name
/// in the serif, a dot leader, and its time.
struct RecipeSelectionRow: View {
    let recipe: Recipe
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
                TickBox(ticked: isSelected, size: 15)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }

                Text(recipe.title)
                    .font(.plate(17, .semibold))
                    .foregroundColor(isSelected ? Theme.ink : Theme.ink2)
                    .lineLimit(1)
                    .layoutPriority(1)

                if let time = recipe.totalTimeMinutes {
                    DotLeader()
                    Text(time.printedMinutes)
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
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - A date with bounds

/// A date set as an index line — label, dot leader, the date — that opens a
/// calendar beneath it, held between whatever bounds the menu sets.
private struct JournalDateLine: View {
    let label: String
    @Binding var date: Date
    var from: Date = .distantPast
    var through: Date = .distantFuture

    @State private var open = false

    /// Whole days, and never a backwards range — a ClosedRange with its
    /// ends crossed traps. The lower end is the start of its day: the
    /// calendar hands back midnight, which a bound at "now" would refuse,
    /// and today could never be picked.
    private var bounds: ClosedRange<Date> {
        let calendar = Calendar.current
        let lower = from == .distantPast ? from : calendar.startOfDay(for: from)
        let upper = through == .distantFuture ? through
            : (calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: through)) ?? through)
        return lower...max(lower, upper)
    }

    /// Every pick set at the start of its day.
    private var day: Binding<Date> {
        Binding(
            get: { date },
            set: { date = Calendar.current.startOfDay(for: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { open.toggle() }
            } label: {
                IndexEntry(
                    title: label,
                    figure: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                    figureColor: open ? Theme.accent : Theme.ink
                )
            }
            .buttonStyle(.plain)

            if open {
                DatePicker("", selection: day, in: bounds, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Theme.accent)
                    .padding(.bottom, Theme.spacingSM)
            }
        }
    }
}

#Preview {
    ManualMealPlanCreatorView()
}
