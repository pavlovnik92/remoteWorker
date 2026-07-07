import SwiftData
import SwiftUI

/// S2 · Активная сессия: hero-таймер, подсказка, кластер кружков, «Пауза»/«Завершить».
struct ActiveSessionView: View {
    let session: WorkSession
    var onPause: () -> Void
    var onFinish: () -> Void
    var onEdit: (ActivityTemplate) -> Void
    var onAdd: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(BreakCenter.self) private var breakCenter
    @AppStorage(AppSettings.breakIntervalKey) private var breakInterval = 50

    @Query(sort: [
        SortDescriptor(\ActivityTemplate.sortOrder),
        SortDescriptor(\ActivityTemplate.createdAt),
    ])
    private var templates: [ActivityTemplate]

    var body: some View {
        VStack(spacing: 0) {
            sessionHeader
                .padding(.top, 6)

            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                VStack(spacing: 10) {
                    hint(now: timeline.date)
                        .padding(.top, 12)
                        .padding(.horizontal, 26)

                    ActivityClusterView(
                        session: session,
                        templates: templates,
                        now: timeline.date,
                        breakIntervalMinutes: breakInterval,
                        onTap: handleTap,
                        onEdit: onEdit,
                        onDelete: handleDelete,
                        onAdd: onAdd
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                }
            }

            HStack(spacing: 12) {
                Button(action: onPause) {
                    Label("Пауза", systemImage: "pause.fill")
                }
                .buttonStyle(NeutralButtonStyle())

                Button(action: onFinish) {
                    Label("Завершить", systemImage: "flag.fill")
                }
                .buttonStyle(AccentButtonStyle())
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
        }
    }

    private var sessionHeader: some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 3)
                    .background(Circle().fill(Theme.accent.opacity(0.24)).frame(width: 16, height: 16))
                Text("РАБОЧИЙ ДЕНЬ ИДЁТ")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.text2)
            }
            Text(timerInterval: session.effectiveStart...Date.distantFuture, countsDown: false)
                .font(.system(size: 46, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.text)
        }
    }

    /// Активность с лимитом, который уже превышен (для подсказки «пора закругляться»).
    private func overdueEntry(now: Date) -> (name: String, minutes: Int)? {
        guard
            let entry = session.activeEntry,
            let limit = entry.template?.plannedMinutes,
            limit > 0
        else { return nil }
        let minutes = Int(entry.duration(asOf: now) / 60)
        return minutes >= limit ? (entry.name, minutes) : nil
    }

    @ViewBuilder
    private func hint(now: Date) -> some View {
        let streak = breakCenter.workStreakMinutes(session: session, asOf: now)
        let threshold = Int(Double(breakInterval) * 0.6)

        if let overdue = overdueEntry(now: now) {
            HStack(spacing: 7) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14))
                    .foregroundStyle(ActivityCategory.distraction.color)
                Text("«\(overdue.name)» уже \(overdue.minutes) мин — пора закругляться")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ActivityCategory.distraction.color.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(ActivityCategory.distraction.color.opacity(0.25), lineWidth: 1)
                    )
            )
        } else if streak >= threshold {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
                Text("\(streak) мин в фокусе — кружки отдыха подросли")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1)
                    )
            )
        } else if session.activeEntry == nil {
            Text(session.entries.isEmpty
                 ? "Тапни по кружку — с чего начнёшь?"
                 : "Между активностями — выбери следующую")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.text3)
                .padding(.vertical, 8)
        } else {
            Text("Данных пока немного — кластер в равновесии")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.text3)
                .padding(.vertical, 8)
        }
    }

    private func handleTap(_ template: ActivityTemplate) {
        let wasWork = session.activeEntry?.category == .work
        let newEntry = SessionService.toggleActivity(template, in: session, context: context)
        if let newEntry, newEntry.category == .work {
            breakCenter.workStarted(at: newEntry.startedAt, continuingWorkChain: wasWork)
        } else {
            breakCenter.cancelCountdown()
        }
        if let newEntry {
            breakCenter.activityStarted(newEntry)
        } else {
            breakCenter.cancelActivityLimit()
        }
    }

    private func handleDelete(_ template: ActivityTemplate) {
        if session.activeEntry?.template?.persistentModelID == template.persistentModelID {
            session.activeEntry?.endedAt = .now
            breakCenter.cancelCountdown()
            breakCenter.cancelActivityLimit()
        }
        context.delete(template)
        try? context.save()
    }
}
