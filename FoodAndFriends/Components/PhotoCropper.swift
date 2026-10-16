import SwiftUI
import UIKit

/// Crop a photo to whatever shape you like before it's saved. The whole
/// photo is shown; a box sits over it. Drag a corner or an edge to resize
/// the box, drag inside it to move it. A row of shapes — the whole photo,
/// square, 4:3, 3:2, 16:9 — sets the box to the largest of that shape,
/// centred, as a place to start; after that it's free again.
struct PhotoCropper: View {
    let image: UIImage
    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    /// The box, as fractions of the photo — so it holds still whatever the
    /// screen does.
    @State private var crop = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// The box as it was when the current drag began.
    @State private var dragStart: CGRect?

    private enum Handle {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move
    }

    private static let shapes: [(label: String, ratio: CGFloat?)] = [
        ("Whole", nil), ("Square", 1), ("4:3", 4.0 / 3.0), ("3:2", 3.0 / 2.0), ("16:9", 16.0 / 9.0),
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geometry in
                let photo = photoRect(in: geometry.size)
                let box = viewRect(crop, in: photo)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: photo.width, height: photo.height)
                        .offset(x: photo.minX, y: photo.minY)

                    // Shade what's cut away.
                    Path { path in
                        path.addRect(photo)
                        path.addRect(box)
                    }
                    .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                    frameLines(box)

