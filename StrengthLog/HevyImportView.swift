import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class HevyImportCoordinator {
  var document: HevyCSVDocument?
  var notice: HevyImportNotice?

  func open(_ url: URL) {
    let hasAccess = url.startAccessingSecurityScopedResource()
    defer {
      if hasAccess { url.stopAccessingSecurityScopedResource() }
    }
    do {
      let data = try Data(contentsOf: url)
      document = try HevyCSVParser.parse(data: data, filename: url.lastPathComponent)
    } catch {
      notice = HevyImportNotice(
        title: "Couldn’t Open Hevy CSV",
        message: error.localizedDescription)
    }
  }
}

struct HevyImportNotice: Identifiable {
  let id = UUID()
  let title: String
  let message: String
}

enum HevyExerciseMappingChoice: Equatable {
  case exercise(UUID)
  case createCustom
}

private enum HevyExerciseSort: String, CaseIterable, Identifiable {
  case frequency = "Frequency"
  case recency = "Recent"
  case alphabetical = "A–Z"

  var id: String { rawValue }
}

private enum HevyExerciseRecencyFilter: Int, CaseIterable, Identifiable {
  case all = 0
  case days30 = 30
  case days60 = 60
  case days90 = 90

  var id: Int { rawValue }
  var label: String { self == .all ? "All" : "\(rawValue)d" }
}

private struct HevyExerciseImportRow: Identifiable {
  let id: String
  let name: String
  let frequency: Int
  let mostRecent: Date
}

struct HevyImportView: View {
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @Query(sort: \Exercise.name) private var exercises: [Exercise]
  @Query private var savedMappings: [ExternalExerciseMapping]

  let document: HevyCSVDocument
  let onCancel: () -> Void
  let onComplete: (HevyImportResult) -> Void

  @State private var selectedPersonID: UUID?
  @State private var selectedRoutineKeys: Set<String> = []
  @State private var didInitializeSelection = false
  @State private var choices: [String: HevyExerciseMappingChoice] = [:]
  @State private var exerciseSort: HevyExerciseSort = .frequency
  @State private var exerciseRecencyFilter: HevyExerciseRecencyFilter = .all
  @State private var mappingRequest: HevyMappingRequest?
  @State private var isImporting = false
  @State private var importError: String?
  @State private var successfulImport: HevyImportResult?

  private var selectedWorkouts: [HevyCSVWorkout] {
    document.workouts.filter { selectedRoutineKeys.contains(HevyImporter.routineKey($0.title)) }
  }

  private var allExerciseRows: [HevyExerciseImportRow] {
    makeExerciseRows(from: selectedWorkouts)
  }

  private var exerciseRows: [HevyExerciseImportRow] {
    guard
      exerciseRecencyFilter != .all,
      let newestWorkout = selectedWorkouts.map(\.startedAt).max(),
      let cutoff = Calendar.current.date(
        byAdding: .day, value: -exerciseRecencyFilter.rawValue, to: newestWorkout)
    else { return allExerciseRows }
    return makeExerciseRows(from: selectedWorkouts.filter { $0.startedAt >= cutoff })
  }

