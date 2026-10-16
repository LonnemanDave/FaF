import Foundation
import FirebaseFirestore

/// What a report is about.
enum ReportTarget: String {
    case user, recipe, variation, mealPlan, activity

    var noun: String {
        switch self {
        case .user: return "person"
        case .recipe: return "recipe"
        case .variation: return "variation"
        case .mealPlan: return "menu"
        case .activity: return "entry"
        }
    }
}

enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "Spam or advertising"
    case offensive = "Offensive or hateful"
    case harassment = "Harassment or bullying"
    case sexual = "Sexual content"
    case violence = "Violence or threats"
    case dangerous = "Dangerous food advice"
    case impersonation = "Pretending to be someone else"
    case other = "Something else"

    var id: String { rawValue }
}

/* Apple's guideline 1.2: anywhere people see each other's writing, they
 * need a way to report it and a way to block the person behind it.
 *
 * Reports are write-only — the rules let a cook file one but never read
 * it back, so nobody can find out who reported them. Blocking is quiet:
 * the blocked cook is told nothing. It ends the friendship on both sides
 * (that's what actually takes away their view of your private recipes,
 * menus and Table entries), clears any friend request between you, and
 * the rules refuse new requests from them. Anything of theirs that's
 * shared with everyone is filtered out here, on this phone. */
@MainActor
final class ModerationService: ObservableObject {
    static let shared = ModerationService()

    /// Everyone the signed-in cook has blocked.
    @Published private(set) var blockedIds: Set<String> = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var userId: String?

    private init() {}

    func startListening(userId: String) {
        stopListening()
        self.userId = userId
        listener = db.collection("users").document(userId).collection("blocked")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot else { return }
                Task { @MainActor in
                    self?.blockedIds = Set(snapshot.documents.map(\.documentID))
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        userId = nil
        blockedIds = []
    }

    func isBlocked(_ userId: String?) -> Bool {
        guard let userId else { return false }
        return blockedIds.contains(userId)
    }

    // MARK: - Blocking

    func block(_ targetId: String) async throws {
        guard let me = userId, targetId != me else { return }
        let users = db.collection("users")
        let requests = db.collection("friendRequests")

        // Requests either way between the two of you, old-style ids included.
        let sent = try await requests.whereField("fromUserId", isEqualTo: me)
            .whereField("toUserId", isEqualTo: targetId).getDocuments()
        let received = try await requests.whereField("toUserId", isEqualTo: me)
            .whereField("fromUserId", isEqualTo: targetId).getDocuments()

        let batch = db.batch()
        batch.setData(["blockedAt": Timestamp(date: Date())],
                      forDocument: users.document(me).collection("blocked").document(targetId))
        batch.updateData(["friends": FieldValue.arrayRemove([targetId]), "updatedAt": Date()],
                         forDocument: users.document(me))
        batch.updateData(["friends": FieldValue.arrayRemove([me]), "updatedAt": Date()],
                         forDocument: users.document(targetId))
        for doc in sent.documents + received.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()

        blockedIds.insert(targetId)
        FriendService.shared.forget(targetId)
    }

    func unblock(_ targetId: String) async throws {
        guard let me = userId else { return }
        try await db.collection("users").document(me).collection("blocked").document(targetId).delete()
        blockedIds.remove(targetId)
    }

    /// The people you've blocked, for the list under You.
    func fetchBlockedUsers() async -> [FAFUser] {
        var people: [FAFUser] = []
        for id in blockedIds.sorted() {
            if let user = try? await db.collection("users").document(id).getDocument(as: FAFUser.self) {
                people.append(user)
            }
        }
        return people.sorted { $0.username < $1.username }
    }

    // MARK: - Reporting

    func report(
        _ target: ReportTarget,
        id targetId: String,
        author targetUserId: String?,
        reason: ReportReason,
        note: String,
        context: [String: String] = [:]
    ) async throws {
        guard let me = userId else { return }
        var data: [String: Any] = [
            "reporterId": me,
            "targetType": target.rawValue,
            "targetId": targetId,
            "reason": reason.rawValue,
            "note": String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000)),
            "status": "open",
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let targetUserId { data["targetUserId"] = targetUserId }
        if !context.isEmpty { data["context"] = context }
        try await db.collection("reports").addDocument(data: data)
    }
}

// MARK: - Filtering

/// Anything with an author, so lists of it can drop the people you've blocked.
protocol Authored {
    var authorId: String { get }
}

extension Recipe: Authored {}
extension RecipeVariation: Authored {}
extension MealPlan: Authored {}
extension Activity: Authored {}

extension Array where Element: Authored {
    /// Without anything written by someone you've blocked.
    @MainActor var unblocked: [Element] {
        let blocked = ModerationService.shared.blockedIds
        return blocked.isEmpty ? self : filter { !blocked.contains($0.authorId) }
    }
}
