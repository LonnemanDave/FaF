import Foundation
import FirebaseFirestore

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
}

struct FriendRequest: Codable, Identifiable {
    @DocumentID var id: String?
    let fromUserId: String
    let toUserId: String
    var status: FriendRequestStatus
    let createdAt: Date

    // For displaying request info
    var fromUsername: String?
    var toUsername: String?
}