  private func makeExerciseRows(from workouts: [HevyCSVWorkout]) -> [HevyExerciseImportRow] {
    var rowsByKey: [String: HevyExerciseImportRow] = [:]
    for workout in workouts {
      for exercise in workout.exercises {
        let key = HevyExerciseMatcher.normalize(exercise.title)
        if let row = rowsByKey[key] {
          rowsByKey[key] = HevyExerciseImportRow(
            id: key,
            name: row.name,
            frequency: row.frequency + 1,
            mostRecent: max(row.mostRecent, workout.startedAt))
        } else {
          rowsByKey[key] = HevyExerciseImportRow(
            id: key, name: exercise.title, frequency: 1, mostRecent: workout.startedAt)
        }
      }
    }
    return rowsByKey.values.sorted { lhs, rhs in
      switch exerciseSort {
      case .frequency:
        if lhs.frequency != rhs.frequency { return lhs.frequency > rhs.frequency }
        if lhs.mostRecent != rhs.mostRecent { return lhs.mostRecent > rhs.mostRecent }
      case .recency:
        if lhs.mostRecent != rhs.mostRecent { return lhs.mostRecent > rhs.mostRecent }
        if lhs.frequency != rhs.frequency { return lhs.frequency > rhs.frequency }
      case .alphabetical:
        break
      }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }

  private var mappedExerciseCount: Int {
    allExerciseRows.count { mappingChoice(for: $0.name) != nil }
  }

  private var selectedSetCount: Int {
    selectedWorkouts.flatMap(\.exercises).reduce(0) { $0 + $1.sets.count }
  }

  private var exerciseMappingFooter: String {
    let importBehavior =
      "This filter only changes the mapping list. Unmapped exercises are skipped in routines and history."
    guard exerciseRecencyFilter != .all else {
      return "Every exercise in the selected routines is shown. \(importBehavior)"
    }
    return
      "Showing \(exerciseRows.count) of \(allExerciseRows.count) exercises used in the last \(exerciseRecencyFilter.rawValue) days, measured from the newest selected workout. \(importBehavior)"
  }

  var body: some View {
    NavigationStack {
      List {
        Section("Import summary") {
          LabeledContent("File", value: document.filename)
          LabeledContent(
            "Routines", value: "\(selectedRoutineKeys.count) of \(document.routineNames.count)")
          LabeledContent(
            "History", value: "\(selectedWorkouts.count) of \(document.workouts.count) workouts")
          LabeledContent("Sets", value: "\(selectedSetCount) of \(document.rowCount)")
        }

        Section {
          ForEach(document.routineNames, id: \.self) { routineName in
            routineSelectionRow(routineName)
          }
        } header: {
          HStack {
            Text("Choose routines")
            Spacer()
            Button(selectedRoutineKeys.count == document.routineNames.count ? "None" : "All") {
              if selectedRoutineKeys.count == document.routineNames.count {
                selectedRoutineKeys.removeAll()
              } else {
                selectedRoutineKeys = Set(document.routineNames.map(HevyImporter.routineKey))
              }
            }
            .textCase(nil)
          }
        } footer: {
          Text(
            "A new routine will be created for every selection. If its name is already used, a numbered name will be chosen."
          )
        }

        Section {
          if people.isEmpty {
            Label(
              "Finish onboarding before importing history.",
              systemImage: "person.crop.circle.badge.exclamationmark"
            )
            .foregroundStyle(.secondary)
          } else {
            Picker("Import history for", selection: $selectedPersonID) {
              ForEach(people) { person in
                Text(person.name).tag(Optional(person.id))
              }
            }
          }
        } footer: {
          Text(
            "Hevy exports one account. Its routines and workout history will be assigned to this person."
          )
        }

        Section {
          Picker("Exercise history", selection: $exerciseRecencyFilter) {
            ForEach(HevyExerciseRecencyFilter.allCases) { filter in
              Text(filter.label).tag(filter)
            }
          }
          .pickerStyle(.segmented)

          Picker("Sort exercises", selection: $exerciseSort) {
            ForEach(HevyExerciseSort.allCases) { sort in
              Text(sort.rawValue).tag(sort)
            }
          }
          .pickerStyle(.segmented)

          ForEach(exerciseRows) { row in
            exerciseMappingRow(row)
          }
        } header: {
          Text("Exercise mapping · \(mappedExerciseCount) of \(allExerciseRows.count) mapped")
        } footer: {
          Text(exerciseMappingFooter)
        }

        Section {
          Button {
            performImport()
          } label: {
            if isImporting {
              ProgressView().frame(maxWidth: .infinity)
            } else {
              Label("Create Routines and Import History", systemImage: "square.and.arrow.down")
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
          }
          .disabled(
            isImporting || selectedPersonID == nil || selectedRoutineKeys.isEmpty
              || exercises.isEmpty)
        } footer: {
          Text(
            "Routines are always created and never update existing routines. Previously imported workouts are skipped."
          )
        }
      }
      .navigationTitle("Import from Hevy")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
            .disabled(isImporting)
        }
      }
      .interactiveDismissDisabled(isImporting)
      .task(id: exercises.count) { initializeImport() }
      .sheet(item: $mappingRequest) { request in
        HevyExerciseMappingPicker(
          externalName: request.externalName,
          currentChoice: mappingChoice(for: request.externalName)
        ) { choice in
          let key = HevyExerciseMatcher.normalize(request.externalName)
          let existingNames = choices.keys.filter {
            HevyExerciseMatcher.normalize($0) == key
          }
          for existingName in existingNames {
            choices.removeValue(forKey: existingName)
          }
          if let choice {
            choices[request.externalName] = choice
          }
          mappingRequest = nil
        }
      }
      .alert(
        "Import Failed",
        isPresented: Binding(
          get: { importError != nil },
          set: { if !$0 { importError = nil } })
      ) {
        Button("OK") { importError = nil }
      } message: {
        Text(importError ?? "Unknown error")
      }
      .alert(item: $successfulImport) { result in
        Alert(
          title: Text("Hevy Import Complete"),
          message: Text(result.summaryMessage),
          dismissButton: .default(Text("Done")) { onComplete(result) })
      }
    }
  }

