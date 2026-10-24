import AppIntents
import SwiftData
import UIKit

struct RoutineShortcutEntity: AppEntity, Identifiable {
  let id: UUID
  let name: String

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Routine")
  static let defaultQuery = RoutineShortcutEntityQuery()

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }
}

struct RoutineShortcutEntityQuery: EntityQuery {
  @MainActor
  func entities(for identifiers: [UUID]) async throws -> [RoutineShortcutEntity] {
    guard let context = RoutineShortcutIntegration.modelContainer?.mainContext else { return [] }
    let requestedIDs = Set(identifiers)
    let routines = try context.fetch(FetchDescriptor<Routine>())
    return
      routines
      .filter { requestedIDs.contains($0.id) && RoutineShortcutIntegration.isEligible($0) }
      .map { RoutineShortcutEntity(id: $0.id, name: $0.name) }
  }

  @MainActor
  func suggestedEntities() async throws -> [RoutineShortcutEntity] {
    guard let context = RoutineShortcutIntegration.modelContainer?.mainContext else { return [] }
    return try context.fetch(FetchDescriptor<Routine>())
      .filter(RoutineShortcutIntegration.isEligible)
      .sorted { $0.createdAt < $1.createdAt }
      .map { RoutineShortcutEntity(id: $0.id, name: $0.name) }
  }
}

struct StartRoutineIntent: AppIntent {
  static let title: LocalizedStringResource = "Start Routine"
  static let description = IntentDescription("Start a saved StrengthLog routine.")
  static var openAppWhenRun: Bool { true }

  @Parameter(title: "Routine") var routine: RoutineShortcutEntity

  @MainActor
  func perform() async throws -> some IntentResult {
    guard let context = RoutineShortcutIntegration.modelContainer?.mainContext,
      RoutineShortcutIntegration.start(routineID: routine.id, in: context) != nil
    else {
      throw RoutineShortcutError.unavailable
    }
    return .result(dialog: "Opening \(routine.name).")
  }
}

struct StrengthLogAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartRoutineIntent(),
      phrases: ["Start \(\.$routine) in \(.applicationName)"],
      shortTitle: "Start Routine",
      systemImageName: "dumbbell.fill")
  }
}

enum RoutineShortcutError: LocalizedError {
  case unavailable

  var errorDescription: String? {
    "That routine is no longer available or can’t be started. Open StrengthLog to choose another routine."
  }
}

enum RoutineShortcutIntegration {
  static let quickActionType = "com.cseibert.StrengthLog.start-routine"
  static let pendingRoutineIDKey = "pendingRoutineQuickActionID"
  static let startRoutineNotification = Notification.Name("startRoutineQuickAction")
  static let displayedQuickActionLimit = 4

  @MainActor static var modelContainer: ModelContainer?

  static func isEligible(_ routine: Routine) -> Bool {
    routine.deletedAt == nil && !routine.visibleExercises.isEmpty
  }

  @MainActor
  static func start(routineID: UUID, in context: ModelContext) -> WorkoutSession? {
    guard
      let routine = try? context.fetch(FetchDescriptor<Routine>())
        .first(where: { $0.id == routineID && isEligible($0) })
    else { return nil }

    let people = (try? context.fetch(FetchDescriptor<PersonProfile>())) ?? []
    let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
    let catalog = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    return WorkoutSessionStarter.start(
      routine: routine, people: people, sessions: sessions, catalog: catalog, in: context)
  }

  @MainActor
  static func refreshQuickActions(in context: ModelContext) {
    let routines = ((try? context.fetch(FetchDescriptor<Routine>())) ?? [])
      .filter(isEligible)
      .sorted { lhs, rhs in
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
      }
      .prefix(displayedQuickActionLimit)

    UIApplication.shared.shortcutItems = routines.map { routine in
      UIApplicationShortcutItem(
        type: quickActionType,
        localizedTitle: routine.name,
        localizedSubtitle: nil,
        icon: UIApplicationShortcutIcon(systemImageName: "dumbbell.fill"),
        userInfo: ["routineID": routine.id.uuidString as NSString])
    }
  }

  static func receiveQuickAction(_ item: UIApplicationShortcutItem) -> Bool {
    guard item.type == quickActionType,
      let rawID = item.userInfo?["routineID"] as? String,
      UUID(uuidString: rawID) != nil
    else { return false }
    UserDefaults.standard.set(rawID, forKey: pendingRoutineIDKey)
    NotificationCenter.default.post(name: startRoutineNotification, object: nil)
    return true
  }

  @MainActor
  static func consumePendingQuickAction(in context: ModelContext) -> (WorkoutSession?, String?)? {
    guard let rawID = UserDefaults.standard.string(forKey: pendingRoutineIDKey) else { return nil }
    UserDefaults.standard.removeObject(forKey: pendingRoutineIDKey)
    guard let id = UUID(uuidString: rawID) else {
      return (nil, RoutineShortcutError.unavailable.localizedDescription)
    }
    guard let session = start(routineID: id, in: context) else {
      return (nil, RoutineShortcutError.unavailable.localizedDescription)
    }
    return (session, nil)
  }
}
