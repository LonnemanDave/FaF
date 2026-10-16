import SwiftUI

/// Friends — who's waiting to be let in, and who's already at your table.
struct FriendsView: View {
    /// Opened as a sheet from the Table: it closes itself.
    var showsClose: Bool = false

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var friendService = FriendService.shared
    @ObservedObject var userService = UserService.shared

    @State private var showAddFriend = false
    @State private var answering: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    plate

                    if !friendService.pendingRequests.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHead(title: "Waiting for you", figure: "\(friendService.pendingRequests.count)")
                                .padding(.bottom, 2)
                            ForEach(Array(friendService.pendingRequests.enumerated()), id: \.element.id) { position, request in
                                requestLine(request)
                                if position < friendService.pendingRequests.count - 1 {
                                    DashedDivider()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        SectionHead(title: "At your table", figure: "\(friendService.friends.count)")
                            .padding(.bottom, 2)
                        if friendService.friends.isEmpty {
                            BlankLeaf(
                                note: "No friends here yet. Find them by their username.",
                                action: (label: "Find friends", run: { showAddFriend = true })
                            )
                        } else {
                            ForEach(Array(friendService.friends.enumerated()), id: \.element.id) { position, friend in
                                NavigationLink(value: friend.id ?? "") {
                                    friendLine(friend)
                                }
                                .buttonStyle(.plain)
                                if position < friendService.friends.count - 1 {
                                    DashedDivider()
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
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                if showsClose {
                    ToolbarItem(placement: .topBarLeading) {
                        MarginButton("Close") { dismiss() }
                    }
                }
            }
            .toolbar(showsClose ? .visible : .hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { friendId in
                if let friend = friendService.friends.first(where: { $0.id == friendId }) {
                    UserProfileView(user: friend)
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .task { await loadData() }
            .refreshable { await loadData() }
        }
    }

    // MARK: - Plate

    private var plate: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 12)
            HStack(alignment: .firstTextBaseline) {
                Text("Friends")
                    .font(.plate(32))
                    .foregroundColor(Theme.ink)
                Spacer(minLength: Theme.spacingSM)
                Button {
                    showAddFriend = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Theme.ink)
                        .frame(width: 36, height: 36, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Find a friend")
            }
            Text("Who cooks with you".uppercased())
                .smallCaps(10, weight: .medium, tracking: 1.4)
                .foregroundColor(Theme.ink2)
                .padding(.top, 4)
            Rule()
                .padding(.top, 12)
        }
        .padding(.top, Theme.spacingSM)
    }

    // MARK: - Lines

    private func requestLine(_ request: FriendRequest) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Monogram(name: request.fromUsername ?? "?", size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(request.fromUsername ?? "someone")")
                    .font(.plate(17, .semibold))
                    .foregroundColor(Theme.ink)
                Text("would like a seat at your table")
                    .font(.setting(12).italic())
                    .foregroundColor(Theme.ink3)
            }
            Spacer(minLength: Theme.spacingSM)
            if answering == request.id {
                ProgressView().tint(Theme.ink3)
            } else {
                MarginButton("Decline") { Task { await answer(request, accept: false) } }
                MarginButton("Accept") { Task { await answer(request, accept: true) } }
                    .padding(.leading, Theme.spacingSM)
            }
        }
        .padding(.vertical, 12)
    }

    private func friendLine(_ friend: FAFUser) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Monogram(name: friend.displayName ?? friend.username, imageURL: friend.profileImageURL, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName ?? "@\(friend.username)")
                    .font(.plate(17, .semibold))
                    .foregroundColor(Theme.ink)
                Text([friend.displayName == nil ? nil : "@\(friend.username)", friend.location.isEmpty ? nil : friend.location]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.setting(12))
                    .foregroundColor(Theme.ink3)
            }
            Spacer(minLength: Theme.spacingSM)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.ink3)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func answer(_ request: FriendRequest, accept: Bool) async {
        answering = request.id
        defer { answering = nil }
        do {
            if accept {
                try await friendService.acceptFriendRequest(request)
            } else {
                try await friendService.declineFriendRequest(request)
            }
        } catch {
            print("Error answering friend request: \(error)")
        }
    }

    private func loadData() async {
        guard let userId = userService.currentUser?.id else { return }
        #if DEBUG
        if DesignHarness.isOn { return }
        #endif
        await friendService.fetchPendingRequests(for: userId)
        await friendService.fetchFriends(for: userId)
    }
}

#Preview {
    FriendsView()
}
