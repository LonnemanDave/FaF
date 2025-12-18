import SwiftUI

struct HomeView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var userService = UserService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: FAFSpacing.lg) {
                Spacer()

                // Welcome message
                VStack(spacing: FAFSpacing.sm) {
                    FAFIcon(.fork, size: 64, color: .fafCoral)

                    if let user = userService.currentUser {
                        Text("Welcome, @\(user.username)!")
                            .font(FAFTypography.h1)
                            .foregroundColor(.fafBlack)

                        Text(user.location)
                            .font(FAFTypography.body)
                            .foregroundColor(.fafGray)
                    } else {
                        Text("Welcome!")
                            .font(FAFTypography.h1)
                            .foregroundColor(.fafBlack)
                    }
                }

                Spacer()

                Text("Your food adventures start here")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)

                Spacer()

                // Sign out button
                FAFButton(title: "Sign Out", style: .secondary) {
                    do {
                        try authManager.signOut()
                    } catch {
                        print("Sign out error: \(error)")
                    }
                }
            }
            .padding(FAFSpacing.lg)
            .background(Color.fafWhite)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HomeView()
}
