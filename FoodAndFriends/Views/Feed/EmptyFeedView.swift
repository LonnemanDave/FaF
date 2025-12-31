import SwiftUI

struct EmptyFeedView: View {
    let hasFriends: Bool
    var onAddFriends: (() -> Void)?
    var onCreateRecipe: (() -> Void)?

    var body: some View {
        VStack(spacing: FAFSpacing.md) {
            Spacer(minLength: 60)

            // Icon
            Circle()
                .fill(Color.fafCoralLight)
                .frame(width: 80, height: 80)
                .overlay(
                    FAFIcon(hasFriends ? .fork : .friends, size: 36, color: .fafCoral)
                )

            // Title
            Text(emptyTitle)
                .font(FAFTypography.h2)
                .foregroundColor(.fafBlack)
                .multilineTextAlignment(.center)

            // Message
            Text(emptyMessage)
                .font(FAFTypography.body)
                .foregroundColor(.fafGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FAFSpacing.xl)

            // Action Button
            FAFButton(
                title: hasFriends ? "Share Your First Recipe" : "Find Friends",
                style: .accent
            ) {
                if hasFriends {
                    onCreateRecipe?()
                } else {
                    onAddFriends?()
                }
            }
            .padding(.top, FAFSpacing.md)
            .padding(.horizontal, FAFSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyTitle: String {
        hasFriends ? "No activity yet" : "Add some friends!"
    }

    private var emptyMessage: String {
        hasFriends
            ? "Start sharing your favorite recipes\nand meal plans with friends!"
            : "Connect with friends to see what\nthey're cooking and planning."
    }
}

#Preview("No Friends") {
    EmptyFeedView(hasFriends: false)
        .background(Color.fafBackground)
}

#Preview("Has Friends") {
    EmptyFeedView(hasFriends: true)
        .background(Color.fafBackground)
}
