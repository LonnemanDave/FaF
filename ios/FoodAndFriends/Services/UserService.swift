import Foundation
import FirebaseFirestore

enum UserServiceError: LocalizedError {
    case usernameTaken
    case userNotFound
    case invalidUsername
    case firestoreError(Error)

    var errorDescription: String? {
        switch self {
        case .usernameTaken:
            return "This username is already taken"
        case .userNotFound:
            return "User not found"
        case .invalidUsername:
            return "Username must be 3-20 characters and contain only letters, numbers, and underscores"
        case .firestoreError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class UserService: ObservableObject {
    static let shared = UserService()

    private let db = Firestore.firestore()
    private let usersCollection = "users"

    @Published var currentUser: FAFUser?

    private init() {}

    // MARK: - Username Validation

    func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        return username.range(of: usernameRegex, options: .regularExpression) != nil
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let lowercasedUsername = username.lowercased()
        let snapshot = try await db.collection(usersCollection)
            .whereField("username", isEqualTo: lowercasedUsername)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.isEmpty
    }

    // MARK: - User CRUD

    func createUser(userId: String, email: String, username: String, location: String) async throws {
        let lowercasedUsername = username.lowercased()

        guard isValidUsername(username) else {
            throw UserServiceError.invalidUsername
        }

        guard try await isUsernameAvailable(username) else {
            throw UserServiceError.usernameTaken
        }

        let user = FAFUser(
            email: email,
            username: lowercasedUsername,
            displayName: nil,
            location: location,
            profileImageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let userRef = db.collection(usersCollection).document(userId)
        try userRef.setData(from: user)

        // Fetch the user to get the document with proper @DocumentID
        _ = try await fetchUser(userId: userId)
    }

    func fetchUser(userId: String) async throws -> FAFUser? {
        let doc = try await db.collection(usersCollection).document(userId).getDocument()

        guard doc.exists else { return nil }

        let user = try doc.data(as: FAFUser.self)
        self.currentUser = user
        return user
    }

    func updateUser(_ user: FAFUser) async throws {
        guard let userId = user.id else {
            throw UserServiceError.userNotFound
        }

        var updatedUser = user
        updatedUser.updatedAt = Date()

        try db.collection(usersCollection).document(userId).setData(from: updatedUser, merge: true)
        self.currentUser = updatedUser
    }

    func updateUsername(userId: String, newUsername: String) async throws {
        let lowercasedNew = newUsername.lowercased()

        guard isValidUsername(newUsername) else {
            throw UserServiceError.invalidUsername
        }

        guard try await isUsernameAvailable(newUsername) else {
            throw UserServiceError.usernameTaken
        }

        let userRef = db.collection(usersCollection).document(userId)
        try await userRef.updateData(["username": lowercasedNew, "updatedAt": Date()])

        if var user = currentUser {
            user.username = lowercasedNew
            self.currentUser = user
        }
    }

    func clearCurrentUser() {
        currentUser = nil
    }
}
