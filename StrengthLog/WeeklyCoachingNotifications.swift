import Foundation
import UserNotifications

extension Notification.Name {
  static let openWeeklyCoachingReport = Notification.Name("openWeeklyCoachingReport")
}

enum WeeklyCoachingNotificationCoordinator {
  static let requestID = "weekly-coaching-report"
  static let enabledKey = "weeklyCoachingReminderEnabled"
  static let weekdayKey = "weeklyCoachingReminderWeekday"
  static let hourKey = "weeklyCoachingReminderHour"
  static let minuteKey = "weeklyCoachingReminderMinute"
  static let pendingRouteKey = "weeklyCoachingPendingRoute"

  static func setEnabled(_ enabled: Bool) async throws {
    let center = UNUserNotificationCenter.current()
    if enabled {
      let settings = await center.notificationSettings()
      if settings.authorizationStatus == .notDetermined {
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
          UserDefaults.standard.set(false, forKey: enabledKey)
          return
        }
      } else if settings.authorizationStatus == .denied {
        UserDefaults.standard.set(false, forKey: enabledKey)
        return
      }
      UserDefaults.standard.set(true, forKey: enabledKey)
      try await schedule()
    } else {
      UserDefaults.standard.set(false, forKey: enabledKey)
      center.removePendingNotificationRequests(withIdentifiers: [requestID])
    }
  }

  static func schedule() async throws {
    guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
    var components = DateComponents()
    components.weekday = min(max(UserDefaults.standard.integer(forKey: weekdayKey), 1), 7)
    let storedHour =
      UserDefaults.standard.object(forKey: hourKey) == nil
      ? 9 : UserDefaults.standard.integer(forKey: hourKey)
    components.hour = min(max(storedHour, 0), 23)
    components.minute = min(max(UserDefaults.standard.integer(forKey: minuteKey), 0), 59)
    let content = UNMutableNotificationContent()
    content.title = "Your training week is ready"
    content.body = "Review your workouts and Lift Coach notes in Progress."
    content.sound = .default
    content.userInfo = ["destination": "weekly-coaching-report"]
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
    try await UNUserNotificationCenter.current().add(request)
  }
}
