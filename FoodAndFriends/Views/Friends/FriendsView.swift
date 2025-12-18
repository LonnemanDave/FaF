import SwiftUI

struct FriendsView: View {
    @ObservedObject var friendService = FriendService.shared
    @ObservedObject var userService = UserService.shared

    @State private var showAddFriend = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FAFSpacing.lg) {
                    // Pending Requests Section
                    if !friendService.pendingRequests.isEmpty {
                        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                            Text("Friend Requests")
                                .font(FAFTypography.h3)
                                .foregroundColor(.fafBlack)
                                .padding(.horizontal, FAFSpacing.lg)

                            ForEach(friendService.pendingRequests) { request in
                                FriendRequestRow(request: request)
                            }
                        }
                        .padding(.top, FAFSpacing.md)
                    }

                    // Friends List
                    VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                        Text("My Friends")
                            .font(FAFTypography.h3)
                            .foregroundColor(.fafBlack)
                            .padding(.horizontal, FAFSpacing.lg)

                        if friendService.friends.isEmpty {
                            EmptyFriendsView(showAddFriend: $showAddFriend)
                        } else {
                            ForEach(friendService.friends) { friend in
                                FriendRow(friend: friend)
                            }
                        }
                    }
                    .padding(.top, FAFSpacing.md)
                }
                .padding(.bottom, FAFSpacing.xl)
            }
            .background(Color.fafWhite)
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        FAFIcon(.plus, size: 20, color: .fafCoral)
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard let userId = userService.currentUser?.id else { return }
        await friendService.fetchPendingRequests(for: userId)
        await friendService.fetchFriends(for: userId)
    }
}

// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let request: FriendRequest
    @ObservedObject var friendService = FriendService.shared
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: FAFSpacing.md) {
            // Avatar
            Circle()
                .fill(Color.fafGrayXLight)
                .frame(width: 50, height: 50)
                .overlay(
                    FAFIcon(.profile, size: 24, color: .fafGray)
                )

            // Info
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                Text("@\(request.fromUsername ?? "unknown")")
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafBlack)
                Text("wants to be friends")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }

            Spacer()

            // Actions
            if isLoading {
                ProgressView()
            } else {
                HStack(spacing: FAFSpacing.xs) {
                    Button {
                        Task { await acceptRequest() }
                    } label: {
                        FAFIcon(.check, size: 20, color: .fafSage)
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.fafSage.opacity(0.1))
                    .cornerRadius(FAFRadius.sm)

                    Button {
                        Task { await declineRequest() }
                    } label: {
                        FAFIcon(.close, size: 20, color: .fafCoral)
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.fafCoral.opacity(0.1))
                    .cornerRadius(FAFRadius.sm)
                }
            }
        }
        .padding(FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
        .padding(.horizontal, FAFSpacing.lg)
    }

    private func acceptRequest() async {
        isLoading = true
        do {
            try await friendService.acceptFriendRequest(request)
        } catch {
            print("Error accepting request: \(error)")
        }
        isLoading = false
    }

    private func declineRequest() async {
        isLoading = true
        do {
            try await friendService.declineFriendRequest(request)
        } catch {
            print("Error declining request: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: FAFUser

    var body: some View {
        HStack(spacing: FAFSpacing.md) {
            // Avatar
            Circle()
                .fill(Color.fafGrayXLight)
                .frame(width: 50, height: 50)
                .overlay(
                    FAFIcon(.profile, size: 24, color: .fafGray)
                )

            // Info
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                Text("@\(friend.username)")
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafBlack)
                Text(friend.location)
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }

            Spacer()

            FAFIcon(.forward, size: 16, color: .fafGray)
        }
        .padding(FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
        .padding(.horizontal, FAFSpacing.lg)
    }
}

// MARK: - Empty State

struct EmptyFriendsView: View {
    @Binding var showAddFriend: Bool

    var body: some View {
        VStack(spacing: FAFSpacing.md) {
            FAFIcon(.friends, size: 48, color: .fafGray)

            Text("No friends yet")
                .font(FAFTypography.body)
                .foregroundColor(.fafGray)

            Button {
                showAddFriend = true
            } label: {
                Text("Find Friends")
                    .font(FAFTypography.button)
                    .foregroundColor(.fafCoral)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FAFSpacing.xxl)
    }
}

#Preview {
    FriendsView()
}
