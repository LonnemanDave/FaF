import Foundation
import FirebaseFirestore

struct FAFUser: Codable, Identifiable {
    @DocumentID var id: String?
    let email: String
    var username: String
    var displayName: String?
    var location: String
    var profileImageURL: String?
    let createdAt: Date
    var updatedAt: Date

    var isProfileComplete: Bool {
        !username.isEmpty && !location.isEmpty
    }
}

