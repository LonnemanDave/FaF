import Foundation
import FirebaseStorage
import UIKit

enum StorageServiceError: LocalizedError {
    case imageConversionFailed
    case uploadFailed(Error)
    case downloadURLFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to process image"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadURLFailed:
            return "Failed to get image URL"
        }
    }
}

class StorageService {
    static let shared = StorageService()

    private let storage = Storage.storage()
    private let profileImagesPath = "profile_images"

    private init() {}

    // MARK: - Profile Image

    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        // Resize and compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageServiceError.imageConversionFailed
        }

        let filename = "\(userId).jpg"
        let ref = storage.reference().child(profileImagesPath).child(filename)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await ref.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw StorageServiceError.uploadFailed(error)
        }
    }

    func deleteProfileImage(userId: String) async throws {
        let filename = "\(userId).jpg"
        let ref = storage.reference().child(profileImagesPath).child(filename)

        do {
            try await ref.delete()
        } catch {
            // Ignore if file doesn't exist
            print("Delete profile image error (may not exist): \(error)")
        }
    }

    // MARK: - Generic Image Upload

    func uploadImage(_ image: UIImage, path: String, filename: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageServiceError.imageConversionFailed
        }

        let ref = storage.reference().child(path).child(filename)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await ref.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw StorageServiceError.uploadFailed(error)
        }
    }
}

// MARK: - UIImage Extension for Resizing

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let aspectRatio = size.width / size.height

        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