  private func initializeImport() {
    guard !exercises.isEmpty else { return }
    if !didInitializeSelection {
      selectedRoutineKeys = Set(document.routineNames.map(HevyImporter.routineKey))
      didInitializeSelection = true
    }
    let saved = Dictionary(
      savedMappings.filter { $0.source == HevyImporter.source }.map {
        ($0.normalizedExternalName, $0.exerciseID)
      }, uniquingKeysWith: { first, _ in first })
    let exerciseIDs = Set(exercises.map(\.id))
    for name in document.exerciseNames where choices[name] == nil {
      let normalized = HevyExerciseMatcher.normalize(name)
      if let savedID = saved[normalized], exerciseIDs.contains(savedID) {
        choices[name] = .exercise(savedID)
      } else if let suggestion = HevyExerciseMatcher.bestMatch(for: name, in: exercises),
        suggestion.score >= 0.42
      {
        choices[name] = .exercise(suggestion.exercise.id)
      }
    }
    if selectedPersonID == nil { selectedPersonID = people.first?.id }
  }

  private func routineSelectionRow(_ routineName: String) -> some View {
    let key = HevyImporter.routineKey(routineName)
    let isSelected = selectedRoutineKeys.contains(key)
    return Button {
      if isSelected {
        selectedRoutineKeys.remove(key)
      } else {
        selectedRoutineKeys.insert(key)
      }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(routineName).foregroundStyle(.primary)
          Text(routineDetails(routineName))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? Theme.mint : Color.secondary)
      }
    }
  }

  private func exerciseMappingRow(_ row: HevyExerciseImportRow) -> some View {
    let isMapped = mappingChoice(for: row.name) != nil
    return Button {
      mappingRequest = HevyMappingRequest(externalName: row.name)
    } label: {
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text(row.name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
          Spacer()
          Text("\(row.frequency)×")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        HStack {
          Text(mappingLabel(for: row.name))
            .font(.caption)
            .foregroundStyle(isMapped ? Color.secondary : Theme.coral)
          Spacer()
          Text(row.mostRecent, format: .dateTime.month(.abbreviated).day().year())
            .font(.caption)
            .foregroundStyle(.tertiary)
          Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
        }
      }
      .padding(.vertical, 3)
    }
  }

  private func mappingLabel(for externalName: String) -> String {
    guard let choice = mappingChoice(for: externalName) else {
      return "Not mapped · will be skipped"
    }
    switch choice {
    case .createCustom:
      return "Create “\(externalName)”"
    case .exercise(let id):
      return exercises.first(where: { $0.id == id })?.name ?? "Needs a match"
    }
  }

  private func mappingChoice(for externalName: String) -> HevyExerciseMappingChoice? {
    let key = HevyExerciseMatcher.normalize(externalName)
    return choices.first { HevyExerciseMatcher.normalize($0.key) == key }?.value
  }

  private func performImport() {
    guard
      let selectedPersonID,
      let person = people.first(where: { $0.id == selectedPersonID }),
      !selectedRoutineKeys.isEmpty
    else { return }
    isImporting = true
    do {
      let result = try HevyImporter.run(
        document: document,
        person: person,
        selectedRoutineKeys: selectedRoutineKeys,
        choices: choices,
        catalog: exercises,
        context: context)
      isImporting = false
      successfulImport = result
    } catch {
      context.rollback()
      isImporting = false
      importError = error.localizedDescription
    }
  }

  private func routineDetails(_ routineName: String) -> String {
    let workouts = document.workouts.filter {
      HevyImporter.routineKey($0.title) == HevyImporter.routineKey(routineName)
    }
    let exerciseCount = Set(
      workouts.flatMap(\.exercises).map { HevyExerciseMatcher.normalize($0.title) }
    ).count
    return
      "\(workouts.count) workout\(workouts.count == 1 ? "" : "s") · \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
  }
}

