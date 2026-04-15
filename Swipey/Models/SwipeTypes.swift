import Foundation

enum SwipeDirection {
    case left
    case right
}

struct SwipeAction {
    let assetID: String
    let direction: SwipeDirection
}

enum LibraryAccessState {
    case notDetermined
    case authorized
    case denied
}
