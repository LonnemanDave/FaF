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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingXL) {
                cover
                    .padding(.top, 60)

                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    journalField("Email", field: .email) {
                        TextField(text: $email, prompt: Text("you@example.com").foregroundColor(Theme.ink3)) { Text("Email") }
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    journalField("Password", field: .password, note: isSignUp ? "6 or more" : nil) {
                        SecureField(text: $password, prompt: Text("Password").foregroundColor(Theme.ink3)) { Text("Password") }
                            .textContentType(isSignUp ? .newPassword : .password)
                            .submitLabel(isSignUp ? .next : .go)
                            .onSubmit {
                                if isSignUp {
                                    focusedField = .confirmPassword
                                } else if isFormValid {
                                    submit()
                                }
                            }
                    }

                    if isSignUp {
                        journalField("Once more", field: .confirmPassword) {
                            SecureField(text: $confirmPassword, prompt: Text("The same password").foregroundColor(Theme.ink3)) { Text("Confirm password") }
                                .textContentType(.newPassword)
                                .submitLabel(.go)
                                .onSubmit { if isFormValid { submit() } }
                        }
                    } else {
                        HStack {
                            Spacer()
                            MarginButton("Forgot password?") { showResetPassword = true }
                        }
                    }

                    Button {
                        submit()
                    } label: {
                        if authManager.isLoading {
                            ProgressView().tint(Theme.paper)
                        } else {
                            Text(isSignUp ? "Start your journal" : "Sign in")
                        }
                    }
                    .buttonStyle(.press)
                    .disabled(!isFormValid || authManager.isLoading)
                }

                HStack(spacing: Theme.spacingSM) {
                    Rule()
                    Text("or".uppercased())
                        .smallCaps(10, weight: .medium, tracking: 1.4)
                        .foregroundColor(Theme.ink3)
                        .fixedSize()
                    Rule()
                }

                VStack(spacing: Theme.spacingSM) {
                    Button("Sign in with Google") {
                        Task { await handleGoogleSignIn() }
                    }
                    .buttonStyle(.pressOutline)

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
                    // Apple's own button, squared off and inked to match the page.
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 46)
                    .id(colorScheme)
                }

                HStack(spacing: Theme.spacingSM) {
                    Text(isSignUp ? "Already keeping one?" : "No journal yet?")
                        .font(.setting(14))
                        .foregroundColor(Theme.ink2)
                    MarginButton(isSignUp ? "Sign in" : "Start one") {
                        withAnimation {
                            isSignUp.toggle()
                            clearForm()
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Text("By continuing you agree to the [Terms of use](https://faf-1-93659.web.app/terms) and [Privacy policy](https://faf-1-93659.web.app/privacy).")
                    .font(.setting(12))
                    .foregroundColor(Theme.ink3)
                    .tint(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Theme.spacingLG)
            }
            .page()
        }
        .background(Theme.paper)
        .scrollDismissesKeyboard(.interactively)
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

    /// The journal's cover: double rule, the title, what it is, a hairline.
    private var cover: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 16)
            Text("Food & Friends")
                .font(.plate(40))
                .foregroundColor(Theme.ink)
            Text("A cook's journal".uppercased())
                .smallCaps(11, weight: .medium, tracking: 1.6)
                .foregroundColor(Theme.ink2)
                .padding(.top, 6)
            Rule()
                .padding(.top, 16)
        }
    }

    /// A line to write on — label, entry, a rule that darkens while writing —
    /// with the screen's own focus, so Next moves down the page.
    private func journalField<Entry: View>(
        _ label: String, field: Field, note: String? = nil, @ViewBuilder entry: () -> Entry
    ) -> some View {
        let active = focusedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .smallCaps(10, weight: .semibold, tracking: 1.4)
                    .foregroundColor(active ? Theme.ink : Theme.ink2)
                Spacer(minLength: 0)
                if let note {
                    Text(note).font(.setting(11)).foregroundColor(Theme.ink3)
                }
            }
            entry()
                .font(.setting(17))
                .foregroundColor(Theme.ink)
                .tint(Theme.accent)
                .focused($focusedField, equals: field)
            Rule(weight: active ? 1.5 : 1, color: active ? Theme.ink : Theme.rule)
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

// MARK: - Reset Password View

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                PlateHeader(title: "Reset password", subtitle: "A link by email")

                Text("Write the email you signed up with and we'll send a link to set a new password.")
                    .font(.setting(15))
                    .foregroundColor(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                FieldLine(label: "Email", text: $email, prompt: "you@example.com")
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { sendReset() }

                Button {
                    sendReset()
                } label: {
                    if isLoading {
                        ProgressView().tint(Theme.paper)
                    } else {
                        Text("Send the link")
                    }
                }
                .buttonStyle(.press)
                .disabled(email.isEmpty || isLoading)

                Spacer()
            }
            .padding(.top, Theme.spacingSM)
            .page()
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Cancel") { dismiss() }
                }
            }
            .alert("Sent", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Check your inbox for the reset link.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func sendReset() {
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
