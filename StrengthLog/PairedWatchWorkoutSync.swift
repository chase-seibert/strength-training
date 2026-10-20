import Foundation
import WatchConnectivity

extension Notification.Name {
  static let pairedWatchSetCompletionRequested =
    Notification.Name("pairedWatchSetCompletionRequested")
}

/// Sends the latest active-workout snapshot to the iPhone's paired Apple Watch.
/// CloudKit sharing remains the transport for watches on another Apple Account.
final class PairedWatchWorkoutSync: NSObject, WCSessionDelegate {
  static let shared = PairedWatchWorkoutSync()

  private var latestContext: [String: Any]?
  private var hasActivated = false

  private override init() {
    super.init()
  }

  static func activate() {
    shared.activateSession()
  }

  static func update(_ snapshot: KidsWatchSnapshot?, progress: KidsWatchProgressSnapshot? = nil) {
    shared.updateContext(snapshot, progress: progress)
  }

  private func activateSession() {
    guard WCSession.isSupported(), !hasActivated else { return }
    hasActivated = true
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  private func updateContext(
    _ snapshot: KidsWatchSnapshot?, progress: KidsWatchProgressSnapshot? = nil
  ) {
    guard WCSession.isSupported() else { return }
    var context: [String: Any] = ["source": "pairedPhone"]
    if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
      context["snapshot"] = data
    } else {
      context["hasActiveWorkout"] = false
    }
    if let progress,
      let data = try? JSONEncoder().encode(progress)
    {
      context["progress"] = data
    }
    latestContext = context
    guard WCSession.default.activationState == .activated else { return }
    transmit(context)
  }

  private func transmit(_ context: [String: Any]) {
    do {
      try WCSession.default.updateApplicationContext(context)
    } catch {
      NSLog("Unable to update paired Watch workout context: %@", error.localizedDescription)
    }
    if WCSession.default.isReachable {
      WCSession.default.sendMessage(context, replyHandler: nil) { error in
        NSLog("Unable to send live paired Watch workout update: %@", error.localizedDescription)
      }
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated, let latestContext else { return }
    transmit(latestContext)
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard message["command"] as? String == "completeSetForEveryone" else { return }
    Task { @MainActor in
      NotificationCenter.default.post(
        name: .pairedWatchSetCompletionRequested,
        object: message)
    }
  }
}
