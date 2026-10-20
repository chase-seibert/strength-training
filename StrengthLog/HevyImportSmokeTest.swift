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
      let configuration = ModelConfiguration(
        schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
      if ProcessInfo.processInfo.arguments.contains("-validateCoordinatedExerciseOrderOnly") {
        try verifyCoordinatedExerciseOrderPersistence(schema: schema)
        return
      }
      try verifyMasterUnitPersistence(schema: schema)
      try verifyCatalogDefaultsAndCorrections(schema: schema)
      try verifyCoordinatedExerciseOrderPersistence(schema: schema)
      try verifyRepCountingPersistence(schema: schema)
      try verifySideTotalRepsReminderDefaults(schema: schema)
      try verifyWorkoutDurations()
      try verifyPerDumbbellLoadSummary()
    }

    private static func verifyPerDumbbellLoadSummary() throws {
      let participant = ParticipantLog(
        participantName: "Dumbbell Tester", measurement: 30,
        sets: [WorkoutSet(sortOrder: 0, reps: 8, measurement: 25)])
      let defaultLoadSet = WorkoutSet(sortOrder: 1, reps: 8)
      guard let set = participant.sets.first,
        set.measurement == 25,
        set.summary(participant: participant, unit: .pounds, usesPerDumbbellLoad: true)
          == "25 lb per dumbbell × 8 reps",
        set.summary(participant: participant, unit: .kilograms, usesPerDumbbellLoad: true)
          == "25 kg per dumbbell × 8 reps",
        set.summary(participant: participant, unit: .pounds)
          == "25 lb × 8 reps",
        defaultLoadSet.summary(
          participant: participant, unit: .pounds, usesPerDumbbellLoad: true)
          == "30 lb per dumbbell × 8 reps"
      else { throw SmokeError.dumbbellLoadFormatting }
    }

    private static func verifyWorkoutDurations() throws {
      let start = Date(timeIntervalSince1970: 1_800_000_000)
      let end = start.addingTimeInterval(90 * 60)
      let active = WorkoutSession(
        routineID: UUID(), participantNames: [], exercises: [], startedAt: start, isActive: true)
      let completed = WorkoutSession(
        routineID: UUID(), participantNames: [], exercises: [], startedAt: start, endedAt: end,
        isActive: false)
      let missingEnd = WorkoutSession(
        routineID: UUID(), participantNames: [], exercises: [], startedAt: start, isActive: false)
      guard
        active.workoutDuration == nil,
        active.workoutDuration(at: end) == 90 * 60,
        completed.workoutDuration == 90 * 60,
        completed.workoutDuration(at: end.addingTimeInterval(20 * 60)) == 90 * 60,
        missingEnd.workoutDuration == nil,
        WorkoutSession.validatedWorkoutDuration(start: start, end: start) == nil,
        WorkoutSession.validatedWorkoutDuration(start: end, end: start) == nil,
        WorkoutSession.validatedWorkoutDuration(
          start: start, end: start.addingTimeInterval(WorkoutSession.maximumWorkoutDuration + 1))
          == nil,
        WorkoutSession.validatedWorkoutDuration(start: .distantFuture, end: .distantPast) == nil
      else { throw SmokeError.invalidWorkoutDuration }
    }

    private static func verifyRepCountingPersistence(schema: Schema) throws {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let configuration = ModelConfiguration(
        schema: schema, url: directory.appendingPathComponent("reps.store"), cloudKitDatabase: .none
      )
      let sessionID: UUID
      let setID: UUID
      let exerciseID: UUID
      do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        func exercise(_ source: String, custom: Bool = false) -> Exercise {
          let result = Exercise(
            sourceID: source, name: source, category: "strength", equipment: "cable",
            primaryMuscle: "abdominals", unit: .pounds, instructions: "", isCustom: custom)
          result.repCountingModeRaw = nil  // Simulate the absence of this field in old records.
          context.insert(result)
          return result
        }
        let cable = exercise("Cable_Russian_Twists")
        cable.name = "Renamed cable twists"
        let userChoice = exercise("One-Arm_Dumbbell_Row")
        userChoice.repCountingMode = .standard
        let custom = exercise("Standing_Cable_Lift", custom: true)
        let alternating = exercise("Single-Arm_Cable_Crossover")
        let set = WorkoutSet(sortOrder: 0, reps: 7, isCompleted: true, measurement: 20)
        let skipped = WorkoutSet(sortOrder: 1, reps: 100, isCompleted: true, isSkipped: true)
        let bestSet = WorkoutSet(sortOrder: 2, reps: 12, isCompleted: true, measurement: 15)
        let participant = ParticipantLog(
          participantName: "Tester", measurement: 10, sets: [set, skipped, bestSet])
        let log = ExerciseLog(
          exerciseID: cable.id, exerciseName: cable.name, unit: .pounds,
          sortOrder: 0, participants: [participant])
        let session = WorkoutSession(
          routineID: UUID(), participantNames: ["Tester"], exercises: [log])
        context.insert(session)
        try context.save()
        sessionID = session.id
        exerciseID = cable.id
        setID = set.id
        guard log.repCountingMode == .standard, log.completedPoundsVolume(for: "Tester") == 320
        else {
          throw SmokeError.repCounting
        }
        guard PersonalRecords.achievements(in: [session]).first?.value == 180
        else {
          throw SmokeError.repCounting
        }
        try SeedData.initializeRepCountingModes(in: context)
        guard log.repCountingMode == .perSide, cable.repCountingModeRaw == "perSide",
          userChoice.repCountingMode == .standard, custom.repCountingModeRaw == "standard",
          alternating.repCountingMode == .standard,
          log.completedPoundsVolume(for: "tester") == 640,
          log.completedPoundsVolume(for: "Other person") == 0,
          set.summary(
            participant: participant, unit: log.unit, repCountingMode: log.repCountingMode)
            == "20 lb × 7 reps/side"
        else { throw SmokeError.repCounting }
        let celebration = WorkoutCelebrationSummary.make(
          session: session, allSessions: [session], routineName: "Test", colorHexByName: [:])
        guard celebration.totalVolume == 640, celebration.people.first?.completedSetCount == 2
        else {
          throw SmokeError.repCounting
        }
        cable.repCountingMode = .standard
        try SeedData.initializeRepCountingModes(in: context)
        guard log.repCountingMode == .standard, set.reps == 7, set.isCompleted else {
          throw SmokeError.repCounting
        }
        cable.repCountingMode = .perSide
        cable.unit = .repetitions
        guard log.targetLabel == "reps/side",
          set.summary(
            participant: participant, unit: log.unit, repCountingMode: log.repCountingMode)
            == "7 reps/side",
          PersonalRecords.value(for: set, participant: participant, unit: log.unit) == 7
        else { throw SmokeError.repCounting }
        let repRecord = WorkoutCelebrationSummary.make(
          session: session, allSessions: [session], routineName: "Test", colorHexByName: [:])
        guard repRecord.people.first?.personalRecords.first?.unitLabel == "reps/side" else {
          throw SmokeError.repCounting
        }
        cable.unit = .seconds
        guard log.targetLabel == "sec", log.completedPoundsVolume() == 0 else {
          throw SmokeError.repCounting
        }
        cable.unit = .pounds
        let duplicate = Exercise(
          originalName: cable.canonicalOriginalName, rootExerciseID: cable.id,
          name: "Copy", category: cable.category, equipment: cable.equipment,
          primaryMuscle: cable.primaryMuscle, unit: cable.unit,
          repCountingMode: cable.repCountingMode, instructions: "", isCustom: true)
        context.insert(duplicate)
        duplicate.repCountingMode = .standard
        guard log.repCountingMode == .perSide else { throw SmokeError.repCounting }
        let orphan = ExerciseLog(
          exerciseName: "Unknown", unit: .pounds, sortOrder: 1, participants: [])
        context.insert(orphan)
        guard orphan.repCountingMode == .standard else { throw SmokeError.repCounting }
        try context.save()
      }
      let reopened = try ModelContainer(for: schema, configurations: [configuration])
      try SeedData.initializeRepCountingModes(in: reopened.mainContext)
      let sessions = try reopened.mainContext.fetch(FetchDescriptor<WorkoutSession>())
      guard let session = sessions.first(where: { $0.id == sessionID }),
        let log = session.exercises.first, let set = log.participants.first?.orderedSets.first,
        log.exerciseID == exerciseID, log.repCountingMode == .perSide,
        log.completedPoundsVolume() == 640, set.id == setID, set.reps == 7, set.isCompleted,
        log.participants.first?.sets.count == 3
      else { throw SmokeError.repCounting }
    }

    private static func verifySideTotalRepsReminderDefaults(schema: Schema) throws {
      let container = try ModelContainer(
        for: schema,
        configurations: [
          ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
      let context = container.mainContext
      let cableTwists = Exercise(
        sourceID: "Cable_Russian_Twists", name: "Cable Russian Twists", category: "strength",
        equipment: "cable", primaryMuscle: "abdominals", unit: .pounds,
        repCountingMode: .perSide, instructions: "")
      let pallof = Exercise(
        sourceID: "Pallof_Press", name: "Pallof Press", category: "strength",
        equipment: "cable", primaryMuscle: "abdominals", unit: .pounds,
        repCountingMode: .perSide, instructions: "")
      let ordinary = Exercise(
        name: "Bench Press", category: "strength", equipment: "barbell",
        primaryMuscle: "chest", unit: .pounds, instructions: "")
      context.insert(cableTwists)
      context.insert(pallof)
      context.insert(ordinary)
      let set = WorkoutSet(sortOrder: 0, reps: 24, isCompleted: true)
      let participant = ParticipantLog(participantName: "Tester", measurement: 50, sets: [set])
      let log = ExerciseLog(
        exerciseID: cableTwists.id, exerciseName: cableTwists.name, unit: .pounds,
        sortOrder: 0, participants: [participant])
      context.insert(log)

      guard cableTwists.hasSideTotalRepsReminder, pallof.hasSideTotalRepsReminder,
        !ordinary.hasSideTotalRepsReminder, log.hasSideTotalRepsReminder,
        log.repCountingMode == .standard, log.completedPoundsVolume() == 1_200,
        set.reps == 24
      else { throw SmokeError.repCounting }

      cableTwists.sideTotalRepsReminderEnabled = false
      guard !log.hasSideTotalRepsReminder, log.repCountingMode == .perSide,
        log.completedPoundsVolume() == 2_400, set.reps == 24
      else { throw SmokeError.repCounting }
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

      // Reorder the existing disk-backed history without replacing its logs or recorded sets.
      let oldOrder = history.exercises.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
      var rejectedIncompleteOrder = false
      do {
        try history.saveExerciseOrder(Array(oldOrder.dropLast()), in: reopened.mainContext)
      } catch {
        rejectedIncompleteOrder = true
      }
      guard rejectedIncompleteOrder,
        history.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id) == oldOrder
      else { throw SmokeError.exerciseOrder }
      let newOrder = Array(oldOrder.reversed())
      try history.saveExerciseOrder(newOrder, in: reopened.mainContext)
      let reorderedContainer = try ModelContainer(for: schema, configurations: [configuration])
      let reorderedSessions = try reorderedContainer.mainContext.fetch(
        FetchDescriptor<WorkoutSession>())
      guard let reordered = reorderedSessions.first(where: { $0.id == historyID }),
        reordered.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id) == newOrder
      else { throw SmokeError.exerciseOrder }
      for (index, exerciseID) in exerciseIDs.enumerated() {
        guard let log = reordered.exercises.first(where: { $0.exerciseID == exerciseID }),
          let set = log.participants.first?.sets.first,
          set.id == setIDs[index], set.reps == 17, set.measurement == 42, set.isCompleted
        else { throw SmokeError.exerciseOrder }
      }
    }

    private static func verifyCoordinatedExerciseOrderPersistence(schema: Schema) throws {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let configuration = ModelConfiguration(
        schema: schema, url: directory.appendingPathComponent("order.store"),
        cloudKitDatabase: .none)
      let routineID = UUID()
      let sessionID = UUID()
      let exerciseIDs = [UUID(), UUID(), UUID()]
      let logIDs = [UUID(), UUID(), UUID()]
      let entryIDs = [UUID(), UUID(), UUID()]
      let setIDs = [UUID(), UUID(), UUID()]
      let originalSessionOrder = logIDs
      let newSessionOrder = [logIDs[2], logIDs[0], logIDs[1]]
      let originalRoutineOrder = entryIDs

      do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let exercises = (0..<3).map { index in
          Exercise(
            name: "Order Exercise \(index)", category: "strength", equipment: "barbell",
            primaryMuscle: "other", unit: .pounds, instructions: "")
        }
        for (index, exercise) in exercises.enumerated() { exercise.id = exerciseIDs[index] }
        let entries = exercises.enumerated().map { index, exercise in
          let entry = RoutineExercise.make(exercise: exercise, sortOrder: index)
          entry.id = entryIDs[index]
          return entry
        }
        let routine = Routine(name: "Order Test", exercises: entries)
        routine.id = routineID
        let logs = exercises.enumerated().map { index, exercise in
          let set = WorkoutSet(
            sortOrder: 0, reps: 8 + index, isCompleted: index == 0,
            measurement: Double(100 + index))
          set.id = setIDs[index]
          let log = ExerciseLog(
            exerciseID: exercise.id, exerciseName: exercise.name, unit: .pounds,
            sortOrder: index,
            participants: [ParticipantLog(participantName: "Tester", measurement: 100, sets: [set])]
          )
          log.id = logIDs[index]
          return log
        }
        let session = WorkoutSession(
          routineID: routine.id, participantNames: ["Tester"], exercises: logs)
        session.id = sessionID
        context.insert(routine)
        context.insert(session)
        for exercise in exercises { context.insert(exercise) }
        let otherRoutine = Routine(
          name: "Other Order Test",
          exercises: exercises.enumerated().map {
            RoutineExercise.make(exercise: $0.element, sortOrder: $0.offset)
          })
        context.insert(otherRoutine)
        try context.save()

        let baselineRoutineOrder = entries.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
        let firstSet = logs[0].participants[0].sets[0]
        firstSet.reps = 19
        var rejectedPersistence = false
        do {
          try session.saveExerciseOrder(
            newSessionOrder, to: routine, expectedSessionOrder: originalSessionOrder,
            expectedRoutineOrder: baselineRoutineOrder, in: context,
            saveOperation: { throw SmokeError.exerciseOrder })
        } catch {
          rejectedPersistence = true
        }
        guard rejectedPersistence,
          session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id)
            == originalSessionOrder,
          routine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id)
            == originalRoutineOrder,
          firstSet.reps == 19
        else { throw SmokeError.exerciseOrder }
        firstSet.reps = 8
        try context.save()

        entries[0].sortOrder = 1
        entries[1].sortOrder = 0
        var rejectedStaleDraft = false
        do {
          try session.saveExerciseOrder(
            newSessionOrder, to: routine, expectedSessionOrder: originalSessionOrder,
            expectedRoutineOrder: baselineRoutineOrder, in: context)
        } catch {
          rejectedStaleDraft = true
        }
        guard rejectedStaleDraft else { throw SmokeError.exerciseOrder }
        entries[0].sortOrder = 0
        entries[1].sortOrder = 1
        try context.save()
        try session.saveExerciseOrder(
          newSessionOrder, to: routine, expectedSessionOrder: originalSessionOrder,
          expectedRoutineOrder: baselineRoutineOrder, in: context)
        guard
          session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id)
            == newSessionOrder,
          routine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id)
            == [entryIDs[2], entryIDs[0], entryIDs[1]]
        else { throw SmokeError.exerciseOrder }
      }

      let reopened = try ModelContainer(for: schema, configurations: [configuration])
      let context = reopened.mainContext
      let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
      let routines = try context.fetch(FetchDescriptor<Routine>())
      guard let session = sessions.first(where: { $0.id == sessionID }),
        let routine = routines.first(where: { $0.id == routineID }),
        session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id)
          == newSessionOrder,
        routine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id)
          == [entryIDs[2], entryIDs[0], entryIDs[1]],
        let otherRoutine = routines.first(where: { $0.name == "Other Order Test" }),
        otherRoutine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
          .compactMap(\.exerciseID) == exerciseIDs
      else { throw SmokeError.exerciseOrder }
      for index in exerciseIDs.indices {
        guard let log = session.exercises.first(where: { $0.id == logIDs[index] }),
          log.exerciseID == exerciseIDs[index],
          let set = log.participants.first?.sets.first,
          set.id == setIDs[index], set.reps == 8 + index,
          set.measurement == Double(100 + index), set.isCompleted == (index == 0)
        else { throw SmokeError.exerciseOrder }
      }
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
    case invalidWorkoutDuration
    case unitPersistence
    case catalogDefaults
    case exerciseOrder
    case repCounting
    case dumbbellLoadFormatting

    var errorDescription: String? {
      switch self {
      case .unexpectedCounts: "The importer created the wrong routine or workout count."
      case .lostSetData: "The importer did not preserve per-set values or notes."
      case .lostRoutineExercises:
        "The imported routine did not contain every mapped exercise."
      case .duplicateImport: "The importer did not skip a duplicate workout."
      case .routineCollision: "The importer did not create a uniquely named routine."
      case .invalidWorkoutDuration:
        "Workout duration accepted a missing, invalid, or over-limit interval."
      case .unitPersistence:
        "Master exercise units or recorded values failed the on-disk persistence check."
      case .catalogDefaults:
        "Catalog targets, unit corrections, or saved values failed the persistence check."
      case .exerciseOrder:
        "Exercise reordering failed to preserve the saved order, exercise logs, or sets."
      case .repCounting:
        "Master rep-counting defaults, live resolution, volume, or disk persistence failed."
      case .dumbbellLoadFormatting:
        "Dumbbell load summaries did not preserve per-dumbbell meaning or ordinary load wording."
      }
    }
  }
#endif
