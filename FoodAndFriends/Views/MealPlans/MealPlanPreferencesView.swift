import SwiftUI

struct MealPlanPreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var preferences: MealPlanPreferences

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: FAFSpacing.lg) {
                    // Dietary Restrictions
                    dietaryRestrictionsSection

                    // Cuisine Preferences
                    cuisineSection

                    // Allergens
                    allergensSection

                    // Calorie Goal
                    calorieGoalSection

                    // Skill Level
                    skillLevelSection

                    // Meal Types
                    mealTypesSection

                    // Quick Meals
                    quickMealsSection
                }
                .padding(FAFSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fafBackground.ignoresSafeArea())
            .navigationTitle("Meal Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.fafGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .foregroundColor(.fafSage)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Dietary Restrictions Section

    private var dietaryRestrictionsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionLabel(title: "Dietary Restrictions", subtitle: "Select any that apply")

            FlowLayout(spacing: FAFSpacing.sm) {
                ForEach(DietaryRestriction.allCases) { restriction in
                    ToggleChip(
                        title: restriction.displayName,
                        isSelected: preferences.dietaryRestrictions.contains(restriction)
                    ) {
                        if preferences.dietaryRestrictions.contains(restriction) {
                            preferences.dietaryRestrictions.removeAll { $0 == restriction }
                        } else {
                            preferences.dietaryRestrictions.append(restriction)
                        }
                    }
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Cuisine Section

    private var cuisineSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionLabel(title: "Cuisine Preferences", subtitle: "Select your favorite cuisines")

            FlowLayout(spacing: FAFSpacing.sm) {
                ForEach(CuisineType.allCases) { cuisine in
                    ToggleChip(
                        title: cuisine.rawValue,
                        isSelected: preferences.cuisinePreferences.contains(cuisine.rawValue)
                    ) {
                        if preferences.cuisinePreferences.contains(cuisine.rawValue) {
                            preferences.cuisinePreferences.removeAll { $0 == cuisine.rawValue }
                        } else {
                            preferences.cuisinePreferences.append(cuisine.rawValue)
                        }
                    }
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Allergens Section

    private var allergensSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionLabel(title: "Allergens", subtitle: "Select allergens to avoid")

            FlowLayout(spacing: FAFSpacing.sm) {
                ForEach(CommonAllergen.allCases) { allergen in
                    ToggleChip(
                        title: allergen.rawValue,
                        isSelected: preferences.allergens.contains(allergen.rawValue),
                        selectedColor: .fafCoral
                    ) {
                        if preferences.allergens.contains(allergen.rawValue) {
                            preferences.allergens.removeAll { $0 == allergen.rawValue }
                        } else {
                            preferences.allergens.append(allergen.rawValue)
                        }
                    }
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Calorie Goal Section

    private var calorieGoalSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionLabel(title: "Calorie Goal", subtitle: "Optional - portion guidance")

            HStack(spacing: FAFSpacing.sm) {
                ForEach(CalorieGoal.allCases) { goal in
                    CalorieGoalButton(
                        goal: goal,
                        isSelected: preferences.calorieGoal == goal
                    ) {
                        if preferences.calorieGoal == goal {
                            preferences.calorieGoal = nil
                        } else {
                            preferences.calorieGoal = goal
                        }
                    }
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Skill Level Section

    private var skillLevelSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionLabel(title: "Cooking Skill Level", subtitle: "Affects recipe complexity")

            HStack(spacing: FAFSpacing.sm) {
                ForEach(SkillLevel.allCases) { level in
                    SkillLevelButton(
                        level: level,
                        isSelected: preferences.cookingSkillLevel == level
                    ) {
                        preferences.cookingSkillLevel = level
                    }
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Meal Types Section

    private var mealTypesSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionLabel(title: "Meals to Plan", subtitle: "Which meals should we include?")

            HStack(spacing: FAFSpacing.sm) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    ToggleChip(
                        title: mealType.displayName,
                        isSelected: preferences.mealTypes.contains(mealType)
                    ) {
                        if preferences.mealTypes.contains(mealType) {
                            preferences.mealTypes.removeAll { $0 == mealType }
                        } else {
                            preferences.mealTypes.append(mealType)
                        }
                    }
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Quick Meals Section

    private var quickMealsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                Text("Prefer Quick Meals")
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafTextPrimary)
                Text("Prioritize recipes under 30 minutes")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
            Spacer()
            Toggle("", isOn: $preferences.quickMealsPreferred)
                .tint(.fafSage)
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
            Text(title)
                .font(FAFTypography.bodyBold)
                .foregroundColor(.fafTextPrimary)
            Text(subtitle)
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
        }
    }
}

// MARK: - Toggle Chip

struct ToggleChip: View {
    let title: String
    let isSelected: Bool
    var selectedColor: Color = .fafSage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FAFTypography.caption)
                .foregroundColor(isSelected ? .white : .fafTextPrimary)
                .padding(.horizontal, FAFSpacing.md)
                .padding(.vertical, FAFSpacing.sm)
                .background(isSelected ? selectedColor : Color.fafBackgroundSecondary)
                .cornerRadius(FAFRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.full)
                        .stroke(isSelected ? selectedColor : Color.fafDivider, lineWidth: 1)
                )
        }
    }
}

// MARK: - Calorie Goal Button

struct CalorieGoalButton: View {
    let goal: CalorieGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FAFSpacing.xs) {
                Text(goal.displayName)
                    .font(FAFTypography.label)
                    .foregroundColor(isSelected ? .fafSage : .fafTextPrimary)

                Text(goal.description)
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(FAFSpacing.md)
            .background(isSelected ? Color.fafSage.opacity(0.1) : Color.fafBackgroundSecondary)
            .cornerRadius(FAFRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FAFRadius.md)
                    .stroke(isSelected ? Color.fafSage : Color.fafDivider, lineWidth: 1)
            )
        }
    }
}

// MARK: - Skill Level Button

struct SkillLevelButton: View {
    let level: SkillLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FAFSpacing.xs) {
                Text(level.displayName)
                    .font(FAFTypography.label)
                    .foregroundColor(isSelected ? .fafSage : .fafTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(FAFSpacing.md)
            .background(isSelected ? Color.fafSage.opacity(0.1) : Color.fafBackgroundSecondary)
            .cornerRadius(FAFRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FAFRadius.md)
                    .stroke(isSelected ? Color.fafSage : Color.fafDivider, lineWidth: 1)
            )
        }
    }
}

#Preview {
    MealPlanPreferencesView(preferences: .constant(.default))
}
