import Foundation
import FirebaseStorage
import UIKit

/// ImageStorage provides async upload/download of images to Firebase Storage with local disk caching.
struct ImageStorage {
    private static let cacheDirectory: URL = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("employeeImages", isDirectory: true)
    }()

    /// Download an image by URL, using disk cache if available. Calls completion with image data if successful.
    static func downloadImage(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        let cacheURL = cacheURLForImage(url: url)

        // Try disk cache first
        if let data = try? Data(contentsOf: cacheURL) {
            completion(.success(data))
            return
        }
        // Fall back to network
        let storageRef = Storage.storage().reference(forURL: url.absoluteString)
        storageRef.getData(maxSize: 8 * 1024 * 1024) { data, error in
            if let data = data {
                // Save to cache
                try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                try? data.write(to: cacheURL, options: .atomic)
                completion(.success(data))
            } else if let error = error {
                completion(.failure(error))
            } else {
                completion(.failure(NSError(domain: "ImageStorage", code: -1)))
            }
        }
    }

    /// Upload an image and return the resulting download URL. Optionally caches the image data.
    static func uploadImage(_ image: UIImage, for id: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            completion(.failure(NSError(domain: "ImageStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image as JPEG"])));
            return
        }
        let storageRef = Storage.storage().reference().child("employeeImages/\(id).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        storageRef.putData(data, metadata: metadata) { meta, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            storageRef.downloadURL { url, error in
                if let url = url {
                    // Save to cache
                    let cacheURL = cacheURLForImage(url: url)
                    try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                    try? data.write(to: cacheURL, options: .atomic)
                    completion(.success(url))
                } else if let error = error {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Returns the local cache URL for a remote image.
    private static func cacheURLForImage(url: URL) -> URL {
        cacheDirectory.appendingPathComponent(url.lastPathComponent)
    }
}
