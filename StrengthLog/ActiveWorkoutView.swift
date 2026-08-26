import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @Query private var routines: [Routine]
  @Query private var catalog: [Exercise]
  @Bindable var session: WorkoutSession
  let onDone: () -> Void
  let onDelete: () -> Void
  @State private var showingPeople = false
  @State private var showingExercisePicker = false
  @State private var editMode: EditMode = .inactive
  @State private var showingDeleteConfirmation = false

  var body: some View {
    List {
      ForEach(session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })) { exercise in
        ActiveExerciseCard(
          exercise: exercise,
          catalogExercise: catalogByName[exercise.exerciseName],
          visiblePeople: session.participantNames,
          colors: Dictionary(uniqueKeysWithValues: people.map { ($0.name, $0.colorHex) })
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }
      .onMove(perform: moveExercises)

      HStack(spacing: 10) {
        workoutAction("Change People", systemImage: "person.2.fill") {
          showingPeople = true
        }
        workoutAction(
          editMode.isEditing ? "Finish Reorder" : "Reorder",
          systemImage: editMode.isEditing ? "checkmark" : "arrow.up.arrow.down"
        ) {
          withAnimation(.snappy) {
            editMode = editMode.isEditing ? .inactive : .active
          }
        }
        workoutAction("Add Exercise", systemImage: "plus") {
          showingExercisePicker = true
        }
      }
      .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 24, trailing: 16))
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .environment(\.editMode, $editMode)
    .background(Color(.systemGroupedBackground))
    .navigationTitle(routineName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Done") { onDone() }
          .fontWeight(.bold)
      }
    }
    .safeAreaInset(edge: .bottom) {
      Button(role: .destructive) {
        showingDeleteConfirmation = true
      } label: {
        Label("Delete Workout", systemImage: "trash")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
      }
      .buttonStyle(.bordered)
      .tint(.red)
      .padding()
      .background(.bar)
    }
    .confirmationDialog(
      "Delete workout?",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete Workout", role: .destructive, action: onDelete)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This permanently deletes the \(routineName) workout from \(session.startedAt.formatted(date: .abbreviated, time: .shortened))."
      )
    }
    .sheet(isPresented: $showingPeople) {
      ParticipantVisibilitySheet(session: session, people: people)
        .presentationDetents([.medium])
    }
    .sheet(isPresented: $showingExercisePicker) {
      AddExerciseToWorkoutSheet(session: session)
    }
  }

  private var catalogByName: [String: Exercise] {
    Dictionary(uniqueKeysWithValues: catalog.map { ($0.name, $0) })
  }

  private var routineName: String {
    routines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }

  private func workoutAction(
    _ title: String, systemImage: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 7) {
        Image(systemName: systemImage)
          .font(.headline)
        Text(title)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .foregroundStyle(Theme.navy)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(.background, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func moveExercises(from source: IndexSet, to destination: Int) {
    var ordered = session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
    ordered.move(fromOffsets: source, toOffset: destination)
    for (index, exercise) in ordered.enumerated() {
      exercise.sortOrder = index
    }
    try? context.save()
  }
}

struct AddExerciseToWorkoutSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query(sort: \Exercise.name) private var exercises: [Exercise]
  @Bindable var session: WorkoutSession
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
          if session.add(exercise) {
            try? context.save()
            dismiss()
          }
        } label: {
          HStack(spacing: 12) {
            ExerciseArtwork(exercise: exercise)
              .frame(width: 48, height: 48)
              .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
              Text(exercise.name).foregroundStyle(.primary)
              Text("\(exercise.primaryMuscle.capitalized) · \(exercise.unit.title)")
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if session.contains(exercise) {
              Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
            }
          }
        }
        .disabled(session.contains(exercise))
      }
      .searchable(text: $searchText, prompt: "Exercise name")
      .navigationTitle("Add Exercise")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
    }
  }
}

struct ActiveExerciseCard: View {
  @Bindable var exercise: ExerciseLog
  let catalogExercise: Exercise?
  let visiblePeople: [String]
  let colors: [String: String]
  @State private var showingImages = false

  private var visibleLogs: [ParticipantLog] {
    exercise.participants.filter { visiblePeople.contains($0.participantName) }
  }

