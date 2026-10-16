import SwiftUI

/// The Table — what friends have been cooking, set as a dated log: today,
/// yesterday, then the days before, each entry with whose it is, what they
/// did, and what it was. A recipe or a menu opens where it's tapped.
struct FeedView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var feedService = FeedService.shared
    @ObservedObject var friendService = FriendService.shared
    @ObservedObject var moderation = ModerationService.shared

    @State private var showFriends = false
    @State private var selectedRecipe: Recipe?
    @State private var selectedMealPlan: MealPlan?
    @State private var openingId: String?
    @State private var reporting: ReportSubject?
    @State private var blocking: Activity?

    /// Entries grouped by the day they were written, newest first.
    /// The Table, less anyone you've blocked.
    private var entries: [Activity] { feedService.feedActivities.unblocked }

    private var days: [(day: Date, entries: [Activity])] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.createdAt) }
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    plate

                    if feedService.isLoading && entries.isEmpty {
                        ProgressView()
                            .tint(Theme.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacingXL)
                    } else if entries.isEmpty {
                        BlankLeaf(
                            note: friendService.friends.isEmpty
                                ? "Nobody at the table yet. Add friends and what they cook turns up here."
                                : "Nothing written down yet. When friends add a recipe or plan a menu, it's set here.",
                            action: friendService.friends.isEmpty
                                ? (label: "Find friends", run: { showFriends = true })
                                : nil
                        )
                    } else {
                        ForEach(days, id: \.day) { day in
                            VStack(alignment: .leading, spacing: 0) {
                                SectionHead(title: dayName(day.day), figure: "\(day.entries.count)")
                                    .padding(.bottom, 4)
                                ForEach(Array(day.entries.enumerated()), id: \.element.id) { position, activity in
                                    TableEntry(activity: activity, isOpening: openingId == activity.id) {
                                        open(activity)
                                    }
                                    .contextMenu { moderationActions(for: activity) }
                                    if position < day.entries.count - 1 {
                                        DashedDivider()
                                    }
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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .navigationDestination(item: $selectedMealPlan) { mealPlan in
                MealPlanDetailView(mealPlan: mealPlan)
            }
            .sheet(isPresented: $showFriends) {
                FriendsView(showsClose: true)
            }
            .sheet(item: $reporting) { subject in
                ReportSheet(subject: subject)
            }
            .blockConfirmation(
                username: blocking?.authorUsername,
                userId: blocking?.authorId,
                isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } })
            )
            .task { await loadFeed() }
            .refreshable { await loadFeed() }
        }
    }

    // MARK: - Plate

    private var plate: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 12)

            HStack(alignment: .firstTextBaseline) {
                Text("The Table")
                    .font(.plate(32))
                    .foregroundColor(Theme.ink)

                Spacer(minLength: Theme.spacingSM)

                Button {
                    showFriends = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "person.2")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.ink)
                        if !friendService.pendingRequests.isEmpty {
                            Rectangle()
                                .fill(Theme.accent)
                                .frame(width: 6, height: 6)
                                .offset(x: 4, y: -3)
                        }
                    }
                    .frame(width: 36, height: 36, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(friendService.pendingRequests.isEmpty
                                    ? "Friends"
                                    : "Friends, \(friendService.pendingRequests.count) waiting")
            }

            Text(edition.uppercased())
                .smallCaps(10, weight: .medium, tracking: 1.4)
                .foregroundColor(Theme.ink2)
                .padding(.top, 4)

            Rule()
                .padding(.top, 12)
        }
        .padding(.top, Theme.spacingSM)
    }

    private var edition: String {
        let count = userService.currentUser?.friends.count ?? friendService.friends.count
        let waiting = friendService.pendingRequests.count
        var line = "What friends are cooking · \(count) \(count == 1 ? "friend" : "friends")"
        if waiting > 0 { line += " · \(waiting) waiting" }
        return line
    }

    /// "Today", "Yesterday", then "Monday, Oct 12".
    private func dayName(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    // MARK: - Report and block

    /// Press and hold an entry: report it, report its author, or block them.
    @ViewBuilder
    private func moderationActions(for activity: Activity) -> some View {
        if activity.authorId != userService.currentUser?.id {
            let who = "@\(activity.authorUsername ?? "them")"
            if let id = activity.id {
                Button {
                    reporting = ReportSubject(target: .activity, targetId: id, authorId: activity.authorId,
                                              authorUsername: activity.authorUsername, label: activity.contentTitle)
                } label: {
                    Label("Report this entry", systemImage: "flag")
                }
            }
            Button {
                reporting = ReportSubject(target: .user, targetId: activity.authorId, authorId: activity.authorId,
                                          authorUsername: activity.authorUsername, label: who)
            } label: {
                Label("Report \(who)", systemImage: "person.crop.circle.badge.exclamationmark")
            }
            Button(role: .destructive) {
                blocking = activity
            } label: {
                Label("Block \(who)", systemImage: "hand.raised")
            }
        }
    }

    // MARK: - Opening an entry

    private func open(_ activity: Activity) {
        openingId = activity.id
        Task {
            defer { openingId = nil }
            if activity.isRecipeActivity, let id = activity.recipeId {
                selectedRecipe = try? await RecipeService.shared.fetchRecipe(id: id)
            } else if activity.isMealPlanActivity, let id = activity.mealPlanId {
                selectedMealPlan = try? await MealPlanService.shared.fetchMealPlan(id: id)
            }
        }
    }

    private func loadFeed() async {
        guard let user = userService.currentUser, let userId = user.id else { return }
        #if DEBUG
        if DesignHarness.isOn { return }
        #endif
        if friendService.friends.isEmpty {
            await friendService.fetchFriends(for: userId)
        }
        await friendService.fetchPendingRequests(for: userId)
        await feedService.fetchFeed(for: user)
    }
}

