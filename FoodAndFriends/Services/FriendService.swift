import Foundation
import FirebaseFirestore

enum FriendServiceError: LocalizedError {
    case userNotFound
    case alreadyFriends
    case requestAlreadySent
    case cannotAddSelf
    case requestExpired
    case firestoreError(Error)

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .alreadyFriends:
            return "You're already friends with this user"
        case .requestAlreadySent:
            return "Friend request already sent"
        case .cannotAddSelf:
            return "You cannot add yourself as a friend"
        case .requestExpired:
            return "That request is too old to accept — ask them to send a new one."
        case .firestoreError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class FriendService: ObservableObject {
    static let shared = FriendService()

    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let friendRequestsCollection = "friendRequests"

    private var pendingRequestsListener: ListenerRegistration?
    private var sentRequestsListener: ListenerRegistration?
    private var friendsListener: ListenerRegistration?
    private var currentUserId: String?

    @Published var friends: [FAFUser] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []

    private init() {}

    // MARK: - Realtime Listeners

    func startListening(userId: String) {
        stopListening()
        currentUserId = userId
        ModerationService.shared.startListening(userId: userId)

        // Listen for pending requests (incoming)
        pendingRequestsListener = db.collection(friendRequestsCollection)
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to pending requests: \(error)")
                    return
                }
                Task { await self.processPendingRequests(snapshot) }
            }

