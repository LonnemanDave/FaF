import SwiftUI

/// A step's one photograph, set full width above the step's text. With none
/// yet, the recipe's cook gets a dashed line to take one; nobody else sees
/// anything. Changing or removing it happens in the full-size view.
struct StepPhoto: View {
    let url: String?
    var canAdd: Bool = false
    var isUploading: Bool = false
    var onAdd: () -> Void = {}
    var onOpen: (String) -> Void = { _ in }

    var body: some View {
        if isUploading {
            ZStack {
                Theme.fill
                ProgressView().tint(Theme.ink3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
        } else if let url {
            Button {
                onOpen(url)
            } label: {
                NaturalPhoto(url: url)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Step photo — open it larger")
        } else if canAdd {
            Button(action: onAdd) {
                HStack(spacing: Theme.spacingSM) {
                    Image(systemName: "camera")
                        .font(.system(size: 14))
                    Text("A photo of this step".uppercased())
                        .smallCaps(9, weight: .semibold, tracking: 1.2)
                }
                .foregroundColor(Theme.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(
                    Rectangle().strokeBorder(Theme.ink3, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a photo of this step")
        }
    }
}

/// A step's photograph as large as the page allows, with the step it
/// belongs to underneath — and, for the recipe's cook only, Replace and
/// Remove.
struct StepPhotoViewer: View {
    let url: String
    let caption: String
    var onCrop: ((UIImage) -> Void)?
    var onReplace: (() -> Void)?
    var onRemove: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var confirmRemove = false
    @State private var isLoadingForCrop = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Spacer(minLength: 0)
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .empty:
                        ProgressView().tint(Theme.ink3).frame(maxWidth: .infinity, minHeight: 240)
                    default:
                        Text("This photo couldn't be loaded.")
                            .font(.setting(14).italic())
                            .foregroundColor(Theme.ink3)
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .frame(maxWidth: .infinity)

                Text(caption)
                    .font(.setting(14).italic())
                    .foregroundColor(Theme.ink2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .page()

                if onReplace != nil || onRemove != nil {
                    HStack(spacing: Theme.spacingLG) {
                        if let onCrop {
                            if isLoadingForCrop {
                                ProgressView().tint(Theme.ink3)
                            } else {
                                MarginButton("Crop") {
                                    Task {
                                        // The full photo, fetched again, to frame afresh.
                                        isLoadingForCrop = true
                                        defer { isLoadingForCrop = false }
                                        guard let link = URL(string: url),
                                              let (data, _) = try? await URLSession.shared.data(from: link),
                                              let image = UIImage(data: data) else { return }
                                        dismiss()
                                        onCrop(image)
                                    }
                                }
                            }
                        }
                        if let onReplace {
                            MarginButton("Replace") {
                                dismiss()
                                onReplace()
                            }
                        }
                        if onRemove != nil {
                            MarginButton("Remove", destructive: true) { confirmRemove = true }
                        }
                        Spacer(minLength: 0)
                    }
                    .page()
                }
                Spacer(minLength: 0)
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Done") { dismiss() }
                }
            }
            .confirmationDialog("Take this photo off the step?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    onRemove?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
