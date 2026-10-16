import SwiftUI

/// The photographs pinned to one step — a row of small squares under the
/// step's text, and, for the recipe's own cook, a PHOTO mark in the margin
/// to take another. Friends see the row but can't add to it.
struct StepPhotoStrip: View {
    let photos: [String]
    var canAdd: Bool = false
    var isUploading: Bool = false
    var onAdd: () -> Void = {}
    var onOpen: (String) -> Void = { _ in }

    var body: some View {
        if !photos.isEmpty || canAdd {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacingSM) {
                    ForEach(photos, id: \.self) { url in
                        Button {
                            onOpen(url)
                        } label: {
                            PhotoPlate(url: url, height: 64, placeholder: "")
                                .frame(width: 64)
                                .clipped()
                                .overlay(Rectangle().stroke(Theme.rule, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Step photo")
                    }

                    if canAdd {
                        Button(action: onAdd) {
                            ZStack {
                                Rectangle()
                                    .strokeBorder(Theme.ink3, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                if isUploading {
                                    ProgressView().tint(Theme.ink3)
                                } else {
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera")
                                            .font(.system(size: 15))
                                        Text("Photo".uppercased())
                                            .smallCaps(8, weight: .semibold, tracking: 1.1)
                                    }
                                    .foregroundColor(Theme.ink2)
                                }
                            }
                            .frame(width: 64, height: 64)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)
                        .accessibilityLabel("Add a photo to this step")
                    }
                }
                .padding(.vertical, 1)
            }
            // The page's room for the thumb index is for vertical lists, not this row.
            .contentMargins(.bottom, 0, for: .scrollContent)
        }
    }
}

/// One step photograph, as large as the page allows, with the step it
/// belongs to underneath — and, for its cook, a way to take it out.
struct StepPhotoViewer: View {
    let url: String
    let caption: String
    var onRemove: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var confirmRemove = false

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
                Spacer(minLength: 0)
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Done") { dismiss() }
                }
                if onRemove != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        MarginButton("Remove", destructive: true) { confirmRemove = true }
                    }
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
