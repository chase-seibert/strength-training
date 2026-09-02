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
      try verifyMasterUnitPersistence(schema: schema)
      try verifyCatalogDefaultsAndCorrections(schema: schema)
    }

    private static func verifyCatalogDefaultsAndCorrections(schema: Schema) throws {
      struct Entry: Decodable {
        let id: String
        let name: String
        let unit: TrackingUnit
        let defaultDurationSeconds: Int?
      }
      let url = Bundle.main.url(forResource: "exercise-catalog", withExtension: "json")!
      let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
      let catalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
      let cases: [(String, TrackingUnit, TrackingUnit, Int)] = [
        ("Balance_Board", .pounds, .seconds, 30),
        ("Battling_Ropes", .pounds, .seconds, 30),
        ("Mountain_Climbers", .repetitions, .seconds, 30),
        ("Isometric_Chest_Squeezes", .repetitions, .seconds, 10),
        ("Isometric_Neck_Exercise_-_Front_And_Back", .repetitions, .seconds, 5),
        ("Isometric_Neck_Exercise_-_Sides", .repetitions, .seconds, 5),
        ("Superman", .seconds, .repetitions, 12),
        ("Toe_Touchers", .seconds, .repetitions, 12),
        ("Ankle_Circles", .seconds, .repetitions, 12),
        ("Stomach_Vacuum", .seconds, .seconds, 20),
        ("One_Handed_Hang", .seconds, .seconds, 20),
        ("Shoulder_Stretch", .seconds, .seconds, 30),
        ("All_Fours_Quad_Stretch", .seconds, .seconds, 20),
        ("Cat_Stretch", .seconds, .seconds, 15),
        ("Chair_Lower_Back_Stretch", .seconds, .seconds, 10),
      ]
      // Time targets must not inherit a user's rep preference.
      let oldReps = UserDefaults.standard.object(forKey: WorkoutPreferences.defaultRepsKey)
      UserDefaults.standard.set(12, forKey: WorkoutPreferences.defaultRepsKey)
      defer {
        UserDefaults.standard.set(oldReps, forKey: WorkoutPreferences.defaultRepsKey)
      }
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let suite = "catalog-default-test-\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suite)!
      defer { defaults.removePersistentDomain(forName: suite) }
      let configuration = ModelConfiguration(
        schema: schema, url: directory.appendingPathComponent("catalog.store"),
        cloudKitDatabase: .none)
      var exerciseIDs: [UUID] = []
      var setIDs: [UUID] = []
      let historyID: UUID
      let untouchedIDs: [UUID]
      func exercise(_ sourceID: String, unit: TrackingUnit) -> Exercise {
        Exercise(
          sourceID: sourceID, name: catalog[sourceID]!.name, category: "strength",
          equipment: "body only", primaryMuscle: "other", unit: unit, instructions: "")
      }
      do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        var logs: [ExerciseLog] = []
        for (index, test) in cases.enumerated() {
          let (sourceID, previousUnit, correctedUnit, target) = test
          guard catalog[sourceID]?.unit == correctedUnit else {
            throw SmokeError.catalogDefaults
          }
          let fresh = exercise(sourceID, unit: correctedUnit)
          guard fresh.defaultTarget == target else { throw SmokeError.catalogDefaults }
          let master = exercise(sourceID, unit: previousUnit)
          master.name = "Renamed \(sourceID)"
          context.insert(master)
          exerciseIDs.append(master.id)
          let set = WorkoutSet(
            sortOrder: 0, reps: 17, isCompleted: true, measurement: 42,
            durationSeconds: previousUnit == .seconds ? 17 : nil)
          setIDs.append(set.id)
          logs.append(
            ExerciseLog(
              exerciseID: master.id, exerciseName: master.name, unit: previousUnit,
              sortOrder: index,
              participants: [
                ParticipantLog(participantName: "Tester", measurement: 42, sets: [set])
              ]))
        }
        let history = WorkoutSession(
          routineID: UUID(), participantNames: ["Tester"], exercises: logs,
          endedAt: .now, isActive: false)
        historyID = history.id
        context.insert(history)

        let customized = exercise("Balance_Board", unit: .minutes)
        let custom = exercise("Battling_Ropes", unit: .pounds)
        custom.isCustom = true
        let deleted = exercise("Mountain_Climbers", unit: .repetitions)
        deleted.deletedAt = .now
        let duplicate = Exercise(
          originalName: "Isometric Chest Squeezes", name: "Renamed duplicate",
          category: "strength", equipment: "body only", primaryMuscle: "chest",
          unit: .seconds, instructions: "", isCustom: true)
        guard duplicate.defaultTarget == 10 else { throw SmokeError.catalogDefaults }
        duplicate.unit = .repetitions
        untouchedIDs = [customized, custom, deleted, duplicate].map(\.id)
        for item in [customized, custom, deleted, duplicate] { context.insert(item) }
        try context.save()
      }
      // Correct a reopened disk store, not just newly inserted in-memory records.
      do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        try SeedData.correctReviewedCatalogUnits(in: context, defaults: defaults)
        let masters = try context.fetch(FetchDescriptor<Exercise>())
        let freshSession = WorkoutSession(
          routineID: UUID(), participantNames: ["Tester"], exercises: [])
        context.insert(freshSession)
        for (index, test) in cases.enumerated() {
          guard let master = masters.first(where: { $0.id == exerciseIDs[index] }),
            master.unit == test.2, master.defaultTarget == test.3,
            freshSession.add(master),
            freshSession.exercises.last?.participants.first?.sets.first?.reps == test.3
          else { throw SmokeError.catalogDefaults }
        }
        let untouchedUnits: [TrackingUnit] = [.minutes, .pounds, .repetitions, .repetitions]
        for (id, unit) in zip(untouchedIDs, untouchedUnits) {
          guard masters.first(where: { $0.id == id })?.unit == unit else {
            throw SmokeError.catalogDefaults
          }
        }
        // A subsequent explicit choice, even the old default, must survive relaunch.
        masters.first(where: { $0.id == exerciseIDs[0] })?.unit = .pounds
        try context.save()
      }
      let reopened = try ModelContainer(for: schema, configurations: [configuration])
      try SeedData.correctReviewedCatalogUnits(in: reopened.mainContext, defaults: defaults)
      let sessions = try reopened.mainContext.fetch(FetchDescriptor<WorkoutSession>())
      guard sessions.count == 2, let history = sessions.first(where: { $0.id == historyID }),
        !history.isActive, history.exercises.count == cases.count,
        try reopened.mainContext.fetchCount(FetchDescriptor<Exercise>())
          == cases.count + untouchedIDs.count
      else { throw SmokeError.catalogDefaults }
      for (index, test) in cases.enumerated() {
        guard let log = history.exercises.first(where: { $0.sortOrder == index }),
          log.exerciseID == exerciseIDs[index],
          log.unit == (index == 0 ? .pounds : test.2), log.unitRaw == test.1.rawValue,
          let set = log.participants.first?.sets.first,
          set.id == setIDs[index], set.reps == 17, set.measurement == 42, set.isCompleted,
          set.durationSeconds == (test.1 == .seconds ? 17 : nil)
        else { throw SmokeError.catalogDefaults }
      }
      // Every bundled seconds default resolves independently of the rep preference.
      for entry in entries where entry.unit == .seconds {
        guard let seconds = entry.defaultDurationSeconds, seconds > 0,
          exercise(entry.id, unit: .seconds).defaultTarget == seconds
        else { throw SmokeError.catalogDefaults }
      }
      let customTimer = exercise("Balance_Board", unit: .seconds)
      customTimer.sourceID = nil
      customTimer.originalName = "New custom timer"
      guard customTimer.defaultTarget == 30 else { throw SmokeError.catalogDefaults }
    }

    private static func verifyMasterUnitPersistence(schema: Schema) throws {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let suite = "exercise-unit-test-\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suite)!
      defer { defaults.removePersistentDomain(forName: suite) }
      let configuration = ModelConfiguration(
        schema: schema, url: directory.appendingPathComponent("workouts.store"),
        cloudKitDatabase: .none)
      let sessionID: UUID
      let setID: UUID
      do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let plank = Exercise(
          sourceID: "Plank", name: "Plank", category: "strength", equipment: "body only",
          primaryMuscle: "abdominals", unit: .repetitions, instructions: "")
        context.insert(plank)
        let set = WorkoutSet(sortOrder: 0, reps: 45, isCompleted: true)
        let participant = ParticipantLog(participantName: "Tester", measurement: 0, sets: [set])
        let log = ExerciseLog(
          exerciseID: plank.id, exerciseName: "Plank", unit: .repetitions, sortOrder: 0,
          participants: [participant])
        let session = WorkoutSession(
          routineID: UUID(), participantNames: ["Tester"], exercises: [log])
        context.insert(session)
        try context.save()
        sessionID = session.id
        setID = set.id
        guard log.unit == .repetitions else { throw SmokeError.unitPersistence }
        try SeedData.correctPlankDefault(in: context, defaults: defaults)
        guard log.unit == .seconds, plank.defaultTarget == 60, set.reps == 45,
          set.isCompleted, set.summary(participant: participant, unit: log.unit) == "45 sec"
        else { throw SmokeError.unitPersistence }

        // The correction is one-off: subsequent explicit user choices win.
        plank.unit = .repetitions
        try SeedData.correctPlankDefault(in: context, defaults: defaults)
        guard log.unit == .repetitions else { throw SmokeError.unitPersistence }
        plank.unit = .seconds
        let newSession = WorkoutSession(
          routineID: UUID(), participantNames: ["Tester"], exercises: [])
        context.insert(newSession)
        newSession.add(plank)
        guard newSession.exercises.first?.participants.first?.sets.first?.reps == 60 else {
          throw SmokeError.unitPersistence
        }
        let importedSet = WorkoutSet(sortOrder: 0, reps: 60, durationSeconds: 60)
        guard importedSet.target(for: .minutes) == 1 else { throw SmokeError.unitPersistence }
        importedSet.setTarget(75, unit: .seconds)
        guard importedSet.durationSeconds == 75 else { throw SmokeError.unitPersistence }
        // A deliberate duplicate is a separate master, even when its root identity is shared.
        let duplicate = Exercise(
          originalName: "Plank", rootExerciseID: plank.id, name: "Plank Copy",
          category: "strength", equipment: "body only", primaryMuscle: "abdominals",
          unit: .repetitions, instructions: "", isCustom: true)
        context.insert(duplicate)
        duplicate.unit = .pounds
        guard log.unit == .seconds else { throw SmokeError.unitPersistence }
        try context.save()
      }
      let reopened = try ModelContainer(for: schema, configurations: [configuration])
      let sessions = try reopened.mainContext.fetch(FetchDescriptor<WorkoutSession>())
      guard let restored = sessions.first(where: { $0.id == sessionID }),
        let log = restored.exercises.first, let set = log.participants.first?.sets.first,
        log.unitRaw == TrackingUnit.repetitions.rawValue, log.unit == .seconds,
        set.id == setID, set.reps == 45, set.isCompleted,
        sessions.count == 2
      else { throw SmokeError.unitPersistence }
    }
  }

  private enum SmokeError: LocalizedError {
    case unexpectedCounts
    case lostSetData
    case lostRoutineExercises
    case duplicateImport
    case routineCollision
    case unitPersistence
    case catalogDefaults

    var errorDescription: String? {
      switch self {
      case .unexpectedCounts: "The importer created the wrong routine or workout count."
      case .lostSetData: "The importer did not preserve per-set values or notes."
      case .lostRoutineExercises:
        "The imported routine did not contain every mapped exercise."
      case .duplicateImport: "The importer did not skip a duplicate workout."
      case .routineCollision: "The importer did not create a uniquely named routine."
      case .unitPersistence:
        "Master exercise units or recorded values failed the on-disk persistence check."
      case .catalogDefaults:
        "Catalog targets, unit corrections, or saved values failed the persistence check."
      }
    }
  }
#endif
