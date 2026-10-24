import AppIntents
import HealthKit
import SwiftData
import SwiftUI

struct CompletedHealthWorkout {
  let id: UUID
  let start: Date
  let end: Date
  let duration: TimeInterval

  init?(session: WorkoutSession) {
    guard
      !session.isActive,
      session.deletedAt == nil,
      session.completedSetCount > 0,
      let end = session.endedAt,
      let duration = WorkoutSession.validatedWorkoutDuration(start: session.startedAt, end: end)
    else { return nil }
    id = session.id
    start = session.startedAt
    self.end = end
    self.duration = duration
  }
}

enum HealthKitWorkoutRecorder {
  static let recordingEnabledKey = "healthKitWorkoutRecordingEnabled"
  private static let store = HKHealthStore()

  static var isHealthDataAvailable: Bool {
    HKHealthStore.isHealthDataAvailable()
  }

  static var hasWorkoutWriteAuthorization: Bool {
    isHealthDataAvailable
      && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
  }

  static func requestWorkoutWriteAuthorization() async throws -> Bool {
    guard isHealthDataAvailable else { return false }
    let workoutType = HKObjectType.workoutType()
    if store.authorizationStatus(for: workoutType) == .sharingAuthorized { return true }
    let shareTypes: Set<HKSampleType> = [workoutType]
    try await store.requestAuthorization(toShare: shareTypes, read: [])
    return store.authorizationStatus(for: workoutType) == .sharingAuthorized
  }

  static func record(_ workout: CompletedHealthWorkout) async throws {
    guard hasWorkoutWriteAuthorization else { return }
    let workoutType = HKObjectType.workoutType()

    let metadata: [String: Any] = [
      HKMetadataKeySyncIdentifier: "com.cseibert.StrengthLog.workout.\(workout.id.uuidString)",
      HKMetadataKeySyncVersion: 1,
    ]
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .traditionalStrengthTraining
    configuration.locationType = .unknown
    let builder = HKWorkoutBuilder(
      healthStore: store, configuration: configuration, device: nil)
    try await perform { builder.beginCollection(withStart: workout.start, completion: $0) }
    try await perform { builder.addMetadata(metadata, completion: $0) }
    try await perform { builder.endCollection(withEnd: workout.end, completion: $0) }
    try await finish(builder)
  }

  private static func perform(
    _ operation: (@escaping @Sendable (Bool, (any Error)?) -> Void) -> Void
  ) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, any Error>) in
      operation { success, error in
        if let error {
          continuation.resume(throwing: error)
        } else if success {
          continuation.resume()
        } else {
          continuation.resume(throwing: NSError(domain: "HealthKitWorkoutRecorder", code: 1))
        }
      }
    }
  }

  private static func finish(_ builder: HKWorkoutBuilder) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, any Error>) in
      builder.finishWorkout { workout, error in
        if let error {
          continuation.resume(throwing: error)
        } else if workout != nil {
          continuation.resume()
        } else {
          continuation.resume(throwing: NSError(domain: "HealthKitWorkoutRecorder", code: 2))
        }
      }
    }
  }
}

@main
struct StrengthLogApp: App {
  @UIApplicationDelegateAdaptor(KidsWatchShareApplicationDelegate.self) private var appDelegate
  @State private var importCoordinator = HevyImportCoordinator()
  @State private var storageError: String?
  @State private var retentionError: String?
  @State private var widgetError: String?
  private let container: ModelContainer

