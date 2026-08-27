import Charts
import SwiftData
import SwiftUI

private let routineSymbols = [
  "dumbbell.fill",
  "figure.strengthtraining.traditional",
  "figure.strengthtraining.functional",
  "figure.run",
  "figure.walk",
  "figure.rower",
  "figure.stairs",
  "figure.mixed.cardio",
  "figure.highintensity.intervaltraining",
  "figure.core.training",
  "figure.cooldown",
  "bolt.fill",
  "flame.fill",
  "heart.fill",
  "scope",
  "trophy.fill",
  "medal.fill",
  "star.fill",
]

private let routineColors = [
  "FF5A45", "59A8FA", "45D1A8", "A778F5", "F5B942",
  "E96BA8", "2F80ED", "27AE60", "EB5757", "6B7280",
]

struct RoutinesView: View {
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<Routine> { $0.deletedAt == nil }, sort: \Routine.createdAt)
  private var routines: [Routine]
  @Query(filter: #Predicate<Routine> { $0.deletedAt != nil })
  private var deletedRoutines: [Routine]
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @State private var showingNewRoutine = false
  @State private var showingStarterRoutines = false

  var body: some View {
    List {
      if routines.isEmpty {
        ContentUnavailableView {
          Label("No routines yet", systemImage: "list.bullet.clipboard")
        } description: {
          Text("Start from an Upper Body, Lower Body, or Core template—or make your own.")
        } actions: {
          Button("Add Starter Routines") { showingStarterRoutines = true }
            .buttonStyle(.borderedProminent)
          Button("Create My Own") { showingNewRoutine = true }
            .buttonStyle(.bordered)
        }
        .listRowBackground(Color.clear)
      } else {
        ForEach(routines) { routine in
          NavigationLink {
            RoutineDetailView(routine: routine)
          } label: {
            HStack(spacing: 14) {
              Image(systemName: routine.symbol)
                .font(.title2)
                .foregroundStyle(Color(hex: routine.colorHex))
                .frame(width: 46, height: 46)
                .background(
                  Color(hex: routine.colorHex).opacity(0.12),
                  in: RoundedRectangle(cornerRadius: 13))
              VStack(alignment: .leading, spacing: 4) {
                Text(routine.name).font(.headline)
                Text("\(routine.exercises.count) exercises")
                  .font(.subheadline).foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 4)
          }
        }
        .onDelete(perform: deleteRoutines)
      }

      if !deletedRoutines.isEmpty {
        Section {
          NavigationLink {
            DeletedRoutinesView()
          } label: {
            Label(
              "Deleted Routines (\(deletedRoutines.count))",
              systemImage: "trash")
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Routines")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button("Create My Own", systemImage: "square.and.pencil") {
            showingNewRoutine = true
          }
          Button("Add Starter Routines", systemImage: "sparkles") {
            showingStarterRoutines = true
          }
        } label: {
          Label("Add routine", systemImage: "plus")
        }
      }
    }
    .sheet(isPresented: $showingNewRoutine) { NewRoutineSheet() }
    .sheet(isPresented: $showingStarterRoutines) {
      StarterRoutinePicker(
        people: people,
        existingRoutineNames: Set(routines.map { $0.name.lowercased() })
      )
    }
  }

  private func deleteRoutines(at offsets: IndexSet) {
    for offset in offsets { routines[offset].deletedAt = .now }
    try? context.save()
  }
}

struct DeletedRoutinesView: View {
  @Environment(\.modelContext) private var context
  @Query(
    filter: #Predicate<Routine> { $0.deletedAt != nil }, sort: \Routine.createdAt,
    order: .reverse)
  private var routines: [Routine]

  var body: some View {
    Group {
      if routines.isEmpty {
        ContentUnavailableView(
          "No Deleted Routines", systemImage: "trash",
          description: Text("Deleted routines will appear here and can be restored."))
      } else {
        List(routines) { routine in
          HStack(spacing: 14) {
            Image(systemName: routine.symbol)
              .font(.title3)
              .foregroundStyle(Color(hex: routine.colorHex))
              .frame(width: 42, height: 42)
              .background(
                Color(hex: routine.colorHex).opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
              Text(routine.name).font(.headline)
              if let deletedAt = routine.deletedAt {
                Text("Deleted \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            Button("Restore") { restore(routine) }
              .buttonStyle(.bordered)
          }
          .padding(.vertical, 3)
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Restore", systemImage: "arrow.uturn.backward") { restore(routine) }
              .tint(Theme.mint)
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Deleted Routines")
  }

  private func restore(_ routine: Routine) {
    routine.deletedAt = nil
    try? context.save()
  }
}

struct StarterRoutineCard: View {
  let template: StarterRoutineTemplate
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: template.symbol)
          .font(.title2)
          .foregroundStyle(Color(hex: template.colorHex))
          .frame(width: 48, height: 48)
          .background(
            Color(hex: template.colorHex).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        VStack(alignment: .leading, spacing: 4) {
          Text(template.name).font(.headline).foregroundStyle(.primary)
          Text(template.summary)
            .font(.subheadline).foregroundStyle(.secondary)
          Text(template.exercises.map(\.name).joined(separator: " · "))
            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundStyle(isSelected ? Theme.coral : .secondary)
      }
      .padding(14)
      .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(isSelected ? Theme.coral : .clear, lineWidth: 2)
      }
    }
    .buttonStyle(.plain)
  }
}

struct StarterRoutinePicker: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  let people: [PersonProfile]
  let existingRoutineNames: Set<String>
  @State private var selectedIDs: Set<String>

  init(people: [PersonProfile], existingRoutineNames: Set<String>) {
    self.people = people
    self.existingRoutineNames = existingRoutineNames
    _selectedIDs = State(
      initialValue: Set(
        StarterRoutineTemplate.all.filter {
          !existingRoutineNames.contains($0.name.lowercased())
        }.map(\.id)))
  }

  private var availableTemplates: [StarterRoutineTemplate] {
    StarterRoutineTemplate.all.filter { !existingRoutineNames.contains($0.name.lowercased()) }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          if availableTemplates.isEmpty {
            EmptyStateView(
              symbol: "checkmark.circle.fill", title: "Starters already added",
              message: "You can edit those routines or create your own.")
          } else {
            Text("Choose any templates to add. Every routine remains fully editable.")
              .foregroundStyle(.secondary)
              .padding(.bottom, 6)
            ForEach(availableTemplates) { template in
              StarterRoutineCard(
                template: template, isSelected: selectedIDs.contains(template.id)
              ) {
                toggle(template.id)
              }
            }
          }
        }
        .padding()
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Starter Routines")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") { addSelected() }
            .disabled(selectedIDs.isEmpty)
        }
      }
    }
  }

  private func toggle(_ id: String) {
    if selectedIDs.contains(id) {
      selectedIDs.remove(id)
    } else {
      selectedIDs.insert(id)
    }
  }

  private func addSelected() {
    for template in availableTemplates where selectedIDs.contains(template.id) {
      context.insert(template.makeRoutine())
    }
    try? context.save()
    dismiss()
  }
}

