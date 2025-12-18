import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

enum AuthState: Equatable {
    case unknown
    case signedOut
    case signedIn
    case needsProfileSetup
}

enum AuthError: LocalizedError {
    case signInFailed
    case signOutFailed
    case userNotFound
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Sign in failed. Please try again."
        case .signOutFailed:
            return "Sign out failed. Please try again."
        case .userNotFound:
            return "No account found with this email."
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "An account already exists with this email."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var authState: AuthState = .unknown
    @Published var firebaseUser: FirebaseAuth.User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    private init() {
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.firebaseUser = user
                if let user = user {
                    await self?.checkUserProfile(userId: user.uid)
                } else {
                    self?.authState = .signedOut
                }
            }
        }
    }

    private func checkUserProfile(userId: String) async {
        do {
            let user = try await UserService.shared.fetchUser(userId: userId)
            if let user = user, user.isProfileComplete {
                authState = .signedIn
            } else {
                authState = .needsProfileSetup
            }
        } catch {
            authState = .needsProfileSetup
        }
    }

    // MARK: - Email/Password Auth

    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            firebaseUser = result.user
            authState = .needsProfileSetup
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            firebaseUser = result.user
            await checkUserProfile(userId: result.user.uid)
        } catch let error as NSError {
            isLoading = false
            throw mapFirebaseError(error)
        }

        isLoading = false
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isLoading = false
            throw AuthError.signInFailed
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                isLoading = false
                throw AuthError.signInFailed
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            firebaseUser = authResult.user
            await checkUserProfile(userId: authResult.user.uid)
        } catch {
            isLoading = false
            throw AuthError.unknown(error)
        }

        isLoading = false
    }

    // MARK: - Apple Sign-In

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async throws {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let nonce = currentNonce else {
                isLoading = false
                throw AuthError.signInFailed
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                firebaseUser = authResult.user
                await checkUserProfile(userId: authResult.user.uid)
            } catch {
                isLoading = false
                throw AuthError.unknown(error)
            }

        case .failure(let error):
            isLoading = false
            throw AuthError.unknown(error)
        }

        isLoading = false
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Sign Out

    func signOut() throws {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            UserService.shared.clearCurrentUser()
            authState = .signedOut
        } catch {
            throw AuthError.signOutFailed
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Helpers

    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return .unknown(error)
        }

        switch errorCode {
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .wrongPassword, .invalidCredential:
            return .invalidCredentials
        case .userNotFound:
            return .userNotFound
        case .weakPassword:
            return .weakPassword
        default:
            return .unknown(error)
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