  init() {
    let schema = Schema([
      PersonProfile.self,
      WeeklyCoachingReport.self,
      Exercise.self,
      Routine.self,
      RoutineExercise.self,
      Prescription.self,
      SetTemplate.self,
      WorkoutSession.self,
      ExerciseLog.self,
      ParticipantLog.self,
      WorkoutSet.self,
      ExternalExerciseMapping.self,
    ])
    #if DEBUG
      let usesBasicWorkoutFixture = ProcessInfo.processInfo.arguments.contains(
        "-basicWorkoutFixture")
    #else
      let usesBasicWorkoutFixture = false
    #endif
    var configuration = ModelConfiguration(
      schema: schema, isStoredInMemoryOnly: usesBasicWorkoutFixture, groupContainer: .none,
      cloudKitDatabase: .none)
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-diskWorkoutPerformanceFixture") {
        // Fresh disposable SQLite store per launch, separate from all user data.
        let directory = FileManager.default.temporaryDirectory
          .appendingPathComponent("WorkoutPerformanceStore", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        do {
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch { fatalError("Unable to create performance store: \(error)") }
        configuration = ModelConfiguration(
          "WorkoutPerformance", schema: schema,
          url: directory.appendingPathComponent("workout.sqlite"), cloudKitDatabase: .none)
      }
      if ProcessInfo.processInfo.arguments.contains("-repCountingMigrationFixture") {
        // A separate disposable store, never the user's normal workout database.
        configuration = ModelConfiguration(
          "RepCountingMigrationFixture", schema: schema, groupContainer: .none)
      }
    #endif
    do {
      container = try ModelContainer(for: schema, configurations: [configuration])
    } catch {
      fatalError("Unable to create StrengthLog data store: \(error)")
    }
    RoutineShortcutIntegration.modelContainer = container
    StrengthLogAppShortcuts.updateAppShortcutParameters()
    RoutineShortcutIntegration.refreshQuickActions(in: container.mainContext)
    let usesIsolatedStorageFixture =
      usesBasicWorkoutFixture
      || ProcessInfo.processInfo.arguments.contains("-diskWorkoutPerformanceFixture")
      || ProcessInfo.processInfo.arguments.contains("-repCountingMigrationFixture")
    if !usesIsolatedStorageFixture {
      ProgressWidgetPublication.configure(modelContainer: container)
    }

    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-repCountingMigrationFixture") {
        do {
          if try container.mainContext.fetchCount(FetchDescriptor<Exercise>()) == 0 {
            BasicWorkoutFixture.install(in: container.mainContext)
          }
          try BasicWorkoutFixture.verifyMigrationSnapshot(
            in: container.mainContext, storeURL: configuration.url)
          try SeedData.initializeRepCountingModes(in: container.mainContext)
          try BasicWorkoutFixture.verifyMigrationSnapshot(
            in: container.mainContext, storeURL: configuration.url)
          try "Rep-counting migration verified".write(
            to: configuration.url.appendingPathExtension("rep-counting-verified.txt"),
            atomically: true, encoding: .utf8)
        } catch {
          fatalError("Migration fixture failed: \(error)")
        }
      } else if usesBasicWorkoutFixture {
        BasicWorkoutFixture.install(in: container.mainContext)
      }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(importCoordinator)
        .onOpenURL { importCoordinator.open($0) }
        .onReceive(NotificationCenter.default.publisher(for: .progressWidgetPublicationFailed)) {
          notification in
          widgetError =
            notification.object as? String ?? "Open StrengthLog to retry the widget refresh."
        }
        .alert(
          "Couldn’t update exercise data",
          isPresented: Binding(
            get: { storageError != nil }, set: { if !$0 { storageError = nil } }
          )
        ) {
          Button("OK") { storageError = nil }
        } message: {
          Text(storageError ?? "")
        }
        .alert(
          "Couldn’t refresh the Progress widget",
          isPresented: Binding(
            get: { widgetError != nil }, set: { if !$0 { widgetError = nil } }
          )
        ) {
          Button("OK") { widgetError = nil }
        } message: {
          Text(widgetError ?? "")
        }
        .alert(
          "Couldn’t delete expired workouts",
          isPresented: Binding(
            get: { retentionError != nil }, set: { if !$0 { retentionError = nil } }
          )
        ) {
          Button("OK") { retentionError = nil }
        } message: {
          Text(retentionError ?? "")
        }
        .task {
          do {
            #if DEBUG
              if !ProcessInfo.processInfo.arguments.contains("-basicWorkoutFixture") {
                try await SeedData.seedIfNeeded(in: container.mainContext)
              }
            #else
              try await SeedData.seedIfNeeded(in: container.mainContext)
            #endif
          } catch {
            storageError = error.localizedDescription
          }
          #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            let usesFixtureStore =
              arguments.contains("-basicWorkoutFixture")
              || arguments.contains("-diskWorkoutPerformanceFixture")
              || arguments.contains("-repCountingMigrationFixture")
          #else
            let usesFixtureStore = false
          #endif
          if !usesFixtureStore {
            do {
              _ = try DeletedWorkoutRetention.purgeExpired(in: container.mainContext)
            } catch {
              retentionError = error.localizedDescription
            }
          }
          ProgressWidgetPublication.schedule()
          #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-runHevyImportSmokeTest") {
              do {
                try HevyImportSmokeTest.run()
                UserDefaults.standard.set(true, forKey: "hevyImportSmokePassed")
                UserDefaults.standard.removeObject(forKey: "hevyImportSmokeError")
              } catch {
                UserDefaults.standard.set(false, forKey: "hevyImportSmokePassed")
                UserDefaults.standard.set(
                  error.localizedDescription, forKey: "hevyImportSmokeError")
              }
            }
          #endif
        }
    }
    .modelContainer(container)
  }
}

