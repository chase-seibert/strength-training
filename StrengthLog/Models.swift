import Foundation
import SwiftData
import SwiftUI

enum WorkoutPreferences {
  static let defaultRepsKey = "defaultWorkoutReps"
  static let fallbackReps = 8

  static var defaultReps: Int {
    let stored = UserDefaults.standard.integer(forKey: defaultRepsKey)
    return stored > 0 ? stored : fallbackReps
  }
}

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

extension PersonProfile {
  static func ordered(_ people: [PersonProfile]) -> [PersonProfile] {
    people.sorted { lhs, rhs in
      if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
      let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
      if nameComparison != .orderedSame { return nameComparison == .orderedAscending }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }

  /// Orders snapshot participant names by their current profile order while retaining
  /// the original spelling and position of names that no longer have a profile.
  static func orderedNames(_ names: [String], using people: [PersonProfile]) -> [String] {
    var firstNameByKey: [String: String] = [:]
    for name in names {
      firstNameByKey[name.lowercased()] = firstNameByKey[name.lowercased()] ?? name
    }

    var orderedNames: [String] = []
    var usedKeys = Set<String>()
    for person in ordered(people) {
      let key = person.name.lowercased()
      if let name = firstNameByKey[key], usedKeys.insert(key).inserted {
        orderedNames.append(name)
      }
    }
    for name in names {
      if usedKeys.insert(name.lowercased()).inserted { orderedNames.append(name) }
    }
    return orderedNames
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
  var deletedAt: Date?

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
    isCustom: Bool = false,
    deletedAt: Date? = nil
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
    self.deletedAt = deletedAt
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
  // Legacy field retained so existing stores can be opened; new workouts own participants.
  var participantNames: [String] = []
  @Relationship(deleteRule: .cascade) var exercises: [RoutineExercise]

  init(
    name: String, symbol: String = "dumbbell.fill", colorHex: String = "FF5A45",
    exercises: [RoutineExercise] = [],
    externalID: String? = nil, notes: String? = nil,
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

  /// Returns the routine's configured people, inferring them for routines created before
  /// participantNames was added to the model.
  var configuredParticipantNames: [String] {
    let source =
      participantNames.isEmpty
      ? exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).flatMap(\.prescriptions).map(
        \.participantName)
      : participantNames
    var names: [String] = []
    var seen = Set<String>()
    for name in source {
      let key = name.lowercased()
      if seen.insert(key).inserted { names.append(name) }
    }
    return names
  }

  func contains(_ exercise: Exercise) -> Bool {
    exercises.contains { $0.exerciseName.caseInsensitiveCompare(exercise.name) == .orderedSame }
  }

  @discardableResult
  func add(_ exercise: Exercise) -> Bool {
    guard !contains(exercise) else { return false }
    exercises.append(
      RoutineExercise.make(exercise: exercise, sortOrder: exercises.count))
    return true
  }
}

@Model
final class RoutineExercise {
  var id: UUID
  var exerciseID: UUID?
  var exerciseName: String
  var notes: String?
  var supersetID: String?
  // Legacy cached unit retained for older stores; UI and new sessions resolve Exercise.unit.
  var unitRaw: String
  var sortOrder: Int
  // Legacy routine defaults retained for migration from the earlier schema. New routines leave it empty.
  @Relationship(deleteRule: .cascade) var prescriptions: [Prescription]

  init(
    exerciseName: String, unit: TrackingUnit, sortOrder: Int,
    exerciseID: UUID? = nil,
    prescriptions: [Prescription] = [], notes: String? = nil, supersetID: String? = nil
  ) {
    id = UUID()
    self.exerciseID = exerciseID
    self.exerciseName = exerciseName
    self.notes = notes
    self.supersetID = supersetID
    unitRaw = unit.rawValue
    self.sortOrder = sortOrder
    self.prescriptions = prescriptions
  }

  var legacyUnit: TrackingUnit { TrackingUnit(rawValue: unitRaw) ?? .pounds }

  static func make(exercise: Exercise, sortOrder: Int) -> RoutineExercise {
    return RoutineExercise(
      exerciseName: exercise.name,
      unit: exercise.unit,
      sortOrder: sortOrder,
      exerciseID: exercise.id)
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
  // Legacy schema field retained for compatibility; new sessions leave it blank and resolve
  // the current routine name from routineID.
  var routineName: String
  var startedAt: Date
  var endedAt: Date?
  var isActive: Bool
  var deletedAt: Date?
  var participantNames: [String]
  @Relationship(deleteRule: .cascade) var exercises: [ExerciseLog]

  init(
    routineID: UUID, participantNames: [String], exercises: [ExerciseLog],
    startedAt: Date = .now, endedAt: Date? = nil, isActive: Bool = true,
    externalID: String? = nil, notes: String? = nil, deletedAt: Date? = nil
  ) {
    id = UUID()
    self.externalID = externalID
    self.notes = notes
    self.routineID = routineID
    self.routineName = ""
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.isActive = isActive
    self.deletedAt = deletedAt
    self.participantNames = participantNames
    self.exercises = exercises
  }

  var completedSetCount: Int {
    exercises.flatMap(\.participants).filter { isParticipantActive($0.participantName) }
      .flatMap(\.sets).filter(\.isCompleted).count
  }
  var totalSetCount: Int {
    exercises.flatMap(\.participants).filter { isParticipantActive($0.participantName) }
      .flatMap(\.sets).filter { !$0.isSkipped }.count
  }

  func isParticipantActive(_ name: String) -> Bool {
    participantNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
  }

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
        sets: (0..<3).map { WorkoutSet(sortOrder: $0, reps: WorkoutPreferences.defaultReps) })
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
  var isBilateral: Bool = false
  @Relationship(deleteRule: .cascade) var participants: [ParticipantLog]

  init(
    exerciseName: String, unit: TrackingUnit, sortOrder: Int,
    participants: [ParticipantLog], notes: String? = nil, supersetID: String? = nil,
    isBilateral: Bool = false
  ) {
    id = UUID()
    self.exerciseName = exerciseName
    self.notes = notes
    self.supersetID = supersetID
    unitRaw = unit.rawValue
    self.sortOrder = sortOrder
    self.isBilateral = isBilateral
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

  var orderedSets: [WorkoutSet] {
    sets.sorted { $0.sortOrder < $1.sortOrder }
  }

  var canCompleteNextSet: Bool {
    orderedSets.allSatisfy(\.isCompleted)
  }

  var nextSetNumber: Int {
    orderedSets.count + 1
  }

  var nextSetReps: Int {
    orderedSets.last?.reps ?? WorkoutPreferences.defaultReps
  }

  func canToggleCompletion(of set: WorkoutSet) -> Bool {
    let ordered = orderedSets
    guard let index = ordered.firstIndex(where: { $0.id == set.id }) else { return false }
    if set.isCompleted {
      return !ordered.dropFirst(index + 1).contains(where: \.isCompleted)
    }
    return ordered.prefix(index).allSatisfy(\.isCompleted)
  }

  @discardableResult
  func toggleCompletion(of set: WorkoutSet) -> [WorkoutSet] {
    guard canToggleCompletion(of: set) else { return [] }
    if !set.isCompleted {
      set.isCompleted = true
      set.isLeftCompleted = true
      set.isRightCompleted = true
      return []
    }
    set.isCompleted = false
    set.isLeftCompleted = false
    set.isRightCompleted = false
    return []
  }

  @discardableResult
  func completeNextSet() -> WorkoutSet? {
    guard canCompleteNextSet else { return nil }
    normalizeSetOrder()
    let set = WorkoutSet(
      sortOrder: sets.count,
      reps: sets.sorted(by: { $0.sortOrder < $1.sortOrder }).last?.reps
        ?? WorkoutPreferences.defaultReps,
      isCompleted: true)
    set.isLeftCompleted = true
    set.isRightCompleted = true
    sets.append(set)
    return set
  }

  private func normalizeSetOrder() {
    for (index, set) in orderedSets.enumerated() {
      set.sortOrder = index
    }
  }
}

@Model
final class WorkoutSet {
  var id: UUID
  var sortOrder: Int
  var reps: Int
  var isCompleted: Bool
  // A declaration-level default lets SwiftData add this field to existing stores
  // through its lightweight migration path without requiring the user to reset data.
  var isSkipped: Bool = false
  var measurement: Double?
  var distanceMiles: Double?
  var durationSeconds: Double?
  var rpe: Double?
  var setTypeRaw: String?
  var leftReps: Int?
  var rightReps: Int?
  var isLeftCompleted: Bool = false
  var isRightCompleted: Bool = false

  init(
    sortOrder: Int, reps: Int, isCompleted: Bool = false, isSkipped: Bool = false,
    measurement: Double? = nil,
    distanceMiles: Double? = nil, durationSeconds: Double? = nil, rpe: Double? = nil,
    setType: String? = nil, leftReps: Int? = nil, rightReps: Int? = nil,
    isLeftCompleted: Bool? = nil, isRightCompleted: Bool? = nil
  ) {
    id = UUID()
    self.sortOrder = sortOrder
    self.reps = reps
    self.isCompleted = isCompleted
    self.isSkipped = isSkipped
    self.measurement = measurement
    self.distanceMiles = distanceMiles
    self.durationSeconds = durationSeconds
    self.rpe = rpe
    setTypeRaw = setType
    self.leftReps = leftReps
    self.rightReps = rightReps
    self.isLeftCompleted = isLeftCompleted ?? isCompleted
    self.isRightCompleted = isRightCompleted ?? isCompleted
  }

  func reps(for side: WorkoutSide) -> Int {
    switch side {
    case .left: leftReps ?? reps
    case .right: rightReps ?? reps
    }
  }

  func setReps(_ value: Int, for side: WorkoutSide) {
    switch side {
    case .left: leftReps = value
    case .right: rightReps = value
    }
  }

  func isCompleted(on side: WorkoutSide) -> Bool {
    switch side {
    case .left: isLeftCompleted
    case .right: isRightCompleted
    }
  }

  func toggleCompletion(on side: WorkoutSide) {
    switch side {
    case .left: isLeftCompleted.toggle()
    case .right: isRightCompleted.toggle()
    }
    isCompleted = isLeftCompleted && isRightCompleted
  }
}

enum WorkoutSide: String, CaseIterable, Identifiable {
  case left = "L"
  case right = "R"

  var id: String { rawValue }
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

  func makeRoutine() -> Routine {
    let routineExercises = exercises.enumerated().map { index, plan in
      RoutineExercise(
        exerciseName: plan.name,
        unit: plan.unit,
        sortOrder: index)
    }
    return Routine(
      name: name,
      symbol: symbol,
      colorHex: colorHex,
      exercises: routineExercises)
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