        // Listen for sent requests (outgoing)
        sentRequestsListener = db.collection(friendRequestsCollection)
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to sent requests: \(error)")
                    return
                }
                Task { await self.processSentRequests(snapshot) }
            }

        // Listen to user document for friends array changes
        friendsListener = db.collection(usersCollection).document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to friends: \(error)")
                    return
                }
                Task { await self.processFriendsUpdate(snapshot) }
            }
    }

    func stopListening() {
        ModerationService.shared.stopListening()
        pendingRequestsListener?.remove()
        sentRequestsListener?.remove()
        friendsListener?.remove()
        pendingRequestsListener = nil
        sentRequestsListener = nil
        friendsListener = nil
        currentUserId = nil
        friends = []
        pendingRequests = []
        sentRequests = []
    }

    private func processPendingRequests(_ snapshot: QuerySnapshot?) async {
        guard let documents = snapshot?.documents else { return }

        var requests = documents.compactMap { doc in
            try? doc.data(as: FriendRequest.self)
        }

        // Fetch usernames for each request
        for i in requests.indices {
            if let user = try? await fetchUser(userId: requests[i].fromUserId) {
                requests[i].fromUsername = user.username
            }
        }

        self.pendingRequests = requests
    }

    private func processSentRequests(_ snapshot: QuerySnapshot?) async {
        guard let documents = snapshot?.documents else { return }

        var requests = documents.compactMap { doc in
            try? doc.data(as: FriendRequest.self)
        }

        // Fetch usernames for each request
        for i in requests.indices {
            if let user = try? await fetchUser(userId: requests[i].toUserId) {
                requests[i].toUsername = user.username
            }
        }

        self.sentRequests = requests
    }

    private func processFriendsUpdate(_ snapshot: DocumentSnapshot?) async {
        guard let snapshot = snapshot,
              let user = try? snapshot.data(as: FAFUser.self) else {
            self.friends = []
            return
        }

        var friendsList: [FAFUser] = []
        for friendId in user.friends {
            if let friend = try? await fetchUser(userId: friendId) {
                friendsList.append(friend)
            }
        }

        self.friends = friendsList
    }

    // Legacy - for backwards compatibility
    func clearData() {
        stopListening()
    }

    // MARK: - Search Users

    func searchUsers(query: String) async throws -> [FAFUser] {
        let lowercasedQuery = query.lowercased()

        // Search by username prefix
        let snapshot = try await db.collection(usersCollection)
            .whereField("username", isGreaterThanOrEqualTo: lowercasedQuery)
            .whereField("username", isLessThanOrEqualTo: lowercasedQuery + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        let blocked = ModerationService.shared.blockedIds
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FAFUser.self)
        }
        .filter { !blocked.contains($0.id ?? "") }
    }

    /// Drops someone from every local list at once — after blocking them.
    func forget(_ userId: String) {
        friends.removeAll { $0.id == userId }
        pendingRequests.removeAll { $0.fromUserId == userId }
        sentRequests.removeAll { $0.toUserId == userId }
    }

    /// A request's document id is who it's from and who it's to, so the
    /// rules can find it: accepting one is what lets you add yourself to
    /// the sender's friends, and nothing else does.
    static func requestId(from: String, to: String) -> String { "\(from)_\(to)" }

    // MARK: - Friend Requests

    func sendFriendRequest(from currentUserId: String, to targetUserId: String) async throws {
        // Can't add yourself
        guard currentUserId != targetUserId else {
            throw FriendServiceError.cannotAddSelf
        }

        // Check if already friends
        let currentUserDoc = try await db.collection(usersCollection).document(currentUserId).getDocument()
        if let currentUser = try? currentUserDoc.data(as: FAFUser.self),
           currentUser.friends.contains(targetUserId) {
            throw FriendServiceError.alreadyFriends
        }

        // A pending request either way between just these two
        let requests = db.collection(friendRequestsCollection)
        let pending = FriendRequestStatus.pending.rawValue
        let outgoing = try await requests.whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("toUserId", isEqualTo: targetUserId)
            .whereField("status", isEqualTo: pending).getDocuments()
        let incoming = try await requests.whereField("fromUserId", isEqualTo: targetUserId)
            .whereField("toUserId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: pending).getDocuments()

        if !outgoing.isEmpty || !incoming.isEmpty {
            throw FriendServiceError.requestAlreadySent
        }

        // Create (or renew a declined) friend request
        let request = FriendRequest(
            fromUserId: currentUserId,
            toUserId: targetUserId,
            status: .pending,
            createdAt: Date()
        )

        try await requests.document(Self.requestId(from: currentUserId, to: targetUserId))
            .setData(from: request)
    }

    func acceptFriendRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else { return }

        // Requests from before ids meant anything can't be proved to the
        // rules — clear it away and ask for a fresh one.
        guard requestId == Self.requestId(from: request.fromUserId, to: request.toUserId) else {
            try? await db.collection(friendRequestsCollection).document(requestId).delete()
            pendingRequests.removeAll { $0.id == requestId }
            throw FriendServiceError.requestExpired
        }

        let batch = db.batch()

        // Update request status
        let requestRef = db.collection(friendRequestsCollection).document(requestId)
        batch.updateData(["status": FriendRequestStatus.accepted.rawValue], forDocument: requestRef)

        // Add each user to the other's friends list
        let fromUserRef = db.collection(usersCollection).document(request.fromUserId)
        batch.updateData([
            "friends": FieldValue.arrayUnion([request.toUserId]),
            "updatedAt": Date()
        ], forDocument: fromUserRef)

        let toUserRef = db.collection(usersCollection).document(request.toUserId)
        batch.updateData([
            "friends": FieldValue.arrayUnion([request.fromUserId]),
            "updatedAt": Date()
        ], forDocument: toUserRef)

        try await batch.commit()

        // Refresh local data
        await fetchPendingRequests(for: request.toUserId)
        await fetchFriends(for: request.toUserId)
    }

    func declineFriendRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else { return }

        try await db.collection(friendRequestsCollection).document(requestId).updateData([
            "status": FriendRequestStatus.declined.rawValue
        ])

        // Remove from local list
        pendingRequests.removeAll { $0.id == requestId }
    }

    // MARK: - Fetch Data

    func fetchPendingRequests(for userId: String) async {
        do {
            let snapshot = try await db.collection(friendRequestsCollection)
                .whereField("toUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
                .getDocuments()

            var requests = snapshot.documents.compactMap { doc in
                try? doc.data(as: FriendRequest.self)
            }

            // Fetch usernames for each request
            for i in requests.indices {
                if let user = try? await fetchUser(userId: requests[i].fromUserId) {
                    requests[i].fromUsername = user.username
                }
            }

            self.pendingRequests = requests
        } catch {
            print("Error fetching pending requests: \(error)")
        }
    }

    func fetchSentRequests(for userId: String) async {
        do {
            let snapshot = try await db.collection(friendRequestsCollection)
                .whereField("fromUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
                .getDocuments()

            var requests = snapshot.documents.compactMap { doc in
                try? doc.data(as: FriendRequest.self)
            }

            // Fetch usernames for each request
            for i in requests.indices {
                if let user = try? await fetchUser(userId: requests[i].toUserId) {
                    requests[i].toUsername = user.username
                }
            }

            self.sentRequests = requests
        } catch {
            print("Error fetching sent requests: \(error)")
        }
    }

    func fetchFriends(for userId: String) async {
        do {
            let userDoc = try await db.collection(usersCollection).document(userId).getDocument()
            guard let user = try? userDoc.data(as: FAFUser.self) else { return }

            var friendsList: [FAFUser] = []
            for friendId in user.friends {
                if let friend = try? await fetchUser(userId: friendId) {
                    friendsList.append(friend)
                }
            }

            self.friends = friendsList
        } catch {
            print("Error fetching friends: \(error)")
        }
    }

    func removeFriend(currentUserId: String, friendId: String) async throws {
        let batch = db.batch()

        let currentUserRef = db.collection(usersCollection).document(currentUserId)
        batch.updateData([
            "friends": FieldValue.arrayRemove([friendId]),
            "updatedAt": Date()
        ], forDocument: currentUserRef)

        let friendRef = db.collection(usersCollection).document(friendId)
        batch.updateData([
            "friends": FieldValue.arrayRemove([currentUserId]),
            "updatedAt": Date()
        ], forDocument: friendRef)

        try await batch.commit()

        // Update local list
        friends.removeAll { $0.id == friendId }
    }

    // MARK: - Helpers

    private func fetchUser(userId: String) async throws -> FAFUser? {
        let doc = try await db.collection(usersCollection).document(userId).getDocument()
        return try? doc.data(as: FAFUser.self)
    }
}
