import SwiftUI

/// S2b · День на паузе: замороженный таймер и кнопка «Продолжить день».
struct PausedSessionView: View {
    let session: WorkSession
    var onResume: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.card2)
                        .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
                        .frame(width: 188, height: 188)
                    Image(systemName: "pause.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.text3)
                }
                .padding(.bottom, 14)

                Text("День на паузе")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.text)

                Text(
                    timerInterval: session.effectiveStart...Date.distantFuture,
                    pauseTime: session.currentPause?.startedAt,
                    countsDown: false
                )
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.text2)

                Text("Активности и время сейчас не учитываются.\nОтдохни — мы подождём.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            Button(action: onResume) {
                Label("Продолжить день", systemImage: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(AccentButtonStyle(height: 58))
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
        }
    }
}
