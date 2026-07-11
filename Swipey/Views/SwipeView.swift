import ComposableArchitecture
import SwiftUI
import UIKit

struct SwipeView: View {
    let store: StoreOf<SwipeFeature>

    @State private var dragOffset: CGSize = .zero
    @State private var cardOpacity: Double = 1

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                topBar

                if let currentAsset = store.currentAsset {
                    GeometryReader { geometry in
                        ZStack {
                            AssetCardMediaView(asset: currentAsset)
                                .overlay(alignment: .top) {
                                    swipeFeedbackOverlay
                                        .padding(22)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(.white.opacity(0.18), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 14)
                        }
                        .offset(x: dragOffset.width, y: dragOffset.height * 0.2)
                        .rotationEffect(.degrees(Double(dragOffset.width / 26)))
                        .opacity(cardOpacity - min(Double(abs(dragOffset.width) / 500.0), 0.35))
                        .gesture(cardGesture(cardWidth: geometry.size.width))
                        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: dragOffset)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                } else {
                    emptyState
                        .padding(.horizontal, 24)
                }

                bottomControls
            }
            .padding(.vertical, 12)
        }
        .alert("Удалить медиафайлы?", isPresented: Binding(
            get: { store.showDeleteConfirmation },
            set: { if $0 == false { store.send(.view(.deleteConfirmationDismissed)) } }
        )) {
            Button("Отмена", role: .cancel) {
                store.send(.view(.deleteConfirmationDismissed))
            }
            Button("Удалить", role: .destructive) {
                let ids = store.queuedForDeletion
                let deleteSet = Set(ids)
                let removedBeforeCurrent = store.assets[..<min(store.currentIndex, store.assets.count)]
                    .filter { deleteSet.contains($0.id) }
                    .count

                Task {
                    do {
                        try await PhotoManager.shared.deleteAssets(with: ids)
                        await MainActor.run {
                            PhotoManager.shared.removeAssets(withIDs: deleteSet)
                        }
                        store.send(
                            .deleteQueuedAssetsResponse(
                                .success(
                                    SwipeFeature.DeleteResult(
                                        ids: ids,
                                        removedBeforeCurrent: removedBeforeCurrent
                                    )
                                )
                            )
                        )
                    } catch {
                        store.send(.deleteQueuedAssetsResponse(.failure(error)))
                    }
                }
            }
        } message: {
            Text("Будут удалены \(store.queuedForDeletion.count) медиафайлов из галереи.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Swipey")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Осталось свайпов: \(store.remainingSwipes)/\(SwipeLimiter.dailyLimit)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
            }

            Spacer()

            Text("Удалено: \(store.deletedCount)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.green)

            Text("Медиафайлы закончились")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Вы обработали все доступные фото и видео. Можно удалить отмеченные или зайти позже.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomControls: some View {
        HStack(spacing: 10) {
            Button {
                store.send(.view(.undoTapped))
                impact(style: .light)
            } label: {
                Label("Отменить", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .disabled(store.canUndo == false)

            Button {
                if store.queuedForDeletion.isEmpty == false {
                    store.send(.view(.queueDeletionTapped))
                }
            } label: {
                Label("Удалить \(store.queuedForDeletion.count)", systemImage: "trash")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(store.queuedForDeletion.isEmpty)

            if store.canSwipe == false {
                Button {
                    store.send(.view(.paywallPresented))
                } label: {
                    Image(systemName: "crown")
                        .font(.system(size: 17, weight: .bold))
                        .padding(14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var swipeFeedbackOverlay: some View {
        if dragOffset.width != 0 {
            let isRight = dragOffset.width > 0
            let progress = min(abs(dragOffset.width) / swipeThreshold, 1)

            HStack {
                if isRight {
                    overlayBadge(title: "ОСТАВИТЬ", icon: "checkmark.circle.fill", color: .green, progress: progress)
                    Spacer()
                } else {
                    Spacer()
                    overlayBadge(title: "УДАЛИТЬ", icon: "trash.fill", color: .red, progress: progress)
                }
            }
        }
    }

    private func overlayBadge(title: String, icon: String, color: Color, progress: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.85), in: Capsule())
        .foregroundStyle(.white)
        .opacity(progress)
    }

    private func cardGesture(cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard store.hasAssets else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard store.hasAssets else {
                    resetCardPosition()
                    return
                }

                if store.canSwipe == false {
                    store.send(.view(.paywallPresented))
                    warningFeedback()
                    resetCardPosition()
                    return
                }

                let x = value.translation.width
                if abs(x) > swipeThreshold {
                    let direction: SwipeDirection = x > 0 ? .right : .left
                    completeSwipe(direction: direction, cardWidth: cardWidth)
                } else {
                    resetCardPosition()
                }
            }
    }

    private func completeSwipe(direction: SwipeDirection, cardWidth: CGFloat) {
        let finalX: CGFloat = direction == .left ? -(cardWidth * 1.45) : cardWidth * 1.45

        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: finalX, height: dragOffset.height * 0.25)
            cardOpacity = 0.05
        }

        if direction == .left {
            warningFeedback()
        } else {
            impact(style: .medium)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            store.send(.view(.swipeCompleted(direction)))
            dragOffset = .zero
            cardOpacity = 1
        }
    }

    private func resetCardPosition() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            dragOffset = .zero
            cardOpacity = 1
        }
    }

    private func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func warningFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}
