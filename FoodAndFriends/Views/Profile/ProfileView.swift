import SwiftUI

struct ProfileView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var userService = UserService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FAFSpacing.xl) {
                    // Profile Header
                    VStack(spacing: FAFSpacing.md) {
                        // Avatar
                        Circle()
                            .fill(Color.fafGrayXLight)
                            .frame(width: 100, height: 100)
                            .overlay(
                                FAFIcon(.profile, size: 40, color: .fafGray)
                            )

                        if let user = userService.currentUser {
                            Text("@\(user.username)")
                                .font(FAFTypography.h2)
                                .foregroundColor(.fafBlack)

                            HStack(spacing: FAFSpacing.xs) {
                                FAFIcon(.location, size: 14, color: .fafGray)
                                Text(user.location)
                                    .font(FAFTypography.body)
                                    .foregroundColor(.fafGray)
                            }
                        }
                    }
                    .padding(.top, FAFSpacing.xl)

                    // Stats Row
                    HStack(spacing: FAFSpacing.xl) {
                        StatItem(value: "0", label: "Meals")
                        StatItem(value: "0", label: "Friends")
                        StatItem(value: "0", label: "Places")
                    }
                    .padding(.vertical, FAFSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.md)

                    // Menu Items
                    VStack(spacing: 0) {
                        ProfileMenuItem(icon: .settings, title: "Settings")
                        ProfileMenuItem(icon: .bell, title: "Notifications")
                        ProfileMenuItem(icon: .heart, title: "Favorites")
                    }
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.md)

                    Spacer(minLength: FAFSpacing.xl)

                    // Sign Out
                    FAFButton(title: "Sign Out", style: .secondary) {
                        do {
                            try authManager.signOut()
                        } catch {
                            print("Sign out error: \(error)")
                        }
                    }
                }
                .padding(FAFSpacing.lg)
            }
            .background(Color.fafWhite)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: FAFSpacing.xxs) {
            Text(value)
                .font(FAFTypography.h2)
                .foregroundColor(.fafBlack)
            Text(label)
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Menu Item

struct ProfileMenuItem: View {
    let icon: FAFIconType
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: FAFSpacing.md) {
                FAFIcon(icon, size: 20, color: .fafBlack)
                Text(title)
                    .font(FAFTypography.body)
                    .foregroundColor(.fafBlack)
                Spacer()
                FAFIcon(.forward, size: 14, color: .fafGray)
            }
            .padding(FAFSpacing.md)
        }
    }
}

#Preview {
    ProfileView()
}
