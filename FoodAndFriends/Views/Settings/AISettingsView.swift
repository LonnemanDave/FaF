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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingXL) {
                    PlateHeader(title: "The AI assistant", subtitle: "Claude, with your own key")

                    Text("Add a Claude API key and you can ask for recipes and whole menus. The key is yours — it's kept on this phone.")
                        .font(.setting(15))
                        .foregroundColor(Theme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    sharingSection

                    apiKeySection

                    featuresSection

                    helpSection
                }
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Done") { dismiss() }
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

    // MARK: - What leaves the phone

    /// Said plainly, and agreed to, before any key can be saved.
    private var sharingSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            SectionHead(title: "What's sent, and to whom")

            Text("When you ask for a recipe or a menu, what you type — the dish, your notes, and the diets, allergies and cuisines you tick — is sent from this phone to Anthropic, the company that makes Claude, so it can write the answer. Nothing else from your journal is sent, and none of it passes through Food & Friends' servers. Anthropic handles it under its own privacy policy.")
                .font(.setting(14))
                .foregroundColor(Theme.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                aiService.setSharingConsent(!aiService.hasSharingConsent)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
                    TickBox(ticked: aiService.hasSharingConsent)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                    Text("I agree to my requests being sent to Anthropic")
                        .font(.setting(15))
                        .foregroundColor(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(aiService.hasSharingConsent ? .isSelected : [])

            Link(destination: URL(string: "https://www.anthropic.com/legal/privacy")!) {
                Text("Anthropic's privacy policy".uppercased())
                    .smallCaps(10, weight: .semibold, tracking: 1.3)
                    .foregroundColor(Theme.accent)
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            SectionHead(title: "Your key")

            // Status
            IndexEntry(
                title: "Claude API key",
                figure: aiService.hasValidAPIKey ? "Set" : "Not set",
                figureColor: aiService.hasValidAPIKey ? Theme.herb : Theme.ink3
            ) {
                if showSuccessMessage {
                    Text("Checked".uppercased())
                        .smallCaps(9, weight: .semibold, tracking: 1.2)
                        .foregroundColor(Theme.herb)
                        .fixedSize()
                        .transition(.opacity)
                }
            }

            // Input line — secure unless shown
            HStack(alignment: .bottom, spacing: Theme.spacingMD) {
                FieldLine(
                    label: aiService.hasValidAPIKey ? "A new key" : "Paste the key",
                    text: $apiKeyInput,
                    prompt: "sk-ant-…",
                    secure: !isShowingKey
                )
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                MarginButton(isShowingKey ? "Hide" : "Show") {
                    isShowingKey.toggle()
                }
                .padding(.bottom, 10)
                .accessibilityLabel(isShowingKey ? "Hide key" : "Show key")
            }

            // Buttons
            Button {
                validateAPIKey()
            } label: {
                if aiService.isLoading {
                    ProgressView()
                        .tint(Theme.paper)
                } else {
                    Text(aiService.hasValidAPIKey ? "Check and replace" : "Check and save")
                }
            }
            .buttonStyle(.press)
            .disabled(apiKeyInput.isEmpty || aiService.isLoading || !aiService.hasSharingConsent)

            if aiService.hasValidAPIKey {
                MarginButton("Remove the key", destructive: true) {
                    showRemoveConfirmation = true
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.spacingXS)
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "What it's for")
                .padding(.bottom, Theme.spacingXS)

            FeatureRow(
                icon: "fork.knife",
                title: "Ask for a recipe",
                description: "Name a dish and get it written up, ingredients and method"
            )
            DashedDivider()
            FeatureRow(
                icon: "calendar",
                title: "Plan a menu",
                description: "A week of meals, cooked to your preferences"
            )
            DashedDivider()
            FeatureRow(
                icon: "magnifyingglass",
                title: "Look in the box first",
                description: "Recipes already written are found before a new one is asked for"
            )
        }
    }

    // MARK: - Help Section

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Getting a key")

            VStack(alignment: .leading, spacing: 0) {
                HelpStep(number: 1, text: "Go to console.anthropic.com")
                HelpStep(number: 2, text: "Create an account or sign in")
                HelpStep(number: 3, text: "Open API Keys")
                HelpStep(number: 4, text: "Make a new key and paste it above")
            }

            Link(destination: URL(string: "https://console.anthropic.com")!) {
                HStack(spacing: 4) {
                    Text("Open the Anthropic console".uppercased())
                        .smallCaps(11, weight: .semibold, tracking: 1.3)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacingSM)
            }

            Text("Your key is kept in this phone's keychain and is never sent to our servers.")
                .font(.setting(12).italic())
                .foregroundColor(Theme.ink3)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
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

/// One use of the assistant: a small mark in the margin, the name in the
/// serif, a line about it underneath.
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Theme.ink3)
                .frame(width: 20, alignment: .leading)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.plate(17, .semibold))
                    .foregroundColor(Theme.ink)

                Text(description)
                    .font(.setting(13))
                    .foregroundColor(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Help Step

/// A numbered instruction, set like a step of the method.
struct HelpStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingMD) {
            Text("\(number)")
                .font(.plate(19))
                .foregroundColor(Theme.accent)
                .frame(width: 20, alignment: .leading)

            Text(text)
                .font(.setting(15))
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AISettingsView()
}
