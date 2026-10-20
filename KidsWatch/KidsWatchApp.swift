import Charts
import CloudKit
import SwiftUI
@preconcurrency import WatchConnectivity
@preconcurrency import WatchKit

@main
struct KidsWatchApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var model = KidsWatchModel()
  @WKApplicationDelegateAdaptor(KidsWatchApplicationDelegate.self) private var delegate

  var body: some Scene {
    WindowGroup {
      KidsWatchHomeView()
        .environmentObject(model)
        .task {
          model.applyPairedPhoneContext(KidsWatchConnectivityDelegate.shared.currentPhoneContext)
          await model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pairedPhoneWorkoutChanged)) { note in
          guard let context = note.object as? [String: Any] else { return }
          model.applyPairedPhoneContext(context)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kidsWatchCloudChanged)) { _ in
          Task { await model.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { Task { await model.refresh() } }
        }
    }
  }
}

final class KidsWatchApplicationDelegate: NSObject, WKApplicationDelegate {
  func applicationDidFinishLaunching() {
    WKApplication.shared().registerForRemoteNotifications()
    KidsWatchConnectivityDelegate.shared.activate()
    Task {
      let key = "kidsWatchSharedDatabaseSubscriptionInstalled"
      guard !UserDefaults.standard.bool(forKey: key) else { return }
      let subscription = CKDatabaseSubscription(subscriptionID: "kids-watch-shared-changes")
      let notification = CKSubscription.NotificationInfo()
      notification.shouldSendContentAvailable = true
      subscription.notificationInfo = notification
      do {
        _ = try await CKContainer(identifier: "iCloud.com.cseibert.StrengthLog")
          .sharedCloudDatabase.save(subscription)
        UserDefaults.standard.set(true, forKey: key)
      } catch {
        NSLog(
          "Unable to subscribe to Kids Watch shared database changes: %@",
          error.localizedDescription)
      }
    }
  }

  func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async
    -> WKBackgroundFetchResult
  {
    NotificationCenter.default.post(name: .kidsWatchCloudChanged, object: nil)
    return .newData
  }
}

extension Notification.Name {
  fileprivate static let kidsWatchCloudChanged = Notification.Name("kidsWatchCloudChanged")
  fileprivate static let pairedPhoneWorkoutChanged = Notification.Name("pairedPhoneWorkoutChanged")
}

private final class KidsWatchConnectivityDelegate: NSObject, WCSessionDelegate {
  static let shared = KidsWatchConnectivityDelegate()

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  var currentPhoneContext: [String: Any] {
    let session = WCSession.default
    guard session.activationState == .activated else { return [:] }
    var context = session.receivedApplicationContext
    if session.isCompanionAppInstalled {
      context["source"] = "pairedPhone"
    }
    return context
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated, error == nil else {
      if let error {
        NSLog("Unable to activate paired iPhone workout sync: %@", error.localizedDescription)
      }
      return
    }
    publishCurrentPhoneContext()
  }

  func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
    guard session.activationState == .activated else { return }
    publishCurrentPhoneContext()
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any])
  {
    NotificationCenter.default.post(
      name: .pairedPhoneWorkoutChanged, object: applicationContext)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    NotificationCenter.default.post(
      name: .pairedPhoneWorkoutChanged, object: message)
  }

  func completeSetForEveryone(sessionID: UUID, exerciseID: UUID, setNumber: Int) -> Bool {
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else { return false }
    session.sendMessage(
      [
        "command": "completeSetForEveryone",
        "sessionID": sessionID.uuidString,
        "exerciseID": exerciseID.uuidString,
        "setNumber": setNumber,
      ], replyHandler: nil
    ) { error in
      NSLog("Unable to complete Watch workout set: %@", error.localizedDescription)
    }
    return true
  }

  private func publishCurrentPhoneContext() {
    NotificationCenter.default.post(
      name: .pairedPhoneWorkoutChanged, object: currentPhoneContext)
  }
}

@MainActor
final class KidsWatchModel: ObservableObject {
  private let cachedSnapshotKey = "kidsWatchLastSharedSnapshot"
  private let cachedProgressKey = "kidsWatchLastProgressSnapshot"
  @Published private(set) var snapshot: KidsWatchSnapshot?
  @Published private(set) var progressSnapshot: KidsWatchProgressSnapshot?
  @Published private(set) var isOffline = false
  @Published private(set) var lastFetchAt: Date?
  @Published private(set) var isUsingPairedPhone = false

