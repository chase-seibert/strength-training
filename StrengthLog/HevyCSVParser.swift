import Foundation

struct HevyCSVDocument: Identifiable {
  let id = UUID()
  let filename: String
  let rowCount: Int
  let workouts: [HevyCSVWorkout]

  var routineNames: [String] {
    var seen = Set<String>()
    return workouts.map(\.title).filter { seen.insert($0.lowercased()).inserted }
  }

  var exerciseNames: [String] {
    var seen = Set<String>()
    return workouts.flatMap(\.exercises).map(\.title).filter {
      seen.insert($0.lowercased()).inserted
    }
  }
}

struct HevyCSVWorkout {
  let sourceID: String
  let title: String
  let startedAt: Date
  let endedAt: Date?
  let description: String?
  var exercises: [HevyCSVExercise]
}

struct HevyCSVExercise {
  let title: String
  let notes: String?
  let supersetID: String?
  var sets: [HevyCSVSet]
}

struct HevyCSVSet {
  let index: Int
  let type: String?
  let weightPounds: Double?
  let reps: Int?
  let distanceMiles: Double?
  let durationSeconds: Double?
  let rpe: Double?
}

enum HevyCSVParser {
  static func parse(data: Data, filename: String) throws -> HevyCSVDocument {
    guard let text = String(data: data, encoding: .utf8) else {
      throw HevyCSVImportError.invalidEncoding
    }
    let normalizedText =
      text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let table = parseCSV(normalizedText)
    guard let header = table.first, !header.isEmpty else {
      throw HevyCSVImportError.emptyFile
    }

    let normalizedHeader = header.map(normalizeHeader)
    let required = ["title", "start_time", "exercise_title"]
    let missing = required.filter { !normalizedHeader.contains($0) }
    guard missing.isEmpty else { throw HevyCSVImportError.missingColumns(missing) }

    let indices = Dictionary(
      normalizedHeader.enumerated().map { ($1, $0) },
      uniquingKeysWith: { first, _ in first })
    var parsedRows: [ParsedRow] = []
    for (offset, values) in table.dropFirst().enumerated() {
      guard values.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
      else { continue }
      let rowNumber = offset + 2
      let title = value("title", in: values, indices: indices)
      let startRaw = value("start_time", in: values, indices: indices)
      let exerciseTitle = value("exercise_title", in: values, indices: indices)
      guard !title.isEmpty, !startRaw.isEmpty, !exerciseTitle.isEmpty else {
        throw HevyCSVImportError.missingValue(row: rowNumber)
      }
      guard let startedAt = parseDate(startRaw) else {
        throw HevyCSVImportError.invalidDate(row: rowNumber, value: startRaw)
      }
      let endRaw = value("end_time", in: values, indices: indices)
      let endedAt = endRaw.isEmpty ? nil : parseDate(endRaw)
      if !endRaw.isEmpty, endedAt == nil {
        throw HevyCSVImportError.invalidDate(row: rowNumber, value: endRaw)
      }

      let weightPounds =
        number("weight_lbs", values, indices)
        ?? number("weight_lb", values, indices)
        ?? number("weight_kg", values, indices).map { $0 * 2.204_622_621_8 }
      let distanceMiles =
        number("distance_miles", values, indices)
        ?? number("distance_mi", values, indices)
        ?? number("distance_km", values, indices).map { $0 * 0.621_371_192_2 }
        ?? number("distance_meters", values, indices).map { $0 * 0.000_621_371_2 }

      parsedRows.append(
        ParsedRow(
          order: offset,
          workoutKey: "\(title.lowercased())|\(startRaw)",
          sourceID: "hevy-csv|\(title.lowercased())|\(startRaw)|\(endRaw)",
          title: title,
          startedAt: startedAt,
          endedAt: endedAt,
          description: optionalValue("description", values, indices),
          exerciseTitle: exerciseTitle,
          notes: optionalValue("exercise_notes", values, indices),
          supersetID: optionalValue("superset_id", values, indices),
          set: HevyCSVSet(
            index: integer("set_index", values, indices) ?? 0,
            type: optionalValue("set_type", values, indices),
            weightPounds: weightPounds,
            reps: integer("reps", values, indices),
            distanceMiles: distanceMiles,
            durationSeconds: number("duration_seconds", values, indices),
            rpe: number("rpe", values, indices))))
    }
    guard !parsedRows.isEmpty else { throw HevyCSVImportError.emptyFile }
    return HevyCSVDocument(
      filename: filename, rowCount: parsedRows.count, workouts: group(parsedRows))
  }

