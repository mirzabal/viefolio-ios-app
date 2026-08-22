import Foundation
import FirebaseStorage
import UIKit

// MARK: - Storage Service

final class StorageService {
    static let shared = StorageService()

    private let storage = Storage.storage()

    private init() {}

    func uploadAvatar(_ data: Data, userUid: String) async throws -> String {
        try await upload(data, path: "profiles/\(userUid)/avatar")
    }

    /// One object per image — a fixed per-project path would make a second
    /// upload overwrite the first.
    func uploadProjectImage(_ data: Data, userUid: String, projectId: String) async throws -> String {
        try await upload(data, path: "project-images/\(userUid)/\(projectId)/\(UUID().uuidString)")
    }

    private func upload(_ data: Data, path: String) async throws -> String {
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL().absoluteString
    }

    static func preparedJPEG(from data: Data, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