  init() {
    if let data = UserDefaults.standard.data(forKey: cachedSnapshotKey) {
      snapshot = try? JSONDecoder().decode(KidsWatchSnapshot.self, from: data)
      progressSnapshot = snapshot.map {
        KidsWatchProgressSnapshot(
          updatedAt: $0.updatedAt,
          progress: $0.progress ?? [],
          recentWorkouts: $0.recentWorkouts ?? [])
      }
      isOffline = snapshot != nil
    }
    if let data = UserDefaults.standard.data(forKey: cachedProgressKey) {
      progressSnapshot = try? JSONDecoder().decode(KidsWatchProgressSnapshot.self, from: data)
      isOffline = isOffline || progressSnapshot != nil
    }
  }

  func refresh() async {
    guard !isUsingPairedPhone else { return }
    do {
      let query = CKQuery(
        recordType: "KidsWatchCurrentExercise", predicate: NSPredicate(value: true))
      let sharedDatabase = CKContainer(identifier: "iCloud.com.cseibert.StrengthLog")
        .sharedCloudDatabase
      let zones = try await sharedDatabase.allRecordZones()
      var records: [CKRecord] = []
      for zone in zones where zone.zoneID.zoneName != CKRecordZone.default().zoneID.zoneName {
        let (matches, _) = try await sharedDatabase.records(
          matching: query,
          inZoneWith: zone.zoneID,
          desiredKeys: nil,
          resultsLimit: 50)
        records.append(contentsOf: matches.compactMap { try? $0.1.get() })
      }
      guard !isUsingPairedPhone else { return }
      let newest =
        records
        .filter {
          $0["personID"] != nil && ($0["payload"] != nil || $0["progressPayload"] != nil)
        }
        .sorted {
          ($0["updatedAt"] as? Date ?? .distantPast)
            > ($1["updatedAt"] as? Date ?? .distantPast)
        }
      if let data = newest.first?["payload"] as? Data,
        let latestSnapshot = try? JSONDecoder().decode(KidsWatchSnapshot.self, from: data),
        !latestSnapshot.participants.isEmpty
      {
        snapshot = latestSnapshot
        progressSnapshot = KidsWatchProgressSnapshot(
          updatedAt: latestSnapshot.updatedAt,
          progress: latestSnapshot.progress ?? [],
          recentWorkouts: latestSnapshot.recentWorkouts ?? [])
        UserDefaults.standard.set(data, forKey: cachedSnapshotKey)
        if let progressData = try? JSONEncoder().encode(progressSnapshot) {
          UserDefaults.standard.set(progressData, forKey: cachedProgressKey)
        }
      } else if let data = newest.first?["progressPayload"] as? Data,
        let progress = try? JSONDecoder().decode(KidsWatchProgressSnapshot.self, from: data)
      {
        snapshot = nil
        progressSnapshot = progress
        UserDefaults.standard.set(data, forKey: cachedProgressKey)
        UserDefaults.standard.removeObject(forKey: cachedSnapshotKey)
      } else {
        snapshot = nil
        progressSnapshot = nil
        UserDefaults.standard.removeObject(forKey: cachedProgressKey)
        UserDefaults.standard.removeObject(forKey: cachedSnapshotKey)
      }
      isOffline = false
      lastFetchAt = .now
    } catch {
      isOffline = true
      let cloudError = error as NSError
      NSLog(
        "KidsWatch shared workout refresh failed (domain=%@ code=%ld)",
        cloudError.domain, cloudError.code)
    }
  }

  func applyPairedPhoneContext(_ context: [String: Any]) {
    guard context["command"] as? String != "completeSetForEveryone" else { return }
    guard context["source"] as? String == "pairedPhone" else { return }
    isUsingPairedPhone = true
    if let data = context["snapshot"] as? Data,
      let latestSnapshot = try? JSONDecoder().decode(KidsWatchSnapshot.self, from: data)
    {
      snapshot = latestSnapshot
      progressSnapshot = KidsWatchProgressSnapshot(
        updatedAt: latestSnapshot.updatedAt,
        progress: latestSnapshot.progress ?? [],
        recentWorkouts: latestSnapshot.recentWorkouts ?? [])
      UserDefaults.standard.set(data, forKey: cachedSnapshotKey)
      if let progressData = try? JSONEncoder().encode(progressSnapshot) {
        UserDefaults.standard.set(progressData, forKey: cachedProgressKey)
      }
    } else {
      snapshot = nil
      UserDefaults.standard.removeObject(forKey: cachedSnapshotKey)
      if let data = context["progress"] as? Data {
        progressSnapshot = try? JSONDecoder().decode(KidsWatchProgressSnapshot.self, from: data)
        UserDefaults.standard.set(data, forKey: cachedProgressKey)
      } else {
        progressSnapshot = nil
        UserDefaults.standard.removeObject(forKey: cachedProgressKey)
      }
    }
    isOffline = false
    lastFetchAt = .now
  }