private struct HevyMappingRequest: Identifiable {
  let externalName: String
  var id: String { externalName }
}

private struct HevyExerciseMappingPicker: View {
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Exercise.name) private var exercises: [Exercise]
  let externalName: String
  let currentChoice: HevyExerciseMappingChoice?
  let onSelect: (HevyExerciseMappingChoice?) -> Void
  @State private var searchText = ""

  private var results: [Exercise] {
    if !searchText.isEmpty {
      return exercises.filter { $0.name.localizedStandardContains(searchText) }
    }
    return HevyExerciseMatcher.rankedMatches(for: externalName, in: exercises).map(\.exercise)
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Button {
            onSelect(nil)
          } label: {
            Label("Skip this exercise", systemImage: "forward.end.circle")
              .foregroundStyle(.secondary)
          }
          Button {
            onSelect(.createCustom)
          } label: {
            Label("Create “\(externalName)”", systemImage: "plus.circle.fill")
          }
        }
        Section(searchText.isEmpty ? "Suggested local exercises" : "Search results") {
          ForEach(results) { exercise in
            Button {
              onSelect(.exercise(exercise.id))
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 3) {
                  Text(exercise.name).foregroundStyle(.primary)
                  Text("\(exercise.primaryMuscle.capitalized) · \(exercise.equipment.capitalized)")
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if currentChoice == .exercise(exercise.id) {
                  Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
                }
              }
            }
          }
        }
      }
      .searchable(text: $searchText, prompt: "Exercise name")
      .navigationTitle(externalName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}

enum HevyExerciseMatcher {
  struct Match {
    let exercise: Exercise
    let score: Double
  }

  static func bestMatch(for externalName: String, in exercises: [Exercise]) -> Match? {
    rankedMatches(for: externalName, in: exercises).first
  }

  static func rankedMatches(for externalName: String, in exercises: [Exercise]) -> [Match] {
    let external = normalize(externalName)
    let externalTokens = Set(external.split(separator: " ").map(String.init))
    return exercises.map { exercise in
      let local = normalize(exercise.name)
      if local == external { return Match(exercise: exercise, score: 1) }
      let localTokens = Set(local.split(separator: " ").map(String.init))
      let intersection = Double(externalTokens.intersection(localTokens).count)
      let union = Double(max(1, externalTokens.union(localTokens).count))
      var score = intersection / union
      if local.contains(external) || external.contains(local) { score += 0.18 }
      let equipment = normalize(exercise.equipment)
      if !equipment.isEmpty, externalTokens.contains(equipment) { score += 0.12 }
      return Match(exercise: exercise, score: min(0.99, score))
    }.sorted {
      if $0.score != $1.score { return $0.score > $1.score }
      return $0.exercise.name.localizedCaseInsensitiveCompare($1.exercise.name)
        == .orderedAscending
    }
  }

