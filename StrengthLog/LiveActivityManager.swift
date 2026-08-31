import ActivityKit
import Foundation
import UserNotifications

@MainActor
final class LiveActivityManager {
  static let shared = LiveActivityManager()

  private let notificationCenter = UNUserNotificationCenter.current()
  private let notificationIdentifier = "lift-chase-rest-timer"
  private var activity: Activity<LiftChaseLiveActivityAttributes>?

  private init() {}

  func requestRestTimerNotificationPermission() {
    Task {
      _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound])
    }
  }

  func scheduleRestTimerNotification(
    at endDate: Date,
    exerciseName: String
  ) {
    let interval = endDate.timeIntervalSinceNow
    guard interval > 1 else { return }

    let content = UNMutableNotificationContent()
    content.title = "Rest complete"
    content.body = "\(exerciseName) is ready for your next set."
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    let request = UNNotificationRequest(
      identifier: notificationIdentifier, content: content, trigger: trigger)
    notificationCenter.add(request)
  }

  func cancelRestTimerNotification() {
    notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
  }

  func startOrUpdate(
    sessionID: String,
    routineName: String,
    restEndDate: Date,
    exerciseName: String,
    setProgress: String,
    effort: String
  ) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let attributes = LiftChaseLiveActivityAttributes(
      sessionID: sessionID, routineName: routineName)
    let state = LiftChaseLiveActivityAttributes.ContentState(
      restEndDate: restEndDate,
      exerciseName: exerciseName,
      setProgress: setProgress,
      effort: effort)
    let content = ActivityContent(state: state, staleDate: restEndDate)

    Task { @MainActor in
      if let activity = activity ?? Activity<LiftChaseLiveActivityAttributes>.activities.first {
        self.activity = activity
        await activity.update(content)
        return
      }
      do {
        activity = try Activity.request(
          attributes: attributes, content: content, pushType: nil)
      } catch {
        activity = nil
      }
    }
  }

  func end() {
    cancelRestTimerNotification()
    Task { @MainActor in
      for activity in Activity<LiftChaseLiveActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      activity = nil
    }
  }
}
