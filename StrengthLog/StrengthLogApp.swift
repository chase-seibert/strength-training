import SwiftData
import SwiftUI

@main
struct StrengthLogApp: App {
  @State private var importCoordinator = HevyImportCoordinator()
  private let container: ModelContainer = {
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
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
      return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
      fatalError("Unable to create StrengthLog data store: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(importCoordinator)
        .onOpenURL { importCoordinator.open($0) }
        .task {
          await SeedData.seedIfNeeded(in: container.mainContext)
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

  var body: some View {
    @Bindable var importCoordinator = importCoordinator
    Group {
      if hasCompletedOnboarding {
        RootView()
      } else {
        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
      }
    }
    .onAppear {
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
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<WorkoutSession> { $0.isActive }) private var activeSessions:
    [WorkoutSession]

  var body: some View {
    Group {
      if let session = activeSessions.first {
        NavigationStack {
          ActiveWorkoutView(session: session) {
            close(session)
          } onDelete: {
            delete(session)
          }
        }
      } else {
        TabView {
          NavigationStack { HomeView() }
            .tabItem { Label("Workout", systemImage: "dumbbell.fill") }

          NavigationStack { RoutinesView() }
            .tabItem { Label("Routines", systemImage: "list.bullet.clipboard.fill") }

          NavigationStack { ExerciseLibraryView() }
            .tabItem { Label("Exercises", systemImage: "figure.strengthtraining.traditional") }

          NavigationStack { ProgressView() }
            .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }

          NavigationStack { SettingsView() }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
      }
    }
    .tint(Theme.coral)
  }

  private func close(_ session: WorkoutSession) {
    guard session.isActive else { return }
    session.endedAt = .now
    session.isActive = false
    updateRoutineDefaults(from: session)
    try? context.save()
  }

  private func delete(_ session: WorkoutSession) {
    context.delete(session)
    try? context.save()
  }

  private func updateRoutineDefaults(from session: WorkoutSession) {
    let targetID = session.routineID
    var descriptor = FetchDescriptor<Routine>(
      predicate: #Predicate { $0.id == targetID && $0.deletedAt == nil })
    descriptor.fetchLimit = 1
    guard let routine = try? context.fetch(descriptor).first else { return }
    for exerciseLog in session.exercises {
      guard
        let routineExercise = routine.exercises.first(where: {
          $0.exerciseName == exerciseLog.exerciseName
        })
      else { continue }
      for participantLog in exerciseLog.participants {
        let templates = participantLog.sets.sorted(by: { $0.sortOrder < $1.sortOrder }).map {
          SetTemplate(sortOrder: $0.sortOrder, reps: $0.reps)
        }
        if let prescription = routineExercise.prescriptions.first(where: {
          $0.participantName == participantLog.participantName
        }) {
          prescription.measurement = participantLog.measurement
          prescription.sets = templates
        } else {
          routineExercise.prescriptions.append(
            Prescription(
              participantName: participantLog.participantName,
              measurement: participantLog.measurement, sets: templates))
        }
      }
    }
  }
}
