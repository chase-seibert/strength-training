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
  @State private var showingExercisePicker = false
  @State private var editMode: EditMode = .inactive
  @State private var showingDeleteConfirmation = false
  @State private var pendingParticipantRemoval: String?
  @State private var showingParticipantRemovalConfirmation = false

  var body: some View {
    List {
      participantPills
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

      ForEach(session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })) { exercise in
        ActiveExerciseCard(
          exercise: exercise,
          catalogExercise: catalogByName[exercise.exerciseName],
          visiblePeople: PersonProfile.orderedNames(session.participantNames, using: people),
          colors: Dictionary(uniqueKeysWithValues: people.map { ($0.name, $0.colorHex) })
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }
      .onMove(perform: moveExercises)

      HStack(spacing: 10) {
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

      VStack(spacing: 12) {
        Button("Complete Workout", action: onDone)
          .font(.headline)
          .frame(maxWidth: 240)
          .padding(.vertical, 13)
          .buttonStyle(.borderedProminent)
          .tint(Theme.coral)

        Button("Delete Workout", role: .destructive) {
          showingDeleteConfirmation = true
        }
        .font(.body.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(.red)
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
      }
      .frame(maxWidth: .infinity)
      .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 32, trailing: 16))
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .environment(\.editMode, $editMode)
    .background(Color(.systemGroupedBackground))
    .background(DismissKeyboardOnTap())
    .navigationTitle(routineName)
    .navigationBarTitleDisplayMode(.inline)
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

  private var participantPills: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("People")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(PersonProfile.ordered(people)) { person in
            let isSelected = session.isParticipantActive(person.name)
            Button {
              toggleParticipant(person.name)
            } label: {
              HStack(spacing: 6) {
                InitialBadge(name: person.name, colorHex: person.colorHex, size: 26)
                Text(person.name)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(isSelected ? .primary : .secondary)
                Image(systemName: isSelected ? "checkmark" : "plus")
                  .font(.caption.bold())
                  .foregroundStyle(isSelected ? Theme.coral : .secondary)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 7)
              .background(
                isSelected ? Theme.coral.opacity(0.14) : Color.secondary.opacity(0.08),
                in: Capsule()
              )
              .overlay {
                Capsule()
                  .stroke(
                    isSelected ? Theme.coral.opacity(0.45) : Color.secondary.opacity(0.18),
                    lineWidth: 1)
              }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(person.name), \(isSelected ? "included" : "excluded")")
            .accessibilityHint("Double tap to \(isSelected ? "hide" : "include") this person")
          }
        }
        .padding(.vertical, 2)
      }
    }
    .confirmationDialog(
      "Hide \(pendingParticipantRemoval ?? "person") from this workout?",
      isPresented: $showingParticipantRemovalConfirmation,
      titleVisibility: .visible
    ) {
      Button("Hide Person", role: .destructive) {
        if let pendingParticipantRemoval { removeParticipant(pendingParticipantRemoval) }
        pendingParticipantRemoval = nil
      }
      Button("Cancel", role: .cancel) { pendingParticipantRemoval = nil }
    } message: {
      Text("Completed sets will be kept. You can turn this person back on later in this workout.")
    }
  }

  private func toggleParticipant(_ name: String) {
    if session.isParticipantActive(name) {
      guard session.participantNames.count > 1 else { return }
      let hasCompletedSets = session.exercises.flatMap(\.participants).contains {
        $0.participantName.caseInsensitiveCompare(name) == .orderedSame
          && $0.sets.contains(where: \.isCompleted)
      }
      if hasCompletedSets {
        pendingParticipantRemoval = name
        showingParticipantRemovalConfirmation = true
      } else {
        removeParticipant(name)
      }
    } else {
      session.participantNames = PersonProfile.orderedNames(
        session.participantNames + [name], using: people)
      for exercise in session.exercises
      where !exercise.participants.contains(where: {
        $0.participantName.caseInsensitiveCompare(name) == .orderedSame
      }) {
        exercise.participants.append(
          ParticipantLog(
            participantName: name, measurement: 0,
            sets: (0..<3).map { WorkoutSet(sortOrder: $0, reps: 10) }))
      }
      try? context.save()
    }
  }

  private func removeParticipant(_ name: String) {
    session.participantNames.removeAll {
      $0.caseInsensitiveCompare(name) == .orderedSame
    }
    try? context.save()
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
    visiblePeople.compactMap { name in
      exercise.participants.first {
        $0.participantName.caseInsensitiveCompare(name) == .orderedSame
      }
    }
  }

  private var allVisibleSetsDone: Bool {
    let sets = visibleLogs.flatMap(\.sets)
    return !sets.isEmpty && sets.allSatisfy(\.isCompleted)
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
  @Environment(\.modelContext) private var context
  @Bindable var participant: ParticipantLog
  let unit: TrackingUnit
  let colorHex: String
  @State private var measurementText = ""
  @State private var measurementFocused = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        InitialBadge(name: participant.participantName, colorHex: colorHex, size: 30)
        Text(participant.participantName).font(.subheadline.bold())
        Spacer()
        SelectAllTextField(
          text: $measurementText,
          isFocused: $measurementFocused,
          keyboardType: .decimalPad,
          textAlignment: .right,
          font: .monospacedDigitSystemFont(ofSize: 17, weight: .semibold),
          accessibilityLabel: "\(unit.title) for \(participant.participantName)",
          step: unit == .pounds ? 5 : 1,
          minimumValue: 0
        )
        .frame(width: 68, height: 30)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(hex: colorHex).opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
          RoundedRectangle(cornerRadius: 9)
            .stroke(Color(hex: colorHex).opacity(0.30), lineWidth: 1)
        }
        .onAppear { measurementText = participant.measurement.tidy }
        .onChange(of: measurementText) { _, newValue in
          guard let value = Double(newValue) else { return }
          participant.measurement = value
          for set in participant.sets { set.measurement = nil }
          try? context.save()
        }
        .onChange(of: measurementFocused) { _, isFocused in
          if !isFocused, measurementText.isEmpty {
            measurementText = participant.measurement.tidy
          }
        }
        Text(unit.label).font(.caption).foregroundStyle(.secondary)
      }
      HStack(spacing: 12) {
        Label("Tap a set to complete", systemImage: "checkmark.circle")
        Label("Tap reps to edit", systemImage: "pencil")
      }
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 9) {
          ForEach(participant.orderedSets) { set in
            VStack(spacing: 5) {
              Text("SET")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
              Button {
                withAnimation(.snappy) {
                  participant.toggleCompletion(of: set).forEach(context.delete)
                }
                try? context.save()
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
              .disabled(!participant.canToggleCompletion(of: set))
              .opacity(participant.canToggleCompletion(of: set) ? 1 : 0.45)
              .accessibilityLabel(
                set.isCompleted
                  ? "Remove set \(set.sortOrder + 1)" : "Complete set \(set.sortOrder + 1)"
              )
              Text(unit.usesReps ? "REPS" : "TARGET")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
              WorkoutRepsField(set: set, unit: unit)
            }
          }

          Button {
            withAnimation(.snappy) {
              _ = participant.completeNextSet()
            }
            try? context.save()
          } label: {
            VStack(spacing: 5) {
              Text("NEXT SET")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
              Image(systemName: "\(participant.nextSetNumber).circle.fill")
                .font(.headline)
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 42, height: 38)
                .background(
                  Color(hex: colorHex).opacity(0.12),
                  in: RoundedRectangle(cornerRadius: 11))
              Text("\(participant.nextSetReps)")
                .font(.caption.monospacedDigit())
                .frame(width: 42)
              Text(unit.usesReps ? "REPS" : "TARGET")
                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          .disabled(!participant.canCompleteNextSet)
          .opacity(participant.canCompleteNextSet ? 1 : 0.45)
          .accessibilityLabel(
            "Complete set \(participant.nextSetNumber) for \(participant.participantName)"
          )
        }
      }
    }
    .padding(12)
    .background(Color(hex: colorHex).opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
  }
}

struct WorkoutRepsField: View {
  @Environment(\.modelContext) private var context
  @Bindable var set: WorkoutSet
  let unit: TrackingUnit
  @State private var text = ""
  @State private var isFocused = false

  var body: some View {
    SelectAllTextField(
      text: $text,
      isFocused: $isFocused,
      keyboardType: .numberPad,
      textAlignment: .center,
      font: .monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
      accessibilityLabel: unit.usesReps ? "Reps" : "Target",
      step: 1,
      minimumValue: 1
    )
    .frame(width: 42, height: 25)
    .padding(.horizontal, 5)
    .padding(.vertical, 4)
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
    }
    .onAppear { text = "\(set.reps)" }
    .onChange(of: text) { _, newValue in
      guard let reps = Int(newValue), reps > 0 else { return }
      set.reps = reps
      try? context.save()
    }
    .onChange(of: isFocused) { _, focused in
      if !focused, text.isEmpty { text = "\(set.reps)" }
    }
  }
}