  func completeSetForEveryone(setNumber: Int) {
    guard isUsingPairedPhone, var snapshot, setNumber > 0,
      KidsWatchConnectivityDelegate.shared.completeSetForEveryone(
        sessionID: snapshot.sessionID,
        exerciseID: snapshot.exerciseID,
        setNumber: setNumber)
    else { return }

    for participantIndex in snapshot.participants.indices {
      guard
        let setIndex = snapshot.participants[participantIndex].sets.firstIndex(where: {
          $0.number == setNumber && !$0.isSkipped
        })
      else { continue }
      snapshot.participants[participantIndex].sets[setIndex].isCompleted = true
    }
    self.snapshot = snapshot
    if let data = try? JSONEncoder().encode(snapshot) {
      UserDefaults.standard.set(data, forKey: cachedSnapshotKey)
    }
  }

  func canCompleteSetForEveryone(setNumber: Int) -> Bool {
    snapshot?.participants.contains { participant in
      participant.sets.contains {
        $0.number == setNumber && !$0.isSkipped && !$0.isCompleted
      }
    } ?? false
  }
}

private struct KidsWatchHomeView: View {
  @EnvironmentObject private var model: KidsWatchModel

  var body: some View {
    Group {
      if let snapshot = model.snapshot, !snapshot.participants.isEmpty {
        TabView {
          ForEach(snapshot.participants) { participant in
            ParticipantExerciseCard(snapshot: snapshot, participant: participant)
          }
          ProgressSummaryScreen(
            progress: snapshot.progress ?? [],
            recentWorkouts: snapshot.recentWorkouts ?? [])
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
      } else if let progress = model.progressSnapshot {
        ProgressSummaryScreen(
          progress: progress.progress,
          recentWorkouts: progress.recentWorkouts
        )
        .accessibilityIdentifier("kids-watch-progress-summary")
      } else if model.isOffline {
        ContentUnavailableView(
          "Workout unavailable",
          systemImage: "wifi.slash",
          description: Text("Open the app when connected to refresh the shared workout."))
      } else if model.isUsingPairedPhone {
        ContentUnavailableView(
          "No active workout",
          systemImage: "figure.strengthtraining.traditional",
          description: Text("Start a workout on your iPhone to see its current exercise here."))
      } else {
        ContentUnavailableView(
          "Waiting for a shared workout",
          systemImage: "figure.strengthtraining.traditional",
          description: Text(
            "Accept the invite on a device signed in to this Apple Account, then refresh here."))
      }
    }
    .accessibilityIdentifier("kids-watch-current-exercise")
  }
}

private struct ProgressSummaryScreen: View {
  let progress: [KidsWatchSnapshot.PersonProgress]
  let recentWorkouts: [KidsWatchSnapshot.WorkoutHistory]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Label("My Progress", systemImage: "chart.xyaxis.line")
          .font(.headline)
        Text("Training volume · 12 weeks")
          .font(.caption2)
          .foregroundStyle(.secondary)

