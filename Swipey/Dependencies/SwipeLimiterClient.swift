import ComposableArchitecture

@DependencyClient
struct SwipeLimiterClient: Sendable {
    var consumeSwipe: @Sendable () async -> Bool = { false }
    var remaining: @Sendable () async -> Int = { 0 }
}

extension SwipeLimiterClient: DependencyKey {
    static let liveValue = Self(
        consumeSwipe: {
            let limiter = await MainActor.run { SwipeLimiter.shared }
            return await MainActor.run {
                limiter.consumeSwipe()
            }
        },
        remaining: {
            let limiter = await MainActor.run { SwipeLimiter.shared }
            return await MainActor.run {
                limiter.remaining
            }
        }
    )
}

extension DependencyValues {
    var swipeLimiterClient: SwipeLimiterClient {
        get { self[SwipeLimiterClient.self] }
        set { self[SwipeLimiterClient.self] = newValue }
    }
}
