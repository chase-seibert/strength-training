import SwiftData
import SwiftUI

@main
struct StrengthLogApp: App {
  @State private var importCoordinator = HevyImportCoordinator()
  private let container: ModelContainer

  init() {
    let schema = Schema([
      PersonProfile.self,
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
    let configuration = ModelConfiguration(
      schema: schema, isStoredInMemoryOnly: usesBasicWorkoutFixture)
    do {
      container = try ModelContainer(for: schema, configurations: [configuration])
    } catch {
      fatalError("Unable to create StrengthLog data store: \(error)")
    }

    #if DEBUG
      if usesBasicWorkoutFixture {
        BasicWorkoutFixture.install(in: container.mainContext)
      }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(importCoordinator)
        .onOpenURL { importCoordinator.open($0) }
        .task {
          #if DEBUG
            if !ProcessInfo.processInfo.arguments.contains("-basicWorkoutFixture") {
              await SeedData.seedIfNeeded(in: container.mainContext)
            }
          #else
            await SeedData.seedIfNeeded(in: container.mainContext)
          #endif
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
  @Environment(HevyImportCoordinator.self) private var importCoordinator
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
    try? context.save()
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
  @State private var navigationPath: [ActiveWorkoutRoute] = []
  @State private var selectedTab = 0
  @State private var didRestoreActiveWorkout = false

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack(path: $navigationPath) {
        HomeView(
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
    .onAppear {
      guard !didRestoreActiveWorkout else { return }
      didRestoreActiveWorkout = true
      if let activeSession = activeSessions.first {
        presentActiveWorkout(activeSession)
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
    close(session)
    dismissActiveWorkout()
  }

  private func deleteAndDismiss(_ session: WorkoutSession) {
    delete(session)
    dismissActiveWorkout()
  }

  private func close(_ session: WorkoutSession) {
    guard session.isActive else { return }
    session.endedAt = .now
    session.isActive = false
    try? context.save()
  }

  private func delete(_ session: WorkoutSession) {
    session.deletedAt = .now
    session.isActive = false
    session.endedAt = session.endedAt ?? .now
    try? context.save()
  }
}
