import SwiftUI

/// Finding a friend by their username and asking them to the table.
struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var friendService = FriendService.shared
    @ObservedObject var userService = UserService.shared

    @State private var searchText = ""
    @State private var searchResults: [FAFUser] = []
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var sentRequestIds: Set<String> = []

    private let searchDebouncer = Debouncer(delay: 0.3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    PlateHeader(title: "Find a friend", subtitle: "By their username")

                    SearchLine(placeholder: "Username", text: $searchText)
                        .onChange(of: searchText) { _, newValue in
                            performSearch(query: newValue)
                        }

                    if isSearching {
                        ProgressView()
                            .tint(Theme.ink3)
                            .frame(maxWidth: .infinity)
                    } else if searchText.isEmpty {
                        BlankLeaf(note: "Type the start of a friend's username — they'll get a note asking them to your table.")
                    } else if searchResults.isEmpty {
                        BlankLeaf(note: "No one goes by \"\(searchText)\".")
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(searchResults.enumerated()), id: \.element.id) { position, user in
                                resultLine(user)
                                if position < searchResults.count - 1 {
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
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Cancel") { dismiss() }
                }
            }
            .onAppear { loadSentRequests() }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func resultLine(_ user: FAFUser) -> some View {
        let isFriend = user.id.map { userService.currentUser?.friends.contains($0) ?? false } ?? false
        let isSent = user.id.map(sentRequestIds.contains) ?? false
        return HStack(alignment: .center, spacing: 12) {
            Monogram(name: user.displayName ?? user.username, imageURL: user.profileImageURL, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user.username)")
                    .font(.plate(17, .semibold))
                    .foregroundColor(Theme.ink)
                if !user.location.isEmpty {
                    Text(user.location)
                        .font(.setting(12))
                        .foregroundColor(Theme.ink3)
                }
            }
            Spacer(minLength: Theme.spacingSM)
            if isFriend {
                Text("At your table".uppercased())
                    .smallCaps(9, weight: .semibold, tracking: 1.2)
                    .foregroundColor(Theme.herb)
            } else if isSent {
                Text("Sent".uppercased())
                    .smallCaps(9, weight: .semibold, tracking: 1.2)
                    .foregroundColor(Theme.ink3)
            } else {
                MarginButton("Add") { sendRequest(to: user) }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchDebouncer.debounce {
            Task { @MainActor in
                isSearching = true
                do {
                    let results = try await friendService.searchUsers(query: query)
                    // Filter out current user
                    searchResults = results.filter { $0.id != userService.currentUser?.id }
                } catch {
                    print("Search error: \(error)")
                }
                isSearching = false
            }
        }
    }

    private func sendRequest(to user: FAFUser) {
        guard let currentUserId = userService.currentUser?.id,
              let targetUserId = user.id else { return }

        Task {
            do {
                try await friendService.sendFriendRequest(from: currentUserId, to: targetUserId)
                sentRequestIds.insert(targetUserId)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func loadSentRequests() {
        guard let userId = userService.currentUser?.id else { return }
        Task {
            await friendService.fetchSentRequests(for: userId)
            sentRequestIds = Set(friendService.sentRequests.map { $0.toUserId })
        }
    }
}

#Preview {
    AddFriendView()
}
