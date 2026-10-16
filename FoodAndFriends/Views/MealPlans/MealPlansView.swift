import SwiftUI

/// Menus — the weeks planned out. The one on now, the ones coming up, and
/// the past ones filed underneath, each set as an index line with its dates
/// carried across.
struct MealPlansView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared
    @ObservedObject var aiService = AIService.shared

    @State private var hasLoaded = false
    @State private var showAIMealPlanGenerator = false
    @State private var showManualMealPlanCreator = false

    private enum Season: String, CaseIterable {
        case now = "On now"
        case coming = "Coming up"
        case past = "Past"
    }

    /// Compared by day, so a menu's last day still counts as on.
    private func season(of plan: MealPlan) -> Season {
        let calendar = Calendar.current
        let now = Date()
        if calendar.compare(now, to: plan.startDate, toGranularity: .day) == .orderedAscending { return .coming }
        if calendar.compare(now, to: plan.endDate, toGranularity: .day) == .orderedDescending { return .past }
        return .now
    }

    private var seasons: [(season: Season, plans: [MealPlan])] {
        Season.allCases.compactMap { season in
            let plans = mealPlanService.userMealPlans
                .filter { self.season(of: $0) == season }
                .sorted { season == .past ? $0.startDate > $1.startDate : $0.startDate < $1.startDate }
            return plans.isEmpty ? nil : (season, plans)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    plate

                    if !hasLoaded && mealPlanService.userMealPlans.isEmpty {
                        ProgressView()
                            .tint(Theme.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacingXL)
                    } else if mealPlanService.userMealPlans.isEmpty {
                        BlankLeaf(
                            note: "No menus planned yet. Plan a week and its dinners turn up on Home each day.",
                            action: (label: "Plan a menu", run: { showManualMealPlanCreator = true })
                        )
                    } else {
                        ForEach(seasons, id: \.season) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                SectionHead(title: group.season.rawValue, figure: "\(group.plans.count)")
                                    .padding(.bottom, 2)
                                ForEach(Array(group.plans.enumerated()), id: \.element.id) { position, plan in
                                    NavigationLink(value: plan) {
                                        IndexEntry(
                                            title: plan.name,
                                            subtitle: summary(of: plan),
                                            figure: plan.printedDates,
                                            figureColor: group.season == .now ? Theme.accent : Theme.ink2,
                                            dimmed: group.season == .past,
                                            serifTitle: true
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if position < group.plans.count - 1 {
                                        DashedDivider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MealPlan.self) { plan in
                MealPlanDetailView(mealPlan: plan)
            }
            .sheet(isPresented: $showAIMealPlanGenerator) {
                AIMealPlanGeneratorView()
            }
            .sheet(isPresented: $showManualMealPlanCreator) {
                ManualMealPlanCreatorView()
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

    // MARK: - Plate

    private var plusMark: some View {
        Image(systemName: "plus")
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(Theme.ink)
            .frame(width: 36, height: 36, alignment: .trailing)
            .contentShape(Rectangle())
    }

    private var plate: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 12)

            HStack(alignment: .firstTextBaseline) {
                Text("Menus")
                    .font(.plate(32))
                    .foregroundColor(Theme.ink)

                Spacer(minLength: Theme.spacingSM)

                // With the assistant, + offers a choice; without it, + just opens the form.
                if aiService.hasValidAPIKey {
                    Menu {
                        Button {
                            showManualMealPlanCreator = true
                        } label: {
                            Label("Plan a menu", systemImage: "square.and.pencil")
                        }
                        Button {
                            showAIMealPlanGenerator = true
                        } label: {
                            Label("Ask for a menu", systemImage: "sparkles")
                        }
                    } label: {
                        plusMark
                    }
                    .accessibilityLabel("Plan a menu")
                } else {
                    Button {
                        showManualMealPlanCreator = true
                    } label: {
                        plusMark
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Plan a menu")
                }
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

    private var edition: String {
        let count = mealPlanService.userMealPlans.count
        switch count {
        case 0: return "The week, planned · none yet"
        case 1: return "The week, planned · 1 menu"
        default: return "The week, planned · \(count) menus"
        }
    }

    // MARK: - Lines

    /// "6 days · 8 meals · Stew tonight, leftovers tomorrow."
    private func summary(of plan: MealPlan) -> String {
        var parts = [
            "\(plan.numberOfDays) \(plan.numberOfDays == 1 ? "day" : "days")",
            "\(plan.totalMeals) \(plan.totalMeals == 1 ? "meal" : "meals")",
        ]
        if let description = plan.description, !description.isEmpty { parts.append(description) }
        return parts.joined(separator: " · ")
    }

    private func loadMealPlans() async {
        guard let userId = userService.currentUser?.id else { return }
        await mealPlanService.fetchUserMealPlans(userId: userId)
    }
}

extension MealPlan {
    /// "Oct 14–20", or "Sep 28 – Oct 4" when it runs across a month.
    var printedDates: String {
        let calendar = Calendar.current
        let start = startDate.formatted(.dateTime.month(.abbreviated).day())
        if calendar.isDate(startDate, equalTo: endDate, toGranularity: .month) {
            return "\(start)–\(calendar.component(.day, from: endDate))"
        }
        return "\(start) – \(endDate.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

#Preview {
    MealPlansView()
}