struct AppRootView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase
  @Environment(HevyImportCoordinator.self) private var importCoordinator
  @State private var retentionError: String?
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @AppStorage("hasInitializedOnboardingState") private var hasInitializedOnboardingState = false
  @Query private var people: [PersonProfile]

  private var usesBasicWorkoutFixture: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains("-basicWorkoutFixture")
    #else
      false
    #endif
  }

  var body: some View {
    @Bindable var importCoordinator = importCoordinator
    Group {
      if hasCompletedOnboarding || usesBasicWorkoutFixture {
        RootView()
      } else {
        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
      }
    }
    .onAppear {
      guard !usesBasicWorkoutFixture else { return }
      normalizeLegacyPeopleOrderIfNeeded()
      guard !hasInitializedOnboardingState else { return }
      if !people.isEmpty { hasCompletedOnboarding = true }
      hasInitializedOnboardingState = true
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        purgeExpiredDeletedWorkouts()
        ProgressWidgetPublication.schedule()
      } else if phase == .background {
        RoutineShortcutIntegration.refreshQuickActions(in: context)
      }
    }
    .sheet(item: $importCoordinator.document) { document in
      HevyImportView(
        document: document,
        onCancel: { importCoordinator.document = nil },
        onComplete: { _ in
          importCoordinator.document = nil
        })
    }
    .alert(item: $importCoordinator.notice) { notice in
      Alert(
        title: Text(notice.title), message: Text(notice.message),
        dismissButton: .default(Text("OK")))
    }
    .alert(
      "Couldn’t delete expired workouts",
      isPresented: Binding(
        get: { retentionError != nil }, set: { if !$0 { retentionError = nil } }
      )
    ) {
      Button("OK") { retentionError = nil }
    } message: {
      Text(retentionError ?? "")
    }
  }

  private func purgeExpiredDeletedWorkouts() {
    do {
      if try DeletedWorkoutRetention.purgeExpired(in: context) > 0 {
        ProgressWidgetPublication.schedule()
      }
    } catch {
      retentionError = error.localizedDescription
    }
  }

  private func normalizeLegacyPeopleOrderIfNeeded() {
    guard Set(people.map(\.sortOrder)).count != people.count else { return }
    let onboardingColors = ["FF5A45", "59A8FA", "45D1A8", "A778F5", "F5B942", "E96BA8"]
    let ordered = people.sorted { lhs, rhs in
      let lhsColor = onboardingColors.firstIndex(of: lhs.colorHex) ?? onboardingColors.count
      let rhsColor = onboardingColors.firstIndex(of: rhs.colorHex) ?? onboardingColors.count
      if lhsColor != rhsColor { return lhsColor < rhsColor }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
    for (index, person) in ordered.enumerated() { person.sortOrder = index }
    _ = saveAndRefreshProgressWidget(context)
  }
}

