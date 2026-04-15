import SwiftUI
import UIKit
import Observation

struct ContentView: View {
    @State private var viewModel = SwipeViewModel()

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        Group {
            if viewModel.isLoading {
                loadingView
            } else {
                switch viewModel.accessState {
                case .authorized:
                    SwipeView(viewModel: bindableViewModel)
                case .notDetermined:
                    loadingView
                case .denied:
                    PermissionDeniedView(
                        onOpenSettings: openSettings,
                        onRetry: viewModel.refreshAfterSettings
                    )
                }
            }
        }
        .task {
            await viewModel.bootstrap()
        }
        .fullScreenCover(isPresented: $bindableViewModel.isPaywallPresented) {
            PaywallView {
                bindableViewModel.isPaywallPresented = false
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if $0 == false { viewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
    ContentView()
}
