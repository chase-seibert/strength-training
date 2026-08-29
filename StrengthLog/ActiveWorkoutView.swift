import Charts
import SwiftData
import SwiftUI

private struct ExerciseCardOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: [UUID: CGFloat] = [:]

  static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

struct ActiveWorkoutView: View {
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @Query private var routines: [Routine]
  @Query private var catalog: [Exercise]
  @Bindable var session: WorkoutSession
  let onDone: () -> Void
  let onDelete: () -> Void
  let onClose: () -> Void
  @State private var showingExercisePicker = false
  @State private var editMode: EditMode = .inactive
  @State private var showingDeleteConfirmation = false
  @State private var pendingParticipantRemoval: String?
  @State private var showingParticipantRemovalConfirmation = false
  @State private var didRestoreScrollPosition = false
  @State private var currentExerciseID: UUID?
  @State private var requestedExerciseID: UUID?

  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, exercise in
          ActiveExerciseCard(
            exercise: exercise,
            catalogExercise: catalogByName[exercise.exerciseName],
            visiblePeople: visiblePeople,
            colors: participantColors,
            position: index + 1,
            total: orderedExercises.count,
            onAdvance: { jumpExercise(after: exercise, by: 1) }
          )
          .id(exercise.id)
          .background {
            GeometryReader { geometry in
              Color.clear.preference(
                key: ExerciseCardOffsetPreferenceKey.self,
                value: [
                  exercise.id: geometry.frame(in: .named("active-workout-scroll")).minY
                ])
            }
          }
          .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 12, trailing: 12))
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
          Button(action: onDone) {
            Text("Complete Workout")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 13)
          }
          .buttonStyle(.borderedProminent)
          .tint(Theme.coral)

          Button("Delete Workout", role: .destructive) {
            showingDeleteConfirmation = true
          }
          .font(.body.weight(.semibold))
          .buttonStyle(.plain)
          .foregroundStyle(.red)
          .alert(
            "Delete workout?",
            isPresented: $showingDeleteConfirmation
          ) {
            Button("Delete Workout", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
          } message: {
            Text(
              "This moves the \(routineName) workout from \(session.startedAt.formatted(date: .abbreviated, time: .shortened)) to Deleted Workouts, where it can be restored."
            )
          }
        }
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 32, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }
      .listStyle(.plain)
      .coordinateSpace(name: "active-workout-scroll")
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .environment(\.editMode, $editMode)
      .background(Color(.systemGroupedBackground))
      .background(DismissKeyboardOnTap())
      .safeAreaInset(edge: .top, spacing: 0) {
        participantPills
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(.regularMaterial)
          .overlay(alignment: .bottom) { Divider() }
      }
      .onAppear {
        guard !didRestoreScrollPosition else { return }
        didRestoreScrollPosition = true
        guard let target = resumeExerciseID else { return }
        currentExerciseID = target
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(target, anchor: .top)
          }
        }
      }
      .onPreferenceChange(ExerciseCardOffsetPreferenceKey.self) { offsets in
        guard requestedExerciseID == nil else { return }
        currentExerciseID =
          orderedExercises.min(by: { lhs, rhs in
            abs((offsets[lhs.id] ?? .greatestFiniteMagnitude) - 120)
              < abs((offsets[rhs.id] ?? .greatestFiniteMagnitude) - 120)
          })?.id ?? orderedExercises.first?.id
      }
      .onChange(of: requestedExerciseID) { _, target in
        guard let target else { return }
        currentExerciseID = target
        withAnimation(.snappy) {
          proxy.scrollTo(target, anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
          if requestedExerciseID == target {
            requestedExerciseID = nil
          }
        }
      }
    }
    .navigationTitle(currentExerciseName)
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button(action: onClose) {
          Image(systemName: "chevron.left")
            .font(.headline.weight(.bold))
        }
        .accessibilityLabel("Close workout")
        .accessibilityIdentifier("close-active-workout")
      }
      ToolbarItem(placement: .topBarTrailing) {
        if currentExerciseIndex > 0 {
          Button {
            jumpExercise(by: -1)
          } label: {
            Image(systemName: "chevron.up")
          }
          .foregroundStyle(Theme.coral)
          .accessibilityLabel("Previous exercise")
          .accessibilityIdentifier("previous-exercise")
        }
      }
    }
    .toolbar(.hidden, for: .tabBar)
    .accessibilityIdentifier("active-workout-screen")
    .sheet(isPresented: $showingExercisePicker) {
      AddExerciseToWorkoutSheet(session: session)
    }
  }

  private var catalogByName: [String: Exercise] {
    Dictionary(uniqueKeysWithValues: catalog.map { ($0.name, $0) })
  }

  private var orderedExercises: [ExerciseLog] {
    session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
  }

  private var visiblePeople: [String] {
    PersonProfile.orderedNames(session.participantNames, using: people)
  }

  private var participantColors: [String: String] {
    Dictionary(uniqueKeysWithValues: people.map { ($0.name, $0.colorHex) })
  }

  private var resumeExerciseID: UUID? {
    guard let first = orderedExercises.first else { return nil }
    guard
      let progressedIndex = orderedExercises.lastIndex(where: { exercise in
        exercise.participants
          .filter { session.isParticipantActive($0.participantName) }
          .flatMap(\.sets)
          .filter(\.isCompleted).count >= 2
      })
    else { return first.id }
    return orderedExercises[min(progressedIndex + 1, orderedExercises.count - 1)].id
  }

  private func jumpExercise(after exercise: ExerciseLog, by change: Int) {
    guard let index = orderedExercises.firstIndex(where: { $0.id == exercise.id }) else { return }
    requestExercise(at: index + change)
  }

  private var currentExerciseIndex: Int {
    guard let currentExerciseID else { return 0 }
    return orderedExercises.firstIndex(where: { $0.id == currentExerciseID }) ?? 0
  }

  private func jumpExercise(by change: Int) {
    guard !orderedExercises.isEmpty else { return }
    let targetIndex = min(max(0, currentExerciseIndex + change), orderedExercises.count - 1)
    requestExercise(at: targetIndex)
  }

  private func requestExercise(at index: Int) {
    guard orderedExercises.indices.contains(index) else { return }
    currentExerciseID = orderedExercises[index].id
    requestedExerciseID = orderedExercises[index].id
  }

  private var routineName: String {
    routines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }

  private var currentExerciseName: String {
    guard let currentExerciseID else {
      return orderedExercises.first?.exerciseName ?? routineName
    }
    return orderedExercises.first(where: { $0.id == currentExerciseID })?.exerciseName
      ?? routineName
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
            .accessibilityIdentifier("participant-picker-\(person.name)")
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
    .accessibilityIdentifier("sticky-participant-picker")
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
        let setCount = exercise.participants.map(\.sets.count).max() ?? 3
        exercise.participants.append(
          ParticipantLog(
            participantName: name, measurement: 0,
            sets: (0..<setCount).map {
              WorkoutSet(sortOrder: $0, reps: WorkoutPreferences.defaultReps)
            }))
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
  @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name)
  private var exercises: [Exercise]
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
  @Environment(\.modelContext) private var context
  @Bindable var exercise: ExerciseLog
  let catalogExercise: Exercise?
  let visiblePeople: [String]
  let colors: [String: String]
  let position: Int
  let total: Int
  let onAdvance: () -> Void
  @State private var showingImages = false
  @State private var showingHistory = false
  @State private var lastSetEditorParticipant: ParticipantLog?

  private let participantColumnWidth: CGFloat = 108

  private var visibleLogs: [ParticipantLog] {
    visiblePeople.compactMap { name in
      exercise.participants.first {
        $0.participantName.caseInsensitiveCompare(name) == .orderedSame
      }
    }
  }

  private var setCount: Int {
    visibleLogs.map(\.sets.count).max() ?? 0
  }

  private var participantSetStatuses: [String] {
    visibleLogs.compactMap { setStatus(for: $0) }
  }

  private var repGuidance: String? {
    let name = exercise.exerciseName.lowercased()
    if ["alternating", "alternate"].contains(where: name.contains) {
      return "Reps are total — split them evenly between sides."
    }
    if [
      "one-arm", "one arm", "single-arm", "single arm", "one-leg", "one leg", "single-leg",
      "single leg",
    ]
    .contains(where: name.contains) {
      return "Reps are per side — 8 means 8 on each side."
    }
    return nil
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        if let catalogExercise, !catalogExercise.imageURLs.isEmpty {
          Button {
            showingImages = true
          } label: {
            ExerciseArtwork(exercise: catalogExercise)
              .frame(width: 54, height: 46)
              .background(Color.secondary.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          }
          .buttonStyle(.plain)
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(exercise.exerciseName)
            .font(.title3.bold())
            .lineLimit(2)
          Text("\(position) of \(total) · \(exercise.unit.title)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          if let repGuidance {
            Text(repGuidance)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 4)
        Button {
          showingHistory = true
        } label: {
          Image(systemName: "chart.xyaxis.line")
            .font(.headline)
            .foregroundStyle(.blue)
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("exercise-history-\(exercise.exerciseName)")
        .accessibilityLabel("Show group history for \(exercise.exerciseName)")
      }

      participantLoadControls

      Divider()

      HStack(alignment: .top, spacing: 6) {
        ForEach(visibleLogs) { participant in
          ParticipantExerciseCell(
            participant: participant,
            exerciseName: exercise.exerciseName,
            colorHex: colors[participant.participantName] ?? "FF5A45",
            onCustomizeLastSet: { lastSetEditorParticipant = participant },
            onResetLastSet: { resetLastSet(for: participant) },
            onSkipLastSets: { skipLastSets($0, for: participant) },
            onRestoreSkippedSets: { restoreSkippedSets(for: participant) },
            reservedSetStatuses: participantSetStatuses
          )
          .frame(width: participantColumnWidth)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Divider()

      setCountControls
    }
    .padding(12)
    .background(
      Color(.systemBackground),
      in: RoundedRectangle(cornerRadius: 20, style: .continuous)
    )
    .onAppear(perform: equalizeSetCounts)
    .onChange(of: visiblePeople) { _, _ in equalizeSetCounts() }
    .sheet(isPresented: $showingImages) {
      if let catalogExercise { ExerciseImageSheet(exercise: catalogExercise) }
    }
    .sheet(isPresented: $showingHistory) {
      ExerciseGroupHistoryView(
        exerciseName: exercise.exerciseName,
        people: visiblePeople,
        colors: colors,
        unit: exercise.unit)
    }
    .sheet(item: $lastSetEditorParticipant) { participant in
      if let lastSet = participant.orderedSets.last(where: { !$0.isSkipped }) {
        LastSetEditorSheet(
          exerciseName: exercise.exerciseName,
          baseReps: baseReps(for: participant),
          set: lastSet)
      }
    }
  }

  private var participantLoadControls: some View {
    HStack(alignment: .top, spacing: 6) {
      ForEach(visibleLogs) { participant in
        MeasurementStepper(
          participant: participant,
          unit: exercise.unit,
          colorHex: colors[participant.participantName] ?? "FF5A45"
        )
        .frame(width: participantColumnWidth)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var setCountControls: some View {
    ZStack(alignment: .bottomTrailing) {
      HStack(spacing: 26) {
        Button(action: removeLastSetForEveryone) {
          HStack(spacing: 12) {
            Image(systemName: "minus.circle")
              .font(.title3.weight(.semibold))
            Text("Remove Set")
          }
          .font(.subheadline.weight(.semibold))
          .frame(minHeight: 44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(setCount > 1 ? Theme.navy : Color.secondary.opacity(0.4))
        .disabled(setCount <= 1)
        .accessibilityIdentifier("remove-shared-set")
        .accessibilityLabel("Remove set")

        Button(action: addSetForEveryone) {
          HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
              .font(.title3.weight(.semibold))
            Text("Add Set")
          }
          .font(.subheadline.weight(.semibold))
          .frame(minHeight: 44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.coral)
        .accessibilityIdentifier("add-shared-set")
        .accessibilityLabel("Add set")
      }
      .padding(.trailing, 64)
      .frame(maxWidth: .infinity)

      Button(action: onAdvance) {
        Image(systemName: "chevron.down")
          .font(.headline.weight(.bold))
          .foregroundStyle(Theme.coral)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(position >= total)
      .opacity(position >= total ? 0.45 : 1)
      .accessibilityLabel("Next exercise")
      .accessibilityIdentifier("next-exercise-\(exercise.exerciseName)")
    }
  }

  private func addSetForEveryone() {
    withAnimation(.snappy) {
      for participant in exercise.participants {
        let ordered = participant.orderedSets
        let base = baseReps(for: participant)
        let lastOverride = lastSetOverride(for: participant)
        if lastOverride != nil, let last = ordered.last { last.reps = base }
        let set = WorkoutSet(
          sortOrder: participant.sets.count,
          reps: lastOverride ?? base)
        participant.sets.append(set)
      }
    }
    try? context.save()
  }

  private func removeLastSetForEveryone() {
    guard setCount > 1 else { return }
    withAnimation(.snappy) {
      for participant in exercise.participants {
        let ordered = participant.orderedSets
        guard let removed = ordered.last, ordered.count > 1 else { continue }
        participant.sets = Array(ordered.dropLast())
        context.delete(removed)
        for (newIndex, set) in participant.orderedSets.enumerated() {
          set.sortOrder = newIndex
        }
      }
      equalizeSetCounts()
    }
    try? context.save()
  }

  private func equalizeSetCounts() {
    let targetCount = exercise.participants.map(\.sets.count).max() ?? 0
    guard targetCount > 0 else { return }
    var changed = false
    for participant in exercise.participants where participant.sets.count < targetCount {
      let reps = baseReps(for: participant)
      while participant.sets.count < targetCount {
        participant.sets.append(
          WorkoutSet(sortOrder: participant.sets.count, reps: reps)
        )
        changed = true
      }
    }
    if changed { try? context.save() }
  }

  private func baseReps(for participant: ParticipantLog) -> Int {
    let activeSets = participant.orderedSets.filter { !$0.isSkipped }
    return activeSets.dropLast().first?.reps
      ?? activeSets.first?.reps
      ?? participant.orderedSets.first?.reps
      ?? WorkoutPreferences.defaultReps
  }

  private func lastSetOverride(for participant: ParticipantLog) -> Int? {
    let activeSets = participant.orderedSets.filter { !$0.isSkipped }
    guard activeSets.count > 1, let last = activeSets.last else {
      return nil
    }
    let base = baseReps(for: participant)
    return last.reps == base ? nil : last.reps
  }

  private func resetLastSet(for participant: ParticipantLog) {
    guard let last = participant.orderedSets.last(where: { !$0.isSkipped }) else { return }
    last.reps = baseReps(for: participant)
    try? context.save()
  }

  private func skipLastSets(_ count: Int, for participant: ParticipantLog) {
    let activeSets = participant.orderedSets.filter { !$0.isSkipped }
    guard activeSets.count > count else { return }
    for set in activeSets.suffix(count) {
      set.isSkipped = true
      set.isCompleted = false
      set.isLeftCompleted = false
      set.isRightCompleted = false
    }
    try? context.save()
  }

  private func restoreSkippedSets(for participant: ParticipantLog) {
    for set in participant.orderedSets where set.isSkipped {
      set.isSkipped = false
    }
    try? context.save()
  }

  private func setStatus(for participant: ParticipantLog) -> String? {
    var status: [String] = []
    if let lastSetOverride = lastSetOverride(for: participant) {
      status.append("Last set: \(lastSetOverride) reps")
    }
    let skippedSetCount = participant.orderedSets.filter(\.isSkipped).count
    if skippedSetCount > 0 {
      status.append(
        skippedSetCount == 1
          ? "Last set skipped"
          : "Last \(skippedSetCount) sets skipped")
    }
    return status.isEmpty ? nil : status.joined(separator: " · ")
  }
}

struct ParticipantExerciseCell: View {
  @Environment(\.modelContext) private var context
  @Bindable var participant: ParticipantLog
  let exerciseName: String
  let colorHex: String
  let onCustomizeLastSet: () -> Void
  let onResetLastSet: () -> Void
  let onSkipLastSets: (Int) -> Void
  let onRestoreSkippedSets: () -> Void
  let reservedSetStatuses: [String]

  private var orderedSets: [WorkoutSet] { participant.orderedSets }

  private var activeSets: [WorkoutSet] {
    orderedSets.filter { !$0.isSkipped }
  }

  private var skippedSetCount: Int {
    orderedSets.filter(\.isSkipped).count
  }

  private var baseReps: Int {
    activeSets.dropLast().first?.reps
      ?? activeSets.first?.reps
      ?? orderedSets.first?.reps
      ?? WorkoutPreferences.defaultReps
  }

  private var lastSetOverride: Int? {
    guard activeSets.count > 1, let last = activeSets.last, last.reps != baseReps else {
      return nil
    }
    return last.reps
  }

  private var completionRows: [[(offset: Int, element: WorkoutSet)]] {
    let indexedSets = Array(activeSets.enumerated())
    guard !indexedSets.isEmpty else { return [] }
    return stride(from: 0, to: indexedSets.count, by: 2).map { start in
      Array(indexedSets[start..<min(start + 2, indexedSets.count)])
    }
  }

  var body: some View {
    VStack(spacing: 6) {
      VStack(spacing: 0) {
        CompactRepsControl(
          participant: participant,
          baseReps: baseReps,
          colorHex: colorHex
        )
        .frame(maxWidth: .infinity)

        HStack(spacing: 0) {
          Spacer(minLength: 0)
          setOptionsMenu
        }
        .frame(height: 36)
      }

      if !reservedSetStatuses.isEmpty {
        ZStack(alignment: .top) {
          ForEach(Array(reservedSetStatuses.enumerated()), id: \.offset) { indexedStatus in
            setStatusText(indexedStatus.element)
              .hidden()
              .accessibilityHidden(true)
          }
          if let setStatus {
            setStatusText(setStatus)
          }
        }
        .frame(maxWidth: .infinity, alignment: .top)
      }

      VStack(spacing: 4) {
        ForEach(completionRows.indices, id: \.self) { rowIndex in
          HStack(spacing: 4) {
            ForEach(completionRows[rowIndex], id: \.element.id) { indexedSet in
              SetCompletionButton(
                set: indexedSet.element,
                participant: participant,
                exerciseName: exerciseName,
                setNumber: indexedSet.offset + 1,
                colorHex: colorHex,
                size: 36)
            }
          }
        }
      }
      .frame(maxWidth: .infinity)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private var setOptionsMenu: some View {
    Menu {
      if activeSets.count >= 2 {
        Button("Customize Last Set…", systemImage: "slider.horizontal.3") {
          onCustomizeLastSet()
        }
        Button("Skip Last Set", systemImage: "forward.end") {
          onSkipLastSets(1)
        }
      }
      if activeSets.count >= 3 {
        Button("Skip Last Two Sets", systemImage: "forward.end.fill") {
          onSkipLastSets(2)
        }
      }
      if lastSetOverride != nil {
        Button("Reset Last Set to \(baseReps)", systemImage: "arrow.uturn.backward") {
          onResetLastSet()
        }
      }
      if skippedSetCount > 0 {
        Button("Restore Skipped Sets", systemImage: "arrow.uturn.backward.circle") {
          onRestoreSkippedSets()
        }
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Color(hex: colorHex))
        .frame(width: 30, height: 30)
        .overlay {
          Circle()
            .stroke(Color(hex: colorHex), lineWidth: 1.5)
        }
        .frame(width: 36, height: 36)
        .contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton)
    .disabled(activeSets.count < 2 && skippedSetCount == 0)
    .accessibilityLabel(
      lastSetOverride == nil ? "Customize set options" : "Last set is \(lastSetOverride!) reps"
    )
    .accessibilityIdentifier("last-set-menu-\(participant.participantName)")
  }

  private var setStatus: String? {
    var status: [String] = []
    if let lastSetOverride {
      status.append("Last set: \(lastSetOverride) reps")
    }
    if skippedSetCount > 0 {
      status.append(
        skippedSetCount == 1
          ? "Last set skipped"
          : "Last \(skippedSetCount) sets skipped")
    }
    return status.isEmpty ? nil : status.joined(separator: " · ")
  }

  private func setStatusText(_ status: String) -> some View {
    Text(status)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(Color(hex: colorHex))
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity)
  }
}

struct SetCompletionButton: View {
  @Environment(\.modelContext) private var context
  @Bindable var set: WorkoutSet
  @Bindable var participant: ParticipantLog
  let exerciseName: String
  let setNumber: Int
  let colorHex: String
  let size: CGFloat

  var body: some View {
    Button(action: toggleCompletion) {
      ZStack(alignment: .topTrailing) {
        Text("\(setNumber)")
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(set.isCompleted ? Color(hex: colorHex) : .secondary)
          .frame(width: size - 4, height: size - 4)
          .background(
            set.isCompleted ? Color(hex: colorHex).opacity(0.14) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(
                set.isCompleted ? Color(hex: colorHex).opacity(0.6) : Color.secondary.opacity(0.2),
                lineWidth: 1)
          }

        if set.isCompleted {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(hex: colorHex))
            .background(Color(.systemBackground), in: Circle())
            .offset(x: 3, y: -3)
        }
      }
      .frame(width: size, height: size)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!participant.canToggleCompletion(of: set))
    .accessibilityIdentifier("participant-set-\(participant.participantName)-\(setNumber)")
    .accessibilityLabel(
      set.isCompleted
        ? "Remove completed \(exerciseName) set \(setNumber)"
        : "Complete \(exerciseName) set \(setNumber)")
  }

  private func toggleCompletion() {
    withAnimation(.snappy) {
      participant.toggleCompletion(of: set).forEach(context.delete)
    }
    try? context.save()
  }
}

struct CompactRepsControl: View {
  @Environment(\.modelContext) private var context
  @Bindable var participant: ParticipantLog
  let baseReps: Int
  let colorHex: String
  @State private var text = ""
  @State private var isFocused = false

  var body: some View {
    VStack(spacing: 1) {
      HStack(spacing: 0) {
        stepButton("minus") { setBaseReps(baseReps - 1) }
        SelectAllTextField(
          text: $text,
          isFocused: $isFocused,
          keyboardType: .numberPad,
          textAlignment: .center,
          font: .monospacedDigitSystemFont(ofSize: 17, weight: .bold),
          accessibilityLabel: "Base reps for \(participant.participantName)",
          step: 1,
          minimumValue: 1
        )
        .frame(maxWidth: .infinity, minHeight: 36)
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(Color(hex: colorHex).opacity(0.38))
            .frame(height: 1)
            .padding(.horizontal, 4)
        }
        stepButton("plus") { setBaseReps(baseReps + 1) }
      }
      Text(baseReps == 1 ? "Rep" : "Reps")
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(.secondary)
    }
    .foregroundStyle(Color(hex: colorHex))
    .onAppear { text = "\(baseReps)" }
    .onChange(of: text) { _, newValue in
      guard let reps = Int(newValue), reps > 0 else { return }
      applyBaseReps(reps, updateText: false)
    }
    .onChange(of: baseReps) { _, reps in
      if !isFocused { text = "\(reps)" }
    }
    .onChange(of: isFocused) { _, focused in
      if !focused, text.isEmpty { text = "\(baseReps)" }
    }
  }

  private func stepButton(_ systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 11, weight: .bold))
        .frame(width: 30, height: 30)
        .background(Color(hex: colorHex).opacity(0.08), in: Circle())
        .overlay {
          Circle()
            .stroke(Color(hex: colorHex).opacity(0.75), lineWidth: 1.25)
        }
        .frame(width: 36, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(
      "base-reps-\(systemName)-\(participant.participantName)")
  }

  private func setBaseReps(_ value: Int) {
    applyBaseReps(value, updateText: true)
  }

  private func applyBaseReps(_ value: Int, updateText: Bool) {
    let reps = max(1, value)
    let sets = participant.orderedSets
    let activeSets = sets.filter { !$0.isSkipped }
    let lastActiveSetID = activeSets.count > 1 ? activeSets.last?.id : nil
    let preservesLastOverride = lastActiveSetID != nil && activeSets.last?.reps != baseReps
    for (_, set) in sets.enumerated()
    where !preservesLastOverride || set.id != lastActiveSetID {
      set.reps = reps
    }
    if updateText { text = "\(reps)" }
    try? context.save()
  }
}

struct LastSetEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  let exerciseName: String
  let baseReps: Int
  @Bindable var set: WorkoutSet
  @State private var text = ""
  @State private var isFocused = false

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Last set reps")
            .font(.headline)
          Text(
            "This overrides the base value of \(baseReps) reps for the final set only. It will be remembered next time."
          )
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        HStack(spacing: 6) {
          Button {
            setReps(set.reps - 1)
          } label: {
            Image(systemName: "minus")
              .frame(width: 44, height: 48)
          }
          .buttonStyle(.bordered)

          SelectAllTextField(
            text: $text,
            isFocused: $isFocused,
            keyboardType: .numberPad,
            textAlignment: .center,
            font: .monospacedDigitSystemFont(ofSize: 24, weight: .bold),
            accessibilityLabel: "Last set reps for \(exerciseName)",
            step: 1,
            minimumValue: 1
          )
          .frame(maxWidth: .infinity, minHeight: 52)
          .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.coral).frame(height: 2)
          }

          Button {
            setReps(set.reps + 1)
          } label: {
            Image(systemName: "plus")
              .frame(width: 44, height: 48)
          }
          .buttonStyle(.bordered)
        }

        Spacer()
      }
      .padding(20)
      .navigationTitle("Customize last set")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .onAppear { text = "\(set.reps)" }
      .onChange(of: text) { _, newValue in
        guard let reps = Int(newValue), reps > 0 else { return }
        setReps(reps, updateText: false)
      }
      .onChange(of: set.reps) { _, reps in
        if !isFocused { text = "\(reps)" }
      }
      .onChange(of: isFocused) { _, focused in
        if !focused, text.isEmpty { text = "\(set.reps)" }
      }
    }
    .presentationDetents([.medium])
  }

  private func setReps(_ value: Int, updateText: Bool = true) {
    set.reps = max(1, value)
    if updateText { text = "\(set.reps)" }
    try? context.save()
  }
}

