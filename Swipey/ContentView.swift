import ComposableArchitecture
import SwiftUI
import UIKit

struct ContentView: View {
    let store: StoreOf<SwipeFeature>

    var body: some View {
        Group {
            if store.isLoading {
                loadingView
            } else {
                switch store.accessState {
                case .authorized:
                    SwipeView(store: store)
                case .notDetermined:
                    loadingView
                case .denied:
                    PermissionDeniedView(
                        onOpenSettings: openSettings,
                        onRetry: { store.send(.view(.retryAfterSettingsTapped)) }
                    )
                }
            }
        }
        .task {
            await store.send(.view(.task)).finish()
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.isPaywallPresented },
            set: { if $0 == false { store.send(.view(.paywallDismissed)) } }
        )) {
            PaywallView {
                store.send(.view(.paywallDismissed))
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if $0 == false { store.send(.view(.errorDismissed)) } }
        )) {
            Button("OK", role: .cancel) { store.send(.view(.errorDismissed)) }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ProgressView("Загружаем галерею...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .tint(.white)
                .foregroundStyle(.white)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    ContentView(
        store: Store(initialState: SwipeFeature.State()) {
            SwipeFeature()
        }
    )
}
