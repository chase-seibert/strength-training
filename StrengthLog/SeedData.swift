import Foundation
import SwiftData

enum SeedData {
  private struct CatalogEntry: Decodable {
    let id: String
    let name: String
    let category: String
    let equipment: String
    let primaryMuscle: String
    let unit: String
    let repCountingMode: RepCountingMode?
    let defaultDurationSeconds: Int?
    let instructions: String
    let imagePaths: [String]
  }

  // Immutable catalog metadata stays outside the user's SwiftData schema.
  private static let catalog: Result<[CatalogEntry], Error> = Result {
    guard let url = Bundle.main.url(forResource: "exercise-catalog", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode([CatalogEntry].self, from: Data(contentsOf: url))
  }

  private static let durationDefaults: [String: Int] = {
    guard let entries = try? catalog.get() else { return [:] }
    return entries.reduce(into: [:]) { defaults, entry in
      guard let seconds = entry.defaultDurationSeconds, seconds > 0 else { return }
      defaults[entry.id] = seconds
      defaults[entry.name] = seconds
    }
  }()

  static func defaultDurationSeconds(sourceID: String?, originalName: String) -> Int {
    if let sourceID, let seconds = durationDefaults[sourceID] { return seconds }
    // Duplicates retain their original name even after being renamed.
    return durationDefaults[originalName] ?? 30
  }

  @MainActor
  static func seedIfNeeded(in context: ModelContext) async throws {
    let exerciseCount = try context.fetchCount(FetchDescriptor<Exercise>())
    let entries = try catalog.get()

    if exerciseCount == 0 {
      for item in entries {
        context.insert(
          Exercise(
            sourceID: item.id,
            name: item.name,
            category: item.category,
            equipment: item.equipment,
            primaryMuscle: item.primaryMuscle,
            unit: TrackingUnit(rawValue: item.unit) ?? .pounds,
            repCountingMode: item.repCountingMode ?? .standard,
            instructions: item.instructions,
            imagePath: item.imagePaths.first,
            additionalImagePaths: Array(item.imagePaths.dropFirst())
          ))
      }
    } else {
      let existing = try context.fetch(FetchDescriptor<Exercise>())
      let bySourceID = Dictionary(
        uniqueKeysWithValues: existing.compactMap { exercise in
          exercise.sourceID.map { ($0, exercise) }
        })
      for item in entries {
        guard let exercise = bySourceID[item.id] else { continue }
        exercise.imagePath = item.imagePaths.first
        exercise.additionalImagePathsRaw =
          item.imagePaths.count > 1
          ? item.imagePaths.dropFirst().joined(separator: "\n") : nil
      }

      normalizeStableExerciseIdentity(existing, in: context)
    }

    try context.save()
    try initializeRepCountingModes(in: context)
    try correctPlankDefault(in: context)
    try correctReviewedCatalogUnits(in: context)
  }

  /// Initialize only legacy nil values. Explicit Standard is a user choice, not "unset".
  @MainActor
  static func initializeRepCountingModes(in context: ModelContext) throws {
    let modes = Dictionary(
      uniqueKeysWithValues: try catalog.get().map {
        ($0.id, $0.repCountingMode ?? .standard)
      })
    let legacy = try context.fetch(
      FetchDescriptor<Exercise>(
        predicate: #Predicate { $0.repCountingModeRaw == nil }))
    for exercise in legacy {
      exercise.repCountingMode =
        !exercise.isCustom
        ? exercise.sourceID.flatMap { modes[$0] } ?? .standard : .standard
    }
    try context.save()
  }

  /// Apply only the reviewed old defaults, leaving custom exercises and other unit choices alone.
  @MainActor
  static func correctReviewedCatalogUnits(
    in context: ModelContext, defaults: UserDefaults = .standard
  ) throws {
    let key = "didCorrectReviewedCatalogUnitsV1"
    guard !defaults.bool(forKey: key) else { return }
    let corrections: [(String, TrackingUnit, TrackingUnit)] = [
      ("Balance_Board", .pounds, .seconds),
      ("Battling_Ropes", .pounds, .seconds),
      ("Mountain_Climbers", .repetitions, .seconds),
      ("Isometric_Chest_Squeezes", .repetitions, .seconds),
      ("Isometric_Neck_Exercise_-_Front_And_Back", .repetitions, .seconds),
      ("Isometric_Neck_Exercise_-_Sides", .repetitions, .seconds),
      ("Superman", .seconds, .repetitions),
      ("Toe_Touchers", .seconds, .repetitions),
      ("Ankle_Circles", .seconds, .repetitions),
    ]
    for (sourceID, previousUnit, correctedUnit) in corrections {
      let descriptor = FetchDescriptor<Exercise>(
        predicate: #Predicate { $0.sourceID == sourceID })
      for exercise in try context.fetch(descriptor)
      where !exercise.isCustom && exercise.deletedAt == nil && exercise.unit == previousUnit {
        exercise.unit = correctedUnit
      }
    }
    try context.save()
    defaults.set(true, forKey: key)
  }

  /// Correct the old bundled default once, without repeatedly overriding user edits.
  @MainActor
  static func correctPlankDefault(
    in context: ModelContext, defaults: UserDefaults = .standard
  ) throws {
    let key = "didCorrectPlankSecondsDefaultV1"
    guard !defaults.bool(forKey: key) else { return }
    let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.sourceID == "Plank" })
    for exercise in try context.fetch(descriptor) where exercise.unit == .repetitions {
      exercise.unit = .seconds
    }
    try context.save()
    defaults.set(true, forKey: key)
  }

  private static func normalizeStableExerciseIdentity(
    _ exercises: [Exercise], in context: ModelContext
  ) {
    for exercise in exercises {
      if exercise.originalName.isEmpty { exercise.originalName = exercise.name }
      if exercise.rootExerciseID == nil { exercise.rootExerciseID = exercise.id }
    }

    let groupedByName = Dictionary(grouping: exercises, by: { $0.name.lowercased() })
    let uniqueByName = groupedByName.compactMapValues { $0.count == 1 ? $0[0] : nil }

    let routineExercises = (try? context.fetch(FetchDescriptor<RoutineExercise>())) ?? []
    for reference in routineExercises where reference.exerciseID == nil {
      reference.exerciseID = uniqueByName[reference.exerciseName.lowercased()]?.id
    }

    let exerciseLogs = (try? context.fetch(FetchDescriptor<ExerciseLog>())) ?? []
    for log in exerciseLogs where log.exerciseID == nil {
      log.exerciseID = uniqueByName[log.exerciseName.lowercased()]?.id
    }
  }
}