  static func normalize(_ value: String) -> String {
    let folded = value.folding(
      options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    let words = folded.lowercased().split { !$0.isLetter && !$0.isNumber }.map { token -> String in
      switch token {
      case "db": "dumbbell"
      case "bb": "barbell"
      case "pullups": "pullup"
      case "pushups": "pushup"
      case "extensions": "extension"
      case "curls": "curl"
      case "twists": "twist"
      default: String(token)
      }
    }
    return words.joined(separator: " ")
  }
}

struct HevyImportResult: Identifiable {
  let id = UUID()
  let routineCount: Int
  let routineExerciseCount: Int
  let workoutCount: Int
  let historyExerciseCount: Int
  let skippedWorkoutCount: Int
  let skippedExerciseCount: Int
  let customExerciseCount: Int

  var summaryMessage: String {
    var parts = [
      "Created \(routineCount) routine\(routineCount == 1 ? "" : "s") with \(routineExerciseCount) exercise\(routineExerciseCount == 1 ? "" : "s").",
      "Imported \(workoutCount) historical workout\(workoutCount == 1 ? "" : "s") with \(historyExerciseCount) exercise entr\(historyExerciseCount == 1 ? "y" : "ies").",
    ]
    if skippedExerciseCount > 0 {
      parts.append(
        "Skipped \(skippedExerciseCount) unmapped exercise\(skippedExerciseCount == 1 ? "" : "s").")
    }
    if skippedWorkoutCount > 0 {
      parts.append(
        "Skipped \(skippedWorkoutCount) previously imported workout\(skippedWorkoutCount == 1 ? "" : "s")."
      )
    }
    if customExerciseCount > 0 {
      parts.append(
        "Created \(customExerciseCount) custom exercise\(customExerciseCount == 1 ? "" : "s").")
    }
    return parts.joined(separator: " ")
  }
}

@MainActor
enum HevyImporter {
  static let source = "hevy-csv"

