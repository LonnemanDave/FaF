import SwiftUI

struct AISettingsView: View {
    @ObservedObject var aiService = AIService.shared
    @Environment(\.dismiss) var dismiss

    @State private var apiKeyInput = ""
    @State private var isShowingKey = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRemoveConfirmation = false
    @State private var showSuccessMessage = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: FAFSpacing.lg) {
                    // Header Info
                    headerSection

                    // API Key Input Section
                    apiKeySection

                    // Features Section
                    featuresSection

                    // Help Section
                    helpSection
                }
                .padding(.horizontal, FAFSpacing.lg)
                .padding(.vertical, FAFSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fafBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        FAFIcon(.close, size: 20, color: .fafGrayDark)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("AI Assistant")
                        .font(FAFTypography.h3)
                        .foregroundColor(.fafTextPrimary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Remove API Key?", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    aiService.removeAPIKey()
                    apiKeyInput = ""
                }
            } message: {
                Text("This will disable AI features until you add a new API key.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: FAFSpacing.md) {
            // AI Icon
            ZStack {
                Circle()
                    .fill(Color.fafSage.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.fafSage)
            }

            VStack(spacing: FAFSpacing.xs) {
                Text("Claude AI Integration")
                    .font(FAFTypography.h2)
                    .foregroundColor(.fafTextPrimary)

                Text("Use your Claude API key to unlock AI-powered recipe and meal plan generation.")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, FAFSpacing.md)
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            // Status
            HStack(spacing: FAFSpacing.sm) {
                Circle()
                    .fill(aiService.hasValidAPIKey ? Color.fafSage : Color.fafGray)
                    .frame(width: 10, height: 10)

                Text(aiService.hasValidAPIKey ? "API Key Configured" : "Not Configured")
                    .font(FAFTypography.label)
                    .foregroundColor(aiService.hasValidAPIKey ? .fafSage : .fafGray)

                Spacer()

                if showSuccessMessage {
                    Text("Validated!")
                        .font(FAFTypography.label)
                        .foregroundColor(.fafSage)
                        .transition(.opacity)
                }
            }

            // Input Field
            VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                Text("API Key")
                    .font(FAFTypography.label)
                    .foregroundColor(.fafGrayDark)

                HStack(spacing: FAFSpacing.sm) {
                    Group {
                        if isShowingKey {
                            TextField("sk-ant-...", text: $apiKeyInput)
                        } else {
                            SecureField("sk-ant-...", text: $apiKeyInput)
                        }
                    }
                    .font(FAFTypography.body)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                    Button {
                        isShowingKey.toggle()
                    } label: {
                        Image(systemName: isShowingKey ? "eye.slash" : "eye")
                            .foregroundColor(.fafGray)
                    }
                }
                .padding(FAFSpacing.md)
                .background(Color.fafBackgroundSecondary)
                .cornerRadius(FAFRadius.md)
            }

            // Buttons
            HStack(spacing: FAFSpacing.md) {
                Button {
                    validateAPIKey()
                } label: {
                    HStack(spacing: FAFSpacing.xs) {
                        if aiService.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Text(aiService.hasValidAPIKey ? "Update Key" : "Validate & Save")
                        }
                    }
                    .font(FAFTypography.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FAFSpacing.sm)
                    .background(apiKeyInput.isEmpty ? Color.fafGray : Color.fafSage)
                    .cornerRadius(FAFRadius.md)
                }
                .disabled(apiKeyInput.isEmpty || aiService.isLoading)

                if aiService.hasValidAPIKey {
                    Button {
                        showRemoveConfirmation = true
                    } label: {
                        Text("Remove")
                            .font(FAFTypography.button)
                            .foregroundColor(.fafCoral)
                            .padding(.vertical, FAFSpacing.sm)
                            .padding(.horizontal, FAFSpacing.lg)
                            .background(Color.fafCoral.opacity(0.1))
                            .cornerRadius(FAFRadius.md)
                    }
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("What You Can Do")
                .font(FAFTypography.h3)
                .foregroundColor(.fafTextPrimary)

            VStack(spacing: FAFSpacing.sm) {
                FeatureRow(
                    icon: "fork.knife",
                    title: "Generate Recipes",
                    description: "Describe a dish and get a complete recipe with ingredients and steps"
                )

                FeatureRow(
                    icon: "calendar",
                    title: "Create Meal Plans",
                    description: "Get personalized meal plans based on your dietary preferences"
                )

                FeatureRow(
                    icon: "magnifyingglass",
                    title: "Smart Search",
                    description: "Find recipes in our database or generate new ones if none exist"
                )
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Help Section

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("How to Get an API Key")
                .font(FAFTypography.h3)
                .foregroundColor(.fafTextPrimary)

            VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                HelpStep(number: 1, text: "Go to console.anthropic.com")
                HelpStep(number: 2, text: "Create an account or sign in")
                HelpStep(number: 3, text: "Navigate to API Keys")
                HelpStep(number: 4, text: "Create a new key and copy it here")
            }

            Link(destination: URL(string: "https://console.anthropic.com")!) {
                HStack {
                    Text("Open Anthropic Console")
                        .font(FAFTypography.button)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14))
                }
                .foregroundColor(.fafSage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FAFSpacing.sm)
                .background(Color.fafSage.opacity(0.1))
                .cornerRadius(FAFRadius.md)
            }

            Text("Your API key is stored securely on your device and is never sent to our servers.")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
                .multilineTextAlignment(.center)
                .padding(.top, FAFSpacing.xs)
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Actions

    private func validateAPIKey() {
        Task {
            do {
                try await aiService.validateAndStoreAPIKey(apiKeyInput)
                withAnimation {
                    showSuccessMessage = true
                }
                apiKeyInput = ""

                // Hide success message after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSuccessMessage = false
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: FAFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.fafSage)
                .frame(width: 32, height: 32)
                .background(Color.fafSage.opacity(0.1))
                .cornerRadius(FAFRadius.sm)

            VStack(alignment: .leading, spacing: FAFSpacing.xxxs) {
                Text(title)
                    .font(FAFTypography.label)
                    .foregroundColor(.fafTextPrimary)

                Text(description)
                    .font(FAFTypography.bodySmall)
                    .foregroundColor(.fafGray)
            }

            Spacer()
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafBackgroundSecondary)
        .cornerRadius(FAFRadius.md)
    }
}

// MARK: - Help Step

struct HelpStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: FAFSpacing.sm) {
            Text("\(number)")
                .font(FAFTypography.label)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.fafSage)
                .clipShape(Circle())

            Text(text)
                .font(FAFTypography.body)
                .foregroundColor(.fafTextPrimary)

            Spacer()
        }
    }
}

#Preview {
    AISettingsView()
}
