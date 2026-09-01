import AudioToolbox
import Charts
import SwiftData
import SwiftUI

#if DEBUG
  import QuartzCore

  @MainActor
  private final class ActiveWorkoutFrameMonitor: ObservableObject {
    struct Sample {
      var framesPerSecond = 0
      var hitchCount = 0
      var worstFrameMilliseconds = 0.0
    }

    // Publish the one-second window atomically so the diagnostic itself causes only one
    // SwiftUI update instead of three back-to-back graph transactions.
    @Published private(set) var sample = Sample()

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var windowStart: CFTimeInterval?
    private var frameCount = 0
    private var windowHitchCount = 0
    private var windowWorstFrameMilliseconds = 0.0

    func start() {
      guard displayLink == nil else { return }
      let displayLink = CADisplayLink(target: self, selector: #selector(frameDidRender(_:)))
      if #available(iOS 15.0, *) {
        displayLink.preferredFrameRateRange = CAFrameRateRange(
          minimum: 60,
          maximum: 120,
          preferred: 120)
      }
      displayLink.add(to: .main, forMode: .common)
      self.displayLink = displayLink
    }

    func stop() {
      displayLink?.invalidate()
      displayLink = nil
      lastTimestamp = nil
      windowStart = nil
    }

    @objc private func frameDidRender(_ displayLink: CADisplayLink) {
      defer { lastTimestamp = displayLink.timestamp }
      guard let lastTimestamp else {
        windowStart = displayLink.timestamp
        return
      }

      let frameDuration = displayLink.timestamp - lastTimestamp
      let expectedDuration = max(displayLink.targetTimestamp - displayLink.timestamp, 1.0 / 120.0)
      let frameMilliseconds = frameDuration * 1_000
      frameCount += 1
      windowWorstFrameMilliseconds = max(windowWorstFrameMilliseconds, frameMilliseconds)
      if frameDuration > max(expectedDuration * 1.5, 1.0 / 45.0) {
        windowHitchCount += 1
      }

      guard let windowStart, displayLink.timestamp - windowStart >= 1 else { return }
      let elapsed = displayLink.timestamp - windowStart
      let sample = Sample(
        framesPerSecond: Int((Double(frameCount) / elapsed).rounded()),
        hitchCount: windowHitchCount,
        worstFrameMilliseconds: windowWorstFrameMilliseconds)
      self.sample = sample
      print(
        "ACTIVE_WORKOUT_FRAME_SAMPLE fps=\(sample.framesPerSecond) hitches=\(sample.hitchCount) worst_ms=\(String(format: "%.1f", sample.worstFrameMilliseconds))"
      )
      self.windowStart = displayLink.timestamp
      frameCount = 0
      windowHitchCount = 0
      windowWorstFrameMilliseconds = 0
    }
  }

  private struct ActiveWorkoutFrameOverlay: View {
    @StateObject private var monitor = ActiveWorkoutFrameMonitor()

    var body: some View {
      Text(
        "\(monitor.sample.framesPerSecond) fps · \(monitor.sample.hitchCount) hitch · \(monitor.sample.worstFrameMilliseconds, specifier: "%.0f") ms"
      )
      .font(.caption2.monospacedDigit().weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(.black.opacity(0.72), in: Capsule())
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onAppear { monitor.start() }
      .onDisappear { monitor.stop() }
    }
  }
#endif

private let activeWorkoutParticipantColumnWidth: CGFloat = 108

private struct ExerciseVisibilityTracker: ViewModifier {
  let exerciseID: UUID
  let isProgrammaticScrollPending: Bool
  @Binding var currentExerciseID: UUID?

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 18.0, *) {
      content.onScrollVisibilityChange(threshold: 0.75) { isVisible in
        guard isVisible, !isProgrammaticScrollPending else { return }
        guard currentExerciseID != exerciseID else { return }
        currentExerciseID = exerciseID
      }
    } else {
      content
    }
  }
}

private struct WorkoutSaveActionKey: EnvironmentKey {
  static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
  fileprivate var scheduleWorkoutSave: () -> Void {
    get { self[WorkoutSaveActionKey.self] }
    set { self[WorkoutSaveActionKey.self] = newValue }
  }
}

private struct ActiveWorkoutDurationLabel: View {
  let startedAt: Date

  var body: some View {
    let duration = max(0, Date.now.timeIntervalSince(startedAt))
    Text("Workout length \(duration.workoutDurationText)")
      .monospacedDigit()
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
  }
}

private struct ActiveWorkoutToolbarTitle: View {
  let exerciseName: String
  let restTimerStartedAt: Date?
  let restTimerDurationSeconds: Int?
  let onSkipRest: () -> Void
  let onRestTimerExpired: () -> Void

  var body: some View {
    Group {
      if let restEndDate, restEndDate > .now {
        HStack(spacing: 8) {
          Text(timerInterval: Date.now...restEndDate, countsDown: true)
            .monospacedDigit()
          Button("Skip", action: onSkipRest)
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(Theme.coral)
        }
        .foregroundStyle(Theme.coral)
        .font(.headline.weight(.semibold))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("live-workout-header")
        .task(id: restEndDate) {
          let delay = max(0, restEndDate.timeIntervalSinceNow)
          try? await Task.sleep(for: .seconds(delay))
          guard !Task.isCancelled else { return }
          onRestTimerExpired()
        }
      } else {
        Text(exerciseName)
          .foregroundStyle(.primary)
          .lineLimit(1)
          .font(.headline)
          .accessibilityLabel(exerciseName)
      }
    }
  }

