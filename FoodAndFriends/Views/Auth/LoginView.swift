import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authManager = AuthManager.shared

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showResetPassword = false

    enum Field: Hashable {
        case email, password, confirmPassword
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: FAFSpacing.xl) {
            Spacer()

            // Logo/Title
            VStack(spacing: FAFSpacing.sm) {
                FAFIcon(.fork, size: 48, color: .fafCoral)
                Text("Food & Friends")
                    .font(FAFTypography.displayMedium)
                    .foregroundColor(.fafBlack)
                Text("Share meals, make memories")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
            }

            Spacer()

            // Email/Password Form
            VStack(spacing: FAFSpacing.md) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .modifier(TextFieldStyle())

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(isSignUp ? .next : .go)
                    .onSubmit {
                        if isSignUp {
                            focusedField = .confirmPassword
                        } else if isFormValid {
                            submit()
                        }
                    }
                    .modifier(TextFieldStyle())

                if isSignUp {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            if isFormValid { submit() }
                        }
                        .modifier(TextFieldStyle())
                }

                if !isSignUp {
                    HStack {
                        Spacer()
                        Button("Forgot password?") {
                            showResetPassword = true
                        }
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                    }
                }

                FAFButton(
                    title: isSignUp ? "Sign Up" : "Sign In",
                    style: .primary,
                    isLoading: authManager.isLoading
                ) {
                    submit()
                }
                .disabled(!isFormValid)
            }

            // Divider
            HStack {
                Rectangle()
                    .fill(Color.fafGrayXLight)
                    .frame(height: 1)
                Text("or")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
                Rectangle()
                    .fill(Color.fafGrayXLight)
                    .frame(height: 1)
            }

            // Social Sign-In
            VStack(spacing: FAFSpacing.sm) {
                FAFButton(
                    title: "Sign in with Google",
                    style: .secondary
                ) {
                    Task { await handleGoogleSignIn() }
                }

                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = authManager.prepareAppleSignIn()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = nonce
                    },
                    onCompletion: { result in
                        Task { await handleAppleSignIn(result) }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)
            }

            Spacer()

            // Toggle Sign Up/Sign In
            HStack(spacing: FAFSpacing.xs) {
                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                Button(isSignUp ? "Sign In" : "Sign Up") {
                    withAnimation {
                        isSignUp.toggle()
                        clearForm()
                    }
                }
                .font(FAFTypography.button)
                .foregroundColor(.fafCoral)
            }
            .padding(.bottom, FAFSpacing.lg)
        }
        .padding(FAFSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fafWhite)
        .onTapGesture {
            focusedField = nil
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showResetPassword) {
            ResetPasswordView()
        }
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        if isSignUp {
            return emailValid && passwordValid && password == confirmPassword
        }
        return emailValid && passwordValid
    }

    private func submit() {
        focusedField = nil
        Task { await handleEmailAuth() }
    }

    private func handleEmailAuth() async {
        do {
            if isSignUp {
                try await authManager.signUp(email: email, password: password)
            } else {
                try await authManager.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleGoogleSignIn() async {
        do {
            try await authManager.signInWithGoogle()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            try await authManager.handleAppleSignIn(result)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        focusedField = nil
    }
}

// MARK: - Text Field Style

struct TextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15))
            .foregroundColor(.black)
            .tint(.fafCoral)
            .padding(16)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
    }
}

// MARK: - Reset Password View

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage = ""
    @State private var showError = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: FAFSpacing.lg) {
                Text("Enter your email and we'll send you a link to reset your password.")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .multilineTextAlignment(.center)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit { sendReset() }
                    .modifier(TextFieldStyle())

                FAFButton(
                    title: "Send Reset Link",
                    style: .primary,
                    isLoading: isLoading
                ) {
                    sendReset()
                }
                .disabled(email.isEmpty)

                Spacer()
            }
            .padding(FAFSpacing.lg)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = false }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.fafCoral)
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Password reset email sent. Check your inbox.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func sendReset() {
        isFocused = false
        Task { await sendResetLink() }
    }

    private func sendResetLink() async {
        isLoading = true
        do {
            try await AuthManager.shared.sendPasswordReset(email: email)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    LoginView()
}
