import Foundation

enum ProgressWidgetConfiguration {
  static let appGroupIdentifier = "group.com.cseibert.StrengthLog"
  static let kind = "StrengthLogProgressWidget"
  static let snapshotFileName = "progress-widget-snapshot.json"
  static let schemaVersion = 1
}

struct ProgressWidgetParticipant: Codable, Hashable, Identifiable {
  let name: String
  let colorHex: String

  var id: String { name.lowercased() }
}

struct ProgressWidgetPoint: Codable, Hashable, Identifiable {
  let personName: String
  let weekStart: Date
  let volume: Double

  var id: String { "\(weekStart.timeIntervalSinceReferenceDate)|\(personName.lowercased())" }
}

struct ProgressWidgetParticipantVolume: Codable, Hashable, Identifiable {
  let personName: String
  let volume: Double

  var id: String { personName.lowercased() }
}

struct ProgressWidgetSessionVolume: Codable, Hashable, Identifiable {
  let sessionID: UUID
  let startedAt: Date
  let participantVolumes: [ProgressWidgetParticipantVolume]

  var id: UUID { sessionID }
}

struct ProgressWidgetHistoryRow: Codable, Hashable, Identifiable {
  let sessionID: UUID
  let routineName: String
  let startedAt: Date
  let completedSetCount: Int
  let totalSetCount: Int
  let personalRecordCount: Int

  var id: UUID { sessionID }
}

struct ProgressWidgetSnapshot: Codable, Hashable {
  let schemaVersion: Int
  let generatedAt: Date
  let calendarIdentifier: String
  let timeZoneIdentifier: String
  let firstWeekday: Int
  let minimumDaysInFirstWeek: Int
  let participants: [ProgressWidgetParticipant]
  let sessionVolumes: [ProgressWidgetSessionVolume]
  let history: [ProgressWidgetHistoryRow]

  func points(asOf now: Date) -> [ProgressWidgetPoint] {
    let calendar = snapshotCalendar
    let lowerBound = calendar.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
    var buckets: [String: ProgressWidgetPoint] = [:]

    for session in sessionVolumes where session.startedAt >= lowerBound && session.startedAt <= now
    {
      let weekStart =
        calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start
        ?? calendar.startOfDay(for: session.startedAt)
      for participantVolume in session.participantVolumes where participantVolume.volume > 0 {
        let key =
          "\(weekStart.timeIntervalSinceReferenceDate)|\(participantVolume.personName.lowercased())"
        if let existing = buckets[key] {
          buckets[key] = ProgressWidgetPoint(
            personName: existing.personName,
            weekStart: existing.weekStart,
            volume: existing.volume + participantVolume.volume)
        } else {
          buckets[key] = ProgressWidgetPoint(
            personName: participantVolume.personName,
            weekStart: weekStart,
            volume: participantVolume.volume)
        }
      }
    }

    return buckets.values.sorted {
      if $0.weekStart != $1.weekStart { return $0.weekStart < $1.weekStart }
      return $0.personName.localizedCaseInsensitiveCompare($1.personName) == .orderedAscending
    }
  }

  func history(asOf now: Date) -> [ProgressWidgetHistoryRow] {
    let lowerBound = (snapshotCalendar.date(byAdding: .weekOfYear, value: -12, to: now) ?? now)
    return history.filter { $0.startedAt >= lowerBound && $0.startedAt <= now }
  }

  private var snapshotCalendar: Calendar {
    let identifier: Calendar.Identifier
    switch calendarIdentifier {
    case "buddhist": identifier = .buddhist
    case "chinese": identifier = .chinese
    case "coptic": identifier = .coptic
    case "ethiopicAmeteMihret": identifier = .ethiopicAmeteMihret
    case "ethiopicAmeteAlem": identifier = .ethiopicAmeteAlem
    case "hebrew": identifier = .hebrew
    case "iso8601": identifier = .iso8601
    case "indian": identifier = .indian
    case "islamic": identifier = .islamic
    case "islamicCivil": identifier = .islamicCivil
    case "japanese": identifier = .japanese
    case "persian": identifier = .persian
    case "republicOfChina": identifier = .republicOfChina
    case "islamicTabular": identifier = .islamicTabular
    case "islamicUmmAlQura": identifier = .islamicUmmAlQura
    default: identifier = .gregorian
    }
    var calendar = Calendar(identifier: identifier)
    calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    calendar.firstWeekday = firstWeekday
    calendar.minimumDaysInFirstWeek = minimumDaysInFirstWeek
    return calendar
  }
}

enum ProgressWidgetSnapshotStore {
  enum StoreError: LocalizedError {
    case appGroupUnavailable
    case unsupportedVersion(Int)

    var errorDescription: String? {
      switch self {
      case .appGroupUnavailable:
        "The shared Progress widget container is unavailable. Check App Group signing and try again."
      case .unsupportedVersion(let version):
        "The Progress widget snapshot uses unsupported version \(version). Open StrengthLog to refresh it."
      }
    }
  }

  static func load() throws -> ProgressWidgetSnapshot? {
    let url = try snapshotURL()
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let snapshot = try JSONDecoder().decode(
      ProgressWidgetSnapshot.self, from: Data(contentsOf: url))
    guard snapshot.schemaVersion == ProgressWidgetConfiguration.schemaVersion else {
      throw StoreError.unsupportedVersion(snapshot.schemaVersion)
    }
    return snapshot
  }

  static func save(_ snapshot: ProgressWidgetSnapshot) throws {
    let url = try snapshotURL()
    let data = try JSONEncoder().encode(snapshot)
    try data.write(to: url, options: .atomic)
  }

  private static func snapshotURL() throws -> URL {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: ProgressWidgetConfiguration.appGroupIdentifier)
    else { throw StoreError.appGroupUnavailable }
    return container.appendingPathComponent(ProgressWidgetConfiguration.snapshotFileName)
  }
}