// MARK: - One entry at the table

/// Whose it is and what they did, small; what it was, in the serif; their
/// line about it underneath; the photograph when a recipe has one.
struct TableEntry: View {
    let activity: Activity
    var isOpening: Bool = false
    let onOpen: () -> Void

    @State private var photoURL: String?

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack(alignment: .center, spacing: 10) {
                    Monogram(name: activity.authorUsername ?? "?", imageURL: activity.authorProfileImageURL, size: 30)
                    Text(byline)
                        .font(.setting(13))
                        .foregroundColor(Theme.ink2)
                        .lineLimit(1)
                    Spacer(minLength: Theme.spacingSM)
                    if isOpening {
                        ProgressView().tint(Theme.ink3).scaleEffect(0.7)
                    } else {
                        Text(activity.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.figure(11, .medium))
                            .foregroundColor(Theme.ink3)
                    }
                }

                if activity.type == .newRecipe, photoURL != nil {
                    PhotoPlate(url: photoURL, height: 180)
                }

                Text(activity.contentTitle ?? "Something new")
                    .font(.plate(19, .semibold))
                    .foregroundColor(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = activity.contentDescription, !description.isEmpty {
                    Text(description)
                        .font(.setting(14).italic())
                        .foregroundColor(Theme.ink2)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: activity.id) { await loadPhoto() }
    }

    /// "@maria_cooks wrote down a recipe", "@sam liked @maria's recipe".
    private var byline: String {
        let who = "@\(activity.authorUsername ?? "someone")"
        switch activity.type {
        case .newRecipe: return "\(who) wrote down a recipe"
        case .newMealPlan: return "\(who) planned a menu"
        case .recipeComment, .mealPlanComment:
            return "\(who) wrote a note on \(target)"
        case .recipeLike, .mealPlanLike:
            return "\(who) liked \(target)"
        }
    }

    private var target: String {
        let kind = activity.isRecipeActivity ? "recipe" : "menu"
        guard let author = activity.targetAuthorUsername else { return "a \(kind)" }
        return "@\(author)'s \(kind)"
    }

    /// A new recipe's photograph, if it has one — fetched once, quietly.
    private func loadPhoto() async {
        guard activity.type == .newRecipe, photoURL == nil else { return }
        if let url = activity.contentImageURL {
            photoURL = url
            return
        }
        #if DEBUG
        if DesignHarness.isOn { return }
        #endif
        guard let id = activity.recipeId else { return }
        photoURL = (try? await RecipeService.shared.fetchRecipe(id: id))?.firstImageURL
    }
}

#Preview {
    FeedView()
}
