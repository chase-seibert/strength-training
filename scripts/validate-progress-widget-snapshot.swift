import Foundation

func date(_ value: String) -> Date {
  ISO8601DateFormatter().date(from: value + "T12:00:00Z")!
}

@main
struct ProgressWidgetSnapshotChecks {
  static func main() throws {
    let snapshot = ProgressWidgetSnapshot(
  schemaVersion: ProgressWidgetConfiguration.schemaVersion,
  generatedAt: date("2026-10-08"),
  calendarIdentifier: "gregorian",
  timeZoneIdentifier: "America/Los_Angeles",
  firstWeekday: 1,
  minimumDaysInFirstWeek: 1,
  participants: [ProgressWidgetParticipant(name: "Chase", colorHex: "FF5A45")],
  sessionVolumes: [
    ProgressWidgetSessionVolume(
      sessionID: UUID(), startedAt: date("2026-10-05"),
      participantVolumes: [ProgressWidgetParticipantVolume(personName: "Chase", volume: 250)]),
    ProgressWidgetSessionVolume(
      sessionID: UUID(), startedAt: date("2026-10-06"),
      participantVolumes: [ProgressWidgetParticipantVolume(personName: "Chase", volume: 300)]),
    ProgressWidgetSessionVolume(
      sessionID: UUID(), startedAt: date("2026-04-01"),
      participantVolumes: [ProgressWidgetParticipantVolume(personName: "Chase", volume: 900)]),
  ],
  history: [
    ProgressWidgetHistoryRow(
      sessionID: UUID(), routineName: "Upper Body", startedAt: date("2026-10-06"),
      completedSetCount: 12, totalSetCount: 14, personalRecordCount: 2),
    ProgressWidgetHistoryRow(
      sessionID: UUID(), routineName: "Old Workout", startedAt: date("2026-04-01"),
      completedSetCount: 4, totalSetCount: 4, personalRecordCount: 0),
  ])

    let points = snapshot.points(asOf: date("2026-10-08"))
    precondition(points.count == 1, "Same-week sessions should aggregate and old sessions should expire")
    precondition(points[0].volume == 550, "The recent weekly volume should sum to 550")
    let history = snapshot.history(asOf: date("2026-10-08"))
    precondition(history.map(\.routineName) == ["Upper Body"])
    precondition(history.first?.personalRecordCount == 2, "The history row should retain its PR count")

    let roundTrip = try JSONDecoder().decode(
      ProgressWidgetSnapshot.self, from: JSONEncoder().encode(snapshot))
    precondition(roundTrip.points(asOf: date("2026-10-08")) == points)
    print("Progress widget snapshot checks passed")
  }
}
