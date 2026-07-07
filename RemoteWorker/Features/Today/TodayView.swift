import SwiftData
import SwiftUI

/// Вкладка «Сегодня»: idle → активная сессия → пауза → итог дня.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(BreakCenter.self) private var breakCenter

    @Query(filter: #Predicate<WorkSession> { $0.endedAt == nil })
    private var activeSessions: [WorkSession]

    @State private var finishedSession: WorkSession?
    @State private var editorTarget: ActivityEditorTarget?
    @State private var runnerExercise: Exercise?
    @State private var showSettings = false

    private var session: WorkSession? { activeSessions.first }

    var body: some View {
        @Bindable var bindableBreakCenter = breakCenter

        ZStack {
            Theme.bg.ignoresSafeArea()

            if let session {
                if session.isPaused {
                    PausedSessionView(session: session) {
                        SessionService.resume(session, context: context)
                    }
                } else {
                    ActiveSessionView(
                        session: session,
                        onPause: { pause(session) },
                        onFinish: { finish(session) },
                        onEdit: { editorTarget = .edit($0) },
                        onAdd: { editorTarget = .new }
                    )
                }
            } else {
                IdleStartView(
                    onStart: startDay,
                    onSettings: { showSettings = true }
                )
            }
        }
        .sheet(item: $editorTarget) { target in
            ActivityEditorSheet(template: target.template)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $bindableBreakCenter.promptVisible, onDismiss: {
            breakCenter.promptDismissed()
        }) {
            BreakSheetView(
                streakMinutes: breakCenter.workStreakMinutes(session: session),
                onStart: { exercise in
                    breakCenter.promptVisible = false
                    runnerExercise = exercise
                },
                onSnooze: { breakCenter.snooze() },
                onSkip: { breakCenter.skip() }
            )
        }
        .fullScreenCover(item: $runnerExercise) { exercise in
            ExerciseRunnerView(exercise: exercise)
        }
        .fullScreenCover(item: $finishedSession) { finished in
            NavigationStack {
                DaySummaryView(session: finished, showsDoneButton: true)
            }
        }
        .task(id: session?.persistentModelID) {
            // Периодическая проверка «пора ли на перерыв», пока вкладка жива.
            while !Task.isCancelled {
                breakCenter.checkPrompt(session: session)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func startDay() {
        SessionService.startDay(context: context)
        Task { await breakCenter.ensureAuthorization() }
    }

    private func pause(_ session: WorkSession) {
        SessionService.pause(session, context: context)
        breakCenter.cancelCountdown()
        breakCenter.cancelActivityLimit()
    }

    private func finish(_ session: WorkSession) {
        SessionService.finish(session, context: context)
        breakCenter.cancelCountdown()
        breakCenter.cancelActivityLimit()
        finishedSession = session
    }
}

enum ActivityEditorTarget: Identifiable {
    case new
    case edit(ActivityTemplate)

    var id: AnyHashable {
        switch self {
        case .new: "new"
        case .edit(let template): template.persistentModelID
        }
    }

    var template: ActivityTemplate? {
        switch self {
        case .new: nil
        case .edit(let template): template
        }
    }
}
