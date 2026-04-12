import OSLog
import SwiftUI

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

    @FocusState private var isSearchFocused: Bool

    private let searchDebouncer = Debouncer(delay: 0.3)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: FAFSpacing.sm) {
                    FAFIcon(.search, size: 18, color: .fafGray)

                    TextField("Search by username", text: $searchText)
                        .font(FAFTypography.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, newValue in
                            performSearch(query: newValue)
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            FAFIcon(.close, size: 16, color: .fafGray)
                        }
                    }
                }
                .padding(FAFSpacing.md)
                .background(Color.fafOffWhite)
                .cornerRadius(FAFRadius.md)
                .padding(FAFSpacing.lg)

                // Results
                if isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack(spacing: FAFSpacing.sm) {
                        FAFIcon(.search, size: 48, color: .fafGray)
                        Text("No users found")
                            .font(FAFTypography.body)
                            .foregroundColor(.fafGray)
                    }
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: FAFSpacing.sm) {
                        FAFIcon(.friends, size: 48, color: .fafGray)
                        Text("Search for friends by username")
                            .font(FAFTypography.body)
                            .foregroundColor(.fafGray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: FAFSpacing.sm) {
                            ForEach(searchResults) { user in
                                SearchResultRow(
                                    user: user,
                                    isSent: sentRequestIds.contains(user.id ?? ""),
                                    onSendRequest: { sendRequest(to: user) }
                                )
                            }
                        }
                        .padding(.horizontal, FAFSpacing.lg)
                        .padding(.top, FAFSpacing.sm)
                    }
                }
            }
            .background(Color.fafWhite)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.fafCoral)
                }
            }
            .onAppear {
                isSearchFocused = true
                loadSentRequests()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

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
                    Logger.friends.error("User search failed: \(error.localizedDescription)")
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

// MARK: - Search Result Row

struct SearchResultRow: View {
    let user: FAFUser
    let isSent: Bool
    let onSendRequest: () -> Void

    @ObservedObject var userService = UserService.shared

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
                Text("@\(user.username)")
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafBlack)
                Text(user.location)
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }

            Spacer()

            // Add Button
            if isAlreadyFriend {
                Text("Friends")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
                    .padding(.horizontal, FAFSpacing.md)
                    .padding(.vertical, FAFSpacing.xs)
                    .background(Color.fafGrayXLight)
                    .cornerRadius(FAFRadius.sm)
            } else if isSent {
                Text("Sent")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
                    .padding(.horizontal, FAFSpacing.md)
                    .padding(.vertical, FAFSpacing.xs)
                    .background(Color.fafGrayXLight)
                    .cornerRadius(FAFRadius.sm)
            } else {
                Button {
                    onSendRequest()
                } label: {
                    Text("Add")
                        .font(FAFTypography.button)
                        .foregroundColor(.fafWhite)
                        .padding(.horizontal, FAFSpacing.md)
                        .padding(.vertical, FAFSpacing.xs)
                        .background(Color.fafCoral)
                        .cornerRadius(FAFRadius.sm)
                }
            }
        }
        .padding(FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }

    private var isAlreadyFriend: Bool {
        guard let userId = user.id else { return false }
        return userService.currentUser?.friends.contains(userId) ?? false
    }
}

#Preview {
    AddFriendView()
}
