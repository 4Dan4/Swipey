import ComposableArchitecture
import CoreGraphics
import UIKit

@DependencyClient
struct PhotoLibraryClient: Sendable {
    var requestAccessIfNeeded: @Sendable () async -> LibraryAccessState = { .notDetermined }
    var refreshAuthorizationStatus: @Sendable () async -> LibraryAccessState = { .notDetermined }
    var loadPhotos: @Sendable () async -> [String] = { [] }
    var preheatThumbnails: @Sendable (_ index: Int, _ targetSize: CGSize, _ window: Int) async -> Void = { _, _, _ in }
    var deleteAssets: @Sendable (_ ids: [String]) async throws -> Void
    var thumbnail: @Sendable (_ assetID: String, _ targetSize: CGSize) async -> UIImage? = { _, _ in nil }
}

extension PhotoLibraryClient: DependencyKey {
    static let liveValue = Self(
        requestAccessIfNeeded: {
            let manager = await MainActor.run { PhotoManager.shared }
            await manager.requestAccessIfNeeded()
            return await MainActor.run {
                manager.refreshAuthorizationStatus()
                return manager.accessState
            }
        },
        refreshAuthorizationStatus: {
            let manager = await MainActor.run { PhotoManager.shared }
            return await MainActor.run {
                manager.refreshAuthorizationStatus()
                return manager.accessState
            }
        },
        loadPhotos: {
            let manager = await MainActor.run { PhotoManager.shared }
            return await MainActor.run {
                manager.loadPhotos()
                return manager.assetIDs
            }
        },
        preheatThumbnails: { index, targetSize, window in
            let manager = await MainActor.run { PhotoManager.shared }
            await MainActor.run {
                manager.preheatThumbnails(around: index, targetSize: targetSize, window: window)
            }
        },
        deleteAssets: { ids in
            let manager = await MainActor.run { PhotoManager.shared }
            try await manager.deleteAssets(with: ids)
            await MainActor.run {
                manager.removeAssets(withIDs: Set(ids))
            }
        },
        thumbnail: { assetID, targetSize in
            let manager = await MainActor.run { PhotoManager.shared }
            return await manager.thumbnail(for: assetID, targetSize: targetSize)
        }
    )
}

extension DependencyValues {
    var photoLibraryClient: PhotoLibraryClient {
        get { self[PhotoLibraryClient.self] }
        set { self[PhotoLibraryClient.self] = newValue }
    }
}
