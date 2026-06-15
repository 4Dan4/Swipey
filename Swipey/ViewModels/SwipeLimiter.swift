import Foundation

@MainActor
final class SwipeLimiter {
    static let dailyLimit = 5000
    static let shared = SwipeLimiter()

    private let defaults: UserDefaults
    private let usedKey = "swipey.swipesUsed"
    private let dateKey = "swipey.lastResetDate"

    private(set) var swipesUsedToday: Int
    private(set) var lastResetDate: Date

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.swipesUsedToday = defaults.integer(forKey: usedKey)
        self.lastResetDate = defaults.object(forKey: dateKey) as? Date ?? .distantPast
        refreshIfNeeded()
    }

    var remaining: Int {
        refreshIfNeeded()
        return max(0, Self.dailyLimit - swipesUsedToday)
    }

    var isLimitReached: Bool {
        remaining == 0
    }

    @discardableResult
    func consumeSwipe() -> Bool {
        refreshIfNeeded()
        guard swipesUsedToday < Self.dailyLimit else {
            return false
        }

        swipesUsedToday += 1
        persist()
        return true
    }

    private func refreshIfNeeded(now: Date = Date()) {
        let calendar = Calendar.current
        guard calendar.isDate(lastResetDate, inSameDayAs: now) else {
            swipesUsedToday = 0
            lastResetDate = now
            persist()
            return
        }
    }

    private func persist() {
        defaults.set(swipesUsedToday, forKey: usedKey)
        defaults.set(lastResetDate, forKey: dateKey)
    }
}
