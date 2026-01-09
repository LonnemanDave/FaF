import SwiftUI

struct FeedView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var feedService = FeedService.shared
    @ObservedObject var friendService = FriendService.shared

    @State private var showFriends = false
    @State private var selectedRecipe: Recipe?
    @State private var selectedMealPlan: MealPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FAFSpacing.lg) {
                    if feedService.isLoading {
                        FeedLoadingView()
                            .padding(.horizontal, FAFSpacing.lg)
                    } else if feedService.feedActivities.isEmpty {
                        EmptyFeedView(
                            hasFriends: !friendService.friends.isEmpty,
                            onAddFriends: {
                                showFriends = true
                            },
                            onCreateRecipe: {
                                // TODO: Navigate to create recipe
                            }
                        )
                    } else {
                        LazyVStack(spacing: FAFSpacing.md) {
                            ForEach(feedService.feedActivities) { activity in
                                ActivityCard(
                                    activity: activity,
                                    onSelectRecipe: { selectedRecipe = $0 },
                                    onSelectMealPlan: { selectedMealPlan = $0 }
                                )
                            }
                        }
                        .padding(.horizontal, FAFSpacing.lg)
                    }
                }
                .padding(.vertical, FAFSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fafBackground.ignoresSafeArea())
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .navigationDestination(item: $selectedMealPlan) { mealPlan in
                // TODO: MealPlanDetailView when implemented
                Text("Meal Plan: \(mealPlan.name)")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFriends = true
                    } label: {
                        ZStack {
                            FAFIcon(.friends, size: 20, color: .fafCoral)

                            // Badge for pending requests
                            if !friendService.pendingRequests.isEmpty {
                                Circle()
                                    .fill(Color.fafCoral)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showFriends) {
                NavigationStack {
                    FriendsView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    showFriends = false
                                }
                                .foregroundColor(.fafCoral)
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    FeedView()
}
