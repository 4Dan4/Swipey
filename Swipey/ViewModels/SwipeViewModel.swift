import CoreGraphics
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SwipeViewModel {
    let photoManager: PhotoManager
    private let limiter: SwipeLimiter

    private(set) var isLoading = true
    private(set) var currentIndex = 0
    private(set) var queuedForDeletion: [String] = []
    private(set) var deletedCount = 0
    private(set) var accessState: LibraryAccessState = .notDetermined
    private(set) var errorMessage: String?

    var showDeleteConfirmation = false
    var isPaywallPresented = false

    private var queuedSet: Set<String> = []
    private var swipeHistory: [SwipeAction] = []
    private var didBootstrap = false

    init(photoManager: PhotoManager, limiter: SwipeLimiter) {
        self.photoManager = photoManager
        self.limiter = limiter
        self.accessState = photoManager.accessState
    }

    convenience init() {
        self.init(photoManager: PhotoManager(), limiter: SwipeLimiter())
    }

    var currentAssetID: String? {
        guard currentIndex < photoManager.assetIDs.count else { return nil }
        return photoManager.assetIDs[currentIndex]
    }

    var hasPhotos: Bool {
        currentAssetID != nil
    }

    var canSwipe: Bool {
        !limiter.isLimitReached
    }

    var shouldShowPaywall: Bool {
        accessState == .authorized && limiter.isLimitReached
    }

    var remainingSwipes: Int {
        limiter.remaining
    }

    var totalPhotosCount: Int {
        photoManager.assetIDs.count
    }

    var canUndo: Bool {
        swipeHistory.isEmpty == false
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        isLoading = true
        await photoManager.requestAccessIfNeeded()
        photoManager.refreshAuthorizationStatus()
        accessState = photoManager.accessState

        if accessState == .authorized {
            photoManager.loadPhotos()
            preheatNext()
        }

        isLoading = false
    }

    func refreshAfterSettings() {
        photoManager.refreshAuthorizationStatus()
        accessState = photoManager.accessState

        if accessState == .authorized {
            photoManager.loadPhotos()
            currentIndex = 0
            queuedForDeletion.removeAll()
            queuedSet.removeAll()
            swipeHistory.removeAll()
            preheatNext()
        }
    }

    func handleSwipe(_ direction: SwipeDirection) {
        guard let currentAssetID else { return }

        guard limiter.consumeSwipe() else {
            isPaywallPresented = true
            return
        }

        if direction == .left {
            enqueueForDeletion(assetID: currentAssetID)
        }

        swipeHistory.append(.init(assetID: currentAssetID, direction: direction))
        currentIndex += 1
        if limiter.isLimitReached {
            isPaywallPresented = true
        }
        preheatNext()
    }

    func presentPaywall() {
        isPaywallPresented = true
    }

    func undoLastSwipe() {
        guard let last = swipeHistory.popLast() else { return }

        currentIndex = max(0, currentIndex - 1)

        if last.direction == .left {
            queuedSet.remove(last.assetID)
            queuedForDeletion.removeAll { $0 == last.assetID }
        }
    }

    func queueDeletion() {
        guard !queuedForDeletion.isEmpty else { return }
        showDeleteConfirmation = true
    }

    func deleteQueuedAssets() async {
        guard !queuedForDeletion.isEmpty else { return }

        do {
            let ids = queuedForDeletion
            let deleteSet = Set(ids)

            let removedBeforeCurrent = photoManager.assetIDs[..<min(currentIndex, photoManager.assetIDs.count)]
                .filter { deleteSet.contains($0) }
                .count

            try await photoManager.deleteAssets(with: ids)
            photoManager.removeAssets(withIDs: deleteSet)

            currentIndex = max(0, currentIndex - removedBeforeCurrent)
            queuedForDeletion.removeAll()
            queuedSet.removeAll()
            swipeHistory.removeAll { deleteSet.contains($0.assetID) }
            deletedCount += ids.count
            preheatNext()
        } catch {
            errorMessage = "Не удалось удалить фото. Проверьте доступ к галерее и попробуйте ещё раз."
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func enqueueForDeletion(assetID: String) {
        guard !queuedSet.contains(assetID) else { return }

        queuedSet.insert(assetID)
        queuedForDeletion.append(assetID)
    }

    private func preheatNext() {
        photoManager.preheatThumbnails(
            around: currentIndex,
            targetSize: CGSize(width: 500, height: 900),
            window: 10
        )
    }
}