struct MeasurementStepper: View {
  @Environment(\.modelContext) private var context
  @Bindable var participant: ParticipantLog
  let unit: TrackingUnit
  let colorHex: String
  @State private var text = ""
  @State private var isFocused = false

  private var step: Double { unit == .pounds ? 5 : 1 }

  var body: some View {
    VStack(spacing: 1) {
      HStack(spacing: 0) {
        stepButton("minus") { adjust(by: -step) }
        SelectAllTextField(
          text: $text,
          isFocused: $isFocused,
          keyboardType: .decimalPad,
          textAlignment: .center,
          font: .monospacedDigitSystemFont(ofSize: 16, weight: .bold),
          accessibilityLabel: "\(unit.title) for \(participant.participantName)",
          step: step,
          minimumValue: 0
        )
        .frame(maxWidth: .infinity, minHeight: 36)
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(Color(hex: colorHex).opacity(0.38))
            .frame(height: 1)
            .padding(.horizontal, 4)
        }
        stepButton("plus") { adjust(by: step) }
      }
      .padding(.top, 4)
      Text(unit.label)
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(.secondary)
    }
    .foregroundStyle(Color(hex: colorHex))
    .onAppear { text = participant.measurement.tidy }
    .onChange(of: text) { _, newValue in
      guard let value = Double(newValue), value >= 0 else { return }
      participant.measurement = value
      for set in participant.sets { set.measurement = nil }
      try? context.save()
    }
    .onChange(of: isFocused) { _, focused in
      if !focused, text.isEmpty { text = participant.measurement.tidy }
    }
  }

  private func stepButton(_ systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 11, weight: .bold))
        .frame(width: 30, height: 30)
        .background(Color(hex: colorHex).opacity(0.08), in: Circle())
        .overlay {
          Circle()
            .stroke(Color(hex: colorHex).opacity(0.75), lineWidth: 1.25)
        }
        .frame(width: 36, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(
      "measurement-\(systemName)-\(participant.participantName)")
  }

  private func adjust(by change: Double) {
    participant.measurement = max(0, participant.measurement + change)
    text = participant.measurement.tidy
    for set in participant.sets { set.measurement = nil }
    try? context.save()
  }
}

