import CoreGraphics
import Photos
import UIKit

@MainActor
final class PhotoManager {
    static let shared = PhotoManager()

    private(set) var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var assetIDs: [String] = []

    private var assetsByID: [String: PHAsset] = [:]
    private let imageManager = PHCachingImageManager()
    private let imageCache = NSCache<NSString, UIImage>()

    var accessState: LibraryAccessState {
        switch authorizationStatus {
        case .authorized, .limited:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAccessIfNeeded() async {
        refreshAuthorizationStatus()

        guard authorizationStatus == .notDetermined else {
            return
        }

        authorizationStatus = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func loadPhotos() {
        guard accessState == .authorized else {
            assetIDs = []
            assetsByID = [:]
            return
        }

        // Fetch only photos, newest first.
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: options)

        var ids: [String] = []
        ids.reserveCapacity(fetchResult.count)

        var mapping: [String: PHAsset] = [:]
        mapping.reserveCapacity(fetchResult.count)

        fetchResult.enumerateObjects { asset, _, _ in
            ids.append(asset.localIdentifier)
            mapping[asset.localIdentifier] = asset
        }

        assetIDs = ids
        assetsByID = mapping
    }

    func removeAssets(withIDs ids: Set<String>) {
        guard !ids.isEmpty else { return }

        assetIDs.removeAll { ids.contains($0) }
        for id in ids {
            assetsByID[id] = nil
            imageCache.removeObject(forKey: id as NSString)
        }
    }

    func thumbnail(for assetID: String, targetSize: CGSize) async -> UIImage? {
        if let cached = imageCache.object(forKey: assetID as NSString) {
            return cached
        }

        guard let asset = assetsByID[assetID] else {
            return nil
        }

        let scale = UIScreen.main.scale
        let size = CGSize(width: max(1, targetSize.width * scale), height: max(1, targetSize.height * scale))

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            var didResume = false

            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard didResume == false else { return }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false

                if isCancelled {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                if isDegraded == false {
                    didResume = true
                    continuation.resume(returning: image)
                }
            }
        }

        if let image {
            imageCache.setObject(image, forKey: assetID as NSString)
        }

        return image
    }

    func preheatThumbnails(around index: Int, targetSize: CGSize, window: Int = 8) {
        guard !assetIDs.isEmpty else { return }

        let start = max(index + 1, 0)
        let end = min(index + window, assetIDs.count - 1)
        guard start <= end else { return }

        let ids = Array(assetIDs[start...end])
        let assets = ids.compactMap { assetsByID[$0] }
        guard !assets.isEmpty else { return }

        let size = CGSize(width: max(1, targetSize.width * UIScreen.main.scale), height: max(1, targetSize.height * UIScreen.main.scale))
        imageManager.startCachingImages(for: assets, targetSize: size, contentMode: .aspectFill, options: nil)
    }

    func deleteAssets(with ids: [String]) async throws {
        let uniqueIDs = Array(Set(ids))
        let assets = uniqueIDs.compactMap { assetsByID[$0] }
        guard !assets.isEmpty else { return }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Swipey.DeleteError", code: 1))
                }
            }
        }
    }
}