  private static func group(_ rows: [ParsedRow]) -> [HevyCSVWorkout] {
    var workouts: [HevyCSVWorkout] = []
    var workoutIndices: [String: Int] = [:]
    for row in rows.sorted(by: { $0.order < $1.order }) {
      let workoutIndex: Int
      if let existing = workoutIndices[row.workoutKey] {
        workoutIndex = existing
      } else {
        workoutIndex = workouts.count
        workoutIndices[row.workoutKey] = workoutIndex
        workouts.append(
          HevyCSVWorkout(
            sourceID: row.sourceID,
            title: row.title,
            startedAt: row.startedAt,
            endedAt: row.endedAt,
            description: row.description,
            exercises: []))
      }

      if workouts[workoutIndex].exercises.last?.title.caseInsensitiveCompare(row.exerciseTitle)
        == .orderedSame
      {
        let exerciseIndex = workouts[workoutIndex].exercises.count - 1
        workouts[workoutIndex].exercises[exerciseIndex].sets.append(row.set)
      } else {
        workouts[workoutIndex].exercises.append(
          HevyCSVExercise(
            title: row.exerciseTitle,
            notes: row.notes,
            supersetID: row.supersetID,
            sets: [row.set]))
      }
    }
    for workoutIndex in workouts.indices {
      for exerciseIndex in workouts[workoutIndex].exercises.indices {
        workouts[workoutIndex].exercises[exerciseIndex].sets.sort { $0.index < $1.index }
      }
    }
    return workouts.sorted { $0.startedAt > $1.startedAt }
  }

  private static func parseCSV(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var field = ""
    var isQuoted = false
    var index = text.startIndex

    func finishField() {
      row.append(field)
      field = ""
    }
    func finishRow() {
      finishField()
      rows.append(row)
      row = []
    }

    while index < text.endIndex {
      let character = text[index]
      let next = text.index(after: index)
      if character == "\"" {
        if isQuoted, next < text.endIndex, text[next] == "\"" {
          field.append("\"")
          index = text.index(after: next)
          continue
        }
        isQuoted.toggle()
      } else if character == ",", !isQuoted {
        finishField()
      } else if character == "\n" || character == "\r", !isQuoted {
        if character == "\r", next < text.endIndex, text[next] == "\n" {
          index = next
        }
        finishRow()
      } else {
        field.append(character)
      }
      index = text.index(after: index)
    }
    if !field.isEmpty || !row.isEmpty { finishRow() }
    return rows
  }

  private static func parseDate(_ value: String) -> Date? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: trimmed) { return date }
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: trimmed) { return date }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    for format in [
      "d MMM yyyy, HH:mm", "d MMM yyyy, H:mm", "yyyy-MM-dd HH:mm:ss",
      "yyyy-MM-dd HH:mm",
    ] {
      formatter.dateFormat = format
      if let date = formatter.date(from: trimmed) { return date }
    }
    return nil
  }

  private static func normalizeHeader(_ value: String) -> String {
    value.replacingOccurrences(of: "\u{feff}", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: " ", with: "_")
  }

  private static func value(_ name: String, in row: [String], indices: [String: Int]) -> String {
    guard let index = indices[name], row.indices.contains(index) else { return "" }
    return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func optionalValue(
    _ name: String, _ row: [String], _ indices: [String: Int]
  ) -> String? {
    let result = value(name, in: row, indices: indices)
    return result.isEmpty ? nil : result
  }

  private static func number(_ name: String, _ row: [String], _ indices: [String: Int]) -> Double? {
    let raw = value(name, in: row, indices: indices)
    return raw.isEmpty ? nil : Double(raw)
  }

  private static func integer(_ name: String, _ row: [String], _ indices: [String: Int]) -> Int? {
    guard let value = number(name, row, indices) else { return nil }
    return Int(value)
  }

  private struct ParsedRow {
    let order: Int
    let workoutKey: String
    let sourceID: String
    let title: String
    let startedAt: Date
    let endedAt: Date?
    let description: String?
    let exerciseTitle: String
    let notes: String?
    let supersetID: String?
    let set: HevyCSVSet
  }
}

enum HevyCSVImportError: LocalizedError {
  case invalidEncoding
  case emptyFile
  case missingColumns([String])
  case missingValue(row: Int)
  case invalidDate(row: Int, value: String)

  var errorDescription: String? {
    switch self {
    case .invalidEncoding:
      "The CSV is not UTF-8 encoded."
    case .emptyFile:
      "The CSV does not contain any workout rows."
    case .missingColumns(let columns):
      "This does not look like a Hevy workout export. Missing: \(columns.joined(separator: ", "))."
    case .missingValue(let row):
      "Row \(row) is missing its routine, start time, or exercise name."
    case .invalidDate(let row, let value):
      "Row \(row) has an unsupported date: \(value)."
    }
  }
}
