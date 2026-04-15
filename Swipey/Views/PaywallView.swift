import SwiftUI

struct PaywallView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.85), Color.cyan.opacity(0.85), Color.teal.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Безлимитная очистка")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Удаляйте сколько угодно фотографий без ограничений")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                    } label: {
                        Text("Оформить подписку")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white)
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button("Назад") {
                        onClose()
                    }
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}
