import ComposableArchitecture
import CoreGraphics

struct SwipeFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var isLoading = true
        var currentIndex = 0
        var assetIDs: [String] = []
        var queuedForDeletion: [String] = []
        var deletedCount = 0
        var accessState: LibraryAccessState = .notDetermined
        var errorMessage: String?
        var showDeleteConfirmation = false
        var isPaywallPresented = false
        var swipeHistory: [SwipeAction] = []
        var didBootstrap = false
        var remainingSwipes = SwipeLimiter.dailyLimit

        var currentAssetID: String? {
            guard currentIndex < assetIDs.count else { return nil }
            return assetIDs[currentIndex]
        }

        var hasPhotos: Bool {
            currentAssetID != nil
        }

        var canSwipe: Bool {
            remainingSwipes > 0
        }

        var totalPhotosCount: Int {
            assetIDs.count
        }

        var canUndo: Bool {
            swipeHistory.isEmpty == false
        }
    }

    enum Action {
        case view(View)
        case bootstrapResponse(LibraryAccessState, [String], Int)
        case authorizationRefreshed(LibraryAccessState, [String], Int)
        case swipeProcessed(assetID: String, direction: SwipeDirection, consumed: Bool, remaining: Int)
        case deleteQueuedAssetsResponse(Result<DeleteResult, any Error>)
    }

    enum View {
        case task
        case retryAfterSettingsTapped
        case swipeCompleted(SwipeDirection)
        case undoTapped
        case queueDeletionTapped
        case deleteConfirmedTapped
        case deleteConfirmationDismissed
        case paywallDismissed
        case paywallPresented
        case errorDismissed
    }

    struct DeleteResult: Equatable {
        let ids: [String]
        let removedBeforeCurrent: Int
    }

    @Dependency(\.photoLibraryClient) var photoLibraryClient
    @Dependency(\.swipeLimiterClient) var swipeLimiterClient

    private let preheatSize = CGSize(width: 500, height: 900)

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(.task):
                guard !state.didBootstrap else { return .none }
                state.didBootstrap = true
                state.isLoading = true
                return .run { send in
                    let accessState = await photoLibraryClient.requestAccessIfNeeded()
                    let assetIDs = accessState == .authorized
                        ? await photoLibraryClient.loadPhotos()
                        : []
                    let remaining = await swipeLimiterClient.remaining()

                    if accessState == .authorized {
                        await photoLibraryClient.preheatThumbnails(0, preheatSize, 10)
                    }

                    await send(.bootstrapResponse(accessState, assetIDs, remaining))
                }

            case .view(.retryAfterSettingsTapped):
                state.isLoading = true
                return .run { send in
                    let accessState = await photoLibraryClient.refreshAuthorizationStatus()
                    let assetIDs = accessState == .authorized
                        ? await photoLibraryClient.loadPhotos()
                        : []
                    let remaining = await swipeLimiterClient.remaining()

                    if accessState == .authorized {
                        await photoLibraryClient.preheatThumbnails(0, preheatSize, 10)
                    }

                    await send(.authorizationRefreshed(accessState, assetIDs, remaining))
                }

            case .view(.swipeCompleted(let direction)):
                guard let currentAssetID = state.currentAssetID else { return .none }
                guard state.canSwipe else {
                    state.isPaywallPresented = true
                    return .none
                }

                return .run { send in
                    let consumed = await swipeLimiterClient.consumeSwipe()
                    let remaining = await swipeLimiterClient.remaining()
                    await send(.swipeProcessed(assetID: currentAssetID, direction: direction, consumed: consumed, remaining: remaining))
                }

            case .view(.undoTapped):
                guard let last = state.swipeHistory.popLast() else { return .none }
                state.currentIndex = max(0, state.currentIndex - 1)

                if last.direction == .left {
                    state.queuedForDeletion.removeAll { $0 == last.assetID }
                }
                return .none

            case .view(.queueDeletionTapped):
                guard !state.queuedForDeletion.isEmpty else { return .none }
                state.showDeleteConfirmation = true
                return .none

            case .view(.deleteConfirmedTapped):
                guard !state.queuedForDeletion.isEmpty else { return .none }
                state.showDeleteConfirmation = false

                let ids = state.queuedForDeletion
                let deleteSet = Set(ids)
                let removedBeforeCurrent = state.assetIDs[..<min(state.currentIndex, state.assetIDs.count)]
                    .filter { deleteSet.contains($0) }
                    .count

                return .run { send in
                    do {
                        try await photoLibraryClient.deleteAssets(ids)
                        await send(.deleteQueuedAssetsResponse(.success(DeleteResult(ids: ids, removedBeforeCurrent: removedBeforeCurrent))))
                    } catch {
                        await send(.deleteQueuedAssetsResponse(.failure(error)))
                    }
                }

            case .view(.deleteConfirmationDismissed):
                state.showDeleteConfirmation = false
                return .none

            case .view(.paywallDismissed):
                state.isPaywallPresented = false
                return .none

            case .view(.paywallPresented):
                state.isPaywallPresented = true
                return .none

            case .view(.errorDismissed):
                state.errorMessage = nil
                return .none

            case .bootstrapResponse(let accessState, let assetIDs, let remaining),
                 .authorizationRefreshed(let accessState, let assetIDs, let remaining):
                state.isLoading = false
                state.accessState = accessState
                state.assetIDs = assetIDs
                state.remainingSwipes = remaining
                state.currentIndex = 0
                state.queuedForDeletion = []
                state.swipeHistory = []
                return .none

            case let .swipeProcessed(assetID, direction, consumed, remaining):
                guard consumed else {
                    state.remainingSwipes = remaining
                    state.isPaywallPresented = true
                    return .none
                }

                if direction == .left, !state.queuedForDeletion.contains(assetID) {
                    state.queuedForDeletion.append(assetID)
                }

                state.swipeHistory.append(.init(assetID: assetID, direction: direction))
                state.currentIndex += 1
                state.remainingSwipes = remaining
                if remaining == 0 {
                    state.isPaywallPresented = true
                }

                return .run { [currentIndex = state.currentIndex, hasPhotos = state.hasPhotos] _ in
                    guard hasPhotos else { return }
                    await photoLibraryClient.preheatThumbnails(currentIndex, preheatSize, 10)
                }

            case .deleteQueuedAssetsResponse(.success(let result)):
                state.assetIDs.removeAll { result.ids.contains($0) }
                state.currentIndex = max(0, state.currentIndex - result.removedBeforeCurrent)
                state.queuedForDeletion = []
                state.swipeHistory.removeAll { result.ids.contains($0.assetID) }
                state.deletedCount += result.ids.count
                return .run { [currentIndex = state.currentIndex, hasPhotos = state.hasPhotos] _ in
                    guard hasPhotos else { return }
                    await photoLibraryClient.preheatThumbnails(currentIndex, preheatSize, 10)
                }

            case .deleteQueuedAssetsResponse(.failure):
                state.errorMessage = "Не удалось удалить фото. Проверьте доступ к галерее и попробуйте ещё раз."
                return .none
            }
        }
    }
}
