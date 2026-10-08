import Foundation

struct ProgressVolumePoint: Identifiable {
  let id: String
  let personName: String
  let weekStart: Date
  let volume: Double
}

enum ProgressSummaryBuilder {
  static func participantNames(in sessions: [WorkoutSession], people: [PersonProfile]) -> [String] {
    var names: [String] = []
    for session in sessions {
      for name in session.participantNames
      where !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
        names.append(name)
      }
    }
    return names.sorted { lhs, rhs in
      let leftOrder =
        people.first(where: { $0.name.caseInsensitiveCompare(lhs) == .orderedSame })?.sortOrder
        ?? Int.max
      let rightOrder =
        people.first(where: { $0.name.caseInsensitiveCompare(rhs) == .orderedSame })?.sortOrder
        ?? Int.max
      if leftOrder != rightOrder { return leftOrder < rightOrder }
      return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
  }

  static func colorHex(for name: String, people: [PersonProfile]) -> String {
    people.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.colorHex
      ?? "6B7280"
  }

  static func volumePoints(
    sessions: [WorkoutSession], calendar: Calendar = .current
  ) -> [ProgressVolumePoint] {
    var buckets: [String: ProgressVolumePoint] = [:]
    for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
      let weekStart =
        calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start
        ?? calendar.startOfDay(for: session.startedAt)
      for name in session.participantNames {
        let sessionVolume = session.exercises.reduce(0) {
          $0 + $1.completedPoundsVolume(for: name)
        }
        guard sessionVolume > 0 else { continue }
        let key = "\(weekStart.timeIntervalSinceReferenceDate)|\(name.lowercased())"
        if let existing = buckets[key] {
          buckets[key] = ProgressVolumePoint(
            id: existing.id, personName: existing.personName, weekStart: existing.weekStart,
            volume: existing.volume + sessionVolume)
        } else {
          buckets[key] = ProgressVolumePoint(
            id: key, personName: name, weekStart: weekStart, volume: sessionVolume)
        }
      }
    }
    return buckets.values.sorted {
      if $0.weekStart != $1.weekStart { return $0.weekStart < $1.weekStart }
      return $0.personName.localizedCaseInsensitiveCompare($1.personName) == .orderedAscending
    }
  }

  static func personalRecordCounts(in sessions: [WorkoutSession]) -> [UUID: Int] {
    Dictionary(grouping: PersonalRecords.achievements(in: sessions), by: \.sessionID)
      .mapValues(\.count)
  }
}
