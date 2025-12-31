import SwiftUI

struct MealPlansView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared

    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fafBackground
                    .ignoresSafeArea()

                Group {
                    if !hasLoaded || mealPlanService.isLoading {
                        MealPlansLoadingView()
                    } else if mealPlanService.userMealPlans.isEmpty {
                        EmptyMealPlansView()
                    } else {
                        MealPlansList(mealPlans: mealPlanService.userMealPlans)
                    }
                }
            }
            .navigationTitle("Meal Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Navigate to create meal plan
                    } label: {
                        FAFIcon(.plus, size: 20, color: .fafCoral)
                    }
                }
            }
            .task {
                if !hasLoaded {
                    await loadMealPlans()
                    hasLoaded = true
                }
            }
            .refreshable {
                await loadMealPlans()
            }
        }
    }

    private func loadMealPlans() async {
        guard let userId = userService.currentUser?.id else { return }
        await mealPlanService.fetchUserMealPlans(userId: userId)
    }
}

// MARK: - Meal Plans List

struct MealPlansList: View {
    let mealPlans: [MealPlan]

    private var activePlans: [MealPlan] {
        let today = Date()
        return mealPlans.filter { $0.startDate <= today && $0.endDate >= today }
    }

    private var upcomingPlans: [MealPlan] {
        let today = Date()
        return mealPlans.filter { $0.startDate > today }
    }

    private var pastPlans: [MealPlan] {
        let today = Date()
        return mealPlans.filter { $0.endDate < today }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FAFSpacing.xl) {
                // Active Plans
                if !activePlans.isEmpty {
                    MealPlanSection(title: "Active", plans: activePlans, isActive: true)
                }

                // Upcoming Plans
                if !upcomingPlans.isEmpty {
                    MealPlanSection(title: "Upcoming", plans: upcomingPlans, isActive: false)
                }

                // Past Plans
                if !pastPlans.isEmpty {
                    MealPlanSection(title: "Past", plans: pastPlans, isActive: false)
                }
            }
            .padding(.vertical, FAFSpacing.md)
        }
    }
}

struct MealPlanSection: View {
    let title: String
    let plans: [MealPlan]
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text(title)
                .font(FAFTypography.h3)
                .foregroundColor(.fafTextPrimary)
                .padding(.horizontal, FAFSpacing.lg)

            ForEach(plans) { plan in
                MealPlanRowCard(mealPlan: plan, isActive: isActive)
            }
        }
    }
}

struct MealPlanRowCard: View {
    let mealPlan: MealPlan
    let isActive: Bool

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: mealPlan.startDate)
        let end = formatter.string(from: mealPlan.endDate)
        return "\(start) - \(end)"
    }

    var body: some View {
        HStack(spacing: FAFSpacing.md) {
            // Calendar icon with active indicator
            ZStack {
                RoundedRectangle(cornerRadius: FAFRadius.sm)
                    .fill(isActive ? Color.fafCoral.opacity(0.1) : Color.fafGrayXLight)
                    .frame(width: 60, height: 60)

                FAFIcon(.calendar, size: 24, color: isActive ? .fafCoral : .fafGray)
            }

            VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                HStack {
                    Text(mealPlan.name)
                        .font(FAFTypography.bodyBold)
                        .foregroundColor(.fafTextPrimary)

                    if isActive {
                        Text("Active")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafWhite)
                            .padding(.horizontal, FAFSpacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.fafCoral)
                            .cornerRadius(4)
                    }
                }

                Text(dateRangeText)
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)

                HStack(spacing: FAFSpacing.md) {
                    Label("\(mealPlan.numberOfDays) days", systemImage: "calendar")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)

                    Label("\(mealPlan.totalMeals) meals", systemImage: "fork.knife")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                }
            }

            Spacer()

            FAFIcon(.forward, size: 16, color: .fafGray)
        }
        .padding(FAFSpacing.md)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.md)
        .padding(.horizontal, FAFSpacing.lg)
    }
}

// MARK: - Empty State

struct EmptyMealPlansView: View {
    var body: some View {
        VStack(spacing: FAFSpacing.lg) {
            Spacer()

            VStack(spacing: FAFSpacing.md) {
                Image(systemName: "calendar")
                    .font(.system(size: 64))
                    .foregroundColor(.fafGrayLight)

                Text("No Meal Plans Yet")
                    .font(FAFTypography.h2)
                    .foregroundColor(.fafTextPrimary)

                Text("Plan your meals for the week\nand never wonder what's for dinner")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .multilineTextAlignment(.center)
            }

            Button {
                // TODO: Navigate to create meal plan
            } label: {
                HStack(spacing: FAFSpacing.sm) {
                    FAFIcon(.plus, size: 16, color: .fafWhite)
                    Text("Create Meal Plan")
                        .font(FAFTypography.button)
                }
                .foregroundColor(.fafWhite)
                .padding(.horizontal, FAFSpacing.xl)
                .padding(.vertical, FAFSpacing.md)
                .background(Color.fafSage)
                .cornerRadius(FAFRadius.md)
            }

            Spacer()
        }
        .padding(FAFSpacing.lg)
    }
}

// MARK: - Loading State

struct MealPlansLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: FAFSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: FAFSpacing.md) {
                        RoundedRectangle(cornerRadius: FAFRadius.sm)
                            .fill(Color.fafGrayXLight)
                            .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.fafGrayXLight)
                                .frame(height: 16)
                                .frame(maxWidth: 150)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.fafGrayXXLight)
                                .frame(height: 12)
                                .frame(maxWidth: 100)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.fafGrayXXLight)
                                .frame(height: 12)
                                .frame(maxWidth: 120)
                        }

                        Spacer()
                    }
                    .padding(FAFSpacing.md)
                    .background(Color.fafCardBackground)
                    .cornerRadius(FAFRadius.md)
                    .padding(.horizontal, FAFSpacing.lg)
                }
            }
            .padding(.vertical, FAFSpacing.md)
        }
        .redacted(reason: .placeholder)
    }
}

#Preview {
    MealPlansView()
}
