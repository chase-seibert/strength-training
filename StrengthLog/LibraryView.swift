import SwiftData
import SwiftUI

struct ExerciseLibraryView: View {
  @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name)
  private var exercises: [Exercise]
  @Query(filter: #Predicate<Exercise> { $0.isCustom && $0.deletedAt != nil })
  private var deletedCustomExercises: [Exercise]
  @State private var searchText = ""
  @State private var selectedMuscle = "All"
  @State private var showingNewExercise = false

  private var muscles: [String] {
    ["All"] + Array(Set(exercises.map { $0.primaryMuscle.capitalized })).sorted()
  }

  private var filtered: [Exercise] {
    exercises.filter { item in
      (selectedMuscle == "All"
        || item.primaryMuscle.caseInsensitiveCompare(selectedMuscle) == .orderedSame)
        && (searchText.isEmpty || item.name.localizedStandardContains(searchText))
    }
  }

  var body: some View {
    List {
      Section {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(muscles, id: \.self) { muscle in
              Button(muscle) { selectedMuscle = muscle }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(selectedMuscle == muscle ? Theme.coral : Color.secondary.opacity(0.18))
                .foregroundStyle(selectedMuscle == muscle ? .white : .primary)
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
    .searchable(text: $searchText, prompt: "Exercise name")
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ExerciseImageCarousel(exercise: exercise, height: 300)
          .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

        VStack(alignment: .leading, spacing: 8) {
          SectionEyebrow(text: exercise.category)
          Text(exercise.name)
            .font(.largeTitle.bold())
          Text("\(exercise.primaryMuscle.capitalized) · \(exercise.equipment.capitalized)")
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Tracking unit").font(.headline)
          Picker("Unit", selection: Binding(get: { exercise.unit }, set: { exercise.unit = $0 })) {
            ForEach(TrackingUnit.allCases) { Text($0.title).tag($0) }
          }
          .pickerStyle(.menu)
          Text("This saved exercise value is used everywhere, including routines.")
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
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @State private var name = ""
  @State private var category = "strength"
  @State private var equipment = "other"
  @State private var muscle = "other"
  @State private var unit: TrackingUnit = .pounds
  @State private var instructions = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Exercise") {
          TextField("Name", text: $name)
          TextField("Primary muscle", text: $muscle)
          TextField("Equipment", text: $equipment)
          TextField("Category", text: $category)
          Picker("Tracking unit", selection: $unit) {
            ForEach(TrackingUnit.allCases) { Text($0.title).tag($0) }
          }
        }
        Section("Form notes") {
          TextField("Instructions or cues", text: $instructions, axis: .vertical)
            .lineLimit(4...8)
        }
      }
      .navigationTitle("New Exercise")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            context.insert(
              Exercise(
                name: name, category: category, equipment: equipment, primaryMuscle: muscle,
                unit: unit, instructions: instructions, isCustom: true))
            try? context.save()
            dismiss()
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
