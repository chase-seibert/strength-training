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
    let instructions: String
    let imagePaths: [String]
  }

  @MainActor
  static func seedIfNeeded(in context: ModelContext) async {
    let exerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
    guard
      let url = Bundle.main.url(forResource: "exercise-catalog", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let entries = try? JSONDecoder().decode([CatalogEntry].self, from: data)
    else { return }

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
            instructions: item.instructions,
            imagePath: item.imagePaths.first,
            additionalImagePaths: Array(item.imagePaths.dropFirst())
          ))
      }
    } else {
      let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
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

    try? context.save()
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
