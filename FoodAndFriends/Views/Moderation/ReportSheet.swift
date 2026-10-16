import SwiftUI

/// What's being reported, carried from wherever the report was started.
struct ReportSubject: Identifiable {
    let target: ReportTarget
    let targetId: String
    /// Whose it is — nil only when that's unknown.
    let authorId: String?
    let authorUsername: String?
    /// A title or a name, so the report reads sensibly to whoever reviews it.
    var label: String?

    var id: String { "\(target.rawValue)-\(targetId)" }
}

/// Reporting, set as a page: why, an optional line, and send. Once sent,
/// the page says what happens next and offers to block the person too.
struct ReportSheet: View {
    let subject: ReportSubject

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var moderation = ModerationService.shared

    @State private var reason: ReportReason?
    @State private var note = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String?
    @State private var confirmBlock = false

    private var canBlock: Bool {
        guard let authorId = subject.authorId else { return false }
        return authorId != UserService.shared.currentUser?.id && !moderation.isBlocked(authorId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingXL) {
                    if sent {
                        thanks
                    } else {
                        form
                    }
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
                    MarginButton(sent ? "Done" : "Cancel") { dismiss() }
                }
            }
            .blockConfirmation(
                username: subject.authorUsername,
                userId: subject.authorId,
                isPresented: $confirmBlock
            ) { dismiss() }
        }
    }

    // MARK: - The form

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXL) {
            PlateHeader(
                title: "Report this \(subject.target.noun)",
                subtitle: subject.label ?? subject.authorUsername.map { "@\($0)" }
            )

            Text("Tell us what's wrong. Reports are private — the person isn't told who sent one.")
                .font(.setting(15))
                .foregroundColor(Theme.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                SectionHead(title: "Why")
                    .padding(.bottom, 2)
                ForEach(Array(ReportReason.allCases.enumerated()), id: \.element.id) { position, option in
                    Button {
                        reason = option
                    } label: {
                        HStack(spacing: Theme.spacingSM) {
                            TickBox(ticked: reason == option)
                            Text(option.rawValue)
                                .font(.setting(16))
                                .foregroundColor(Theme.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(reason == option ? .isSelected : [])
                    if position < ReportReason.allCases.count - 1 {
                        DashedDivider()
                    }
                }
            }

            FieldLine(label: "Anything else", text: $note, prompt: "Optional", multiline: true,
                      note: note.isEmpty ? nil : "\(note.count)/1000")

            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView().tint(Theme.paper)
                    } else {
                        Text("Send the report")
                    }
                }
                .buttonStyle(.press)
                .disabled(reason == nil || isSending)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.setting(12).italic())
                        .foregroundColor(Theme.error)
                }
            }
        }
    }

    // MARK: - Sent

    private var thanks: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            PlateHeader(title: "Thank you", subtitle: "The report is in")

            Text("We read every report, usually within a day. Anything that breaks the rules is taken down, and people who keep breaking them lose their account.")
                .font(.setting(15))
                .foregroundColor(Theme.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if canBlock, let username = subject.authorUsername {
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    Text("Don't want to see @\(username) at all?")
                        .font(.setting(15).italic())
                        .foregroundColor(Theme.ink2)
                    Button("Block @\(username)") { confirmBlock = true }
                        .buttonStyle(.pressOutline)
                }
            }

            Button("Done") { dismiss() }
                .buttonStyle(.press)
        }
    }

    private func send() async {
        guard let reason else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        var context: [String: String] = [:]
        if let label = subject.label { context["label"] = label }
        if let username = subject.authorUsername { context["username"] = username }
        do {
            try await moderation.report(
                subject.target,
                id: subject.targetId,
                author: subject.authorId,
                reason: reason,
                note: note,
                context: context
            )
            withAnimation(.easeOut(duration: 0.2)) { sent = true }
        } catch {
            errorMessage = "It didn't send — check your connection and try again."
        }
    }
}

// MARK: - Blocking

extension View {
    /// The one confirmation every "Block" goes through: what blocking does,
    /// then does it.
    func blockConfirmation(
        username: String?,
        userId: String?,
        isPresented: Binding<Bool>,
        onBlocked: @escaping () -> Void = {}
    ) -> some View {
        confirmationDialog(
            "Block @\(username ?? "them")?",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                guard let userId else { return }
                Task {
                    try? await ModerationService.shared.block(userId)
                    onBlocked()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They're taken off your table and won't be able to send you a friend request. You won't see their recipes, menus or entries. They aren't told. You can unblock them under You.")
        }
    }
}

// MARK: - The ⋯ in the corner

/// Report and block, kept together in the margin of anything someone else
/// wrote: a recipe, a menu, a profile.
struct ModerationMenu: View {
    let subject: ReportSubject
    var onBlocked: () -> Void = {}

    @ObservedObject private var moderation = ModerationService.shared
    @State private var reporting: ReportSubject?
    @State private var confirmBlock = false
    @State private var confirmUnblock = false

    private var authorIsBlocked: Bool { moderation.isBlocked(subject.authorId) }

    var body: some View {
        Menu {
            Button {
                reporting = subject
            } label: {
                Label("Report this \(subject.target.noun)", systemImage: "flag")
            }
            if subject.target != .user, let authorId = subject.authorId {
                Button {
                    reporting = ReportSubject(target: .user, targetId: authorId, authorId: authorId,
                                              authorUsername: subject.authorUsername,
                                              label: subject.authorUsername.map { "@\($0)" })
                } label: {
                    Label("Report @\(subject.authorUsername ?? "them")", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            if subject.authorId != nil {
                if authorIsBlocked {
                    Button {
                        confirmUnblock = true
                    } label: {
                        Label("Unblock @\(subject.authorUsername ?? "them")", systemImage: "hand.raised.slash")
                    }
                } else {
                    Button(role: .destructive) {
                        confirmBlock = true
                    } label: {
                        Label("Block @\(subject.authorUsername ?? "them")", systemImage: "hand.raised")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.ink)
                .frame(width: 36, height: 36, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Report or block")
        .sheet(item: $reporting) { subject in
            ReportSheet(subject: subject)
        }
        .blockConfirmation(username: subject.authorUsername, userId: subject.authorId,
                           isPresented: $confirmBlock, onBlocked: onBlocked)
        .confirmationDialog("Unblock @\(subject.authorUsername ?? "them")?",
                            isPresented: $confirmUnblock, titleVisibility: .visible) {
            Button("Unblock") {
                guard let id = subject.authorId else { return }
                Task { try? await moderation.unblock(id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll see what they share with everyone again. You won't be friends again unless one of you asks.")
        }
    }
}