  private var restEndDate: Date? {
    guard let restTimerStartedAt, let restTimerDurationSeconds else { return nil }
    return restTimerStartedAt.addingTimeInterval(TimeInterval(restTimerDurationSeconds))
  }
}

private struct DashTruncatedName: View {
  let name: String

  private var candidates: [String] {
    guard name.count > 1 else { return [name, "-"] }
    return [name]
      + stride(from: name.count - 1, through: 1, by: -1).map {
        "\(name.prefix($0))-"
      }
      + ["-"]
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      ForEach(candidates, id: \.self) { candidate in
        Text(candidate)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
      }
    }
  }
}

struct ActiveWorkoutView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @Query private var routines: [Routine]
  @Bindable var session: WorkoutSession
  let onDone: () -> Void
  let onDelete: () -> Void
  let onClose: () -> Void
  @State private var showingExercisePicker = false
  @State private var editMode: EditMode = .inactive
  @State private var showingDeleteConfirmation = false
  @State private var didRestoreScrollPosition = false
  @State private var currentExerciseID: UUID?
  @State private var requestedExerciseID: UUID?
  @State private var catalogByID: [UUID: Exercise] = [:]
  @State private var catalogByName: [String: Exercise] = [:]
  @State private var priorPersonalRecordValues: [String: Double] = [:]
  @State private var personalRecordExerciseKeys: Set<String> = []
  @State private var hasPendingSave = false
  @State private var didLoadSupportingData = false
  @State private var previousAutosaveEnabled: Bool?
  @AppStorage(WorkoutPreferences.restTimerNotificationsEnabledKey)
  private var restTimerNotificationsEnabled = false
  #if DEBUG
    @AppStorage(DeveloperPreferences.activeWorkoutFrameMonitorEnabledKey)
    private var activeWorkoutFrameMonitorEnabled = false
  #endif

  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, exercise in
          exerciseCard(
            exercise,
            index: index,
            personalRecordExerciseKeys: personalRecordExerciseKeys
          )
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
          ActiveWorkoutDurationLabel(startedAt: session.startedAt)
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
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .environment(\.editMode, $editMode)
      .background(Color(.systemGroupedBackground))
      .background(DismissKeyboardOnTap())
      .safeAreaInset(edge: .top, spacing: 0) {
        participantPills
          .padding(.horizontal, participantPickerOuterPadding)
          .padding(.vertical, 8)
          .background(Color(.systemBackground))
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
      ToolbarItem(placement: .principal) {
        ActiveWorkoutToolbarTitle(
          exerciseName: currentExerciseName,
          restTimerStartedAt: session.restTimerStartedAt,
          restTimerDurationSeconds: session.restTimerDurationSeconds,
          onSkipRest: clearRestTimer,
          onRestTimerExpired: handleRestTimerExpiry)
      }
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
    #if DEBUG
      .overlay(alignment: .bottomTrailing) {
        if activeWorkoutFrameMonitorEnabled {
          ActiveWorkoutFrameOverlay()
          .padding(.trailing, 8)
          .padding(.bottom, 8)
        }
      }
    #endif
    .sheet(isPresented: $showingExercisePicker) {
      AddExerciseToWorkoutSheet(session: session)
    }
    .environment(\.scheduleWorkoutSave, scheduleSave)
    .onAppear {
      if previousAutosaveEnabled == nil {
        previousAutosaveEnabled = context.autosaveEnabled
        context.autosaveEnabled = false
      }
      loadSupportingDataIfNeeded()
      syncLiveActivity()
    }
    .onDisappear {
      flushPendingSave()
      if let previousAutosaveEnabled {
        context.autosaveEnabled = previousAutosaveEnabled
        self.previousAutosaveEnabled = nil
      }
    }
    .onChange(of: session.exercises.map(\.id)) { _, _ in
      loadRelevantCatalogExercises()
      updateCurrentPersonalRecords()
    }
    .onChange(of: session.restTimerStartedAt) { _, _ in
      syncLiveActivity()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        syncLiveActivity()
      } else {
        flushPendingSave()
      }
    }
    .onChange(of: restTimerNotificationsEnabled) { _, _ in
      syncLiveActivity()
    }
  }

  private var activeRoutine: Routine? {
    routines.first(where: { $0.id == session.routineID })
  }

  private func handleRestTimerExpiry() {
    guard
      let startedAt = session.restTimerStartedAt,
      let duration = session.restTimerDurationSeconds,
      startedAt.addingTimeInterval(TimeInterval(duration)) <= .now
    else { return }
    AudioServicesPlayAlertSound(1005)
    LiveActivityManager.shared.end()
  }

  private func startRestTimer() {
    guard let duration = activeRoutine?.restDurationSeconds, duration > 0 else { return }
    if restTimerNotificationsEnabled {
      LiveActivityManager.shared.requestRestTimerNotificationPermission()
    }
    session.restTimerStartedAt = .now
    session.restTimerDurationSeconds = duration
    saveNow()
    syncLiveActivity()
  }

  private func handleSetCompleted() {
    updateCurrentPersonalRecords()
    if let duration = activeRoutine?.restDurationSeconds, duration > 0 {
      startRestTimer()
    } else {
      flushPendingSave()
    }
  }

  private func syncLiveActivity() {
    guard
      let startedAt = session.restTimerStartedAt,
      let duration = session.restTimerDurationSeconds,
      duration > 0
    else {
      LiveActivityManager.shared.end()
      return
    }
    let restEndDate = startedAt.addingTimeInterval(TimeInterval(duration))
    guard restEndDate > .now else {
      LiveActivityManager.shared.end()
      return
    }
    if !restTimerNotificationsEnabled {
      LiveActivityManager.shared.cancelRestTimerNotification()
    }
    LiveActivityManager.shared.startOrUpdate(
      sessionID: session.id.uuidString,
      routineName: activeRoutine?.name ?? "Workout",
      restEndDate: restEndDate,
      exerciseName: liveActivityDetails.exerciseName,
      setProgress: liveActivityDetails.setProgress,
      effort: liveActivityDetails.effort)
    if restTimerNotificationsEnabled {
      LiveActivityManager.shared.scheduleRestTimerNotification(
        at: restEndDate, exerciseName: liveActivityDetails.exerciseName)
    }
  }

  private var liveActivityDetails:
    (
      exerciseName: String, setProgress: String, effort: String
    )
  {
    guard let exercise = currentExerciseLog else {
      return (currentExerciseName, "", "")
    }
    let participants = visiblePeople.compactMap { name in
      exercise.participants.first {
        $0.participantName.caseInsensitiveCompare(name) == .orderedSame
      }
    }
    let participantsToUse = participants.isEmpty ? exercise.participants : participants
    let totalSets = max(
      participantsToUse.map { $0.orderedSets.filter { !$0.isSkipped }.count }.max() ?? 0, 1)
    let latestCompletedSet =
      participantsToUse
      .flatMap { $0.orderedSets.filter(\.isCompleted) }
      .max { lhs, rhs in
        let lhsDate = lhs.completedAt ?? .distantPast
        let rhsDate = rhs.completedAt ?? .distantPast
        if lhsDate != rhsDate { return lhsDate < rhsDate }
        return lhs.sortOrder < rhs.sortOrder
      }
    let setNumber = min(max((latestCompletedSet?.sortOrder ?? 0) + 1, 1), totalSets)
    let participant = participantsToUse.first
    let set =
      participant?.orderedSets.first {
        !$0.isSkipped && $0.sortOrder + 1 == setNumber
      } ?? participant?.orderedSets.first(where: { !$0.isSkipped })
    let reps = set?.reps ?? participant?.nextSetReps ?? WorkoutPreferences.defaultReps
    let measurement = set?.measurement ?? participant?.measurement ?? 0
    let effort =
      measurement > 0
      ? "\(measurement.tidy) \(exercise.unit.label) × \(reps)"
      : "\(reps) reps"
    return (
      exerciseName: exercise.exerciseName,
      setProgress: "Set \(setNumber) of \(totalSets)",
      effort: effort
    )
  }

  private var currentExerciseLog: ExerciseLog? {
    guard let currentExerciseID else { return orderedExercises.first }
    return orderedExercises.first(where: { $0.id == currentExerciseID }) ?? orderedExercises.first
  }

  private func clearRestTimer() {
    session.restTimerStartedAt = nil
    session.restTimerDurationSeconds = nil
    saveNow()
    LiveActivityManager.shared.end()
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
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-activeWorkoutScrolledPeopleFixture") {
        return orderedExercises.dropFirst().first?.id ?? first.id
      }
    #endif
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

  private var usesAlignedParticipantPicker: Bool { currentExerciseIndex > 0 }

  private var usesTwoPersonAlignedParticipantPicker: Bool {
    usesAlignedParticipantPicker && visiblePeople.count == 2
  }

  private var participantPickerOuterPadding: CGFloat {
    if usesTwoPersonAlignedParticipantPicker { return 0 }
    return usesAlignedParticipantPicker ? 24 : 16
  }

  private var participantPickerPeople: [PersonProfile] {
    let orderedPeople = PersonProfile.ordered(people)
    return orderedPeople.filter { session.isParticipantActive($0.name) }
      + orderedPeople.filter { !session.isParticipantActive($0.name) }
  }

  private func exerciseCard(
    _ exercise: ExerciseLog,
    index: Int,
    personalRecordExerciseKeys: Set<String>
  ) -> some View {
    ActiveExerciseCard(
      exercise: exercise,
      catalogExercise: exercise.exerciseID.flatMap { catalogByID[$0] }
        ?? catalogByName[exercise.exerciseName],
      visiblePeople: visiblePeople,
      colors: participantColors,
      position: index + 1,
      total: orderedExercises.count,
      usesSinglePersonHorizontalLayout: visiblePeople.count == 1,
      onAdvance: { jumpExercise(after: exercise, by: 1) },
      onSetCompleted: handleSetCompleted,
      showsPersonalRecord: personalRecordExerciseKeys.contains(PersonalRecords.key(for: exercise))
    )
    .frame(maxWidth: .infinity, alignment: .top)
    .id(exercise.id)
    .modifier(
      ExerciseVisibilityTracker(
        exerciseID: exercise.id,
        isProgrammaticScrollPending: requestedExerciseID != nil,
        currentExerciseID: $currentExerciseID
      )
    )
  }

  @ViewBuilder
  private var participantPills: some View {
    if usesTwoPersonAlignedParticipantPicker {
      GeometryReader { geometry in
        let columnGap = max(
          6,
          (geometry.size.width - (2 * activeWorkoutParticipantColumnWidth) - 48) / 3)
        let centerDistance = activeWorkoutParticipantColumnWidth + columnGap
        let pillWidth = min(140, centerDistance - 8)
        let firstColumnCenter = 24 + columnGap + (activeWorkoutParticipantColumnWidth / 2)
        participantPillScrollView(
          spacing: centerDistance - pillWidth,
          leadingPadding: firstColumnCenter - (pillWidth / 2),
          pillWidth: pillWidth)
      }
      .frame(height: 46)
    } else {
      participantPillScrollView(
        spacing: usesAlignedParticipantPicker ? 6 : 8,
        leadingPadding: 0,
        pillWidth: usesAlignedParticipantPicker ? activeWorkoutParticipantColumnWidth : nil)
    }
  }

  private func participantPillScrollView(
    spacing: CGFloat, leadingPadding: CGFloat, pillWidth: CGFloat?
  ) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: spacing) {
        ForEach(participantPickerPeople) { person in
          let isSelected = session.isParticipantActive(person.name)
          Button {
            toggleParticipant(person.name)
          } label: {
            participantPickerLabel(for: person, isSelected: isSelected, pillWidth: pillWidth)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("participant-picker-\(person.name)")
          .accessibilityLabel("\(person.name), \(isSelected ? "included" : "excluded")")
          .accessibilityHint("Double tap to \(isSelected ? "hide" : "include") this person")
        }
      }
      .padding(.leading, leadingPadding)
      .padding(.trailing, 16)
      .padding(.vertical, 2)
      .animation(.snappy, value: session.participantNames)
    }
    .accessibilityIdentifier("sticky-participant-picker")
  }

  @ViewBuilder
  private func participantPickerLabel(
    for person: PersonProfile, isSelected: Bool, pillWidth: CGFloat?
  ) -> some View {
    let participantColor = Color(hex: person.colorHex)
    HStack(spacing: usesAlignedParticipantPicker ? 5 : 6) {
      InitialBadge(name: person.name, colorHex: person.colorHex, size: 26)
      Group {
        if usesAlignedParticipantPicker {
          DashTruncatedName(name: person.name)
        } else {
          Text(person.name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
        }
      }
      .foregroundStyle(isSelected ? .primary : .secondary)
      .frame(
        maxWidth: usesAlignedParticipantPicker ? .infinity : nil,
        alignment: .leading)
      Image(systemName: isSelected ? "checkmark" : "plus")
        .font(.caption.bold())
        .foregroundStyle(isSelected ? participantColor : .secondary)
    }
    .padding(.horizontal, usesAlignedParticipantPicker ? 8 : 10)
    .frame(
      width: pillWidth,
      height: 42
    )
    .background(
      isSelected ? participantColor.opacity(0.10) : Color.secondary.opacity(0.06),
      in: Capsule()
    )
    .overlay {
      Capsule()
        .stroke(
          isSelected ? participantColor.opacity(0.45) : Color.secondary.opacity(0.18),
          lineWidth: 1)
    }
  }

  private func toggleParticipant(_ name: String) {
    if session.isParticipantActive(name) {
      guard session.participantNames.count > 1 else { return }
      removeParticipant(name)
    } else {
      session.participantNames = PersonProfile.orderedNames(
        session.participantNames + [name], using: people)
      for exercise in session.exercises
      where !exercise.participants.contains(where: {
        $0.participantName.caseInsensitiveCompare(name) == .orderedSame
      }) {
        let setCount =
          exercise.participants.map(\.sets.count).max()
          ?? WorkoutPreferences.defaultSets
        exercise.participants.append(
          ParticipantLog(
            participantName: name, measurement: 0,
            sets: (0..<setCount).map {
              WorkoutSet(sortOrder: $0, reps: WorkoutPreferences.defaultReps)
            }))
      }
      saveNow()
    }
  }

  private func removeParticipant(_ name: String) {
    session.participantNames.removeAll {
      $0.caseInsensitiveCompare(name) == .orderedSame
    }
    saveNow()
  }

  private func workoutAction(
    _ title: String, systemImage: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: systemImage)
          .font(.subheadline.weight(.semibold))
        Text(title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .foregroundStyle(Theme.navy)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(
        Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }

  private func moveExercises(from source: IndexSet, to destination: Int) {
    var ordered = session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
    ordered.move(fromOffsets: source, toOffset: destination)
    for (index, exercise) in ordered.enumerated() {
      exercise.sortOrder = index
    }
    saveNow()
  }

  private func loadSupportingDataIfNeeded() {
    guard !didLoadSupportingData else { return }
    didLoadSupportingData = true
    loadRelevantCatalogExercises()
    loadPersonalRecordBaseline()
  }

  private func loadRelevantCatalogExercises() {
    let relevantIDs = Set(session.exercises.compactMap(\.exerciseID))
    let relevantNames = Set(session.exercises.map(\.exerciseName))
    guard let exercises = try? context.fetch(FetchDescriptor<Exercise>()) else { return }
    let relevantExercises = exercises.filter {
      relevantIDs.contains($0.id) || relevantNames.contains($0.name)
    }
    catalogByID = Dictionary(uniqueKeysWithValues: relevantExercises.map { ($0.id, $0) })
    catalogByName = relevantExercises.reduce(into: [:]) { result, exercise in
      result[exercise.name] = result[exercise.name] ?? exercise
    }
  }

  private func loadPersonalRecordBaseline() {
    let descriptor = FetchDescriptor<WorkoutSession>(
      predicate: #Predicate { $0.deletedAt == nil })
    guard let history = try? context.fetch(descriptor) else { return }
    let previousAchievements = PersonalRecords.achievements(
      in: history.filter { $0.id != session.id })
    priorPersonalRecordValues = previousAchievements.reduce(into: [:]) { result, achievement in
      let key = personalRecordKey(
        exerciseKey: achievement.exerciseKey, personName: achievement.personName)
      result[key] = max(result[key] ?? 0, achievement.value)
    }
    updateCurrentPersonalRecords()
  }

  private func updateCurrentPersonalRecords() {
    var currentRecordKeys: Set<String> = []
    for exercise in session.exercises {
      let exerciseKey = PersonalRecords.key(for: exercise)
      for participant in exercise.participants
      where session.isParticipantActive(participant.participantName) {
        let recordKey = personalRecordKey(
          exerciseKey: exerciseKey, personName: participant.participantName)
        let previousBest = priorPersonalRecordValues[recordKey] ?? 0
        let hasRecord = participant.sets.contains { set in
          guard set.isCompleted, !set.isSkipped,
            let value = PersonalRecords.value(
              for: set, participant: participant, unit: exercise.unit)
          else { return false }
          return value > previousBest
        }
        if hasRecord { currentRecordKeys.insert(exerciseKey) }
      }
    }
    personalRecordExerciseKeys = currentRecordKeys
  }

  private func personalRecordKey(exerciseKey: String, personName: String) -> String {
    "\(exerciseKey)|\(personName.lowercased())"
  }

  private func scheduleSave() {
    if !hasPendingSave { hasPendingSave = true }
  }

  private func flushPendingSave() {
    guard hasPendingSave else { return }
    saveNow()
  }

  private func saveNow() {
    do {
      try context.save()
      hasPendingSave = false
    } catch {
      hasPendingSave = true
    }
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
  @Environment(\.scheduleWorkoutSave) private var scheduleWorkoutSave
  @Bindable var exercise: ExerciseLog
  let catalogExercise: Exercise?
  let visiblePeople: [String]
  let colors: [String: String]
  let position: Int
  let total: Int
  let usesSinglePersonHorizontalLayout: Bool
  let onAdvance: () -> Void
  let onSetCompleted: () -> Void
  let showsPersonalRecord: Bool
  @State private var showingImages = false
  @State private var showingHistory = false
  @State private var lastSetEditorParticipant: ParticipantLog?

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

  private var usesTwoPersonParticipantColumns: Bool {
    visibleLogs.count == 2
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
          .accessibilityIdentifier("exercise-images-\(exercise.exerciseName)")
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(exercise.exerciseName)
            .font(.title3.bold())
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
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
        if showsPersonalRecord {
          Label("PR", systemImage: "trophy.fill")
            .font(.caption.bold())
            .foregroundStyle(Theme.prYellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.prYellow.opacity(0.18), in: Capsule())
            .accessibilityLabel("Personal record")
        }
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

      if usesSinglePersonHorizontalLayout, let participant = visibleLogs.first {
        singlePersonMeasurementControls(for: participant)

        Divider()

        SinglePersonSetCompletionGrid(
          participant: participant,
          exerciseName: exercise.exerciseName,
          colorHex: colors[participant.participantName] ?? "FF5A45",
          setsPerRow: 8,
          onCustomizeLastSet: { lastSetEditorParticipant = participant },
          onResetLastSet: { resetLastSet(for: participant) },
          onSkipLastSets: { skipLastSets($0, for: participant) },
          onRestoreSkippedSets: { restoreSkippedSets(for: participant) },
          onSetCompleted: onSetCompleted
        )
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        participantLoadControls

        Divider()

        HStack(alignment: .top, spacing: usesTwoPersonParticipantColumns ? 0 : 6) {
          if usesTwoPersonParticipantColumns {
            ForEach(visibleLogs) { participant in
              Spacer(minLength: 0)
              participantExerciseControl(for: participant)
            }
            Spacer(minLength: 0)
          } else {
            ForEach(visibleLogs) { participant in
              participantExerciseControl(for: participant)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

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
        exerciseID: exercise.exerciseID,
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
    HStack(alignment: .top, spacing: usesTwoPersonParticipantColumns ? 0 : 6) {
      if usesTwoPersonParticipantColumns {
        ForEach(visibleLogs) { participant in
          Spacer(minLength: 0)
          participantLoadControl(for: participant)
        }
        Spacer(minLength: 0)
      } else {
        ForEach(visibleLogs) { participant in
          participantLoadControl(for: participant)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func participantLoadControl(for participant: ParticipantLog) -> some View {
    MeasurementStepper(
      participant: participant,
      unit: exercise.unit,
      colorHex: colors[participant.participantName] ?? "FF5A45"
    )
    .fixedSize(horizontal: false, vertical: true)
    .frame(width: activeWorkoutParticipantColumnWidth)
  }

  private func participantExerciseControl(
    for participant: ParticipantLog,
    showsSetCompletions: Bool = true,
    showsSetOptions: Bool = true
  ) -> some View {
    ParticipantExerciseCell(
      participant: participant,
      exerciseName: exercise.exerciseName,
      colorHex: colors[participant.participantName] ?? "FF5A45",
      onCustomizeLastSet: { lastSetEditorParticipant = participant },
      onResetLastSet: { resetLastSet(for: participant) },
      onSkipLastSets: { skipLastSets($0, for: participant) },
      onRestoreSkippedSets: { restoreSkippedSets(for: participant) },
      reservedSetStatuses: participantSetStatuses,
      showsSetCompletions: showsSetCompletions,
      showsSetOptions: showsSetOptions,
      onSetCompleted: onSetCompleted
    )
    .frame(width: activeWorkoutParticipantColumnWidth)
  }

  private func singlePersonMeasurementControls(for participant: ParticipantLog) -> some View {
    HStack(alignment: .top, spacing: 12) {
      participantLoadControl(for: participant)
      participantExerciseControl(
        for: participant,
        showsSetCompletions: false,
        showsSetOptions: false
      )
      .padding(.top, 4)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var setCountControls: some View {
    if usesSinglePersonHorizontalLayout {
      HStack(spacing: 10) {
        sharedSetButtons
        Spacer(minLength: 0)
        nextExerciseButton
      }
    } else {
      ZStack {
        sharedSetButtons

        HStack {
          Spacer(minLength: 0)
          nextExerciseButton
        }
      }
    }
  }

  private var sharedSetButtons: some View {
    HStack(spacing: 10) {
      Button(action: removeLastSetForEveryone) {
        Image(systemName: "minus")
          .font(.caption.weight(.bold))
          .foregroundStyle(setCount > 1 ? Theme.navy : Color.secondary.opacity(0.4))
          .frame(width: 30, height: 30)
          .background(Color.secondary.opacity(0.08), in: Circle())
      }
      .buttonStyle(.plain)
      .disabled(setCount <= 1)
      .accessibilityIdentifier("remove-shared-set")
      .accessibilityLabel("Remove set")

      Button(action: completeOneSetForEveryone) {
        Label("1 set", systemImage: "checkmark")
          .font(.caption.weight(.bold))
          .foregroundStyle(Theme.navy)
          .padding(.horizontal, 9)
          .padding(.vertical, 6)
          .background(Theme.mint.opacity(0.18), in: Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("complete-one-set")
      .accessibilityLabel("Complete one set for everyone")

      Button(action: addSetForEveryone) {
        Image(systemName: "plus")
          .font(.caption.weight(.bold))
          .foregroundStyle(Theme.coral)
          .frame(width: 30, height: 30)
          .background(Theme.coral.opacity(0.12), in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("add-shared-set")
      .accessibilityLabel("Add set")
    }
  }

  private var nextExerciseButton: some View {
    Button(action: onAdvance) {
      Image(systemName: "arrow.down.circle.fill")
        .font(.title3.weight(.semibold))
        .foregroundStyle(position >= total ? Color.secondary.opacity(0.35) : Theme.coral)
        .frame(width: 36, height: 36)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(position >= total)
    .opacity(position >= total ? 0.45 : 1)
    .accessibilityLabel("Next exercise")
    .accessibilityIdentifier("next-exercise-\(exercise.exerciseName)")
  }

  private func completeOneSetForEveryone() {
    let participants = visibleLogs
    guard !participants.isEmpty else { return }
    let completedCounts = participants.map { participant in
      participant.orderedSets.filter { !$0.isSkipped && $0.isCompleted }.count
    }
    guard let maximumCompleted = completedCounts.max() else { return }
    let everyoneIsAtMaximum = completedCounts.allSatisfy { $0 == maximumCompleted }
    let targetCompletedCount = maximumCompleted + (everyoneIsAtMaximum ? 1 : 0)
    var didComplete = false

    withAnimation(.snappy) {
      for participant in participants {
        let completedCount = participant.orderedSets.filter { !$0.isSkipped && $0.isCompleted }
          .count
        guard completedCount < targetCompletedCount else { continue }
        if let nextSet = participant.orderedSets.first(where: { !$0.isSkipped && !$0.isCompleted })
        {
          nextSet.isCompleted = true
          nextSet.isLeftCompleted = true
          nextSet.isRightCompleted = true
          nextSet.completedAt = .now
          didComplete = true
        } else {
          let set = WorkoutSet(
            sortOrder: participant.sets.count,
            reps: baseReps(for: participant),
            isCompleted: true,
            completedAt: .now)
          participant.sets.append(set)
          didComplete = true
        }
      }
    }
    guard didComplete else { return }
    scheduleWorkoutSave()
    onSetCompleted()
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
    scheduleWorkoutSave()
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
    scheduleWorkoutSave()
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
    if changed { scheduleWorkoutSave() }
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
    scheduleWorkoutSave()
  }

  private func skipLastSets(_ count: Int, for participant: ParticipantLog) {
    let activeSets = participant.orderedSets.filter { !$0.isSkipped }
    guard activeSets.count > count else { return }
    for set in activeSets.suffix(count) {
      set.isSkipped = true
      set.isCompleted = false
      set.completedAt = nil
      set.isLeftCompleted = false
      set.isRightCompleted = false
    }
    scheduleWorkoutSave()
  }

  private func restoreSkippedSets(for participant: ParticipantLog) {
    for set in participant.orderedSets where set.isSkipped {
      set.isSkipped = false
    }
    scheduleWorkoutSave()
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
  let showsSetCompletions: Bool
  let showsSetOptions: Bool
  let onSetCompleted: () -> Void

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

  var body: some View {
    VStack(spacing: 6) {
      VStack(spacing: 0) {
        CompactRepsControl(
          participant: participant,
          baseReps: baseReps,
          colorHex: colorHex
        )
        .frame(maxWidth: .infinity)

        if showsSetOptions {
          HStack(spacing: 0) {
            Spacer(minLength: 0)
            ParticipantSetOptionsMenu(
              participant: participant,
              baseReps: baseReps,
              colorHex: colorHex,
              onCustomizeLastSet: onCustomizeLastSet,
              onResetLastSet: onResetLastSet,
              onSkipLastSets: onSkipLastSets,
              onRestoreSkippedSets: onRestoreSkippedSets)
          }
          .frame(height: 36)
        }
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

      if showsSetCompletions {
        ParticipantSetCompletionGrid(
          participant: participant,
          exerciseName: exerciseName,
          colorHex: colorHex,
          setsPerRow: 2,
          onSetCompleted: onSetCompleted)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
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

struct ParticipantSetOptionsMenu: View {
  @Bindable var participant: ParticipantLog
  let baseReps: Int
  let colorHex: String
  let onCustomizeLastSet: () -> Void
  let onResetLastSet: () -> Void
  let onSkipLastSets: (Int) -> Void
  let onRestoreSkippedSets: () -> Void

  private var activeSets: [WorkoutSet] {
    participant.orderedSets.filter { !$0.isSkipped }
  }

  private var skippedSetCount: Int {
    participant.orderedSets.filter(\.isSkipped).count
  }

  private var lastSetOverride: Int? {
    guard activeSets.count > 1, let last = activeSets.last, last.reps != baseReps else {
      return nil
    }
    return last.reps
  }

  var body: some View {
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
}

struct SinglePersonSetCompletionGrid: View {
  @Bindable var participant: ParticipantLog
  let exerciseName: String
  let colorHex: String
  let setsPerRow: Int
  let onCustomizeLastSet: () -> Void
  let onResetLastSet: () -> Void
  let onSkipLastSets: (Int) -> Void
  let onRestoreSkippedSets: () -> Void
  let onSetCompleted: () -> Void

  private var activeSets: [WorkoutSet] {
    participant.orderedSets.filter { !$0.isSkipped }
  }

  private var baseReps: Int {
    activeSets.dropLast().first?.reps
      ?? activeSets.first?.reps
      ?? participant.orderedSets.first?.reps
      ?? WorkoutPreferences.defaultReps
  }

  private var itemRows: [[Int]] {
    let itemIndices = Array(0...activeSets.count)
    return stride(from: 0, to: itemIndices.count, by: setsPerRow).map { start in
      Array(itemIndices[start..<min(start + setsPerRow, itemIndices.count)])
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(itemRows.indices, id: \.self) { rowIndex in
        HStack(spacing: 4) {
          ForEach(itemRows[rowIndex], id: \.self) { itemIndex in
            if itemIndex < activeSets.count {
              SetCompletionButton(
                set: activeSets[itemIndex],
                participant: participant,
                exerciseName: exerciseName,
                setNumber: itemIndex + 1,
                colorHex: colorHex,
                size: 36,
                onSetCompleted: onSetCompleted)
            } else {
              ParticipantSetOptionsMenu(
                participant: participant,
                baseReps: baseReps,
                colorHex: colorHex,
                onCustomizeLastSet: onCustomizeLastSet,
                onResetLastSet: onResetLastSet,
                onSkipLastSets: onSkipLastSets,
                onRestoreSkippedSets: onRestoreSkippedSets)
            }
          }
        }
      }
    }
  }
}

struct ParticipantSetCompletionGrid: View {
  @Bindable var participant: ParticipantLog
  let exerciseName: String
  let colorHex: String
  let setsPerRow: Int
  let onSetCompleted: () -> Void

  private var activeSets: [WorkoutSet] {
    participant.orderedSets.filter { !$0.isSkipped }
  }

  private var completionRows: [[(offset: Int, element: WorkoutSet)]] {
    let indexedSets = Array(activeSets.enumerated())
    guard !indexedSets.isEmpty else { return [] }
    return stride(from: 0, to: indexedSets.count, by: setsPerRow).map { start in
      Array(indexedSets[start..<min(start + setsPerRow, indexedSets.count)])
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(completionRows.indices, id: \.self) { rowIndex in
        HStack(spacing: 4) {
          ForEach(completionRows[rowIndex], id: \.element.id) { indexedSet in
            SetCompletionButton(
              set: indexedSet.element,
              participant: participant,
              exerciseName: exerciseName,
              setNumber: indexedSet.offset + 1,
              colorHex: colorHex,
              size: 36,
              onSetCompleted: onSetCompleted)
          }
        }
      }
    }
  }
}

struct SetCompletionButton: View {
  @Environment(\.modelContext) private var context
  @Environment(\.scheduleWorkoutSave) private var scheduleWorkoutSave
  @Bindable var set: WorkoutSet
  @Bindable var participant: ParticipantLog
  let exerciseName: String
  let setNumber: Int
  let colorHex: String
  let size: CGFloat
  let onSetCompleted: () -> Void

  var body: some View {
    Button(action: toggleCompletion) {
      ZStack(alignment: .topTrailing) {
        let participantColor = Color(hex: colorHex)
        let canToggle = participant.canToggleCompletion(of: set)
        Text("\(setNumber)")
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(
            set.isCompleted
              ? participantColor : participantColor.opacity(canToggle ? 0.85 : 0.35)
          )
          .frame(width: size - 4, height: size - 4)
          .background(
            participantColor.opacity(set.isCompleted ? 0.16 : (canToggle ? 0.07 : 0.03)),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(
                participantColor.opacity(set.isCompleted ? 0.65 : (canToggle ? 0.4 : 0.14)),
                lineWidth: set.isCompleted ? 1.5 : 1)
          }

        if set.isCompleted {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(participantColor)
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
    let wasCompleted = set.isCompleted
    withAnimation(.snappy) {
      participant.toggleCompletion(of: set).forEach(context.delete)
    }
    scheduleWorkoutSave()
    if !wasCompleted && set.isCompleted {
      onSetCompleted()
    }
  }
}

struct CompactRepsControl: View {
  @Environment(\.scheduleWorkoutSave) private var scheduleWorkoutSave
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
      guard reps != baseReps else { return }
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
    scheduleWorkoutSave()
  }
}

struct LastSetEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scheduleWorkoutSave) private var scheduleWorkoutSave
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
    scheduleWorkoutSave()
  }
}

struct MeasurementStepper: View {
  @Environment(\.scheduleWorkoutSave) private var scheduleWorkoutSave
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
      scheduleWorkoutSave()
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
    scheduleWorkoutSave()
  }
}

private struct ExerciseHistoryPoint: Identifiable {
  let id: String
  let exerciseKey: String
  let personName: String
  let date: Date
  let measurement: Double
  let reps: Int
  let isPR: Bool
}

struct ExerciseGroupHistoryView: View {
  @Environment(\.dismiss) private var dismiss
  @Query(
    filter: #Predicate<WorkoutSession> { $0.deletedAt == nil },
    sort: \WorkoutSession.startedAt)
  private var sessions: [WorkoutSession]
  let exerciseID: UUID?
  let exerciseName: String
  let people: [String]
  let colors: [String: String]
  let unit: TrackingUnit

  private var points: [ExerciseHistoryPoint] {
    let achievements = PersonalRecords.achievements(in: sessions)
    return sessions.flatMap { session -> [ExerciseHistoryPoint] in
      guard
        let exercise = session.exercises.first(where: {
          if let exerciseID, let loggedExerciseID = $0.exerciseID {
            return exerciseID == loggedExerciseID
          }
          return $0.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame
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
        let exerciseKey = PersonalRecords.key(for: exercise)
        let isPR = achievements.contains {
          $0.sessionID == session.id
            && $0.exerciseKey == exerciseKey
            && $0.personName.caseInsensitiveCompare(personName) == .orderedSame
        }
        return ExerciseHistoryPoint(
          id: "\(session.id.uuidString)-\(personName.lowercased())",
          exerciseKey: exerciseKey,
          personName: personName,
          date: session.startedAt,
          measurement: measurement,
          reps: reps,
          isPR: isPR)
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
              let personalRecordCount = points.filter(\.isPR).count
              if personalRecordCount > 0 {
                Label(
                  "\(personalRecordCount) personal record\(personalRecordCount == 1 ? "" : "s")",
                  systemImage: "trophy.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.coral)
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
        if point.isPR {
          PointMark(
            x: .value("Date", point.date),
            y: .value(title, value(point))
          )
          .foregroundStyle(Theme.prYellow)
          .symbolSize(28)
          .annotation(position: .top, spacing: 2) {
            Image(systemName: "trophy.fill")
              .font(.caption2)
              .foregroundStyle(Theme.prYellow)
              .accessibilityLabel("Personal record")
          }
        }
      }
      .frame(height: 150)
    }
  }
}
