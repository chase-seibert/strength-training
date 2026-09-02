#if DEBUG
  import Foundation
  import SwiftData

  @MainActor
  enum BasicWorkoutFixture {
    static func install(in context: ModelContext) {
      if ProcessInfo.processInfo.arguments.contains("-validatePersistenceFixture") {
        do { try HevyImportSmokeTest.run() } catch {
          fatalError("Persistence fixture failed: \(error)")
        }
      }
      let usesLongNames = ProcessInfo.processInfo.arguments.contains(
        "-activeWorkoutLongNamesFixture")
      let alex = PersonProfile(
        name: usesLongNames ? "Alexander" : "Alex", colorHex: "FF5A45", sortOrder: 0)
      let jordan = PersonProfile(
        name: usesLongNames ? "Danielle" : "Jordan", colorHex: "53C8A6", sortOrder: 1)
      let owen = PersonProfile(
        name: usesLongNames ? "Benjamin" : "Owen", colorHex: "59A8FA", sortOrder: 2)
      let benchPress = Exercise(
        sourceID: "fixture-bench-press",
        name: "Bench Press",
        category: "strength",
        equipment: "barbell",
        primaryMuscle: "chest",
        unit: .pounds,
        instructions: "Lower the bar with control, then press it up.",
        imagePath: "Barbell_Bench_Press_-_Medium_Grip/0.webp",
        additionalImagePaths: ["Barbell_Bench_Press_-_Medium_Grip/1.webp"])
      let customExercise = Exercise(
        name: "Fixture Custom Curl",
        category: "strength",
        equipment: "dumbbell",
        primaryMuscle: "biceps",
        unit: .pounds,
        instructions: "Keep the elbow still while curling.",
        isCustom: true)
      let squat = Exercise(
        sourceID: "fixture-back-squat",
        name: "Barbell Back Squat",
        category: "strength",
        equipment: "barbell",
        primaryMuscle: "quadriceps",
        unit: .pounds,
        instructions: "Brace, sit between the hips, then stand tall.",
        imagePath: "Barbell_Full_Squat/0.webp",
        additionalImagePaths: ["Barbell_Full_Squat/1.webp"])
      let performanceImagePaths = [
        "Internal_Rotation_with_Band/0.webp",
        "Spinal_Stretch/0.webp",
        "Extended_Range_One-Arm_Kettlebell_Floor_Press/0.webp",
        "Band_Good_Morning_Pull_Through/0.webp",
        "Incline_Bench_Pull/0.webp",
        "Single-Arm_Linear_Jammer/0.webp",
        "Posterior_Tibialis_Stretch/0.webp",
        "Seated_Two-Arm_Palms-Up_Low-Pulley_Wrist_Curl/0.webp",
        "Split_Squat_with_Dumbbells/0.webp",
        "Oblique_Crunches/0.webp",
        "Barbell_Full_Squat/0.webp",
      ]
      let performanceExercises: [Exercise] =
        ProcessInfo.processInfo.arguments.contains("-activeWorkoutPerformanceFixture")
        ? (1...11).map { index in
          Exercise(
            sourceID: "fixture-performance-\(index)",
            name: "Performance Exercise \(index)",
            category: "strength",
            equipment: index.isMultiple(of: 2) ? "dumbbell" : "barbell",
            primaryMuscle: index.isMultiple(of: 2) ? "back" : "legs",
            unit: .pounds,
            instructions: "Performance fixture exercise \(index).",
            imagePath: performanceImagePaths[index - 1])
        } : []
      let performanceCatalogFillers: [Exercise] =
        ProcessInfo.processInfo.arguments.contains("-activeWorkoutPerformanceFixture")
        ? (1...600).map { index in
          Exercise(
            sourceID: "fixture-catalog-\(index)",
            name: "Catalog Exercise \(index)",
            category: "strength",
            equipment: "other",
            primaryMuscle: "other",
            unit: .pounds,
            instructions: "Catalog-size performance fixture.")
        } : []
      let basicRoutineExercise = RoutineExercise(
        exerciseName: benchPress.name,
        unit: .pounds,
        sortOrder: 0,
        exerciseID: benchPress.id,
        prescriptions: [
          Prescription(
            participantName: alex.name,
            measurement: 95,
            sets: (0..<3).map { SetTemplate(sortOrder: $0, reps: 8) }),
          Prescription(
            participantName: jordan.name,
            measurement: 65,
            sets: (0..<3).map { SetTemplate(sortOrder: $0, reps: 8) }),
          Prescription(
            participantName: owen.name,
            measurement: 45,
            sets: (0..<3).map { SetTemplate(sortOrder: $0, reps: 8) }),
        ])
      let basicRoutine = Routine(
        name: "Basic Workout",
        symbol: "dumbbell.fill",
        colorHex: "FF5A45",
        exercises: [basicRoutineExercise]
          + performanceExercises.enumerated().map { index, exercise in
            RoutineExercise(
              exerciseName: exercise.name,
              unit: exercise.unit,
              sortOrder: index + 1,
              exerciseID: exercise.id,
              prescriptions: [alex, jordan, owen].map { person in
                Prescription(
                  participantName: person.name,
                  measurement: Double(45 + index),
                  sets: (0..<5).map { SetTemplate(sortOrder: $0, reps: 8) })
              })
          })
      if ProcessInfo.processInfo.arguments.contains("-restTimerFixture") {
        basicRoutine.restDurationSeconds = 60
      }
      basicRoutine.participantNames = [alex.name, jordan.name, owen.name]

      let lowerRoutineExercise = RoutineExercise(
        exerciseName: squat.name,
        unit: .pounds,
        sortOrder: 0,
        exerciseID: squat.id,
        prescriptions: [
          Prescription(
            participantName: alex.name,
            measurement: 135,
            sets: (0..<3).map { SetTemplate(sortOrder: $0, reps: 5) }),
          Prescription(
            participantName: jordan.name,
            measurement: 95,
            sets: (0..<3).map { SetTemplate(sortOrder: $0, reps: 8) }),
        ])
      let lowerRoutine = Routine(
        name: "Lower Body",
        symbol: "figure.strengthtraining.functional",
        colorHex: "53C8A6",
        exercises: [lowerRoutineExercise])
      lowerRoutine.participantNames = [alex.name, jordan.name]

      // The offsets deliberately leave gaps and include two workouts three days ago so the
      // paged four-week calendar exercises sporadic history and its multi-workout counter.
      var workoutHistory = [
        makeWorkout(
          routine: lowerRoutine, daysAgo: 1, hour: 18,
          efforts: [(alex.name, squat.name, 145, [5, 5, 5])]),
        makeWorkout(
          routine: lowerRoutine, daysAgo: 3, hour: 7,
          efforts: [
            (alex.name, squat.name, 145, [5, 5, 5]),
            (jordan.name, squat.name, 95, [8, 8, 8]),
          ], leaveLastSetUncompleted: true),
        makeWorkout(
          routine: basicRoutine, daysAgo: 3, hour: 17,
          efforts: [
            (alex.name, benchPress.name, 100, [8, 8, 8]),
            (jordan.name, benchPress.name, 65, [10, 10, 9]),
            (owen.name, benchPress.name, 45, [8, 8, 8]),
          ], leaveLastSetUncompleted: true),
        makeWorkout(
          routine: basicRoutine, daysAgo: 7, hour: 18,
          efforts: [(jordan.name, benchPress.name, 60, [10, 10, 10])]),
        makeWorkout(
          routine: lowerRoutine, daysAgo: 12, hour: 7,
          efforts: [(alex.name, squat.name, 135, [5, 5, 5])]),
        makeWorkout(
          routine: basicRoutine, daysAgo: 18, hour: 18,
          efforts: [
            (alex.name, benchPress.name, 95, [8, 8, 8]),
            (jordan.name, benchPress.name, 55, [10, 10, 10]),
          ]),
        makeWorkout(
          routine: lowerRoutine, daysAgo: 24, hour: 8,
          efforts: [
            (alex.name, squat.name, 125, [6, 6, 6]),
            (jordan.name, squat.name, 85, [8, 8, 8]),
          ]),
        makeWorkout(
          routine: basicRoutine, daysAgo: 29, hour: 17,
          efforts: [(alex.name, benchPress.name, 90, [10, 10, 10])]),
      ]
      if ProcessInfo.processInfo.arguments.contains("-recentCompletedWorkoutFixture") {
        workoutHistory.append(
          makeRecentCompletedWorkout(
            routine: basicRoutine, person: alex, exercise: benchPress))
      }
      if ProcessInfo.processInfo.arguments.contains("-activeWorkoutPerformanceFixture") {
        workoutHistory.append(
          contentsOf: (0..<48).map { workoutIndex in
            makePerformanceWorkout(
              routine: basicRoutine,
              people: [alex, jordan, owen],
              exercises: [benchPress] + performanceExercises,
              workoutIndex: workoutIndex)
          })
      }

      context.insert(alex)
      context.insert(jordan)
      context.insert(owen)
      context.insert(benchPress)
      context.insert(squat)
      context.insert(customExercise)
      performanceExercises.forEach(context.insert)
      performanceCatalogFillers.forEach(context.insert)
      context.insert(basicRoutine)
      context.insert(lowerRoutine)
      workoutHistory.forEach(context.insert)
      try? context.save()

      if ProcessInfo.processInfo.arguments.contains("-plankWorkoutFixture") {
        let plank = Exercise(
          sourceID: "Plank", name: "Plank", category: "strength", equipment: "body only",
          primaryMuscle: "abdominals", unit: .seconds, instructions: "Hold the plank.")
        context.insert(plank)
        let routine = Routine(
          name: "Plank Workout", exercises: [RoutineExercise.make(exercise: plank, sortOrder: 0)])
        context.insert(routine)
        _ = WorkoutSessionStarter.start(
          routine: routine, people: [alex], sessions: [], catalog: [plank], in: context)
        return
      }

      if ProcessInfo.processInfo.arguments.contains("-activeWorkoutFixture") {
        let activePeople: [PersonProfile]
        if ProcessInfo.processInfo.arguments.contains("-activeWorkoutOnePersonFixture") {
          activePeople = [alex]
        } else if ProcessInfo.processInfo.arguments.contains("-activeWorkoutTwoPersonFixture") {
          activePeople = [alex, jordan]
        } else {
          activePeople = [alex, jordan, owen]
        }
        let activeWorkout = WorkoutSessionStarter.start(
          routine: basicRoutine,
          people: activePeople,
          sessions: workoutHistory,
          catalog: [benchPress, customExercise, squat] + performanceExercises,
          in: context)
        if ProcessInfo.processInfo.arguments.contains("-activeWorkoutCustomizedLastSetFixture"),
          let participant = activeWorkout?.exercises.first?.participants.first(where: {
            $0.participantName == alex.name
          }),
          let lastSet = participant.orderedSets.last
        {
          lastSet.reps = 18
          try? context.save()
        }
        if ProcessInfo.processInfo.arguments.contains("-activeWorkoutSkippedLastSetFixture"),
          let participant = activeWorkout?.exercises.first?.participants.first(where: {
            $0.participantName == jordan.name
          }),
          let lastSet = participant.orderedSets.last
        {
          lastSet.isSkipped = true
          try? context.save()
        }
        if ProcessInfo.processInfo.arguments.contains(
          "-activeWorkoutThreeSetSkippedLastSetFixture"),
          let exercise = activeWorkout?.exercises.first
        {
          for participant in exercise.participants {
            let reps = participant.orderedSets.first?.reps ?? WorkoutPreferences.defaultReps
            while participant.sets.count < 3 {
              participant.sets.append(
                WorkoutSet(sortOrder: participant.sets.count, reps: reps))
            }
          }
          exercise.participants.first(where: { $0.participantName == jordan.name })?
            .orderedSets.last?.isSkipped = true
          try? context.save()
        }
        if ProcessInfo.processInfo.arguments.contains("-activeWorkoutWrappingFixture"),
          let activeWorkout
        {
          let targetSetCount = activePeople.count == 1 ? 10 : 5
          for exercise in activeWorkout.exercises {
            for participant in exercise.participants {
              let reps = participant.orderedSets.first?.reps ?? WorkoutPreferences.defaultReps
              while participant.sets.count < targetSetCount {
                participant.sets.append(
                  WorkoutSet(sortOrder: participant.sets.count, reps: reps))
              }
            }
          }
          try? context.save()
        }
        if ProcessInfo.processInfo.arguments.contains("-activeWorkoutNavigationFixture") {
          activeWorkout?.add(squat)
          activeWorkout?.add(customExercise)
          try? context.save()
        }
        if ProcessInfo.processInfo.arguments.contains(
          "-activeWorkoutScrolledPeopleFixture"),
          let firstParticipant = activeWorkout?.exercises.sorted(by: {
            $0.sortOrder < $1.sortOrder
          }).first?.participants.first
        {
          for set in firstParticipant.orderedSets.prefix(2) {
            set.isCompleted = true
          }
          try? context.save()
        }
      }
    }

    private static func makePerformanceWorkout(
      routine: Routine,
      people: [PersonProfile],
      exercises: [Exercise],
      workoutIndex: Int
    ) -> WorkoutSession {
      let startedAt = Date.now.addingTimeInterval(TimeInterval(-(workoutIndex + 2) * 86_400))
      let logs = exercises.enumerated().map { exerciseIndex, exercise in
        ExerciseLog(
          exerciseID: exercise.id,
          exerciseName: exercise.name,
          unit: exercise.unit,
          sortOrder: exerciseIndex,
          participants: people.map { person in
            ParticipantLog(
              participantName: person.name,
              measurement: Double(45 + exerciseIndex + (workoutIndex % 20)),
              sets: (0..<5).map { setIndex in
                WorkoutSet(
                  sortOrder: setIndex,
                  reps: 8 + (setIndex % 2),
                  isCompleted: true,
                  measurement: Double(45 + exerciseIndex + (workoutIndex % 20)),
                  completedAt: startedAt.addingTimeInterval(TimeInterval(setIndex * 60)))
              })
          })
      }
      return WorkoutSession(
        routineID: routine.id,
        participantNames: people.map(\.name),
        exercises: logs,
        startedAt: startedAt,
        endedAt: startedAt.addingTimeInterval(50 * 60),
        isActive: false)
    }

    private static func makeWorkout(
      routine: Routine,
      daysAgo: Int,
      hour: Int,
      efforts: [(person: String, exercise: String, weight: Double, reps: [Int])],
      leaveLastSetUncompleted: Bool = false
    ) -> WorkoutSession {
      let calendar = Calendar.current
      let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date.now.startOfDay) ?? .now
      let startedAt = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
      let endedAt = calendar.date(byAdding: .minute, value: 50, to: startedAt) ?? startedAt
      let participantNames = efforts.reduce(into: [String]()) { names, effort in
        if !names.contains(effort.person) { names.append(effort.person) }
      }
      let exerciseNames = efforts.reduce(into: [String]()) { names, effort in
        if !names.contains(effort.exercise) { names.append(effort.exercise) }
      }
      let logs = exerciseNames.enumerated().map { exerciseIndex, exerciseName in
        ExerciseLog(
          exerciseName: exerciseName,
          unit: .pounds,
          sortOrder: exerciseIndex,
          participants: efforts.filter { $0.exercise == exerciseName }.map { effort in
            ParticipantLog(
              participantName: effort.person,
              measurement: effort.weight,
              sets: effort.reps.enumerated().map { setIndex, reps in
                WorkoutSet(
                  sortOrder: setIndex,
                  reps: reps,
                  isCompleted: !leaveLastSetUncompleted || setIndex < effort.reps.count - 1,
                  measurement: effort.weight)
              })
          })
      }
      return WorkoutSession(
        routineID: routine.id,
        participantNames: participantNames,
        exercises: logs,
        startedAt: startedAt,
        endedAt: endedAt,
        isActive: false)
    }

    private static func makeRecentCompletedWorkout(
      routine: Routine, person: PersonProfile, exercise: Exercise
    ) -> WorkoutSession {
      let startedAt = Date.now.addingTimeInterval(-30 * 60)
      let endedAt = Date.now.addingTimeInterval(-5 * 60)
      let participant = ParticipantLog(
        participantName: person.name,
        measurement: 95,
        sets: [
          WorkoutSet(sortOrder: 0, reps: 8, isCompleted: true, measurement: 95),
          WorkoutSet(sortOrder: 1, reps: 8, measurement: 95),
          WorkoutSet(sortOrder: 2, reps: 8, measurement: 95),
        ])
      let log = ExerciseLog(
        exerciseID: exercise.id,
        exerciseName: exercise.name,
        unit: exercise.unit,
        sortOrder: 0,
        participants: [participant])
      return WorkoutSession(
        routineID: routine.id,
        participantNames: [person.name],
        exercises: [log],
        startedAt: startedAt,
        endedAt: endedAt,
        isActive: false)
    }
  }
#endif
