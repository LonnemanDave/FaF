import SwiftUI

struct HomeView: View {
    @ObservedObject var userService = UserService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FAFSpacing.lg) {
                    // Empty State
                    VStack(spacing: FAFSpacing.md) {
                        Spacer(minLength: 100)

                        FAFIcon(.fork, size: 64, color: .fafCoral)

                        Text("No meals yet")
                            .font(FAFTypography.h2)
                            .foregroundColor(.fafBlack)

                        Text("Start sharing your food adventures\nwith friends!")
                            .font(FAFTypography.body)
                            .foregroundColor(.fafGray)
                            .multilineTextAlignment(.center)

                        FAFButton(title: "Add Your First Meal", style: .accent, icon: .plus) {
                            // TODO: Add meal action
                        }
                        .padding(.top, FAFSpacing.md)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(FAFSpacing.lg)
            }
            .background(Color.fafWhite)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var greeting: String {
        if let user = userService.currentUser {
            return "Hi, \(user.username)"
        }
        return "Home"
    }
}

#Preview {
    HomeView()
}