struct RootView: View {
  private struct ActiveWorkoutRoute: Hashable {
    let sessionID: PersistentIdentifier
  }

  @Environment(\.modelContext) private var context
  @Query(
    filter: #Predicate<WorkoutSession> { $0.isActive && $0.deletedAt == nil },
    sort: \WorkoutSession.startedAt,
    order: .reverse)
  private var activeSessions: [WorkoutSession]
  @Query(sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @Query private var routines: [Routine]
  @AppStorage(HealthKitWorkoutRecorder.recordingEnabledKey)
  private var healthKitWorkoutRecordingEnabled = false
  @State private var navigationPath: [ActiveWorkoutRoute] = []
  @State private var selectedTab = 0
  @State private var didRestoreActiveWorkout = false
  @State private var celebrationSummary: WorkoutCelebrationSummary?
  @State private var routineShortcutError: String?

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack(path: $navigationPath) {
        HomeView(
          isCoveredByActiveWorkout: !navigationPath.isEmpty,
          onOpenWorkout: presentActiveWorkout,
          onReturnHome: {
            selectedTab = 0
            navigationPath.removeAll()
          }
        )
        .navigationDestination(for: ActiveWorkoutRoute.self) { route in
          if let session = context.model(for: route.sessionID) as? WorkoutSession {
            ActiveWorkoutView(
              session: session,
              onDone: { completeAndDismiss(session) },
              onDelete: { deleteAndDismiss(session) },
              onClose: dismissActiveWorkout
            )
          }
        }
      }
      .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
      .tag(0)

      NavigationStack { RoutinesView(onOpenWorkout: presentActiveWorkout) }
        .tabItem { Label("Routines", systemImage: "list.bullet.clipboard.fill") }
        .tag(1)

      NavigationStack { ExerciseLibraryView() }
        .tabItem { Label("Exercises", systemImage: "figure.strengthtraining.traditional") }
        .tag(2)

      NavigationStack { ProgressView() }
        .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
        .tag(3)

      NavigationStack { SettingsView() }
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        .tag(4)
    }
    .tint(Theme.coral)
    .onReceive(NotificationCenter.default.publisher(for: .openWeeklyCoachingReport)) { _ in
      selectedTab = 3
    }
    .onReceive(
      NotificationCenter.default.publisher(
        for: RoutineShortcutIntegration.startRoutineNotification
      )
    ) { _ in
      handlePendingRoutineShortcut()
    }
    .fullScreenCover(item: $celebrationSummary) { summary in
      WorkoutCelebrationView(
        summary: summary,
        onDone: { celebrationSummary = nil })
    }
    .alert(
      "Can’t start routine",
      isPresented: Binding(
        get: { routineShortcutError != nil }, set: { if !$0 { routineShortcutError = nil } }
      )
    ) {
      Button("OK") { routineShortcutError = nil }
    } message: {
      Text(routineShortcutError ?? "")
    }
    .onAppear {
      PairedWatchWorkoutSync.activate()
      RoutineShortcutIntegration.refreshQuickActions(in: context)
      handlePendingRoutineShortcut()
      if UserDefaults.standard.bool(forKey: WeeklyCoachingNotificationCoordinator.pendingRouteKey) {
        selectedTab = 3
      }
      if activeSessions.isEmpty { publishKidsWatchProgress() }
      guard !didRestoreActiveWorkout else { return }
      didRestoreActiveWorkout = true
      if let activeSession = activeSessions.first {
        presentActiveWorkout(activeSession)
      }
    }
    .onChange(of: activeSessions.count) { _, count in
      if count == 0 {
        publishKidsWatchProgress()
      } else if let activeSession = activeSessions.first {
        presentActiveWorkout(activeSession)
      }
    }
    .onChange(
      of: routines.map {
        "\($0.id.uuidString):\($0.name):\($0.visibleExercises.count):\($0.deletedAt != nil)"
      }
    ) { _, _ in
      RoutineShortcutIntegration.refreshQuickActions(in: context)
    }
  }

  private func handlePendingRoutineShortcut() {
    guard let result = RoutineShortcutIntegration.consumePendingQuickAction(in: context) else {
      return
    }
    if let session = result.0 {
      presentActiveWorkout(session)
    } else {
      routineShortcutError = result.1
    }
  }

  private func publishKidsWatchProgress() {
    let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: .now) ?? .distantPast
    let descriptor = FetchDescriptor<WorkoutSession>(
      predicate: #Predicate { $0.deletedAt == nil && $0.startedAt >= cutoff },
      sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
    let history = (try? context.fetch(descriptor)) ?? []
    let progress = KidsWatchSnapshot.makeProgressSummary(
      history: history, people: people, routines: routines)
    PairedWatchWorkoutSync.update(nil, progress: progress)
    Task {
      for person in people {
        try? await KidsWatchCloudStore.publish(progress.forPerson(person.id), for: person.id)
      }
    }
  }

  private func presentActiveWorkout(_ session: WorkoutSession) {
    selectedTab = 0
    let route = ActiveWorkoutRoute(sessionID: session.persistentModelID)
    guard navigationPath.last != route else { return }
    navigationPath = [route]
  }

  private func dismissActiveWorkout() {
    guard !navigationPath.isEmpty else { return }
    navigationPath.removeLast()
  }

  private func completeAndDismiss(_ session: WorkoutSession) {
    let didSaveCompletion = close(session)
    if didSaveCompletion, healthKitWorkoutRecordingEnabled,
      let workout = CompletedHealthWorkout(session: session)
    {
      Task {
        try? await HealthKitWorkoutRecorder.record(workout)
      }
    }
    celebrationSummary = makeCelebrationSummary(for: session)
    dismissActiveWorkout()
  }

  private func deleteAndDismiss(_ session: WorkoutSession) {
    delete(session)
    dismissActiveWorkout()
  }

  private func close(_ session: WorkoutSession) -> Bool {
    guard session.isActive else { return false }
    session.endedAt = .now
    session.isActive = false
    session.restTimerStartedAt = nil
    session.restTimerDurationSeconds = nil
    LiveActivityManager.shared.end()
    do {
      try context.save()
      ProgressWidgetPublication.schedule()
    } catch {
      return false
    }
    return true
  }

  private func makeCelebrationSummary(for session: WorkoutSession) -> WorkoutCelebrationSummary {
    let descriptor = FetchDescriptor<WorkoutSession>(
      predicate: #Predicate<WorkoutSession> { $0.deletedAt == nil })
    let history = (try? context.fetch(descriptor)) ?? [session]
    let colors = Dictionary(uniqueKeysWithValues: people.map { ($0.name, $0.colorHex) })
    let routineName =
      routines.first(where: { $0.id == session.routineID })?.name
      ?? (session.routineName.isEmpty ? "Workout" : session.routineName)
    return WorkoutCelebrationSummary.make(
      session: session,
      allSessions: history,
      routineName: routineName,
      colorHexByName: colors)
  }

  private func delete(_ session: WorkoutSession) {
    session.deletedAt = .now
    session.isActive = false
    session.endedAt = session.endedAt ?? .now
    session.restTimerStartedAt = nil
    session.restTimerDurationSeconds = nil
    _ = saveAndRefreshProgressWidget(context)
    LiveActivityManager.shared.end()
  }
}