  static func run(
    document: HevyCSVDocument,
    person: PersonProfile,
    selectedRoutineKeys requestedRoutineKeys: Set<String>? = nil,
    choices: [String: HevyExerciseMappingChoice],
    catalog: [Exercise],
    context: ModelContext
  ) throws -> HevyImportResult {
    let selectedRoutineKeys =
      requestedRoutineKeys
      ?? Set(document.routineNames.map(routineKey))
    let selectedWorkouts = document.workouts.filter {
      selectedRoutineKeys.contains(routineKey($0.title))
    }
    var relevantNames: [String] = []
    var seenExerciseKeys = Set<String>()
    for exercise in selectedWorkouts.flatMap(\.exercises) {
      let key = HevyExerciseMatcher.normalize(exercise.title)
      if seenExerciseKeys.insert(key).inserted { relevantNames.append(exercise.title) }
    }

    let choicesByKey = Dictionary(
      choices.map { (HevyExerciseMatcher.normalize($0.key), $0.value) },
      uniquingKeysWith: { first, _ in first })
    var resolved: [String: Exercise] = [:]
    var resolvedForPersistence: [String: Exercise] = [:]
    let catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    var customCount = 0
    for externalName in relevantNames {
      let key = HevyExerciseMatcher.normalize(externalName)
      guard let choice = choicesByKey[key] else { continue }
      switch choice {
      case .exercise(let id):
        guard let exercise = catalogByID[id] else { continue }
        resolved[key] = exercise
        resolvedForPersistence[externalName] = exercise
      case .createCustom:
        let sourceExercises = selectedWorkouts.flatMap(\.exercises).filter {
          HevyExerciseMatcher.normalize($0.title) == key
        }
        let unit = inferredUnit(sourceExercises)
        let exercise = Exercise(
          name: externalName,
          category: "imported",
          equipment: "other",
          primaryMuscle: "other",
          unit: unit,
          instructions: "Imported from Hevy.",
          isCustom: true)
        context.insert(exercise)
        resolved[key] = exercise
        resolvedForPersistence[externalName] = exercise
        customCount += 1
      }
    }

    persistMappings(resolvedForPersistence, context: context)

    let existingRoutines = try context.fetch(FetchDescriptor<Routine>())
    var usedRoutineNames = Set(existingRoutines.map { $0.name.lowercased() })
    var routinesBySourceKey: [String: Routine] = [:]
    var createdRoutineCount = 0
    var routineExerciseCount = 0
    for routineName in document.routineNames {
      let sourceKey = routineKey(routineName)
      guard selectedRoutineKeys.contains(sourceKey) else { continue }
      let sourceWorkouts = selectedWorkouts.filter { routineKey($0.title) == sourceKey }
      guard
        let latestWorkout = sourceWorkouts.max(by: { $0.startedAt < $1.startedAt })
      else { continue }
      let importedName = uniqueRoutineName(basedOn: routineName, usedNames: &usedRoutineNames)
      let routineExercises = makeRoutineExercises(
        sourceWorkouts, person: person, resolved: resolved)
      let routine = Routine(
        name: importedName,
        symbol: "square.and.arrow.down.fill",
        colorHex: "59A8FA",
        exercises: routineExercises,
        externalID: "\(source)|routine|\(importedName.lowercased())",
        notes: latestWorkout.description)
      context.insert(routine)
      routinesBySourceKey[sourceKey] = routine
      createdRoutineCount += 1
      routineExerciseCount += routineExercises.count
    }

    let existingSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
    let importedIDs = Set(existingSessions.compactMap(\.externalID))
    var importedWorkoutCount = 0
    var historyExerciseCount = 0
    var skippedWorkoutCount = 0
    for workout in selectedWorkouts {
      if importedIDs.contains(workout.sourceID) {
        skippedWorkoutCount += 1
        continue
      }
      guard let routine = routinesBySourceKey[routineKey(workout.title)] else { continue }
      let logs = makeExerciseLogs(workout, person: person, resolved: resolved)
      let session = WorkoutSession(
        routineID: routine.id,
        routineName: routine.name,
        participantNames: [person.name],
        exercises: logs,
        startedAt: workout.startedAt,
        endedAt: workout.endedAt,
        isActive: false,
        externalID: workout.sourceID,
        notes: workout.description)
      context.insert(session)
      importedWorkoutCount += 1
      historyExerciseCount += logs.count
    }

    try context.save()
    return HevyImportResult(
      routineCount: createdRoutineCount,
      routineExerciseCount: routineExerciseCount,
      workoutCount: importedWorkoutCount,
      historyExerciseCount: historyExerciseCount,
      skippedWorkoutCount: skippedWorkoutCount,
      skippedExerciseCount: relevantNames.count - resolved.count,
      customExerciseCount: customCount)
  }

