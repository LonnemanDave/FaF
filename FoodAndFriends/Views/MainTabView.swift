import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab {
        case home
        case friends
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

            FriendsView()
                .tabItem {
                    Image(systemName: selectedTab == .friends ? "person.2.fill" : "person.2")
                    Text("Friends")
                }
                .tag(Tab.friends)

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
