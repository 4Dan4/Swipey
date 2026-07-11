import ComposableArchitecture
import CoreGraphics

struct SwipeFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var isLoading = true
        var currentIndex = 0
        var assets: [MediaAsset] = []
        var queuedForDeletion: [String] = []
        var deletedCount = 0
        var accessState: LibraryAccessState = .notDetermined
        var errorMessage: String?
        var showDeleteConfirmation = false
        var isPaywallPresented = false
        var swipeHistory: [SwipeAction] = []
        var didBootstrap = false
        var remainingSwipes = SwipeLimiter.dailyLimit

        var currentAsset: MediaAsset? {
            guard currentIndex < assets.count else { return nil }
            return assets[currentIndex]
        }

        var hasAssets: Bool {
            currentAsset != nil
        }

        var canSwipe: Bool {
            remainingSwipes > 0
        }

        var totalAssetsCount: Int {
            assets.count
        }

        var canUndo: Bool {
            swipeHistory.isEmpty == false
        }
    }

    enum Action {
        case view(View)
        case bootstrapResponse(LibraryAccessState, [MediaAsset], Int)
        case authorizationRefreshed(LibraryAccessState, [MediaAsset], Int)
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
                    let isAuthorized: Bool
                    switch accessState {
                    case .authorized:
                        isAuthorized = true
                    case .notDetermined, .denied:
                        isAuthorized = false
                    }

                    let assets = isAuthorized ? await photoLibraryClient.loadAssets() : []
                    let remaining = await swipeLimiterClient.remaining()

                    if isAuthorized {
                        await photoLibraryClient.preheatThumbnails(0, preheatSize, 10)
                    }

                    await send(.bootstrapResponse(accessState, assets, remaining))
                }

            case .view(.retryAfterSettingsTapped):
                state.isLoading = true
                return .run { send in
                    let accessState = await photoLibraryClient.refreshAuthorizationStatus()
                    let isAuthorized: Bool
                    switch accessState {
                    case .authorized:
                        isAuthorized = true
                    case .notDetermined, .denied:
                        isAuthorized = false
                    }

                    let assets = isAuthorized ? await photoLibraryClient.loadAssets() : []
                    let remaining = await swipeLimiterClient.remaining()

                    if isAuthorized {
                        await photoLibraryClient.preheatThumbnails(0, preheatSize, 10)
                    }

                    await send(.authorizationRefreshed(accessState, assets, remaining))
                }

            case .view(.swipeCompleted(let direction)):
                guard let currentAssetID = state.currentAsset?.id else { return .none }
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

                let ids = state.queuedForDeletion
                let deleteSet = Set(ids)
                let removedBeforeCurrent = state.assets[..<min(state.currentIndex, state.assets.count)]
                    .filter { deleteSet.contains($0.id) }
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

            case .bootstrapResponse(let accessState, let assets, let remaining),
                 .authorizationRefreshed(let accessState, let assets, let remaining):
                state.isLoading = false
                state.accessState = accessState
                state.assets = assets
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

                return .run { [currentIndex = state.currentIndex, hasAssets = state.hasAssets] _ in
                    guard hasAssets else { return }
                    await photoLibraryClient.preheatThumbnails(currentIndex, preheatSize, 10)
                }

            case .deleteQueuedAssetsResponse(.success(let result)):
                state.assets.removeAll { result.ids.contains($0.id) }
                state.currentIndex = max(0, state.currentIndex - result.removedBeforeCurrent)
                state.queuedForDeletion = []
                state.swipeHistory.removeAll { result.ids.contains($0.assetID) }
                state.deletedCount += result.ids.count
                return .run { [currentIndex = state.currentIndex, hasAssets = state.hasAssets] _ in
                    guard hasAssets else { return }
                    await photoLibraryClient.preheatThumbnails(currentIndex, preheatSize, 10)
                }

            case .deleteQueuedAssetsResponse(.failure):
                state.errorMessage = "Не удалось удалить медиафайлы. Проверьте доступ к галерее и попробуйте ещё раз."
                return .none
            }
        }
    }
}
