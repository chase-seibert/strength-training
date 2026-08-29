import SwiftData
import SwiftUI

struct ExerciseLibraryView: View {
  @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name)
  private var exercises: [Exercise]
  @Query(filter: #Predicate<Exercise> { $0.isCustom && $0.deletedAt != nil })
  private var deletedCustomExercises: [Exercise]
  @State private var searchText = ""
  @State private var selectedFilter = "All"
  @State private var showingNewExercise = false

  private var filters: [String] {
    ["Custom", "All"] + Array(Set(exercises.map { $0.primaryMuscle.capitalized })).sorted()
  }

  private var filtered: [Exercise] {
    exercises.filter { item in
      (selectedFilter == "All"
        || (selectedFilter == "Custom" && item.isCustom)
        || item.primaryMuscle.caseInsensitiveCompare(selectedFilter) == .orderedSame)
        && (searchText.isEmpty || item.name.localizedStandardContains(searchText)
          || item.canonicalOriginalName.localizedStandardContains(searchText))
    }
  }

  var body: some View {
    List {
      Section {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(filters, id: \.self) { filter in
              Button(filter) { selectedFilter = filter }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(selectedFilter == filter ? Theme.coral : Color.secondary.opacity(0.18))
                .foregroundStyle(selectedFilter == filter ? .white : .primary)
                .accessibilityIdentifier("exercise-filter-\(filter)")
            }
          }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
      }

      Section("\(filtered.count) exercises") {
        ForEach(filtered) { exercise in
          ExerciseLibraryRow(exercise: exercise)
        }
      }

      if !deletedCustomExercises.isEmpty {
        Section {
          NavigationLink {
            DeletedCustomExercisesView()
          } label: {
            Label(
              "Deleted Custom Exercises (\(deletedCustomExercises.count))",
              systemImage: "trash")
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .searchable(text: $searchText, prompt: "Name or original name")
    .navigationTitle("Exercises")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Custom exercise", systemImage: "plus") { showingNewExercise = true }
      }
    }
    .sheet(isPresented: $showingNewExercise) { NewExerciseSheet() }
  }
}

private struct ExerciseLibraryRow: View {
  @Environment(\.modelContext) private var context
  let exercise: Exercise

  var body: some View {
    NavigationLink {
      ExerciseDetailView(exercise: exercise)
    } label: {
      HStack(spacing: 12) {
        ExerciseArtwork(exercise: exercise)
          .frame(width: 58, height: 58)
          .background(Color.secondary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 13))
        VStack(alignment: .leading, spacing: 4) {
          Text(exercise.name).font(.headline)
          if exercise.name.caseInsensitiveCompare(exercise.canonicalOriginalName) != .orderedSame {
            Text("Originally \(exercise.canonicalOriginalName)")
              .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
          }
          Text("\(exercise.primaryMuscle.capitalized) · \(exercise.equipment.capitalized)")
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      .padding(.vertical, 2)
    }
    .accessibilityIdentifier("exercise-\(exercise.name)")
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if exercise.isCustom {
        Button("Delete", systemImage: "trash", role: .destructive, action: softDelete)
          .accessibilityIdentifier("delete-custom-exercise-\(exercise.name)")
      }
    }
  }

  private func softDelete() {
    exercise.deletedAt = .now
    try? context.save()
  }
}

struct ExerciseDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Bindable var exercise: Exercise
  @State private var showingRoutinePicker = false
  @State private var showingDeleteConfirmation = false
  @State private var showingEditor = false
  @State private var showingDuplicateEditor = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ExerciseImageCarousel(exercise: exercise, height: 300)
          .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

        VStack(alignment: .leading, spacing: 8) {
          SectionEyebrow(text: exercise.category)
          Text(exercise.name)
            .font(.largeTitle.bold())
          if exercise.canonicalID != exercise.id {
            Label("Duplicate of \(exercise.canonicalOriginalName)", systemImage: "square.on.square")
              .font(.caption).foregroundStyle(.secondary)
          } else if exercise.name.caseInsensitiveCompare(exercise.canonicalOriginalName)
            != .orderedSame
          {
            Label("Originally \(exercise.canonicalOriginalName)", systemImage: "link")
              .font(.caption).foregroundStyle(.secondary)
          }
          Text("\(exercise.primaryMuscle.capitalized) · \(exercise.equipment.capitalized)")
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 10) {
          LabeledContent("Workout tracking", value: exercise.unit.title)
            .font(.headline)
          Text("Edit the exercise to change what each set records.")
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

        if !exercise.instructions.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("Form notes").font(.headline)
            Text(exercise.instructions)
              .font(.body).foregroundStyle(.secondary)
          }
        }

        if !exercise.isCustom {
          Text("Exercise data and imagery: Free Exercise DB (Unlicense)")
            .font(.caption2).foregroundStyle(.tertiary)
        }
      }
      .padding()
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button("Duplicate", systemImage: "plus.square.on.square") {
          showingDuplicateEditor = true
        }
        Button("Edit", systemImage: "pencil") { showingEditor = true }
      }
    }
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 10) {
        Button {
          showingRoutinePicker = true
        } label: {
          Label("Add to Routine", systemImage: "plus.circle.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.coral)

        if exercise.isCustom {
          Button("Delete Custom Exercise", role: .destructive) {
            showingDeleteConfirmation = true
          }
          .font(.subheadline.weight(.semibold))
          .confirmationDialog(
            "Delete custom exercise?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
          ) {
            Button("Delete Exercise", role: .destructive, action: softDelete)
            Button("Cancel", role: .cancel) {}
          } message: {
            Text("\(exercise.name) will move to Deleted Custom Exercises and can be restored.")
          }
        }
      }
      .padding()
      .background(.bar)
    }
    .sheet(isPresented: $showingRoutinePicker) {
      AddExerciseFromLibrarySheet(exercise: exercise)
    }
    .sheet(isPresented: $showingEditor) {
      ExerciseEditorSheet(editing: exercise)
    }
    .sheet(isPresented: $showingDuplicateEditor) {
      ExerciseEditorSheet(duplicating: exercise)
    }
  }

  private func softDelete() {
    exercise.deletedAt = .now
    try? context.save()
    dismiss()
  }
}