struct NewRoutineSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @State private var name = ""
  @State private var symbol = "dumbbell.fill"
  @State private var colorHex = "FF5A45"

  var body: some View {
    NavigationStack {
      Form {
        Section("Routine") {
          TextField("Name", text: $name)
          NavigationLink {
            RoutineAppearanceEditor(symbol: $symbol, colorHex: $colorHex)
          } label: {
            LabeledContent("Appearance") {
              Image(systemName: symbol)
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 34, height: 34)
                .background(
                  Color(hex: colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            }
          }
        }
        Section {
          Text("After creating it, add exercises from the catalog and tune sets for each person.")
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("New Routine")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            context.insert(
              Routine(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines), symbol: symbol,
                colorHex: colorHex))
            try? context.save()
            dismiss()
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}

struct RoutineAppearanceEditor: View {
  @Binding var symbol: String
  @Binding var colorHex: String
  private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
  private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

  private var availableSymbols: [String] {
    var values = [symbol]
    values.append(contentsOf: routineSymbols)
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
  }

  private var availableColors: [String] {
    var values = [colorHex]
    values.append(contentsOf: routineColors)
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Image(systemName: symbol)
          .font(.system(size: 42, weight: .semibold))
          .foregroundStyle(Color(hex: colorHex))
          .frame(maxWidth: .infinity)
          .frame(height: 110)
          .background(
            Color(hex: colorHex).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous))

        VStack(alignment: .leading, spacing: 12) {
          Text("Icon").font(.headline)
          LazyVGrid(columns: iconColumns, spacing: 10) {
            ForEach(availableSymbols, id: \.self) { option in
              Button {
                symbol = option
              } label: {
                Image(systemName: option)
                  .font(.title2)
                  .foregroundStyle(option == symbol ? Color(hex: colorHex) : .secondary)
                  .frame(maxWidth: .infinity)
                  .frame(height: 54)
                  .background(
                    option == symbol
                      ? Color(hex: colorHex).opacity(0.14) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 13)
                  )
                  .overlay {
                    RoundedRectangle(cornerRadius: 13)
                      .stroke(option == symbol ? Color(hex: colorHex) : .clear, lineWidth: 2)
                  }
              }
              .buttonStyle(.plain)
              .accessibilityLabel(option)
              .accessibilityAddTraits(option == symbol ? .isSelected : [])
            }
          }
        }

        VStack(alignment: .leading, spacing: 12) {
          Text("Color").font(.headline)
          LazyVGrid(columns: colorColumns, spacing: 12) {
            ForEach(availableColors, id: \.self) { option in
              Button {
                colorHex = option
              } label: {
                Circle()
                  .fill(Color(hex: option))
                  .frame(width: 48, height: 48)
                  .overlay {
                    if option == colorHex {
                      Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    }
                  }
                  .overlay {
                    Circle().stroke(.white.opacity(0.8), lineWidth: 2).padding(3)
                  }
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Color \(option)")
              .accessibilityAddTraits(option == colorHex ? .isSelected : [])
            }
          }
        }
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Routine Appearance")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct RoutineDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @Query private var catalog: [Exercise]
  @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
  @Bindable var routine: Routine
  @State private var showingExercisePicker = false
  @State private var showingDeleteConfirmation = false
  @State private var showingAppearanceEditor = false
  @State private var editMode: EditMode = .inactive
  @State private var draftName = ""
  @State private var draftSymbol = "dumbbell.fill"
  @State private var draftColorHex = "FF5A45"
  @State private var draftExercises: [RoutineExercise] = []

  private var routineSessions: [WorkoutSession] {
    sessions.filter { $0.routineID == routine.id }
  }

  private var displayedExercises: [RoutineExercise] {
    editMode.isEditing
      ? draftExercises : routine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
  }

  var body: some View {
    List {
      if editMode.isEditing {
        Section("Routine") {
          TextField("Name", text: $draftName)
          Button {
            showingAppearanceEditor = true
          } label: {
            HStack {
              Text("Appearance")
                .foregroundStyle(.primary)
              Spacer()
              Image(systemName: draftSymbol)
                .foregroundStyle(Color(hex: draftColorHex))
                .frame(width: 34, height: 34)
                .background(
                  Color(hex: draftColorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
              Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
            }
          }
        }
      }

      if !routineSessions.isEmpty {
        Section("Pounds volume") {
          Chart(routineSessions.suffix(10)) { session in
            LineMark(
              x: .value("Date", session.startedAt),
              y: .value("Volume", poundsVolume(session))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Theme.coral)
            PointMark(
              x: .value("Date", session.startedAt), y: .value("Volume", poundsVolume(session))
            )
            .foregroundStyle(Theme.coral)
          }
          .frame(height: 160)
          .chartYAxisLabel("lb × reps")
        }
      }

      Section {
        ForEach(displayedExercises) { item in
          VStack(alignment: .leading, spacing: 5) {
            Text(item.exerciseName).font(.headline)
            Text(summary(item))
              .font(.caption).foregroundStyle(.secondary)
          }
          .padding(.vertical, 3)
        }
        .onDelete(perform: deleteExercises)
        .onMove(perform: moveExercises)
        .deleteDisabled(!editMode.isEditing)

        Button("Add exercise", systemImage: "plus.circle.fill") { showingExercisePicker = true }
      } header: {
        Text("Exercises")
      } footer: {
        Text(
          editMode.isEditing
            ? "Exercise additions, deletions, and ordering changes are applied only when you tap Save."
            : "Change an exercise's tracking unit from the Exercises tab. Workout weights, reps, and sets are saved per person in each workout."
        )
      }
    }
    .navigationTitle(routine.name)
    .toolbar {
      if editMode.isEditing {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: cancelEditing)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: saveEditing)
            .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      } else {
        ToolbarItem(placement: .primaryAction) {
          Button("Edit", action: beginEditing)
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      if editMode.isEditing {
        Button(role: .destructive) {
          showingDeleteConfirmation = true
        } label: {
          Label("Delete Routine", systemImage: "trash")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding()
        .background(.bar)
      } else {
        Button {
          WorkoutSessionStarter.start(
            routine: routine, people: people, sessions: sessions, catalog: catalog, in: context)
        } label: {
          Label("Start Routine", systemImage: "play.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.coral)
        .padding()
        .background(.bar)
        .disabled(routine.exercises.isEmpty)
      }
    }
    .sheet(isPresented: $showingExercisePicker) {
      AddExerciseToRoutineSheet(
        existingExerciseNames: displayedExercises.map(\.exerciseName),
        onAdd: addExercise
      )
      .environment(\.editMode, .constant(.inactive))
    }
    .sheet(isPresented: $showingAppearanceEditor) {
      NavigationStack {
        RoutineAppearanceEditor(symbol: $draftSymbol, colorHex: $draftColorHex)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") { showingAppearanceEditor = false }
            }
          }
      }
    }
    .confirmationDialog(
      "Delete \(routine.name)?",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete Routine", role: .destructive, action: deleteRoutine)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "The routine will move to Deleted Routines and can be restored. Workout history remains available."
      )
    }
    .environment(\.editMode, $editMode)
  }

  private func summary(_ item: RoutineExercise) -> String {
    "\(unit(for: item).title) · configured per person when you start a workout"
  }

  private func unit(for item: RoutineExercise) -> TrackingUnit {
    catalog.first(where: { $0.id == item.exerciseID })?.unit
      ?? catalog.first(where: {
        $0.name.caseInsensitiveCompare(item.exerciseName) == .orderedSame
      })?.unit
      ?? item.legacyUnit
  }

  private func moveExercises(from source: IndexSet, to destination: Int) {
    guard editMode.isEditing else { return }
    draftExercises.move(fromOffsets: source, toOffset: destination)
  }

  private func deleteExercises(at offsets: IndexSet) {
    guard editMode.isEditing else { return }
    draftExercises.remove(atOffsets: offsets)
  }

  private func addExercise(_ exercise: Exercise) {
    if editMode.isEditing {
      guard
        !draftExercises.contains(where: {
          $0.exerciseName.caseInsensitiveCompare(exercise.name) == .orderedSame
        })
      else { return }
      draftExercises.append(
        RoutineExercise.make(exercise: exercise, sortOrder: draftExercises.count))
    } else if routine.add(exercise) {
      try? context.save()
    }
  }

  private func beginEditing() {
    draftName = routine.name
    draftSymbol = routine.symbol
    draftColorHex = routine.colorHex
    draftExercises = routine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
    editMode = .active
  }

  private func cancelEditing() {
    draftExercises = []
    editMode = .inactive
  }

  private func saveEditing() {
    let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }
    let keptIDs = Set(draftExercises.map(\.id))
    let deleted = routine.exercises.filter { !keptIDs.contains($0.id) }
    routine.name = trimmedName
    routine.symbol = draftSymbol
    routine.colorHex = draftColorHex
    routine.exercises = draftExercises
    for (index, exercise) in draftExercises.enumerated() { exercise.sortOrder = index }
    deleted.forEach(context.delete)
    try? context.save()
    draftExercises = []
    editMode = .inactive
  }

  private func deleteRoutine() {
    routine.deletedAt = .now
    try? context.save()
    dismiss()
  }

  private func poundsVolume(_ session: WorkoutSession) -> Double {
    var total = 0.0
    for exercise in session.exercises where exercise.unit == .pounds {
      for person in exercise.participants where session.isParticipantActive(person.participantName)
      {
        for set in person.sets where set.isCompleted {
          total += (set.measurement ?? person.measurement) * Double(set.reps)
        }
      }
    }
    return total
  }
}

struct AddExerciseToRoutineSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Exercise.name) private var exercises: [Exercise]
  let existingExerciseNames: [String]
  let onAdd: (Exercise) -> Void
  @State private var searchText = ""

  private var results: [Exercise] {
    guard !searchText.isEmpty else { return Array(exercises.prefix(80)) }
    return exercises.filter { $0.name.localizedStandardContains(searchText) }
      .prefix(100).map { $0 }
  }

  var body: some View {
    NavigationStack {
      List(results) { exercise in
        Button {
          onAdd(exercise)
          dismiss()
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text(exercise.name).foregroundStyle(.primary)
              Text("\(exercise.primaryMuscle.capitalized) · \(exercise.unit.title)")
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if contains(exercise) {
              Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
            }
          }
        }
        .disabled(contains(exercise))
      }
      .searchable(text: $searchText, prompt: "Exercise name")
      .navigationTitle("Add Exercise")
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
  }

  private func contains(_ exercise: Exercise) -> Bool {
    existingExerciseNames.contains {
      $0.caseInsensitiveCompare(exercise.name) == .orderedSame
    }
  }
}

enum WorkoutSessionStarter {
  static func start(
    routine: Routine,
    people: [PersonProfile],
    sessions: [WorkoutSession],
    catalog: [Exercise],
    in context: ModelContext
  ) {
    let orderedPeople = PersonProfile.ordered(people)
    let history =
      sessions
      .filter { $0.routineID == routine.id }
      .sorted { $0.startedAt > $1.startedAt }
    let lastNames = history.first?.participantNames ?? routine.configuredParticipantNames
    let lastKeys = Set(lastNames.map { $0.lowercased() })
    let selectedNames = orderedPeople.map(\.name).filter {
      lastKeys.isEmpty || lastKeys.contains($0.lowercased())
    }
    let participantNames = selectedNames.isEmpty ? orderedPeople.map(\.name) : selectedNames
    guard !participantNames.isEmpty else { return }

    let knownNames = orderedKnownNames(
      history: history, routine: routine, orderedPeople: orderedPeople)
    let logs = routine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map { item in
      ExerciseLog(
        exerciseName: item.exerciseName,
        unit: unit(for: item, catalog: catalog),
        sortOrder: item.sortOrder,
        participants: knownNames.map {
          participantLog(for: $0, exercise: item, history: history)
        })
    }

    context.insert(
      WorkoutSession(
        routineID: routine.id, participantNames: participantNames,
        exercises: logs))
    try? context.save()
  }

  private static func orderedKnownNames(
    history: [WorkoutSession], routine: Routine, orderedPeople: [PersonProfile]
  ) -> [String] {
    var result: [String] = []
    var seen = Set<String>()
    for name in history.flatMap(\.participantNames) + orderedPeople.map(\.name)
      + routine.configuredParticipantNames
    {
      if seen.insert(name.lowercased()).inserted { result.append(name) }
    }
    if result.isEmpty { result = routine.configuredParticipantNames }
    return PersonProfile.orderedNames(result, using: orderedPeople)
  }

  private static func unit(for item: RoutineExercise, catalog: [Exercise]) -> TrackingUnit {
    catalog.first(where: { $0.id == item.exerciseID })?.unit
      ?? catalog.first(where: {
        $0.name.caseInsensitiveCompare(item.exerciseName) == .orderedSame
      })?.unit
      ?? item.legacyUnit
  }

  private static func participantLog(
    for name: String, exercise: RoutineExercise, history: [WorkoutSession]
  ) -> ParticipantLog {
    let previous = history.lazy
      .flatMap(\.exercises)
      .filter {
        $0.exerciseName.caseInsensitiveCompare(exercise.exerciseName) == .orderedSame
      }
      .flatMap(\.participants)
      .first {
        $0.participantName.caseInsensitiveCompare(name) == .orderedSame
      }
    if let previous {
      return ParticipantLog(
        participantName: name, measurement: previous.measurement,
        sets: previous.sets.sorted(by: { $0.sortOrder < $1.sortOrder }).map {
          WorkoutSet(
            sortOrder: $0.sortOrder, reps: $0.reps, measurement: $0.measurement,
            distanceMiles: $0.distanceMiles, durationSeconds: $0.durationSeconds, rpe: $0.rpe,
            setType: $0.setTypeRaw)
        })
    }
    if let legacy = exercise.prescriptions.first(where: {
      $0.participantName.caseInsensitiveCompare(name) == .orderedSame
    }) {
      return ParticipantLog(
        participantName: name,
        measurement: legacy.measurement,
        sets: legacy.sets.sorted(by: { $0.sortOrder < $1.sortOrder }).map {
          WorkoutSet(sortOrder: $0.sortOrder, reps: $0.reps)
        })
    }
    return ParticipantLog(
      participantName: name, measurement: 0,
      sets: (0..<3).map { WorkoutSet(sortOrder: $0, reps: 10) })
  }
}
