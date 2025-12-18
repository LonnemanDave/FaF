import Foundation
import FirebaseFirestore

enum FriendServiceError: LocalizedError {
    case userNotFound
    case alreadyFriends
    case requestAlreadySent
    case cannotAddSelf
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

    @Published var friends: [FAFUser] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []

    private init() {}

    // MARK: - Search Users

    func searchUsers(query: String) async throws -> [FAFUser] {
        let lowercasedQuery = query.lowercased()

        // Search by username prefix
        let snapshot = try await db.collection(usersCollection)
            .whereField("username", isGreaterThanOrEqualTo: lowercasedQuery)
            .whereField("username", isLessThanOrEqualTo: lowercasedQuery + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FAFUser.self)
        }
    }

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

        // Check for existing pending request (either direction)
        let existingRequest = try await db.collection(friendRequestsCollection)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .getDocuments()

        let hasPendingRequest = existingRequest.documents.contains { doc in
            guard let request = try? doc.data(as: FriendRequest.self) else { return false }
            return (request.fromUserId == currentUserId && request.toUserId == targetUserId) ||
                   (request.fromUserId == targetUserId && request.toUserId == currentUserId)
        }

        if hasPendingRequest {
            throw FriendServiceError.requestAlreadySent
        }

        // Create friend request
        let request = FriendRequest(
            fromUserId: currentUserId,
            toUserId: targetUserId,
            status: .pending,
            createdAt: Date()
        )

        try db.collection(friendRequestsCollection).addDocument(from: request)
    }

    func acceptFriendRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else { return }

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