struct DeletedCustomExercisesView: View {
  @Environment(\.modelContext) private var context
  @Query(
    filter: #Predicate<Exercise> { $0.isCustom && $0.deletedAt != nil },
    sort: \Exercise.name)
  private var exercises: [Exercise]

  var body: some View {
    Group {
      if exercises.isEmpty {
        ContentUnavailableView(
          "No Deleted Custom Exercises",
          systemImage: "trash",
          description: Text("Deleted custom exercises will appear here and can be restored."))
      } else {
        List(exercises) { exercise in
          HStack(spacing: 12) {
            ExerciseArtwork(exercise: exercise)
              .frame(width: 50, height: 50)
              .background(Color.secondary.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
              Text(exercise.name).font(.headline)
              if let deletedAt = exercise.deletedAt {
                Text("Deleted \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            Button("Restore") { restore(exercise) }
              .buttonStyle(.bordered)
              .accessibilityIdentifier("restore-custom-exercise-\(exercise.name)")
          }
          .padding(.vertical, 3)
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Restore", systemImage: "arrow.uturn.backward") { restore(exercise) }
              .tint(Theme.mint)
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Deleted Exercises")
  }

  private func restore(_ exercise: Exercise) {
    exercise.deletedAt = nil
    try? context.save()
  }
}

struct AddExerciseFromLibrarySheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<Routine> { $0.deletedAt == nil }, sort: \Routine.createdAt)
  private var routines: [Routine]
  let exercise: Exercise
  @State private var showingNewRoutine = false

  var body: some View {
    NavigationStack {
      List {
        if routines.isEmpty {
          Section {
            ContentUnavailableView(
              "No Routines Yet",
              systemImage: "list.bullet.clipboard",
              description: Text("Create a routine, then add \(exercise.name) to it."))
          }
        } else {
          Section("Choose a routine") {
            ForEach(routines) { routine in
              Button {
                add(to: routine)
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: routine.symbol)
                    .foregroundStyle(Color(hex: routine.colorHex))
                    .frame(width: 32)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(routine.name).foregroundStyle(.primary)
                    Text("\(routine.exercises.count) exercises")
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  if routine.contains(exercise) {
                    Label("Added", systemImage: "checkmark.circle.fill")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(Theme.mint)
                  }
                }
              }
              .disabled(routine.contains(exercise))
            }
          }
        }

        Section {
          Button("Create New Routine", systemImage: "plus") { showingNewRoutine = true }
        }
      }
      .navigationTitle("Add to Routine")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
      .sheet(isPresented: $showingNewRoutine) { NewRoutineSheet() }
    }
  }

  private func add(to routine: Routine) {
    guard routine.add(exercise) else { return }
    try? context.save()
    dismiss()
  }
}

struct NewExerciseSheet: View {
  var body: some View {
    ExerciseEditorSheet()
  }
}

private struct ExerciseEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }) private var exercises: [Exercise]
  private let exercise: Exercise?
  private let duplicateSource: Exercise?
  @State private var name = ""
  @State private var category = "strength"
  @State private var equipment = "other"
  @State private var muscle = "other"
  @State private var unit: TrackingUnit = .pounds
  @State private var instructions = ""

  private static let muscles = [
    "abdominals", "abductors", "adductors", "biceps", "calves", "chest", "forearms",
    "glutes", "hamstrings", "lats", "lower back", "middle back", "neck", "quadriceps",
    "shoulders", "traps", "triceps", "other",
  ]
  private static let equipmentOptions = [
    "body only", "bands", "barbell", "cable", "dumbbell", "e-z curl bar", "exercise ball",
    "foam roll", "kettlebells", "machine", "medicine ball", "other",
  ]
  private static let categoryOptions = [
    "strength", "powerlifting", "olympic weightlifting", "cardio", "plyometrics", "stretching",
    "strongman", "other",
  ]

  init() {
    exercise = nil
    duplicateSource = nil
  }

  init(editing exercise: Exercise) {
    self.exercise = exercise
    duplicateSource = nil
    _name = State(initialValue: exercise.name)
    _category = State(initialValue: exercise.category)
    _equipment = State(initialValue: exercise.equipment)
    _muscle = State(initialValue: exercise.primaryMuscle)
    _unit = State(initialValue: exercise.unit)
    _instructions = State(initialValue: exercise.instructions)
  }

  init(duplicating source: Exercise) {
    exercise = nil
    duplicateSource = source
    _name = State(initialValue: "\(source.name) Copy")
    _category = State(initialValue: source.category)
    _equipment = State(initialValue: source.equipment)
    _muscle = State(initialValue: source.primaryMuscle)
    _unit = State(initialValue: source.unit)
    _instructions = State(initialValue: source.instructions)
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var hasNameConflict: Bool {
    exercises.contains {
      $0.id != exercise?.id && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
    }
  }

  private var title: String {
    if exercise != nil { return "Edit Exercise" }
    if duplicateSource != nil { return "Duplicate Exercise" }
    return "New Exercise"
  }

  private var trackingExplanation: String {
    switch unit {
    case .pounds: "Record weight in pounds and reps for each set."
    case .kilograms: "Record weight in kilograms and reps for each set."
    case .repetitions: "Record reps for each set without a weight."
    case .seconds: "Record a duration in seconds."
    case .minutes: "Record a duration in minutes."
    case .miles: "Record distance in miles."
    case .kilometers: "Record distance in kilometers."
    case .meters: "Record distance in meters."
    case .steps: "Record a step count."
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("e.g. Goblet Squat", text: $name)
            .textInputAutocapitalization(.words)
            .accessibilityLabel("Exercise name")
            .accessibilityIdentifier("exercise-name-field")
        } header: {
          Text("Exercise name")
        } footer: {
          if hasNameConflict && !trimmedName.isEmpty {
            Text("An exercise already uses this name.").foregroundStyle(.red)
          } else {
            Text("This is the name shown in routines, workouts, and history.")
          }
        }

        Section {
          Picker("Tracking unit", selection: $unit) {
            ForEach(TrackingUnit.allCases) { Text($0.title).tag($0) }
          }
        } header: {
          Text("Workout tracking")
        } footer: {
          Text(trackingExplanation)
        }

        Section {
          Picker("Main muscle", selection: $muscle) {
            ForEach(options(including: muscle, defaults: Self.muscles), id: \.self) {
              Text(friendlyName($0)).tag($0)
            }
          }
          Picker("Equipment", selection: $equipment) {
            ForEach(options(including: equipment, defaults: Self.equipmentOptions), id: \.self) {
              Text(friendlyName($0)).tag($0)
            }
          }
          Picker("Exercise type", selection: $category) {
            ForEach(options(including: category, defaults: Self.categoryOptions), id: \.self) {
              Text(friendlyName($0)).tag($0)
            }
          }
        } header: {
          Text("Exercise details")
        } footer: {
          Text(
            "Main muscle is the area doing most of the work. Exercise type groups similar movements."
          )
        }

        Section {
          TextField("Optional technique cues", text: $instructions, axis: .vertical)
            .lineLimit(4...8)
        } header: {
          Text("Form notes")
        } footer: {
          Text("Add reminders such as stance, setup, or range of motion.")
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
            .disabled(trimmedName.isEmpty || hasNameConflict)
        }
      }
    }
  }

  private func options(including current: String, defaults: [String]) -> [String] {
    defaults.contains(current) ? defaults : [current] + defaults
  }

  private func friendlyName(_ raw: String) -> String {
    switch raw {
    case "body only": "Bodyweight"
    case "e-z curl bar": "EZ Curl Bar"
    case "kettlebells": "Kettlebell"
    default: raw.capitalized
    }
  }

  private func save() {
    if let exercise {
      let previousName = exercise.name
      if exercise.originalName.isEmpty { exercise.originalName = previousName }
      if exercise.rootExerciseID == nil { exercise.rootExerciseID = exercise.id }
      exercise.name = trimmedName
      exercise.category = category
      exercise.equipment = equipment
      exercise.primaryMuscle = muscle
      exercise.unit = unit
      exercise.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
      updateReferences(to: exercise, previouslyNamed: previousName)
    } else {
      let source = duplicateSource
      let newExercise = Exercise(
        originalName: source?.canonicalOriginalName,
        rootExerciseID: source?.canonicalID,
        name: trimmedName,
        category: category,
        equipment: equipment,
        primaryMuscle: muscle,
        unit: unit,
        instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
        imagePath: source?.imagePath,
        additionalImagePaths: Array(source?.imagePaths.dropFirst() ?? []),
        isCustom: true)
      context.insert(newExercise)
    }
    try? context.save()
    dismiss()
  }

  private func updateReferences(to exercise: Exercise, previouslyNamed previousName: String) {
    let routineExercises = (try? context.fetch(FetchDescriptor<RoutineExercise>())) ?? []
    for reference in routineExercises
    where reference.exerciseID == exercise.id
      || (reference.exerciseID == nil
        && reference.exerciseName.caseInsensitiveCompare(previousName) == .orderedSame)
    {
      reference.exerciseID = exercise.id
      reference.exerciseName = exercise.name
      reference.unitRaw = exercise.unit.rawValue
    }

    let logs = (try? context.fetch(FetchDescriptor<ExerciseLog>())) ?? []
    for log in logs
    where log.exerciseID == exercise.id
      || (log.exerciseID == nil
        && log.exerciseName.caseInsensitiveCompare(previousName) == .orderedSame)
    {
      log.exerciseID = exercise.id
      log.exerciseName = exercise.name
    }
  }
}
