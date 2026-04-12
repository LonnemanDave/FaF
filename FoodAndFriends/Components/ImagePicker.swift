import SwiftUI
import PhotosUI

// MARK: - Profile Image View with Edit

// Wrapper to make UIImage identifiable for fullScreenCover(item:)
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ProfileImagePicker: View {
    @Binding var selectedImage: UIImage?
    var currentImageURL: String?
    var size: CGFloat = 100

    @State private var selectedItem: PhotosPickerItem?
    @State private var imageToEdit: IdentifiableImage?
    @State private var showFullImage = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main image - tap to view full screen
            Button {
                if selectedImage != nil || currentImageURL != nil {
                    showFullImage = true
                }
            } label: {
                profileImage
            }

            // Camera button - tap to change photo
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Circle()
                    .fill(Color.fafCoral)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    )
            }
            .offset(x: 4, y: 4)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        imageToEdit = IdentifiableImage(image: image)
                    }
                }
            }
        }
        .fullScreenCover(item: $imageToEdit) { item in
            ImageCropperView(image: item.image) { croppedImage in
                selectedImage = croppedImage
                imageToEdit = nil
            } onCancel: {
                imageToEdit = nil
                selectedItem = nil
            }
        }
        .fullScreenCover(isPresented: $showFullImage) {
            FullScreenImageView(
                image: selectedImage,
                imageURL: currentImageURL,
                onDismiss: { showFullImage = false }
            )
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        if let image = selectedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let urlString = currentImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    placeholderView
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholderView
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        Circle()
            .fill(Color.fafGrayXLight)
            .frame(width: size, height: size)
            .overlay(
                FAFIcon(.profile, size: size * 0.4, color: .fafGray)
            )
    }
}

// MARK: - Full Screen Image View

struct FullScreenImageView: View {
    let image: UIImage?
    let imageURL: String?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let urlString = imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure(_):
                        Text("Failed to load image")
                            .foregroundColor(.white)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Image Cropper View

struct ImageCropperView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var minScale: CGFloat = 0.5

    private func cropSize(for geometry: GeometryProxy) -> CGFloat {
        // Crop circle is 90% of screen width
        geometry.size.width * 0.9
    }

    private func calculateMinScale(for geometry: GeometryProxy) -> CGFloat {
        // Calculate scale needed to fit entire image in crop circle
        let cropDiameter = cropSize(for: geometry)
        let imageAspect = image.size.width / image.size.height

        // The image is displayed with scaledToFit behavior for min scale calculation
        let displayWidth: CGFloat
        let displayHeight: CGFloat

        if imageAspect > 1 {
            // Landscape: width is limiting factor
            displayWidth = geometry.size.width
            displayHeight = geometry.size.width / imageAspect
        } else {
            // Portrait: height is limiting factor
            displayHeight = geometry.size.width
            displayWidth = geometry.size.width * imageAspect
        }

        // Min scale allows the smallest dimension to fit in crop circle
        let smallestDimension = min(displayWidth, displayHeight)
        return cropDiameter / max(smallestDimension, cropDiameter)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func magnificationGesture(minScale: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), 5.0)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    var body: some View {
        GeometryReader { geometry in
            let currentCropSize = cropSize(for: geometry)
            let currentMinScale = calculateMinScale(for: geometry)

            ZStack {
                Color.black.ignoresSafeArea()

                // Image with gestures
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .scaleEffect(scale)
                    .offset(offset)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .gesture(
                        SimultaneousGesture(dragGesture, magnificationGesture(minScale: currentMinScale))
                    )

                // Crop overlay
                cropOverlay(geometry: geometry, cropSize: currentCropSize)
                    .allowsHitTesting(false)

                // Controls at top
                VStack {
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .padding()

                        Spacer()

                        Text("Move and Scale")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Button("Done") {
                            let cropped = cropImage(geometry: geometry, cropSize: currentCropSize)
                            onSave(cropped)
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.fafCoral)
                        .padding()
                    }
                    .padding(.top, 60)

                    Spacer()
                }
            }
            .onAppear {
                minScale = currentMinScale
            }
        }
        .defersSystemGestures(on: .all)
        .statusBarHidden()
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func cropOverlay(geometry: GeometryProxy, cropSize: CGFloat) -> some View {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2

        ZStack {
            // Darkened overlay with hole
            Color.black.opacity(0.6)
                .mask(
                    ZStack {
                        Rectangle()
                        Circle()
                            .frame(width: cropSize, height: cropSize)
                            .position(x: centerX, y: centerY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )

            // Circle border
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: cropSize, height: cropSize)
                .position(x: centerX, y: centerY)
        }
    }

    private func cropImage(geometry: GeometryProxy, cropSize: CGFloat) -> UIImage {
        let outputSize: CGFloat = 600 // Final square output

        // Calculate how scaledToFill displays the image in the frame
        let frameSize = geometry.size.width
        let imgW = image.size.width
        let imgH = image.size.height

        // scaledToFill uses uniform scaling to fill the frame
        let fillScale = max(frameSize / imgW, frameSize / imgH)

        // Display dimensions before user's pinch scale
        let baseDisplayW = imgW * fillScale
        let baseDisplayH = imgH * fillScale

        // Final display dimensions with user's scale applied
        let displayW = baseDisplayW * scale
        let displayH = baseDisplayH * scale

        // The crop circle center in display coordinates (relative to image center)
        // offset.width > 0 means image moved right, so crop captures more of the left
        let cropCenterInDisplayX = displayW / 2 - offset.width
        let cropCenterInDisplayY = displayH / 2 - offset.height

        // Convert crop center to original image coordinates
        let totalScale = fillScale * scale
        let cropCenterOriginalX = cropCenterInDisplayX / totalScale
        let cropCenterOriginalY = cropCenterInDisplayY / totalScale

        // Crop size in original image coordinates (same for both dimensions since uniform scale)
        let cropSizeOriginal = cropSize / totalScale

        // Calculate crop rect in original image coordinates
        var cropRect = CGRect(
            x: cropCenterOriginalX - cropSizeOriginal / 2,
            y: cropCenterOriginalY - cropSizeOriginal / 2,
            width: cropSizeOriginal,
            height: cropSizeOriginal
        )

        // Clamp to image bounds
        cropRect.origin.x = max(0, min(cropRect.origin.x, imgW - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, imgH - cropRect.height))
        cropRect.size.width = min(cropRect.width, imgW - cropRect.origin.x)
        cropRect.size.height = min(cropRect.height, imgH - cropRect.origin.y)

        // Render the cropped image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))

        return renderer.image { _ in
            if let cgImage = image.cgImage?.cropping(to: cropRect) {
                let croppedImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: image.imageOrientation)
                croppedImage.draw(in: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
            } else {
                // Fallback: draw entire image
                image.draw(in: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
            }
        }
    }
}
