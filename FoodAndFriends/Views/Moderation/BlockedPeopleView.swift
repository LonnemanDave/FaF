import SwiftUI

/// The people you've blocked, each with a way back.
struct BlockedPeopleView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var moderation = ModerationService.shared

    @State private var people: [FAFUser] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    PlateHeader(title: "Blocked", subtitle: "People kept off your table",
                                figure: "\(moderation.blockedIds.count)")

                    if isLoading {
                        ProgressView()
                            .tint(Theme.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacingXL)
                    } else if people.isEmpty {
                        BlankLeaf(note: "Nobody blocked. Block someone from their page, or from anything they've written, and they're listed here.")
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(people.enumerated()), id: \.element.id) { position, person in
                                HStack(spacing: Theme.spacingSM) {
                                    Monogram(name: person.displayName ?? person.username,
                                             imageURL: person.profileImageURL, size: 30)
                                    Text("@\(person.username)")
                                        .font(.setting(16))
                                        .foregroundColor(Theme.ink)
                                    Spacer(minLength: Theme.spacingSM)
                                    MarginButton("Unblock") {
                                        guard let id = person.id else { return }
                                        Task {
                                            try? await moderation.unblock(id)
                                            people.removeAll { $0.id == id }
                                        }
                                    }
                                }
                                .padding(.vertical, 10)
                                if position < people.count - 1 {
                                    DashedDivider()
                                }
                            }
                        }
                    }

                    Text("Unblocking doesn't make you friends again — either of you can ask.")
                        .font(.setting(12).italic())
                        .foregroundColor(Theme.ink3)
                }
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Done") { dismiss() }
                }
            }
            .task {
                people = await moderation.fetchBlockedUsers()
                isLoading = false
            }
        }
    }
}
