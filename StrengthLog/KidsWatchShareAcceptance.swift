import CloudKit
import UIKit
import UserNotifications

final class KidsWatchShareApplicationDelegate: NSObject, UIApplicationDelegate,
  UNUserNotificationCenterDelegate
{
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    PairedWatchWorkoutSync.activate()
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.content.userInfo["destination"] as? String
      == "weekly-coaching-report"
    {
      UserDefaults.standard.set(
        true, forKey: WeeklyCoachingNotificationCoordinator.pendingRouteKey)
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: .openWeeklyCoachingReport, object: nil)
      }
    }
    completionHandler()
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(
      name: nil, sessionRole: connectingSceneSession.role)
    configuration.delegateClass = KidsWatchShareSceneDelegate.self
    return configuration
  }
}

final class KidsWatchShareSceneDelegate: UIResponder, UIWindowSceneDelegate {
  func windowScene(
    _ windowScene: UIWindowScene,
    userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
  ) {
    accept(cloudKitShareMetadata)
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let metadata = connectionOptions.cloudKitShareMetadata {
      accept(metadata)
    }
  }

  private func accept(_ metadata: CKShare.Metadata) {
    guard KidsWatchCloudStore.isAvailable else { return }
    Task {
      do {
        _ = try await KidsWatchCloudStore.container.accept(metadata)
      } catch {
        NSLog("Unable to accept Kids Watch CloudKit share: %@", error.localizedDescription)
      }
    }
  }
}
