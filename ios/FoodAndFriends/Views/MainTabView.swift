import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab {
        case home
        case recipes
        case mealPlans
        case feed
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == .home ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(Tab.home)

            RecipesView()
                .tabItem {
                    Image(systemName: "fork.knife")
                    Text("Recipes")
                }
                .tag(Tab.recipes)

            MealPlansView()
                .tabItem {
                    Image(systemName: selectedTab == .mealPlans ? "calendar.circle.fill" : "calendar")
                    Text("Meal Plans")
                }
                .tag(Tab.mealPlans)

            FeedView()
                .tabItem {
                    Image(systemName: selectedTab == .feed ? "person.2.fill" : "person.2")
                    Text("Feed")
                }
                .tag(Tab.feed)

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == .profile ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
        .tint(.fafCoral)
    }
}

#Preview {
    MainTabView()
}
