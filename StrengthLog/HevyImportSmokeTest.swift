#if DEBUG
  import Foundation
  import SwiftData

  @MainActor
  enum HevyImportSmokeTest {
    static func run() throws {
      let schema = Schema([
        PersonProfile.self,
        Exercise.self,
        Routine.self,
        RoutineExercise.self,
        Prescription.self,
        SetTemplate.self,
        WorkoutSession.self,
        ExerciseLog.self,
        ParticipantLog.self,
        WorkoutSet.self,
        ExternalExerciseMapping.self,
      ])
      let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: schema, configurations: [configuration])
      let context = container.mainContext
      let person = PersonProfile(name: "Import Tester", colorHex: "FF5A45")
      let squat = Exercise(
        name: "Goblet Squat", category: "strength", equipment: "dumbbell",
        primaryMuscle: "quadriceps", unit: .pounds, instructions: "")
      let plank = Exercise(
        name: "Plank", category: "strength", equipment: "body only",
        primaryMuscle: "abdominals", unit: .seconds, instructions: "")
      let crunch = Exercise(
        name: "Reverse Crunch", category: "strength", equipment: "body only",
        primaryMuscle: "abdominals", unit: .repetitions, instructions: "")
      context.insert(person)
      context.insert(squat)
      context.insert(plank)
      context.insert(crunch)
      context.insert(Routine(name: "Core"))

      let sample = """
        title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_lbs,reps,distance_miles,duration_seconds,rpe
        Core,"26 Aug 2026, 06:43","26 Aug 2026, 07:24","Imported note",Goblet Squat,,"Stay tall",0,normal,55,8,,,8
        Core,"26 Aug 2026, 06:43","26 Aug 2026, 07:24","Imported note",Goblet Squat,,"Stay tall",1,normal,45,10,,,9
        Core,"26 Aug 2026, 06:43","26 Aug 2026, 07:24","Imported note",Plank,,,0,normal,,,,60,
        Core,"20 Aug 2026, 06:43","20 Aug 2026, 07:10",,Reverse Crunch,,,0,normal,,12,,,
        Core,"20 Aug 2026, 06:43","20 Aug 2026, 07:10",,Mystery Move,,,0,normal,,10,,,
        Upper,"25 Aug 2026, 06:43","25 Aug 2026, 07:10",,Pull Up,,,0,normal,,8,,,
        """
      let document = try HevyCSVParser.parse(
        data: Data(sample.utf8), filename: "hevy-smoke.csv")
      let choices: [String: HevyExerciseMappingChoice] = [
        "Goblet Squat": .exercise(squat.id),
        "Plank": .exercise(plank.id),
        "Reverse Crunch": .exercise(crunch.id),
      ]
      let coreKey = HevyImporter.routineKey("Core")
      let first = try HevyImporter.run(
        document: document,
        person: person,
        selectedRoutineKeys: [coreKey],
        choices: choices,
        catalog: [squat, plank, crunch],
        context: context)
      guard
        first.routineCount == 1,
        first.routineExerciseCount == 3,
        first.workoutCount == 2,
        first.historyExerciseCount == 3,
        first.skippedExerciseCount == 1
      else {
        throw SmokeError.unexpectedCounts
      }
      let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
      let latestSession = sessions.max { $0.startedAt < $1.startedAt }
      let gobletLog = latestSession?.exercises.first { $0.exerciseName == "Goblet Squat" }
      let sets = gobletLog?.participants.first?.sets.sorted {
        $0.sortOrder < $1.sortOrder
      }
      guard
        latestSession?.notes == "Imported note",
        sets?.first?.measurement == 55,
        sets?.last?.measurement == 45,
        sets?.last?.rpe == 9
      else { throw SmokeError.lostSetData }

      let routines = try context.fetch(FetchDescriptor<Routine>())
      guard
        let importedRoutine = routines.first(where: { $0.name == "Core (2)" }),
        Set(importedRoutine.exercises.map(\.exerciseName))
          == Set(["Goblet Squat", "Plank", "Reverse Crunch"]),
        routines.first(where: { $0.name == "Core" })?.exercises.isEmpty == true
      else { throw SmokeError.lostRoutineExercises }

      let second = try HevyImporter.run(
        document: document,
        person: person,
        selectedRoutineKeys: [coreKey],
        choices: choices,
        catalog: [squat, plank, crunch],
        context: context)
      guard second.workoutCount == 0, second.skippedWorkoutCount == 2 else {
        throw SmokeError.duplicateImport
      }
      let routineNames = Set(try context.fetch(FetchDescriptor<Routine>()).map(\.name))
      guard routineNames == Set(["Core", "Core (2)", "Core (3)"]) else {
        throw SmokeError.routineCollision
      }
    }
  }

  private enum SmokeError: LocalizedError {
    case unexpectedCounts
    case lostSetData
    case lostRoutineExercises
    case duplicateImport
    case routineCollision

    var errorDescription: String? {
      switch self {
      case .unexpectedCounts: "The importer created the wrong routine or workout count."
      case .lostSetData: "The importer did not preserve per-set values or notes."
      case .lostRoutineExercises:
        "The imported routine did not contain every mapped exercise."
      case .duplicateImport: "The importer did not skip a duplicate workout."
      case .routineCollision: "The importer did not create a uniquely named routine."
      }
    }
  }
#endif
