import AVFoundation
import SwiftUI

struct AssetCardMediaView: View {
    let asset: MediaAsset

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var isVideoPlaying = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                mediaView(size: geometry.size)

                VStack(alignment: .leading, spacing: 12) {
                    if asset.type == .video {
                        videoControls
                    }

                    mediaBadge
                }
                .padding(18)
            }
            .background(Color.black.opacity(0.92))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .task(id: asset.id) {
                await loadContent(for: geometry.size)
            }
            .onDisappear {
                stopPlayback()
            }
        }
    }

    @ViewBuilder
    private func mediaView(size: CGSize) -> some View {
        switch asset.type {
        case .photo:
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .transition(.opacity)
            } else {
                placeholder
            }

        case .video:
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    placeholder
                }

                if let player {
                    InlineVideoPlayer(player: player)
                        .frame(width: size.width, height: size.height)
                }

                if isVideoPlaying == false {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 72, weight: .regular))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
                }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.9))

            ProgressView()
                .tint(.white)
        }
    }

    private var mediaBadge: some View {
        Label(asset.type == .video ? "Видео" : "Фото", systemImage: asset.type == .video ? "video.fill" : "photo.fill")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.white)
    }

    private var videoControls: some View {
        Button {
            togglePlayback()
        } label: {
            Label(isVideoPlaying ? "Пауза" : "Смотреть", systemImage: isVideoPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.45), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadContent(for size: CGSize) async {
        image = nil
        stopPlayback()

        image = await PhotoManager.shared.thumbnail(for: asset.id, targetSize: size)

        guard asset.type == .video else { return }

        if let playerItem = await PhotoManager.shared.playerItem(for: asset.id) {
            let player = AVPlayer(playerItem: playerItem)
            player.actionAtItemEnd = .pause
            self.player = player
        }
    }

    private func togglePlayback() {
        guard let player else { return }

        if isVideoPlaying {
            player.pause()
            isVideoPlaying = false
        } else {
            if let currentItem = player.currentItem,
               currentItem.currentTime() >= currentItem.duration {
                player.seek(to: .zero)
            }

            player.play()
            isVideoPlaying = true
        }
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
        isVideoPlaying = false
    }
}

private struct InlineVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.isUserInteractionEnabled = false
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
