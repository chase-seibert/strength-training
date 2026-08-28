#if DEBUG
  import Foundation
  import SwiftData

  @MainActor
  enum BasicWorkoutFixture {
    static func install(in context: ModelContext) {
      let alex = PersonProfile(name: "Alex", colorHex: "FF5A45", sortOrder: 0)
      let jordan = PersonProfile(name: "Jordan", colorHex: "53C8A6", sortOrder: 1)
      let owen = PersonProfile(name: "Owen", colorHex: "59A8FA", sortOrder: 2)
      let benchPress = Exercise(
        sourceID: "fixture-bench-press",
        name: "Bench Press",
        category: "strength",
        equipment: "barbell",
        primaryMuscle: "chest",
        unit: .pounds,
        instructions: "Lower the bar with control, then press it up.")
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
        instructions: "Brace, sit between the hips, then stand tall.")
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
        exercises: [basicRoutineExercise])
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
      let workoutHistory = [
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

      context.insert(alex)
      context.insert(jordan)
      context.insert(owen)
      context.insert(benchPress)
      context.insert(squat)
      context.insert(customExercise)
      context.insert(basicRoutine)
      context.insert(lowerRoutine)
      workoutHistory.forEach(context.insert)
      try? context.save()

      if ProcessInfo.processInfo.arguments.contains("-activeWorkoutFixture") {
        let activeWorkout = WorkoutSessionStarter.start(
          routine: basicRoutine,
          people: [alex, jordan, owen],
          sessions: workoutHistory,
          catalog: [benchPress, customExercise, squat],
          in: context)
        if ProcessInfo.processInfo.arguments.contains("-activeWorkoutNavigationFixture") {
          activeWorkout?.add(squat)
          activeWorkout?.add(customExercise)
          try? context.save()
        }
      }
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
  }
#endif