  static func routineKey(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private static func uniqueRoutineName(basedOn baseName: String, usedNames: inout Set<String>)
    -> String
  {
    let trimmed = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
    if usedNames.insert(trimmed.lowercased()).inserted { return trimmed }
    var suffix = 2
    while true {
      let candidate = "\(trimmed) (\(suffix))"
      if usedNames.insert(candidate.lowercased()).inserted { return candidate }
      suffix += 1
    }
  }

  private static func persistMappings(_ resolved: [String: Exercise], context: ModelContext) {
    let existing = (try? context.fetch(FetchDescriptor<ExternalExerciseMapping>())) ?? []
    for (externalName, exercise) in resolved {
      let normalized = HevyExerciseMatcher.normalize(externalName)
      if let mapping = existing.first(where: {
        $0.source == source && $0.normalizedExternalName == normalized
      }) {
        mapping.externalName = externalName
        mapping.exerciseID = exercise.id
      } else {
        context.insert(
          ExternalExerciseMapping(
            source: source,
            externalName: externalName,
            normalizedExternalName: normalized,
            exerciseID: exercise.id))
      }
    }
  }

  private static func makeRoutineExercises(
    _ workouts: [HevyCSVWorkout],
    person: PersonProfile,
    resolved: [String: Exercise]
  ) -> [RoutineExercise] {
    var sourceExercises: [HevyCSVExercise] = []
    var seen = Set<String>()
    for workout in workouts.sorted(by: { $0.startedAt > $1.startedAt }) {
      for sourceExercise in workout.exercises {
        let key = HevyExerciseMatcher.normalize(sourceExercise.title)
        guard resolved[key] != nil, seen.insert(key).inserted else { continue }
        sourceExercises.append(sourceExercise)
      }
    }
    return sourceExercises.enumerated().compactMap { index, sourceExercise in
      let key = HevyExerciseMatcher.normalize(sourceExercise.title)
      guard let localExercise = resolved[key] else { return nil }
      let measurement = commonWeight(sourceExercise.sets) ?? 0
      let templates = sourceExercise.sets.enumerated().map { setIndex, set in
        SetTemplate(sortOrder: setIndex, reps: set.reps ?? target(for: set))
      }
      return RoutineExercise(
        exerciseName: localExercise.name,
        unit: inferredUnit([sourceExercise], fallback: localExercise.unit),
        sortOrder: index,
        prescriptions: [
          Prescription(participantName: person.name, measurement: measurement, sets: templates)
        ],
        notes: sourceExercise.notes,
        supersetID: sourceExercise.supersetID)
    }
  }

  private static func makeExerciseLogs(
    _ workout: HevyCSVWorkout,
    person: PersonProfile,
    resolved: [String: Exercise]
  ) -> [ExerciseLog] {
    workout.exercises.enumerated().compactMap { exerciseIndex, sourceExercise in
      let key = HevyExerciseMatcher.normalize(sourceExercise.title)
      guard let localExercise = resolved[key] else { return nil }
      let measurement = commonWeight(sourceExercise.sets) ?? 0
      let sets = sourceExercise.sets.enumerated().map { setIndex, set in
        WorkoutSet(
          sortOrder: setIndex,
          reps: set.reps ?? target(for: set),
          isCompleted: true,
          measurement: set.weightPounds,
          distanceMiles: set.distanceMiles,
          durationSeconds: set.durationSeconds,
          rpe: set.rpe,
          setType: set.type)
      }
      return ExerciseLog(
        exerciseName: localExercise.name,
        unit: inferredUnit([sourceExercise], fallback: localExercise.unit),
        sortOrder: exerciseIndex,
        participants: [
          ParticipantLog(participantName: person.name, measurement: measurement, sets: sets)
        ],
        notes: sourceExercise.notes,
        supersetID: sourceExercise.supersetID)
    }
  }

  private static func commonWeight(_ sets: [HevyCSVSet]) -> Double? {
    let weights = sets.compactMap(\.weightPounds)
    guard !weights.isEmpty else { return nil }
    let grouped = Dictionary(grouping: weights, by: { $0 })
    return grouped.max {
      if $0.value.count != $1.value.count { return $0.value.count < $1.value.count }
      return weights.firstIndex(of: $0.key) ?? 0 > weights.firstIndex(of: $1.key) ?? 0
    }?.key
  }

  private static func target(for set: HevyCSVSet) -> Int {
    if let duration = set.durationSeconds { return max(0, Int(duration.rounded())) }
    if let distance = set.distanceMiles { return max(0, Int(distance.rounded())) }
    return 0
  }

  private static func inferredUnit(
    _ exercises: [HevyCSVExercise], fallback: TrackingUnit = .repetitions
  ) -> TrackingUnit {
    let sets = exercises.flatMap(\.sets)
    if sets.contains(where: { $0.weightPounds != nil }) { return .pounds }
    if sets.contains(where: { $0.distanceMiles != nil }) { return .miles }
    if sets.contains(where: { $0.durationSeconds != nil }) { return .seconds }
    return fallback
  }
}
