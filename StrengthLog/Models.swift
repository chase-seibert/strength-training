import Foundation
import SwiftData
import SwiftUI

enum TrackingUnit: String, CaseIterable, Codable, Identifiable {
  case pounds
  case kilograms
  case repetitions
  case seconds
  case minutes
  case miles
  case kilometers
  case meters
  case steps

  var id: String { rawValue }

  var label: String {
    switch self {
    case .pounds: "lb"
    case .kilograms: "kg"
    case .repetitions: "reps"
    case .seconds: "sec"
    case .minutes: "min"
    case .miles: "mi"
    case .kilometers: "km"
    case .meters: "m"
    case .steps: "steps"
    }
  }

  var title: String { rawValue.capitalized }
  var usesReps: Bool { self == .pounds || self == .kilograms || self == .repetitions }
}

@Model
final class PersonProfile {
  var id: UUID
  var name: String
  var colorHex: String
  var isArchived: Bool
  var sortOrder: Int = 0

  init(name: String, colorHex: String, isArchived: Bool = false, sortOrder: Int = 0) {
    id = UUID()
    self.name = name
    self.colorHex = colorHex
    self.isArchived = isArchived
    self.sortOrder = sortOrder
  }
}

@Model
final class Exercise {
  var id: UUID
  var sourceID: String?
  var name: String
  var category: String
  var equipment: String
  var primaryMuscle: String
  var unitRaw: String
  var instructions: String
  var imagePath: String?
  var additionalImagePathsRaw: String?
  var isCustom: Bool

  init(
    sourceID: String? = nil,
    name: String,
    category: String,
    equipment: String,
    primaryMuscle: String,
    unit: TrackingUnit,
    instructions: String,
    imagePath: String? = nil,
    additionalImagePaths: [String] = [],
    isCustom: Bool = false
  ) {
    id = UUID()
    self.sourceID = sourceID
    self.name = name
    self.category = category
    self.equipment = equipment
    self.primaryMuscle = primaryMuscle
    unitRaw = unit.rawValue
    self.instructions = instructions
    self.imagePath = imagePath
    additionalImagePathsRaw =
      additionalImagePaths.isEmpty ? nil : additionalImagePaths.joined(separator: "\n")
    self.isCustom = isCustom
  }

  var unit: TrackingUnit {
    get { TrackingUnit(rawValue: unitRaw) ?? .pounds }
    set { unitRaw = newValue.rawValue }
  }

  var imageURL: URL? {
    imageURLs.first
  }

  var imagePaths: [String] {
    var paths: [String] = []
    if let imagePath { paths.append(imagePath) }
    if let additionalImagePathsRaw {
      paths.append(contentsOf: additionalImagePathsRaw.split(separator: "\n").map(String.init))
    }
    return paths
  }

  var imageURLs: [URL] {
    imagePaths.compactMap { sourcePath in
      let source = sourcePath as NSString
      let directory = source.deletingLastPathComponent
      let filename = (source.lastPathComponent as NSString).deletingPathExtension
      let subdirectory =
        directory.isEmpty ? "ExerciseImages" : "ExerciseImages/\(directory)"
      return Bundle.main.url(
        forResource: filename,
        withExtension: "webp",
        subdirectory: subdirectory)
    }
  }
}

@Model
final class Routine {
  var id: UUID
  var externalID: String?
  var notes: String?
  var name: String
  var symbol: String
  var colorHex: String
  var createdAt: Date
  var deletedAt: Date?
  @Relationship(deleteRule: .cascade) var exercises: [RoutineExercise]

  init(
    name: String, symbol: String = "dumbbell.fill", colorHex: String = "FF5A45",
    exercises: [RoutineExercise] = [], externalID: String? = nil, notes: String? = nil,
    deletedAt: Date? = nil
  ) {
    id = UUID()
    self.externalID = externalID
    self.notes = notes
    self.name = name
    self.symbol = symbol
    self.colorHex = colorHex
    createdAt = .now
    self.deletedAt = deletedAt
    self.exercises = exercises
  }

  func contains(_ exercise: Exercise) -> Bool {
    exercises.contains { $0.exerciseName.caseInsensitiveCompare(exercise.name) == .orderedSame }
  }

  @discardableResult
  func add(_ exercise: Exercise, for people: [PersonProfile]) -> Bool {
    guard !contains(exercise) else { return false }
    let prescriptions = people.map { person in
      Prescription(
        participantName: person.name,
        measurement: 0,
        sets: (0..<3).map { SetTemplate(sortOrder: $0, reps: 10) })
    }
    exercises.append(
      RoutineExercise(
        exerciseName: exercise.name,
        unit: exercise.unit,
        sortOrder: exercises.count,
        prescriptions: prescriptions))
    return true
  }
}

