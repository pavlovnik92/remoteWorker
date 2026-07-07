import SwiftData
import SwiftUI

/// E3 · Активная разминка: кольцо-таймер, шаги, «Готово».
/// Если идёт сессия — на время упражнения переключает активность на «Разминку»
/// и возвращает предыдущую после завершения.
struct ExerciseRunnerView: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(BreakCenter.self) private var breakCenter

    @State private var startedAt = Date.now
    @State private var previousTemplateID: PersistentIdentifier?

    private var healthColor: Color { ActivityCategory.health.color }
    private var duration: TimeInterval { TimeInterval(exercise.durationSeconds) }
    private var isTimed: Bool { exercise.durationSeconds > 0 }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [healthColor.opacity(0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: cancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.text2)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Theme.card))
                            .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(exercise.zone.title.uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .tracking(0.8)
                        .foregroundStyle(Theme.text2)
                    Text(exercise.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.text)
                }
                .padding(.top, 14)

                Spacer()

                if isTimed {
                    timedRing
                } else {
                    repsRing
                }

                Spacer()

                if exercise.steps.count > 1, isTimed {
                    stepDots
                        .padding(.bottom, 26)
                }

                Button(action: complete) {
                    Label("Готово", systemImage: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                }
                .buttonStyle(AccentButtonStyle(base: healthColor, height: 58))
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
        }
        .onAppear(perform: switchSessionToWarmup)
    }

    // MARK: - Кольца

    private var timedRing: some View {
        TimelineView(.animation(minimumInterval: 0.5)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            let progress = min(1, max(0, elapsed / duration))

            ZStack {
                Circle()
                    .stroke(healthColor.opacity(0.16), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Image(systemName: exercise.iconName)
                        .font(.system(size: 52))
                        .foregroundStyle(healthColor)
                    Text(
                        timerInterval: startedAt...startedAt.addingTimeInterval(duration),
                        countsDown: true
                    )
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    if let step = currentStep(elapsed: elapsed) {
                        Text(step)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.text2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                }
            }
            .padding(7)
            .frame(width: 268, height: 268)
        }
    }

    private var repsRing: some View {
        ZStack {
            Circle()
                .stroke(healthColor.opacity(0.35), lineWidth: 14)
            VStack(spacing: 6) {
                Image(systemName: exercise.iconName)
                    .font(.system(size: 52))
                    .foregroundStyle(healthColor)
                Text("\(exercise.reps)")
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                Text("повторов")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text2)
            }
        }
        .padding(7)
        .frame(width: 268, height: 268)
    }

    private var stepDots: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            let index = stepIndex(elapsed: elapsed)
            HStack(spacing: 8) {
                ForEach(exercise.steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? healthColor : Theme.card2)
                        .frame(width: 32, height: 6)
                }
            }
        }
    }

    private func stepIndex(elapsed: TimeInterval) -> Int {
        guard isTimed, !exercise.steps.isEmpty else { return 0 }
        let fraction = min(0.999, max(0, elapsed / duration))
        return Int(fraction * Double(exercise.steps.count))
    }

    private func currentStep(elapsed: TimeInterval) -> String? {
        guard !exercise.steps.isEmpty else { return nil }
        return exercise.steps[stepIndex(elapsed: elapsed)]
    }

    // MARK: - Интеграция с сессией

    private func switchSessionToWarmup() {
        guard
            let session = SessionService.activeSession(in: context),
            !session.isPaused
        else { return }

        previousTemplateID = session.activeEntry?.template?.persistentModelID
        breakCenter.cancelCountdown()
        breakCenter.cancelActivityLimit()

        if let warmup = SessionService.warmupTemplate(in: context),
           session.activeEntry?.template?.persistentModelID != warmup.persistentModelID,
           let entry = SessionService.toggleActivity(warmup, in: session, context: context) {
            breakCenter.activityStarted(entry)
        }
    }

    private func restorePreviousActivity() {
        guard
            let session = SessionService.activeSession(in: context),
            !session.isPaused
        else { return }

        if let previousTemplateID,
           let previous = context.model(for: previousTemplateID) as? ActivityTemplate {
            let entry = SessionService.toggleActivity(previous, in: session, context: context)
            if let entry, entry.category == .work {
                breakCenter.workStarted(at: entry.startedAt, continuingWorkChain: false)
            }
            if let entry {
                breakCenter.activityStarted(entry)
            } else {
                breakCenter.cancelActivityLimit()
            }
        } else {
            session.activeEntry?.endedAt = .now
            try? context.save()
            breakCenter.cancelActivityLimit()
        }
    }

    private func complete() {
        let session = SessionService.activeSession(in: context)
        let log = ExerciseLog(exercise: exercise, session: session)
        context.insert(log)
        restorePreviousActivity()
        try? context.save()
        breakCenter.exerciseCompleted(stillInSession: session?.isActive == true)
        dismiss()
    }

    private func cancel() {
        restorePreviousActivity()
        dismiss()
    }
}
