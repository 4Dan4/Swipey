import SwiftUI

struct PermissionDeniedView: View {
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 58, weight: .regular))
                    .foregroundStyle(.white)

                Text("Доступ к фото отключён")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Разрешите доступ к медиатеке в Настройках, чтобы свайпать фотографии и помечать их на удаление.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Button("Открыть настройки") {
                        onOpenSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.white)
                    .foregroundStyle(.black)

                    Button("Проверить снова") {
                        onRetry()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.white)
                }
            }
            .padding(24)
        }
    }
}