private struct ExerciseHistoryPoint: Identifiable {
  let id: String
  let personName: String
  let date: Date
  let measurement: Double
  let reps: Int
}

struct ExerciseGroupHistoryView: View {
  @Environment(\.dismiss) private var dismiss
  @Query(
    filter: #Predicate<WorkoutSession> { $0.deletedAt == nil },
    sort: \WorkoutSession.startedAt)
  private var sessions: [WorkoutSession]
  let exerciseName: String
  let people: [String]
  let colors: [String: String]
  let unit: TrackingUnit

  private var points: [ExerciseHistoryPoint] {
    sessions.flatMap { session -> [ExerciseHistoryPoint] in
      guard
        let exercise = session.exercises.first(where: {
          $0.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame
        })
      else { return [] }
      return people.compactMap { personName in
        guard
          let participant = exercise.participants.first(where: {
            $0.participantName.caseInsensitiveCompare(personName) == .orderedSame
          })
        else { return nil }
        let completed = participant.sets.filter(\.isCompleted)
        guard !completed.isEmpty else { return nil }
        let measurement = completed.map { $0.measurement ?? participant.measurement }.max() ?? 0
        let reps = completed.map(\.reps).max() ?? 0
        return ExerciseHistoryPoint(
          id: "\(session.id.uuidString)-\(personName.lowercased())",
          personName: personName,
          date: session.startedAt,
          measurement: measurement,
          reps: reps)
      }
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if points.isEmpty {
          EmptyStateView(
            symbol: "chart.xyaxis.line", title: "No completed sets yet",
            message: "Complete a set to start this exercise’s trend.")
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              HStack(spacing: 12) {
                ForEach(people, id: \.self) { person in
                  Label {
                    Text(person).font(.caption.bold())
                  } icon: {
                    Circle()
                      .fill(Color(hex: colors[person] ?? "FF5A45"))
                      .frame(width: 9, height: 9)
                  }
                }
              }
              historyChart(
                title: unit.title,
                value: { $0.measurement })
              historyChart(
                title: "Best reps",
                value: { Double($0.reps) })
            }
            .padding()
          }
        }
      }
      .navigationTitle(exerciseName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func historyChart(
    title: String,
    value: @escaping (ExerciseHistoryPoint) -> Double
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      Chart(points) { point in
        LineMark(
          x: .value("Date", point.date),
          y: .value(title, value(point)),
          series: .value("Person", point.personName)
        )
        .foregroundStyle(Color(hex: colors[point.personName] ?? "FF5A45"))
        PointMark(
          x: .value("Date", point.date),
          y: .value(title, value(point))
        )
        .foregroundStyle(Color(hex: colors[point.personName] ?? "FF5A45"))
      }
      .frame(height: 150)
    }
  }
}
