import SwiftUI

/// The house rules for a menu — what the kitchen keeps to, what it keeps
/// out, which meals to plan. Set as a printed checklist: tick what applies.
///
/// Changes are pencilled on a draft and only written back on Save, so
/// Cancel really does leave the preferences as they were.
struct MealPlanPreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var preferences: MealPlanPreferences

    @State private var draft: MealPlanPreferences

    init(preferences: Binding<MealPlanPreferences>) {
        _preferences = preferences
        _draft = State(initialValue: preferences.wrappedValue)
    }

    private let twoColumns = [
        GridItem(.flexible(), spacing: Theme.spacingMD, alignment: .leading),
        GridItem(.flexible(), spacing: Theme.spacingMD, alignment: .leading)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingXL) {
                    PlateHeader(title: "Preferences", subtitle: "What the menu keeps to")

                    // Meal Types
                    mealTypesSection

                    // Dietary Restrictions
                    dietaryRestrictionsSection

                    // Allergens
                    allergensSection

                    // Cuisine Preferences
                    cuisineSection

                    // Calorie Goal
                    calorieGoalSection

                    // Skill Level
                    skillLevelSection

                    // Quick Meals
                    quickMealsSection
                }
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MarginButton("Save") {
                        preferences = draft
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Meal Types Section

    private var mealTypesSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Meals to plan", figure: "\(draft.mealTypes.count) of \(MealType.allCases.count)")

            LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 0) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    ChecklistLine(
                        title: mealType.displayName,
                        ticked: draft.mealTypes.contains(mealType)
                    ) {
                        if draft.mealTypes.contains(mealType) {
                            draft.mealTypes.removeAll { $0 == mealType }
                        } else {
                            draft.mealTypes.append(mealType)
                        }
                    }
                }
            }

            if draft.mealTypes.isEmpty {
                Text("Tick at least one — a menu needs something to plan.")
                    .font(.setting(12).italic())
                    .foregroundColor(Theme.error)
            }
        }
    }

    // MARK: - Dietary Restrictions Section

    private var dietaryRestrictionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Diet", figure: tally(draft.dietaryRestrictions.count))

            LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 0) {
                ForEach(DietaryRestriction.allCases) { restriction in
                    ChecklistLine(
                        title: restriction.displayName,
                        ticked: draft.dietaryRestrictions.contains(restriction)
                    ) {
                        if draft.dietaryRestrictions.contains(restriction) {
                            draft.dietaryRestrictions.removeAll { $0 == restriction }
                        } else {
                            draft.dietaryRestrictions.append(restriction)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Allergens Section

    private var allergensSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Keep out", figure: tally(draft.allergens.count))

            LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 0) {
                ForEach(CommonAllergen.allCases) { allergen in
                    ChecklistLine(
                        title: allergen.rawValue,
                        ticked: draft.allergens.contains(allergen.rawValue),
                        tickedInk: Theme.error
                    ) {
                        if draft.allergens.contains(allergen.rawValue) {
                            draft.allergens.removeAll { $0 == allergen.rawValue }
                        } else {
                            draft.allergens.append(allergen.rawValue)
                        }
                    }
                }
            }

            Text("Anything ticked stays out of every dish.")
                .font(.setting(12).italic())
                .foregroundColor(Theme.ink3)
        }
    }

    // MARK: - Cuisine Section

    private var cuisineSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Cuisines", figure: tally(draft.cuisinePreferences.count))

            LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 0) {
                ForEach(CuisineType.allCases) { cuisine in
                    ChecklistLine(
                        title: cuisine.rawValue,
                        ticked: draft.cuisinePreferences.contains(cuisine.rawValue)
                    ) {
                        if draft.cuisinePreferences.contains(cuisine.rawValue) {
                            draft.cuisinePreferences.removeAll { $0 == cuisine.rawValue }
                        } else {
                            draft.cuisinePreferences.append(cuisine.rawValue)
                        }
                    }
                }
            }

            Text("None ticked, and Claude cooks from anywhere.")
                .font(.setting(12).italic())
                .foregroundColor(Theme.ink3)
        }
    }

    // MARK: - Calorie Goal Section

    private var calorieGoalSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Portions", figure: "Optional")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(CalorieGoal.allCases) { goal in
                    ChecklistLine(
                        title: goal.displayName,
                        note: goal.description,
                        ticked: draft.calorieGoal == goal
                    ) {
                        if draft.calorieGoal == goal {
                            draft.calorieGoal = nil
                        } else {
                            draft.calorieGoal = goal
                        }
                    }
                }
            }
        }
    }

    // MARK: - Skill Level Section

    private var skillLevelSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "How you cook")

            IndexSelector(
                options: SkillLevel.allCases.map { (value: $0, label: $0.displayName) },
                selection: $draft.cookingSkillLevel
            )

            Text(draft.cookingSkillLevel.description)
                .font(.setting(12).italic())
                .foregroundColor(Theme.ink3)
        }
    }

    // MARK: - Quick Meals Section

    private var quickMealsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Time")

            ChecklistLine(
                title: "Keep it quick",
                note: "Mostly dishes under 30 minutes",
                ticked: draft.quickMealsPreferred
            ) {
                draft.quickMealsPreferred.toggle()
            }
        }
    }

    // MARK: - Helpers

    private func tally(_ count: Int) -> String? {
        count == 0 ? nil : "\(count) ticked"
    }
}

// MARK: - Checklist line

/// One line of a printed checklist: a ruled box, the item beside it, an
/// optional note set small underneath. Tap anywhere on the line to tick it.
private struct ChecklistLine: View {
    let title: String
    var note: String?
    let ticked: Bool
    /// The ink a ticked item is set in — ink for a preference, the error
    /// ink for something kept out.
    var tickedInk: Color = Theme.ink
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) { action() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM + 2) {
                TickBox(ticked: ticked, size: 16)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 3 }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.setting(15, ticked ? .medium : .regular))
                        .foregroundColor(ticked ? tickedInk : Theme.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if let note {
                        Text(note)
                            .font(.setting(12).italic())
                            .foregroundColor(Theme.ink3)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(ticked ? .isSelected : [])
    }
}

#Preview {
    MealPlanPreferencesView(preferences: .constant(.default))
}
