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
  @State private var navigationExerciseName: String?
  @State private var currentExerciseID: UUID?
  @State private var requestedExerciseID: UUID?

  var body: some View {
    ScrollViewReader { proxy in
      List {
        participantPills
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)

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
        navigationExerciseName =
          orderedExercises.last(where: { exercise in
            (offsets[exercise.id] ?? .greatestFiniteMagnitude) <= 0
          })?.exerciseName
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
    .navigationTitle(navigationExerciseName ?? routineName)
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
        Button {
          jumpExercise(by: -1)
        } label: {
          Image(systemName: "chevron.up")
        }
        .foregroundStyle(Theme.coral)
        .disabled(currentExerciseIndex <= 0)
        .accessibilityLabel("Previous exercise")
        .accessibilityIdentifier("previous-exercise")
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
  @State private var displayedSetCount: Int?

  private var visibleLogs: [ParticipantLog] {
    visiblePeople.compactMap { name in
      exercise.participants.first {
        $0.participantName.caseInsensitiveCompare(name) == .orderedSame
      }
    }
  }

  private var setCount: Int {
    displayedSetCount ?? visibleLogs.map(\.sets.count).max() ?? 0
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

      participantHeaders

      Divider()

      ForEach(0..<setCount, id: \.self) { setIndex in
        SwipeToDeleteSetRow(
          setNumber: setIndex + 1,
          onDelete: { deleteSharedSet(setIndex) }
        ) {
          setRow(setIndex)
        }
        if setIndex < setCount - 1 { Divider().padding(.leading, 46) }
      }

      HStack(spacing: 10) {
        Button(action: addSetForEveryone) {
          Label("Add set", systemImage: "plus.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.coral)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add-shared-set")

        Button(action: onAdvance) {
          Image(systemName: "chevron.down")
            .font(.headline.weight(.bold))
            .foregroundStyle(Theme.coral)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .disabled(position >= total)
        .opacity(position >= total ? 0.45 : 1)
        .accessibilityLabel("Next exercise")
        .accessibilityIdentifier("next-exercise-\(exercise.exerciseName)")
      }
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
  }

  private var participantHeaders: some View {
    HStack(alignment: .top, spacing: 6) {
      Text("SET")
        .font(.caption2.bold())
        .foregroundStyle(.secondary)
        .frame(width: 40)
        .padding(.top, 8)
      ForEach(visibleLogs) { participant in
        ParticipantMatrixHeader(
          participant: participant,
          unit: exercise.unit,
          colorHex: colors[participant.participantName] ?? "FF5A45"
        )
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func setRow(_ setIndex: Int) -> some View {
    HStack(alignment: .center, spacing: 6) {
      Button {
        toggleSetForEveryone(setIndex)
      } label: {
        let completed = sharedSetIsCompleted(setIndex)
        Image(systemName: completed ? "checkmark" : "\(setIndex + 1).circle.fill")
          .font(.subheadline.bold())
          .foregroundStyle(completed ? .white : Theme.navy)
          .frame(width: 40, height: 44)
          .background(completed ? Theme.mint : Color.secondary.opacity(0.12), in: Circle())
      }
      .buttonStyle(.plain)
      .disabled(!canToggleSharedSet(setIndex))
      .accessibilityIdentifier("shared-set-\(setIndex + 1)")
      .accessibilityLabel("Toggle set \(setIndex + 1) for everyone")

      ForEach(visibleLogs) { participant in
        if participant.orderedSets.indices.contains(setIndex) {
          ParticipantSetCell(
            participant: participant,
            set: participant.orderedSets[setIndex],
            colorHex: colors[participant.participantName] ?? "FF5A45"
          )
          .frame(maxWidth: .infinity)
        } else {
          Text("—")
            .font(.headline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 72)
        }
      }
    }
    .padding(.horizontal, 4)
    .background(
      sharedSetIsCompleted(setIndex) ? Theme.mint.opacity(0.14) : .clear,
      in: RoundedRectangle(cornerRadius: 12, style: .continuous)
    )
  }

  private func sharedSetIsCompleted(_ index: Int) -> Bool {
    let sets = visibleLogs.compactMap { participant in
      participant.orderedSets.indices.contains(index) ? participant.orderedSets[index] : nil
    }
    return !sets.isEmpty && sets.count == visibleLogs.count && sets.allSatisfy(\.isCompleted)
  }

  private func canToggleSharedSet(_ index: Int) -> Bool {
    visibleLogs.contains { participant in
      participant.orderedSets.indices.contains(index)
        && participant.canToggleCompletion(of: participant.orderedSets[index])
    }
  }

  private func toggleSetForEveryone(_ index: Int) {
    let shouldComplete = !sharedSetIsCompleted(index)
    withAnimation(.snappy) {
      for participant in visibleLogs where participant.orderedSets.indices.contains(index) {
        let set = participant.orderedSets[index]
        guard set.isCompleted != shouldComplete, participant.canToggleCompletion(of: set) else {
          continue
        }
        participant.toggleCompletion(of: set).forEach(context.delete)
      }
    }
    try? context.save()
  }

  private func addSetForEveryone() {
    let nextCount = setCount + 1
    withAnimation(.snappy) {
      for participant in exercise.participants {
        let last = participant.orderedSets.last
        let set = WorkoutSet(
          sortOrder: participant.sets.count,
          reps: last?.reps ?? WorkoutPreferences.defaultReps)
        participant.sets.append(set)
      }
      displayedSetCount = nextCount
    }
    try? context.save()
  }

  private func deleteSharedSet(_ index: Int) {
    let nextCount =
      exercise.participants.map { participant in
        participant.orderedSets.indices.contains(index)
          ? max(0, participant.sets.count - 1) : participant.sets.count
      }.max() ?? 0
    withAnimation(.snappy) {
      for participant in exercise.participants {
        let ordered = participant.orderedSets
        guard ordered.indices.contains(index) else { continue }
        let removed = ordered[index]
        participant.sets = ordered.filter { $0.id != removed.id }
        context.delete(removed)
        for (newIndex, set) in participant.orderedSets.enumerated() {
          set.sortOrder = newIndex
        }
      }
      displayedSetCount = nextCount
    }
    try? context.save()
  }

  private func equalizeSetCounts() {
    let targetCount = exercise.participants.map(\.sets.count).max() ?? 0
    guard targetCount > 0 else { return }
    var changed = false
    for participant in exercise.participants where participant.sets.count < targetCount {
      let reps = participant.orderedSets.last?.reps ?? WorkoutPreferences.defaultReps
      while participant.sets.count < targetCount {
        participant.sets.append(
          WorkoutSet(sortOrder: participant.sets.count, reps: reps)
        )
        changed = true
      }
    }
    displayedSetCount = targetCount
    if changed { try? context.save() }
  }
}

struct SwipeToDeleteSetRow<Content: View>: View {
  let setNumber: Int
  let onDelete: () -> Void
  let content: Content
  @State private var offset: CGFloat = 0
  @State private var isDeleteRevealed = false

  init(setNumber: Int, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
    self.setNumber = setNumber
    self.onDelete = onDelete
    self.content = content()
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      Image(systemName: "trash")
        .font(.headline)
        .foregroundStyle(.white)
        .frame(width: 72)
        .frame(maxHeight: .infinity)
        .background(.red)
        .opacity(offset < 0 ? 1 : 0)
        .accessibilityHidden(true)

      content
        .padding(.vertical, 4)
        .background(.background)
        .contentShape(Rectangle())
        .offset(x: offset)
        .simultaneousGesture(
          DragGesture(minimumDistance: 12)
            .onChanged { value in
              guard abs(value.translation.width) > abs(value.translation.height) else { return }
              offset = min(0, max(-88, value.translation.width))
            }
            .onEnded { value in
              guard abs(value.translation.width) > abs(value.translation.height) else {
                withAnimation(.snappy) { offset = 0 }
                return
              }
              withAnimation(.snappy) {
                isDeleteRevealed = value.translation.width < -24
                offset = isDeleteRevealed ? -72 : 0
              }
            }
        )
        .accessibilityElement(children: .contain)

      if isDeleteRevealed {
        Button(role: .destructive) {
          delete()
        } label: {
          Image(systemName: "trash")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 72)
            .frame(maxHeight: .infinity)
            .background(.red)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete set \(setNumber)")
        .accessibilityIdentifier("delete-set-\(setNumber)")
      }
    }
    .clipped()
  }

  private func delete() {
    withAnimation(.snappy) {
      isDeleteRevealed = false
      offset = 0
    }
    onDelete()
  }
}

struct ParticipantMatrixHeader: View {
  @Bindable var participant: ParticipantLog
  let unit: TrackingUnit
  let colorHex: String

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 4) {
        InitialBadge(name: participant.participantName, colorHex: colorHex, size: 24)
        Text(participant.participantName)
          .font(.caption.bold())
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      MeasurementStepper(participant: participant, unit: unit, colorHex: colorHex)
    }
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
          font: .monospacedDigitSystemFont(ofSize: 13, weight: .bold),
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
        .font(.caption2.bold())
        .frame(width: 32, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func adjust(by change: Double) {
    participant.measurement = max(0, participant.measurement + change)
    text = participant.measurement.tidy
    for set in participant.sets { set.measurement = nil }
    try? context.save()
  }
}

struct ParticipantSetCell: View {
  @Environment(\.modelContext) private var context
  @Bindable var participant: ParticipantLog
  @Bindable var set: WorkoutSet
  let colorHex: String

  var body: some View {
    VStack(spacing: 4) {
      EditableRepsControl(participant: participant, set: set)
      Button(action: toggleCompletion) {
        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundStyle(set.isCompleted ? Color(hex: colorHex) : .secondary)
          .frame(width: 44, height: 38)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(!participant.canToggleCompletion(of: set))
      .accessibilityIdentifier(
        "participant-set-\(participant.participantName)-\(set.sortOrder + 1)"
      )
      .accessibilityLabel(set.isCompleted ? "Remove completed set" : "Complete set")
    }
    .padding(.vertical, 2)
  }

  private func toggleCompletion() {
    withAnimation(.snappy) {
      participant.toggleCompletion(of: set).forEach(context.delete)
    }
    try? context.save()
  }
}

struct EditableRepsControl: View {
  @Environment(\.modelContext) private var context
  @Bindable var participant: ParticipantLog
  @Bindable var set: WorkoutSet
  @State private var text = ""
  @State private var isFocused = false

  var body: some View {
    HStack(spacing: 0) {
      stepButton("minus", identifier: "reps-minus") { setReps(set.reps - 1) }
      SelectAllTextField(
        text: $text,
        isFocused: $isFocused,
        keyboardType: .numberPad,
        textAlignment: .center,
        font: .monospacedDigitSystemFont(ofSize: 14, weight: .bold),
        accessibilityLabel: "Reps for \(participant.participantName), set \(set.sortOrder + 1)",
        step: 1,
        minimumValue: 1
      )
      .frame(maxWidth: .infinity, minHeight: 44)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(Color.secondary.opacity(0.28))
          .frame(height: 1)
          .padding(.horizontal, 5)
      }
      stepButton("plus", identifier: "reps-plus") { setReps(set.reps + 1) }
    }
    .foregroundStyle(Theme.navy)
    .onAppear { text = "\(set.reps)" }
    .onChange(of: text) { _, newValue in
      guard let reps = Int(newValue), reps > 0 else { return }
      applyReps(reps, updateText: false)
    }
    .onChange(of: set.reps) { _, reps in
      if !isFocused { text = "\(reps)" }
    }
    .onChange(of: isFocused) { _, focused in
      if !focused, text.isEmpty { text = "\(set.reps)" }
    }
  }

  private func stepButton(
    _ systemName: String, identifier: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.caption.bold())
        .frame(width: 32, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(
      "\(identifier)-\(participant.participantName)-\(set.sortOrder + 1)"
    )
  }

  private func setReps(_ value: Int) {
    applyReps(value, updateText: true)
  }

  private func applyReps(_ value: Int, updateText: Bool) {
    let reps = max(1, value)
    let shouldRaiseFollowingSets = reps > set.reps
    set.reps = reps
    if shouldRaiseFollowingSets {
      for followingSet in participant.sets
      where followingSet.sortOrder > set.sortOrder && followingSet.reps < reps {
        followingSet.reps = reps
      }
    }
    if updateText { text = "\(reps)" }
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
