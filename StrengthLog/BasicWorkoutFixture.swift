#if DEBUG
  import Foundation
  import SwiftData

  @MainActor
  enum BasicWorkoutFixture {
    static func install(in context: ModelContext) {
      let person = PersonProfile(name: "Alex", colorHex: "FF5A45")
      let exercise = Exercise(
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
      let routineExercise = RoutineExercise(
        exerciseName: exercise.name,
        unit: .pounds,
        sortOrder: 0,
        exerciseID: exercise.id,
        prescriptions: [
          Prescription(
            participantName: person.name,
            measurement: 95,
            sets: (0..<3).map { SetTemplate(sortOrder: $0, reps: 8) })
        ])
      let routine = Routine(
        name: "Basic Workout",
        symbol: "dumbbell.fill",
        colorHex: "FF5A45",
        exercises: [routineExercise])
      routine.participantNames = [person.name]

      let completedWorkout = WorkoutSession(
        routineID: routine.id,
        participantNames: [person.name],
        exercises: [
          ExerciseLog(
            exerciseName: exercise.name,
            unit: .pounds,
            sortOrder: 0,
            participants: [
              ParticipantLog(
                participantName: person.name,
                measurement: 95,
                sets: (0..<3).map {
                  WorkoutSet(sortOrder: $0, reps: 8, isCompleted: true)
                })
            ])
        ],
        startedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
        endedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
        isActive: false)

      context.insert(person)
      context.insert(exercise)
      context.insert(customExercise)
      context.insert(routine)
      context.insert(completedWorkout)
      try? context.save()
    }
  }
#endif
