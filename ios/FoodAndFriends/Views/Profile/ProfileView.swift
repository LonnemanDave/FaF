import OSLog
import SwiftUI

struct ProfileView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var userService = UserService.shared

    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero Header
                    headerSection

                    // Content
                    VStack(spacing: FAFSpacing.lg) {
                        // Stats Cards
                        statsSection

                        // Quick Actions
                        quickActionsSection

                        // Menu
                        menuSection

                        // Sign Out
                        signOutSection
                    }
                    .padding(.horizontal, FAFSpacing.lg)
                    .padding(.top, FAFSpacing.lg)
                    .padding(.bottom, FAFSpacing.xxxl)
                }
            }
            .background(Color.fafWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(FAFTypography.h3)
                        .foregroundColor(.fafBlack)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Settings action
                    } label: {
                        FAFIcon(.settings, size: 22, color: .fafBlack)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 0) {
            // Banner background
            ZStack(alignment: .bottom) {
                ProfileHeaderBackground()
                    .frame(height: 160)

                // Profile image overlapping the banner
                ZStack {
                    // White border ring
                    Circle()
                        .fill(Color.fafWhite)
                        .frame(width: 148, height: 148)

                    ProfileImagePicker(
                        selectedImage: $selectedImage,
                        currentImageURL: userService.currentUser?.profileImageURL,
                        size: 140
                    )

                    if isUploading {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 140, height: 140)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
                .offset(y: 74)
                .onChange(of: selectedImage) { _, newImage in
                    if let image = newImage {
                        Task { await uploadProfileImage(image) }
                    }
                }
            }

            // User Info - on white background
            if let user = userService.currentUser {
                VStack(spacing: FAFSpacing.xs) {
                    // Display Name or Username as primary
                    Text(user.displayName ?? user.username)
                        .font(FAFTypography.h1)
                        .foregroundColor(.fafBlack)

                    // Username (if display name exists)
                    if user.displayName != nil {
                        Text("@\(user.username)")
                            .font(FAFTypography.body)
                            .foregroundColor(.fafGray)
                    }

                    // Location
                    HStack(spacing: FAFSpacing.xxxs) {
                        FAFIcon(.location, size: 14, color: .fafGrayLight)
                        Text(user.location)
                            .font(FAFTypography.bodySmall)
                            .foregroundColor(.fafGrayLight)
                    }
                    .padding(.top, FAFSpacing.xxxs)
                }
                .padding(.top, 80) // Space for overlapping profile image
                .padding(.bottom, FAFSpacing.md)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: FAFSpacing.md) {
            StatCard(
                value: "\(userService.currentUser?.friends.count ?? 0)",
                label: "Friends",
                icon: .friends
            )
            StatCard(
                value: "0",
                label: "Recipes",
                icon: .fork
            )
            StatCard(
                value: "0",
                label: "Meal Plans",
                icon: .calendar
            )
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: FAFSpacing.md) {
            QuickActionButton(
                icon: .heart,
                label: "Saved",
                color: .fafCoral
            ) {
                // Saved recipes action
            }

            QuickActionButton(
                icon: .calendar,
                label: "Meal Plans",
                color: .fafSage
            ) {
                // Meal plans action
            }

            QuickActionButton(
                icon: .fork,
                label: "My Recipes",
                color: .fafOrange
            ) {
                // My recipes action
            }
        }
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(spacing: FAFSpacing.xxs) {
            ProfileMenuCard(
                title: "Account Settings",
                items: [
                    ProfileMenuItem(icon: .profile, title: "Edit Profile"),
                    ProfileMenuItem(icon: .bell, title: "Notifications"),
                    ProfileMenuItem(icon: .settings, title: "Privacy")
                ]
            )

            ProfileMenuCard(
                title: "Support",
                items: [
                    ProfileMenuItem(icon: .chat, title: "Help Center"),
                    ProfileMenuItem(icon: .star, title: "Rate the App")
                ]
            )
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {
        Button {
            do {
                try authManager.signOut()
            } catch {
                Logger.auth.error("Sign out failed: \(error.localizedDescription)")
            }
        } label: {
            Text("Sign Out")
                .font(FAFTypography.button)
                .foregroundColor(.fafCoral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FAFSpacing.md)
        }
        .padding(.top, FAFSpacing.md)
    }

    // MARK: - Upload Image

    private func uploadProfileImage(_ image: UIImage) async {
        guard let userId = userService.currentUser?.id else { return }

        isUploading = true

        do {
            let resizedImage = image.resized(toMaxDimension: 500)
            let imageURL = try await StorageService.shared.uploadProfileImage(resizedImage, userId: userId)

            if var user = userService.currentUser {
                user.profileImageURL = imageURL
                try await userService.updateUser(user)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            selectedImage = nil
        }

        isUploading = false
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: FAFIconType

    var body: some View {
        VStack(spacing: FAFSpacing.xs) {
            FAFIcon(icon, size: 20, color: .fafGray)

            Text(value)
                .font(FAFTypography.h2)
                .foregroundColor(.fafBlack)

            Text(label)
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: FAFIconType
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FAFSpacing.xs) {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(
                        FAFIcon(icon, size: 22, color: color)
                    )

                Text(label)
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGrayDark)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Profile Menu Card

struct ProfileMenuCard: View {
    let title: String
    let items: [ProfileMenuItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(FAFTypography.labelLarge)
                .foregroundColor(.fafGray)
                .padding(.horizontal, FAFSpacing.md)
                .padding(.top, FAFSpacing.md)
                .padding(.bottom, FAFSpacing.xs)

            ForEach(items.indices, id: \.self) { index in
                items[index]

                if index < items.count - 1 {
                    Divider()
                        .padding(.leading, FAFSpacing.md + 28)
                }
            }
        }
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
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
                FAFIcon(icon, size: 20, color: .fafGrayDark)
                    .frame(width: 24)

                Text(title)
                    .font(FAFTypography.body)
                    .foregroundColor(.fafBlack)

                Spacer()

                FAFIcon(.forward, size: 14, color: .fafGrayLight)
            }
            .padding(.horizontal, FAFSpacing.md)
            .padding(.vertical, FAFSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Header Background

struct ProfileHeaderBackground: View {
    // Pre-defined positions for consistent rendering
    private let iconData: [(icon: String, size: CGFloat, rotation: Double, xOffset: CGFloat, yOffset: CGFloat)] = [
        ("fork.knife", 28, -15, 0.1, 0.2),
        ("leaf", 24, 20, 0.35, 0.15),
        ("carrot", 30, -10, 0.6, 0.25),
        ("cup.and.saucer", 26, 15, 0.85, 0.1),
        ("frying.pan", 32, -20, 0.15, 0.5),
        ("birthday.cake", 22, 25, 0.45, 0.45),
        ("leaf", 28, -5, 0.7, 0.55),
        ("fork.knife", 24, 10, 0.9, 0.4),
        ("carrot", 26, -25, 0.25, 0.75),
        ("cup.and.saucer", 30, 5, 0.55, 0.8),
        ("frying.pan", 22, 15, 0.8, 0.7),
        ("birthday.cake", 28, -10, 0.05, 0.85)
    ]

    // Colors for the food icons
    private let iconColors: [Color] = [.fafCoral, .fafSage, .fafOrange]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clean solid background
                Color.fafOffWhite

                // Scattered food icons in brand colors
                ForEach(0..<iconData.count, id: \.self) { index in
                    let data = iconData[index]
                    let color = iconColors[index % iconColors.count]
                    Image(systemName: data.icon)
                        .font(.system(size: data.size, weight: .regular))
                        .foregroundColor(color.opacity(0.4))
                        .rotationEffect(.degrees(data.rotation))
                        .position(
                            x: geometry.size.width * data.xOffset,
                            y: geometry.size.height * data.yOffset
                        )
                }
            }
        }
        .clipped()
    }
}

#Preview {
    ProfileView()
}
