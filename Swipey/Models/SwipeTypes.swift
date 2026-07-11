import Foundation

enum SwipeDirection: Equatable, Sendable {
    case left
    case right
}

enum MediaAssetType: String, Equatable, Codable, Sendable {
    case photo
    case video
}

struct MediaAsset: Equatable, Identifiable, Codable, Sendable {
    let id: String
    let type: MediaAssetType
}

struct SwipeAction: Equatable, Sendable {
    let assetID: String
    let direction: SwipeDirection
}

enum LibraryAccessState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}
