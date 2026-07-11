import CoreGraphics
import AVFoundation
import Photos
import UIKit

@MainActor
final class PhotoManager {
    static let shared = PhotoManager()

    private(set) var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var assets: [MediaAsset] = []

    private var assetsByID: [String: PHAsset] = [:]
    private let imageManager = PHCachingImageManager()
    private let imageCache = NSCache<NSString, UIImage>()
    private let videoCache = NSCache<NSString, AVPlayerItem>()

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

    func loadAssets() {
        guard accessState == .authorized else {
            assets = []
            assetsByID = [:]
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        let fetchResult = PHAsset.fetchAssets(with: options)

        var loadedAssets: [MediaAsset] = []
        loadedAssets.reserveCapacity(fetchResult.count)

        var mapping: [String: PHAsset] = [:]
        mapping.reserveCapacity(fetchResult.count)

        fetchResult.enumerateObjects { asset, _, _ in
            let type: MediaAssetType?
            switch asset.mediaType {
            case .image:
                type = .photo
            case .video:
                type = .video
            default:
                type = nil
            }

            guard let type else { return }

            loadedAssets.append(.init(id: asset.localIdentifier, type: type))
            mapping[asset.localIdentifier] = asset
        }

        assets = loadedAssets
        assetsByID = mapping
    }

    func removeAssets(withIDs ids: Set<String>) {
        guard !ids.isEmpty else { return }

        assets.removeAll { ids.contains($0.id) }
        for id in ids {
            assetsByID[id] = nil
            imageCache.removeObject(forKey: id as NSString)
            videoCache.removeObject(forKey: id as NSString)
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
        guard !assets.isEmpty else { return }

        let start = max(index + 1, 0)
        let end = min(index + window, assets.count - 1)
        guard start <= end else { return }

        let ids = Array(assets[start...end].map(\.id))
        let assets = ids.compactMap { assetsByID[$0] }
        guard !assets.isEmpty else { return }

        let size = CGSize(width: max(1, targetSize.width * UIScreen.main.scale), height: max(1, targetSize.height * UIScreen.main.scale))
        imageManager.startCachingImages(for: assets, targetSize: size, contentMode: .aspectFill, options: nil)
    }

    func playerItem(for assetID: String) async -> AVPlayerItem? {
        if let cached = videoCache.object(forKey: assetID as NSString) {
            return cached.copy() as? AVPlayerItem
        }

        guard let asset = assetsByID[assetID], asset.mediaType == .video else {
            return nil
        }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        let item = await withCheckedContinuation { (continuation: CheckedContinuation<AVPlayerItem?, Never>) in
            imageManager.requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
                continuation.resume(returning: playerItem)
            }
        }

        if let item {
            videoCache.setObject(item, forKey: assetID as NSString)
            return item.copy() as? AVPlayerItem ?? item
        }

        return nil
    }

    func deleteAssets(with ids: [String]) async throws {
        let uniqueIDs = Array(Set(ids))
        let assets = uniqueIDs.compactMap { assetsByID[$0] }
        guard !assets.isEmpty else { return }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }
}
