import SwiftData
import SwiftUI

/// E2 · Карточка упражнения: hero-блок, описание, шаги, «Начать».
struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(BreakCenter.self) private var breakCenter
    @Environment(\.dismiss) private var dismiss

    @State private var showRunner = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroBlock

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(exercise.name)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Theme.text)
                            HStack(spacing: 8) {
                                tag(exercise.zone.title, color: exercise.accentColor)
                                tag(exercise.dosageText, color: nil)
                                if exercise.isExternal {
                                    tag("вне приложения", color: Theme.violet)
                                }
                            }
                        }
                        Spacer()
                        favoriteButton
                    }

                    if !exercise.details.isEmpty {
                        Text(exercise.details)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.text2)
                            .lineSpacing(4)
                    }

                    if !exercise.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Theme.card2)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Text("\(index + 1)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Theme.text2)
                                        )
                                    Text(step)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
        }
        .background(Theme.bg)
        .safeAreaInset(edge: .bottom) {
            Button {
                if exercise.isExternal {
                    completeExternal()
                } else {
                    showRunner = true
                }
            } label: {
                Label(
                    exercise.isExternal ? "Отметить выполненным" : "Начать",
                    systemImage: exercise.isExternal ? "checkmark" : "play.fill"
                )
                .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(AccentButtonStyle(height: 58))
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .padding(.top, 6)
            .background(Theme.bg.opacity(0.01))
        }
        .fullScreenCover(isPresented: $showRunner) {
            ExerciseRunnerView(exercise: exercise)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var heroBlock: some View {
        RadialGradient(
            colors: [
                exercise.accentColor.mix(with: Theme.card, by: 0.74),
                exercise.accentColor.mix(with: Theme.bg, by: 0.88),
            ],
            center: UnitPoint(x: 0.5, y: 0.45),
            startRadius: 20,
            endRadius: 320
        )
        .frame(height: 250)
        .overlay(
            Image(systemName: exercise.iconName)
                .font(.system(size: 88))
                .foregroundStyle(exercise.accentColor.opacity(0.9))
        )
    }

    private var favoriteButton: some View {
        Button {
            exercise.isFavorite.toggle()
            try? context.save()
        } label: {
            Image(systemName: exercise.isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 20))
                .foregroundStyle(
                    exercise.isFavorite ? ActivityCategory.distraction.color : Theme.text2
                )
                .frame(width: 46, height: 46)
                .background(Circle().fill(Theme.card))
                .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
                .shadow(color: .black.opacity(0.07), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func tag(_ text: String, color: Color?) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color ?? Theme.text2)
            .padding(.vertical, 5)
            .padding(.horizontal, 11)
            .background(
                Capsule().fill(color.map { $0.opacity(0.14) } ?? Theme.card2)
            )
    }

    /// «Вне приложения»: без таймера — просто фиксируем факт.
    private func completeExternal() {
        let session = SessionService.activeSession(in: context)
        let log = ExerciseLog(exercise: exercise, session: session)
        context.insert(log)
        try? context.save()
        breakCenter.exerciseCompleted(stillInSession: session?.isActive == true)
        dismiss()
    }
}