                    // Drag inside to move.
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: box.width, height: box.height)
                        .offset(x: box.minX, y: box.minY)
                        .gesture(drag(.move, photo: photo))

                    ForEach(handles(for: box), id: \.id) { handle in
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: handle.rect.width, height: handle.rect.height)
                            .offset(x: handle.rect.minX, y: handle.rect.minY)
                            .gesture(drag(handle.kind, photo: photo))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, Theme.spacingMD)
            shapeBar
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
    }

    // MARK: - Bars

    private var topBar: some View {
        HStack {
            Button(action: onCancel) { label("Cancel") }
            Spacer()
            Button {
                onDone(cropped())
            } label: {
                label("Use photo")
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, Theme.spacingSM)
    }

    private var shapeBar: some View {
        HStack(spacing: 0) {
            ForEach(Self.shapes, id: \.label) { shape in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { crop = largest(ratio: shape.ratio) }
                } label: {
                    Text(shape.label.uppercased())
                        .smallCaps(10, weight: .semibold, tracking: 1.2)
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.bottom, Theme.spacingMD)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .smallCaps(11, weight: .semibold, tracking: 1.4)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
    }

    // MARK: - The box, drawn

    /// The border, rule-of-thirds lines, and heavier marks at the corners.
    private func frameLines(_ box: CGRect) -> some View {
        let mark: CGFloat = 18
        return ZStack(alignment: .topLeading) {
            Path { path in
                for i in 1...2 {
                    let x = box.minX + box.width * CGFloat(i) / 3
                    let y = box.minY + box.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: box.minY)); path.addLine(to: CGPoint(x: x, y: box.maxY))
                    path.move(to: CGPoint(x: box.minX, y: y)); path.addLine(to: CGPoint(x: box.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)

            Path { $0.addRect(box) }
                .stroke(Color.white, lineWidth: 1)

            Path { path in
                for (corner, dx, dy) in [(CGPoint(x: box.minX, y: box.minY), 1.0, 1.0),
                                         (CGPoint(x: box.maxX, y: box.minY), -1.0, 1.0),
                                         (CGPoint(x: box.maxX, y: box.maxY), -1.0, -1.0),
                                         (CGPoint(x: box.minX, y: box.maxY), 1.0, -1.0)] {
                    path.move(to: CGPoint(x: corner.x + dx * mark, y: corner.y))
                    path.addLine(to: corner)
                    path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * mark))
                }
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .square))
        }
        .allowsHitTesting(false)
    }

    private struct HandleZone {
        let kind: Handle
        let rect: CGRect
        var id: String { "\(kind)" }
    }

    /// Touch zones: 44-point squares at the corners, strips along the middle
    /// of each edge. Corners come last so they win where they overlap.
    private func handles(for box: CGRect) -> [HandleZone] {
        let s: CGFloat = 44, h = s / 2
        let edgeW = max(0, box.width - s), edgeH = max(0, box.height - s)
        return [
            HandleZone(kind: .top, rect: CGRect(x: box.minX + h, y: box.minY - h, width: edgeW, height: s)),
            HandleZone(kind: .bottom, rect: CGRect(x: box.minX + h, y: box.maxY - h, width: edgeW, height: s)),
            HandleZone(kind: .left, rect: CGRect(x: box.minX - h, y: box.minY + h, width: s, height: edgeH)),
            HandleZone(kind: .right, rect: CGRect(x: box.maxX - h, y: box.minY + h, width: s, height: edgeH)),
            HandleZone(kind: .topLeft, rect: CGRect(x: box.minX - h, y: box.minY - h, width: s, height: s)),
            HandleZone(kind: .topRight, rect: CGRect(x: box.maxX - h, y: box.minY - h, width: s, height: s)),
            HandleZone(kind: .bottomLeft, rect: CGRect(x: box.minX - h, y: box.maxY - h, width: s, height: s)),
            HandleZone(kind: .bottomRight, rect: CGRect(x: box.maxX - h, y: box.maxY - h, width: s, height: s)),
        ]
    }

    // MARK: - Dragging

    private func drag(_ handle: Handle, photo: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? crop
                if dragStart == nil { dragStart = crop }
                let dx = value.translation.width / photo.width
                let dy = value.translation.height / photo.height
                crop = adjusted(start, by: handle, dx: dx, dy: dy, photo: photo)
            }
            .onEnded { _ in dragStart = nil }
    }

    /// The box after a drag, kept inside the photo and never smaller than
    /// 60 points a side.
    private func adjusted(_ r: CGRect, by handle: Handle, dx: CGFloat, dy: CGFloat, photo: CGRect) -> CGRect {
        let minW = min(1, 60 / photo.width), minH = min(1, 60 / photo.height)
        var minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY

        if handle == .move {
            let x = min(max(r.minX + dx, 0), 1 - r.width)
            let y = min(max(r.minY + dy, 0), 1 - r.height)
            return CGRect(x: x, y: y, width: r.width, height: r.height)
        }
        if [.left, .topLeft, .bottomLeft].contains(handle) { minX = min(max(r.minX + dx, 0), maxX - minW) }
        if [.right, .topRight, .bottomRight].contains(handle) { maxX = max(min(r.maxX + dx, 1), minX + minW) }
        if [.top, .topLeft, .topRight].contains(handle) { minY = min(max(r.minY + dy, 0), maxY - minH) }
        if [.bottom, .bottomLeft, .bottomRight].contains(handle) { maxY = max(min(r.maxY + dy, 1), minY + minH) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The largest box of a shape (width over height), centred; nil is the whole photo.
    private func largest(ratio: CGFloat?) -> CGRect {
        guard let ratio, image.size.width > 0, image.size.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let photoRatio = image.size.width / image.size.height
        if ratio > photoRatio {
            let height = photoRatio / ratio
            return CGRect(x: 0, y: (1 - height) / 2, width: 1, height: height)
        } else {
            let width = ratio / photoRatio
            return CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
        }
    }

    // MARK: - Geometry

    /// Where the whole photo sits: fitted into the space, centred.
    private func photoRect(in space: CGSize) -> CGRect {
        let size = image.size
        guard size.width > 0, size.height > 0, space.width > 0, space.height > 0 else { return .zero }
        let fit = min(space.width / size.width, space.height / size.height)
        let w = size.width * fit, h = size.height * fit
        return CGRect(x: (space.width - w) / 2, y: (space.height - h) / 2, width: w, height: h)
    }

    private func viewRect(_ n: CGRect, in photo: CGRect) -> CGRect {
        CGRect(x: photo.minX + n.minX * photo.width, y: photo.minY + n.minY * photo.height,
               width: n.width * photo.width, height: n.height * photo.height)
    }

    /// What's inside the box, cut from the full-resolution photo.
    private func cropped() -> UIImage {
        let size = image.size
        let rect = CGRect(x: crop.minX * size.width, y: crop.minY * size.height,
                          width: crop.width * size.width, height: crop.height * size.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            // draw(at:) honours the photo's orientation, so camera shots come out upright.
            image.draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
    }
}

/// A photo at its own shape — as cropped — full width, up to a height.
/// While it loads, a plain frame holds its place.
struct NaturalPhoto: View {
    let url: String
    var maxHeight: CGFloat = 480

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: maxHeight)
            case .empty:
                ZStack {
                    Theme.fill
                    ProgressView().tint(Theme.ink3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
            default:
                ZStack {
                    Theme.fill
                    Text("Photo unavailable".uppercased())
                        .smallCaps(9, weight: .medium, tracking: 1.3)
                        .foregroundColor(Theme.ink3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            }
        }
    }
}