        if progress.contains(where: { $0.weeklyVolume.contains(where: { $0.volume > 0 }) }) {
          Chart {
            ForEach(progress) { person in
              ForEach(person.weeklyVolume) { point in
                LineMark(
                  x: .value("Week", point.weekStart),
                  y: .value("Volume", point.volume),
                  series: .value("Person", person.name)
                )
                .foregroundStyle(Color(kidsWatchHex: person.colorHex))
                .interpolationMethod(.catmullRom)
                PointMark(
                  x: .value("Week", point.weekStart),
                  y: .value("Volume", point.volume)
                )
                .foregroundStyle(Color(kidsWatchHex: person.colorHex))
              }
            }
          }
          .chartXAxis(.hidden)
          .chartYAxis(.hidden)
          .chartLegend(position: .bottom, alignment: .leading)
          .frame(height: 78)
          .accessibilityLabel("Training volume for the last 12 weeks")
        } else {
          Text("Complete weighted sets to start your graph.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(height: 48, alignment: .leading)
        }

        Divider()
        Text("Recent workouts")
          .font(.subheadline.weight(.semibold))
        if recentWorkouts.isEmpty {
          Text("No workout history yet.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        } else {
          ForEach(recentWorkouts.prefix(3)) { workout in
            VStack(alignment: .leading, spacing: 2) {
              Text(workout.routineName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
              HStack(alignment: .firstTextBaseline) {
                Text(workout.startedAt.formatted(.dateTime.month(.abbreviated).day()))
                Spacer(minLength: 3)
                Text(
                  workout.participants.map {
                    "\($0.name.prefix(1)) \($0.completedSets)/\($0.totalSets)"
                  }.joined(separator: " · ")
                )
                .lineLimit(1)
              }
              .font(.caption2.monospacedDigit())
              .foregroundStyle(.secondary)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 4)
    }
    .accessibilityIdentifier("kids-watch-progress-summary")
  }
}

private struct ParticipantExerciseCard: View {
  @EnvironmentObject private var model: KidsWatchModel
  let snapshot: KidsWatchSnapshot
  let participant: KidsWatchSnapshot.ParticipantCard

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text(snapshot.exerciseName)
          .font(.headline)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
        HStack(spacing: 8) {
          Text(String(participant.name.prefix(1)).uppercased())
            .font(.headline.weight(.bold))
            .foregroundStyle(participantColor)
            .frame(width: 30, height: 30)
            .background(participantColor.opacity(0.18), in: Circle())
            .overlay(Circle().stroke(participantColor.opacity(0.7), lineWidth: 1.5))
            .accessibilityLabel(participant.name)
          Text(exerciseValue)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(participantColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        if let endDate = snapshot.exerciseTimerEndDate {
          if endDate > .now {
            Text(timerInterval: Date.now...endDate, countsDown: true)
              .font(.title3.monospacedDigit().weight(.bold))
              .foregroundStyle(participantColor)
              .accessibilityLabel("Exercise timer")
          } else {
            Label("Timer finished", systemImage: "timer")
              .font(.caption.weight(.semibold))
              .foregroundStyle(participantColor)
          }
        }
        ForEach(participant.sets) { set in
          Button {
            model.completeSetForEveryone(setNumber: set.number)
          } label: {
            HStack(spacing: 5) {
              Image(
                systemName: set.isSkipped
                  ? "forward.fill" : (set.isCompleted ? "checkmark.circle.fill" : "circle")
              )
              .foregroundStyle(set.isCompleted && !set.isSkipped ? Color.green : participantColor)
              Text("Set \(set.number)")
              Spacer(minLength: 2)
              Text(setValue(set))
                .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(
            set.isSkipped || !model.isUsingPairedPhone
              || !model.canCompleteSetForEveryone(setNumber: set.number)
          )
          .accessibilityLabel("Complete set \(set.number) for everyone, \(setValue(set))")
          .accessibilityHint("Updates every participant on this exercise")
          .accessibilityIdentifier("watch-complete-set-\(set.number)-for-everyone")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 4)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("participant-card-\(participant.id.uuidString)")
  }

  private var participantColor: Color {
    Color(kidsWatchHex: participant.colorHex ?? "FF5A45")
  }

  private var exerciseValue: String {
    let unit = unitLabel(snapshot.unit)
    if participant.measurement > 0 {
      let load = participant.measurement.formatted(.number.precision(.fractionLength(0...1)))
      return "\(load) \(unit)\(snapshot.usesPerDumbbellLoad ? " per dumbbell" : "")"
    }
    return "\(unit.capitalized) exercise"
  }

  private func unitLabel(_ rawValue: String) -> String {
    switch rawValue {
    case "pounds": "lb"
    case "kilograms": "kg"
    case "repetitions": "reps"
    case "seconds": "sec"
    case "minutes": "min"
    case "miles": "mi"
    case "kilometers": "km"
    case "meters": "m"
    case "steps": "steps"
    default: rawValue
    }
  }

  private func setValue(_ set: KidsWatchSnapshot.SetProgress) -> String {
    if let duration = set.durationSeconds {
      if snapshot.unit == "minutes" {
        return "\((duration / 60).formatted(.number.precision(.fractionLength(0...1)))) min"
      }
      return "\(Int(duration.rounded())) sec"
    }
    if let distance = set.distanceMiles {
      switch snapshot.unit {
      case "kilometers":
        return "\((distance * 1.609344).formatted(.number.precision(.fractionLength(0...2)))) km"
      case "meters":
        return "\((distance * 1609.344).formatted(.number.precision(.fractionLength(0...0)))) m"
      default:
        return "\(distance.formatted(.number.precision(.fractionLength(0...2)))) mi"
      }
    }
    let value = set.measurement ?? participant.measurement
    if value > 0 {
      let load = value.formatted(.number.precision(.fractionLength(0...1)))
      return "\(load) \(unitLabel(snapshot.unit)) × \(set.target)"
    }
    return "\(set.target) \(set.target == 1 ? "rep" : "reps")"
  }
}

extension Color {
  fileprivate init(kidsWatchHex: String) {
    let value = UInt64(kidsWatchHex, radix: 16) ?? 0xFF5A45
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      opacity: 1)
  }
}
