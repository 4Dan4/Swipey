import Foundation

enum SwipeDirection: Equatable {
    case left
    case right
}

struct SwipeAction: Equatable {
    let assetID: String
    let direction: SwipeDirection
}

enum LibraryAccessState: Equatable {
    case notDetermined
    case authorized
    case denied
}