@Model
final class RoutineExercise {
  var id: UUID
  var exerciseName: String
  var notes: String?
  var supersetID: String?
  var unitRaw: String
  var sortOrder: Int
  @Relationship(deleteRule: .cascade) var prescriptions: [Prescription]

  init(
    exerciseName: String, unit: TrackingUnit, sortOrder: Int,
    prescriptions: [Prescription], notes: String? = nil, supersetID: String? = nil
  ) {
    id = UUID()
    self.exerciseName = exerciseName
    self.notes = notes
    self.supersetID = supersetID
    unitRaw = unit.rawValue
    self.sortOrder = sortOrder
    self.prescriptions = prescriptions
  }

  var unit: TrackingUnit {
    get { TrackingUnit(rawValue: unitRaw) ?? .pounds }
    set { unitRaw = newValue.rawValue }
  }
}

@Model
final class Prescription {
  var id: UUID
  var participantName: String
  var measurement: Double
  @Relationship(deleteRule: .cascade) var sets: [SetTemplate]

  init(participantName: String, measurement: Double, sets: [SetTemplate]) {
    id = UUID()
    self.participantName = participantName
    self.measurement = measurement
    self.sets = sets
  }
}

@Model
final class SetTemplate {
  var id: UUID
  var sortOrder: Int
  var reps: Int

  init(sortOrder: Int, reps: Int) {
    id = UUID()
    self.sortOrder = sortOrder
    self.reps = reps
  }
}

@Model
final class WorkoutSession {
  var id: UUID
  var externalID: String?
  var notes: String?
  var routineID: UUID
  var routineName: String
  var startedAt: Date
  var endedAt: Date?
  var isActive: Bool
  var participantNames: [String]
  @Relationship(deleteRule: .cascade) var exercises: [ExerciseLog]

  init(
    routineID: UUID, routineName: String, participantNames: [String], exercises: [ExerciseLog],
    startedAt: Date = .now, endedAt: Date? = nil, isActive: Bool = true,
    externalID: String? = nil, notes: String? = nil
  ) {
    id = UUID()
    self.externalID = externalID
    self.notes = notes
    self.routineID = routineID
    self.routineName = routineName
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.isActive = isActive
    self.participantNames = participantNames
    self.exercises = exercises
  }

  var completedSetCount: Int {
    exercises.flatMap(\.participants).flatMap(\.sets).filter(\.isCompleted).count
  }
  var totalSetCount: Int { exercises.flatMap(\.participants).flatMap(\.sets).count }

  func contains(_ exercise: Exercise) -> Bool {
    exercises.contains { $0.exerciseName.caseInsensitiveCompare(exercise.name) == .orderedSame }
  }

  @discardableResult
  func add(_ exercise: Exercise) -> Bool {
    guard !contains(exercise) else { return false }
    let participantLogs = participantNames.map { name in
      ParticipantLog(
        participantName: name,
        measurement: 0,
        sets: (0..<3).map { WorkoutSet(sortOrder: $0, reps: 10) })
    }
    exercises.append(
      ExerciseLog(
        exerciseName: exercise.name,
        unit: exercise.unit,
        sortOrder: exercises.count,
        participants: participantLogs))
    return true
  }
}

@Model
final class ExerciseLog {
  var id: UUID
  var exerciseName: String
  var notes: String?
  var supersetID: String?
  var unitRaw: String
  var sortOrder: Int
  var isFinished: Bool
  @Relationship(deleteRule: .cascade) var participants: [ParticipantLog]

  init(
    exerciseName: String, unit: TrackingUnit, sortOrder: Int,
    participants: [ParticipantLog], notes: String? = nil, supersetID: String? = nil
  ) {
    id = UUID()
    self.exerciseName = exerciseName
    self.notes = notes
    self.supersetID = supersetID
    unitRaw = unit.rawValue
    self.sortOrder = sortOrder
    isFinished = false
    self.participants = participants
  }

  var unit: TrackingUnit { TrackingUnit(rawValue: unitRaw) ?? .pounds }
}

@Model
final class ParticipantLog {
  var id: UUID
  var participantName: String
  var measurement: Double
  @Relationship(deleteRule: .cascade) var sets: [WorkoutSet]

