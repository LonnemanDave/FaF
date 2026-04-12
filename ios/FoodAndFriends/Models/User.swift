import Foundation
import FirebaseFirestore

struct FAFUser: Codable, Identifiable {
    @DocumentID var id: String?
    let email: String
    var username: String
    var displayName: String?
    var location: String
    var profileImageURL: String?
    var friends: [String]
    let createdAt: Date
    var updatedAt: Date

    var isProfileComplete: Bool {
        !username.isEmpty && !location.isEmpty
    }

    // Default initializer for creating new users
    init(
        id: String? = nil,
        email: String,
        username: String,
        displayName: String? = nil,
        location: String,
        profileImageURL: String? = nil,
        friends: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.location = location
        self.profileImageURL = profileImageURL
        self.friends = friends
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom decoder to handle missing fields from existing Firestore documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        location = try container.decode(String.self, forKey: .location)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        friends = try container.decodeIfPresent([String].self, forKey: .friends) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

