import SwiftData
import SwiftUI

/// Аналитика: сегменты День (A1) / Неделя (A2) / История (A3).
struct AnalyticsTabView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case day = "День"
        case week = "Неделя"
        case history = "История"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .day

    @Query(sort: [SortDescriptor(\WorkSession.startedAt, order: .reverse)])
    private var allSessions: [WorkSession]

    private var latestSession: WorkSession? { allSessions.first }
    private var finishedSessions: [WorkSession] { allSessions.filter { $0.endedAt != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Раздел", selection: $segment) {
                        ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch segment {
                    case .day:
                        if let latestSession {
                            DaySummaryContent(session: latestSession)
                        } else {
                            emptyState
                        }
                    case .week:
                        WeekStatsContent(sessions: allSessions)
                    case .history:
                        if finishedSessions.isEmpty {
                            emptyState
                        } else {
                            historyList
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
            .background(Theme.bg)
            .navigationTitle("Аналитика")
            .navigationDestination(for: WorkSession.self) { session in
                DaySummaryView(session: session)
            }
        }
        .tint(Theme.accent)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundStyle(Theme.text3)
            Text("Пока пусто")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Заверши первый рабочий день —\nи здесь появится честный разбор.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private var historyList: some View {
        VStack(spacing: 12) {
            ForEach(finishedSessions, id: \.persistentModelID) { session in
                NavigationLink(value: session) {
                    historyRow(session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func historyRow(_ session: WorkSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Format.dayTitle(session.startedAt))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("\(Format.hoursMinutes(session.elapsed())) · \(Format.plural(session.exerciseLogs.count, "разминка", "разминки", "разминок"))")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.text2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text3)
            }
            SessionTimelineBar(session: session, height: 10)
        }
        .padding(14)
        .cardStyle(cornerRadius: 18)
    }
}
