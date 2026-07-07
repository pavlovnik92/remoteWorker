import SwiftData
import SwiftUI

/// S3 · Пуш-перерыв: «Пора размяться» с предложенным упражнением.
struct BreakSheetView: View {
    let streakMinutes: Int
    var onStart: (Exercise) -> Void
    var onSnooze: () -> Void
    var onSkip: () -> Void

    @Query(sort: [SortDescriptor(\Exercise.createdAt)])
    private var exercises: [Exercise]

    @State private var suggestion: Exercise?

    private var candidates: [Exercise] {
        let favorites = exercises.filter { $0.isFavorite && !$0.isExternal }
        return favorites.isEmpty ? exercises.filter { !$0.isExternal } : favorites
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ActivityCategory.health.color.mix(with: Theme.card, by: 0.70),
                                    ActivityCategory.health.color.mix(with: Theme.card, by: 0.84),
                                ],
                                center: UnitPoint(x: 0.34, y: 0.28),
                                startRadius: 0,
                                endRadius: 56
                            )
                        )
                    Image(systemName: "heart.circle")
                        .font(.system(size: 30))
                        .foregroundStyle(ActivityCategory.health.color)
                }
                .frame(width: 64, height: 64)
                .padding(.bottom, 4)

                Text("Пора размяться")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(Theme.text)

                Text(subtitleText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 20)

            if let suggestion {
                exerciseCard(suggestion)
                    .padding(.bottom, 18)
            }

            Button {
                if let suggestion { onStart(suggestion) }
            } label: {
                Label("Начать разминку", systemImage: "play.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(AccentButtonStyle(height: 56, cornerRadius: 16))
            .disabled(suggestion == nil)
            .padding(.bottom, 10)

            HStack(spacing: 10) {
                Button("Отложить 10 мин", action: onSnooze)
                    .buttonStyle(NeutralButtonStyle(height: 48, cornerRadius: 14))
                Button(action: onSkip) {
                    Text("Пропустить")
                        .foregroundStyle(Theme.text2)
                }
                .buttonStyle(NeutralButtonStyle(height: 48, cornerRadius: 14))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 12)
        .background(Theme.bg)
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.visible)
        .onAppear {
            if suggestion == nil {
                suggestion = candidates.randomElement()
            }
        }
    }

    private var subtitleText: String {
        if streakMinutes > 0 {
            return "Вы в фокусе уже \(streakMinutes) минут — спина скажет спасибо"
        }
        return "Небольшая пауза вернёт телу тонус"
    }

    private func exerciseCard(_ exercise: Exercise) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(exercise.accentColor.mix(with: Theme.card2, by: 0.86))
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: exercise.iconName)
                        .font(.system(size: 24))
                        .foregroundStyle(exercise.accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("\(exercise.dosageText) · \(exercise.zone.title)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text2)
            }

            Spacer()

            Button {
                shuffleSuggestion()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.text3)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .cardStyle(cornerRadius: 20)
    }

    private func shuffleSuggestion() {
        let pool = candidates.filter { $0.persistentModelID != suggestion?.persistentModelID }
        if let next = pool.randomElement() {
            suggestion = next
        }
    }
}