  init(participantName: String, measurement: Double, sets: [WorkoutSet]) {
    id = UUID()
    self.participantName = participantName
    self.measurement = measurement
    self.sets = sets
  }
}

@Model
final class WorkoutSet {
  var id: UUID
  var sortOrder: Int
  var reps: Int
  var isCompleted: Bool
  var measurement: Double?
  var distanceMiles: Double?
  var durationSeconds: Double?
  var rpe: Double?
  var setTypeRaw: String?

  init(
    sortOrder: Int, reps: Int, isCompleted: Bool = false, measurement: Double? = nil,
    distanceMiles: Double? = nil, durationSeconds: Double? = nil, rpe: Double? = nil,
    setType: String? = nil
  ) {
    id = UUID()
    self.sortOrder = sortOrder
    self.reps = reps
    self.isCompleted = isCompleted
    self.measurement = measurement
    self.distanceMiles = distanceMiles
    self.durationSeconds = durationSeconds
    self.rpe = rpe
    setTypeRaw = setType
  }
}

@Model
final class ExternalExerciseMapping {
  var id: UUID
  var source: String
  var externalName: String
  var normalizedExternalName: String
  var exerciseID: UUID

  init(source: String, externalName: String, normalizedExternalName: String, exerciseID: UUID) {
    id = UUID()
    self.source = source
    self.externalName = externalName
    self.normalizedExternalName = normalizedExternalName
    self.exerciseID = exerciseID
  }
}

struct StarterRoutineTemplate: Identifiable {
  struct ExercisePlan {
    let name: String
    let unit: TrackingUnit
    let setCount: Int
    let target: Int
  }

  let id: String
  let name: String
  let symbol: String
  let colorHex: String
  let summary: String
  let exercises: [ExercisePlan]

  static let all = [
    StarterRoutineTemplate(
      id: "upper-body",
      name: "Upper Body",
      symbol: "figure.strengthtraining.traditional",
      colorHex: "FF5A45",
      summary: "Press, pull, and shoulders",
      exercises: [
        ExercisePlan(
          name: "Dumbbell Bench Press", unit: .pounds, setCount: 3, target: 10),
        ExercisePlan(name: "Seated Cable Rows", unit: .pounds, setCount: 3, target: 10),
        ExercisePlan(
          name: "Dumbbell Shoulder Press", unit: .pounds, setCount: 3, target: 10),
      ]),
    StarterRoutineTemplate(
      id: "lower-body",
      name: "Lower Body",
      symbol: "figure.run",
      colorHex: "59A8FA",
      summary: "Squat, hinge, and legs",
      exercises: [
        ExercisePlan(name: "Barbell Squat", unit: .pounds, setCount: 3, target: 8),
        ExercisePlan(name: "Romanian Deadlift", unit: .pounds, setCount: 3, target: 8),
        ExercisePlan(name: "Leg Press", unit: .pounds, setCount: 3, target: 10),
      ]),
    StarterRoutineTemplate(
      id: "core",
      name: "Core",
      symbol: "figure.core.training",
      colorHex: "45D1A8",
      summary: "Brace, crunch, and raise",
      exercises: [
        ExercisePlan(name: "Plank", unit: .repetitions, setCount: 3, target: 30),
        ExercisePlan(name: "Cable Crunch", unit: .pounds, setCount: 3, target: 12),
        ExercisePlan(name: "Hanging Leg Raise", unit: .repetitions, setCount: 3, target: 10),
      ]),
  ]

  func makeRoutine(participantNames: [String]) -> Routine {
    Routine(
      name: name,
      symbol: symbol,
      colorHex: colorHex,
      exercises: exercises.enumerated().map { index, plan in
        RoutineExercise(
          exerciseName: plan.name,
          unit: plan.unit,
          sortOrder: index,
          prescriptions: participantNames.map { participantName in
            Prescription(
              participantName: participantName,
              measurement: 0,
              sets: (0..<plan.setCount).map {
                SetTemplate(sortOrder: $0, reps: plan.target)
              })
          })
      })
  }
}

enum Theme {
  static let navy = Color(red: 0.05, green: 0.08, blue: 0.14)
  static let coral = Color(red: 1.0, green: 0.31, blue: 0.21)
  static let mint = Color(red: 0.27, green: 0.82, blue: 0.66)
  static let sky = Color(red: 0.35, green: 0.66, blue: 0.98)
}

extension Color {
  init(hex: String) {
    let value = Int(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }
}

extension Double {
  var tidy: String {
    rounded() == self ? String(Int(self)) : formatted(.number.precision(.fractionLength(1)))
  }
}
