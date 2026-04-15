import SwiftUI

struct AssetCardImageView: View {
    let assetID: String
    let photoManager: PhotoManager

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .transition(.opacity)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.9))
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .task(id: assetID) {
                image = await photoManager.thumbnail(
                    for: assetID,
                    targetSize: geometry.size
                )
            }
        }
    }
}