  private var allVisibleSetsDone: Bool {
    !visibleLogs.isEmpty && visibleLogs.flatMap(\.sets).allSatisfy(\.isCompleted)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(exercise.exerciseName).font(.title3.bold())
          Text(exercise.unit.title)
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 8) {
          Image(
            systemName: allVisibleSetsDone ? "checkmark.seal.fill" : "circle.dashed"
          )
          .font(.title2)
          .foregroundStyle(allVisibleSetsDone ? Theme.mint : .secondary)
          if let catalogExercise, !catalogExercise.imageURLs.isEmpty {
            Button {
              showingImages = true
            } label: {
              ExerciseArtwork(exercise: catalogExercise)
                .frame(width: 76, height: 64)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                  Label("Form", systemImage: "photo.on.rectangle")
                    .labelStyle(.iconOnly)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(.black.opacity(0.6), in: Circle())
                    .padding(4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View form images for \(exercise.exerciseName)")
          }
        }
      }

      ForEach(visibleLogs) { participant in
        ParticipantQuickRow(
          participant: participant, unit: exercise.unit,
          colorHex: colors[participant.participantName] ?? "FF5A45")
      }
    }
    .padding()
    .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .sheet(isPresented: $showingImages) {
      if let catalogExercise { ExerciseImageSheet(exercise: catalogExercise) }
    }
  }
}

struct ParticipantQuickRow: View {
  @Bindable var participant: ParticipantLog
  let unit: TrackingUnit
  let colorHex: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        InitialBadge(name: participant.participantName, colorHex: colorHex, size: 30)
        Text(participant.participantName).font(.subheadline.bold())
        Spacer()
        TextField(
          "0",
          value: Binding(
            get: { participant.measurement },
            set: { value in
              participant.measurement = value
              for set in participant.sets { set.measurement = nil }
            }),
          format: .number
        )
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .font(.headline.monospacedDigit())
        .frame(width: 68)
        Text(unit.label).font(.caption).foregroundStyle(.secondary)
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 9) {
          ForEach(participant.sets.sorted(by: { $0.sortOrder < $1.sortOrder })) { set in
            VStack(spacing: 5) {
              Button {
                withAnimation(.snappy) { set.isCompleted.toggle() }
              } label: {
                Image(
                  systemName: set.isCompleted ? "checkmark" : "\(set.sortOrder + 1).circle.fill"
                )
                .font(.headline)
                .foregroundStyle(set.isCompleted ? .white : Color(hex: colorHex))
                .frame(width: 42, height: 38)
                .background(
                  set.isCompleted ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.12),
                  in: RoundedRectangle(cornerRadius: 11))
              }
              .buttonStyle(.plain)
              TextField(
                "reps", value: Binding(get: { set.reps }, set: { set.reps = max(1, $0) }),
                format: .number
              )
              .keyboardType(.numberPad)
              .multilineTextAlignment(.center)
              .font(.caption.monospacedDigit())
              .frame(width: 42)
              Text(unit.usesReps ? "reps" : "target")
                .font(.caption2).foregroundStyle(.secondary)
            }
          }
          Button {
            participant.sets.append(
              WorkoutSet(sortOrder: participant.sets.count, reps: participant.sets.last?.reps ?? 10)
            )
          } label: {
            Image(systemName: "plus")
              .frame(width: 42, height: 38)
              .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Add set for \(participant.participantName)")
        }
      }
    }
    .padding(12)
    .background(Color(hex: colorHex).opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
  }
}

struct ParticipantVisibilitySheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var session: WorkoutSession
  let people: [PersonProfile]

  var body: some View {
    NavigationStack {
      List(people) { person in
        Button {
          toggle(person.name)
        } label: {
          HStack {
            InitialBadge(name: person.name, colorHex: person.colorHex)
            Text(person.name).foregroundStyle(.primary)
            Spacer()
            Image(
              systemName: session.participantNames.contains(person.name)
                ? "checkmark.circle.fill" : "circle"
            )
            .foregroundStyle(
              session.participantNames.contains(person.name) ? Theme.coral : .secondary)
          }
        }
      }
      .navigationTitle("Change People")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }

  private func toggle(_ name: String) {
    if session.participantNames.contains(name) {
      guard session.participantNames.count > 1 else { return }
      session.participantNames.removeAll { $0 == name }
    } else {
      session.participantNames.append(name)
      for exercise in session.exercises
      where !exercise.participants.contains(where: { $0.participantName == name }) {
        exercise.participants.append(
          ParticipantLog(
            participantName: name, measurement: 0,
            sets: (0..<3).map { WorkoutSet(sortOrder: $0, reps: 10) }))
      }
    }
  }
}
