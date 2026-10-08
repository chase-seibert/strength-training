import Foundation
import SwiftData
import WidgetKit

@ModelActor
actor ProgressWidgetSnapshotPublisher {
  func publish() async {
    do {
      let now = Date.now
      let sessionDescriptor = FetchDescriptor<WorkoutSession>(
        predicate: #Predicate<WorkoutSession> { $0.deletedAt == nil },
        sortBy: [SortDescriptor(\.startedAt)])
      let sessions = try modelContext.fetch(sessionDescriptor)
      let routines = try modelContext.fetch(FetchDescriptor<Routine>())
      let people = try modelContext.fetch(
        FetchDescriptor<PersonProfile>(predicate: #Predicate { !$0.isArchived }))
      let snapshot = Self.makeSnapshot(
        sessions: sessions, routines: routines, people: people, now: now,
        calendar: .current)
      try ProgressWidgetSnapshotStore.save(snapshot)
      await MainActor.run {
        WidgetCenter.shared.reloadTimelines(ofKind: ProgressWidgetConfiguration.kind)
      }
    } catch {
      await MainActor.run {
        NotificationCenter.default.post(
          name: .progressWidgetPublicationFailed,
          object: error.localizedDescription)
      }
    }
  }

  private static func makeSnapshot(
    sessions: [WorkoutSession], routines: [Routine], people: [PersonProfile], now: Date,
    calendar: Calendar
  ) -> ProgressWidgetSnapshot {
    let lowerBound = calendar.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
    let includedSessions = sessions.filter { $0.startedAt >= lowerBound && $0.startedAt <= now }
    let names = ProgressSummaryBuilder.participantNames(in: includedSessions, people: people)
    let participants = names.map { name in
      ProgressWidgetParticipant(
        name: name, colorHex: ProgressSummaryBuilder.colorHex(for: name, people: people))
    }
    let routineNames = Dictionary(
      routines.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    let achievementCounts = Dictionary(
      grouping: PersonalRecords.achievements(in: sessions), by: \.sessionID
    )
    .mapValues(\.count)
    let history = includedSessions.sorted { $0.startedAt > $1.startedAt }.prefix(5).map { session in
      ProgressWidgetHistoryRow(
        sessionID: session.id,
        routineName: routineNames[session.routineID] ?? "Unknown Routine",
        startedAt: session.startedAt,
        completedSetCount: session.completedSetCount,
        totalSetCount: session.totalSetCount,
        personalRecordCount: achievementCounts[session.id] ?? 0)
    }
    let sessionVolumes = includedSessions.map { session in
      ProgressWidgetSessionVolume(
        sessionID: session.id,
        startedAt: session.startedAt,
        participantVolumes: session.participantNames.map { name in
          ProgressWidgetParticipantVolume(
            personName: name,
            volume: session.exercises.reduce(0) { $0 + $1.completedPoundsVolume(for: name) })
        })
    }
    return ProgressWidgetSnapshot(
      schemaVersion: ProgressWidgetConfiguration.schemaVersion,
      generatedAt: now,
      calendarIdentifier: String(describing: calendar.identifier),
      timeZoneIdentifier: calendar.timeZone.identifier,
      firstWeekday: calendar.firstWeekday,
      minimumDaysInFirstWeek: calendar.minimumDaysInFirstWeek,
      participants: participants,
      sessionVolumes: sessionVolumes,
      history: history)
  }
}

@MainActor
enum ProgressWidgetPublication {
  private static var publisher: ProgressWidgetSnapshotPublisher?
  private static var pendingPublication: Task<Void, Never>?

  static func configure(modelContainer: ModelContainer) {
    publisher = ProgressWidgetSnapshotPublisher(modelContainer: modelContainer)
  }

  static func schedule() {
    guard let publisher else { return }
    pendingPublication?.cancel()
    pendingPublication = Task {
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      await publisher.publish()
    }
  }
}

@MainActor
func saveAndRefreshProgressWidget(_ context: ModelContext) -> Bool {
  do {
    try context.save()
    ProgressWidgetPublication.schedule()
    return true
  } catch {
    return false
  }
}

extension Notification.Name {
  static let progressWidgetPublicationFailed = Notification.Name("progressWidgetPublicationFailed")
}
