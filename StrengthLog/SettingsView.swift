import CloudKit
import HealthKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(\.modelContext) private var context
  @Environment(HevyImportCoordinator.self) private var importCoordinator
  @Query(sort: \PersonProfile.sortOrder) private var people: [PersonProfile]
  @AppStorage(WorkoutPreferences.defaultSetsKey) private var defaultWorkoutSets =
    WorkoutPreferences.fallbackSets
  @AppStorage(WorkoutPreferences.defaultRepsKey) private var defaultWorkoutReps =
    WorkoutPreferences.fallbackReps
  @AppStorage(WorkoutPreferences.restTimerNotificationsEnabledKey)
  private var restTimerNotificationsEnabled = false
  @AppStorage(HealthKitWorkoutRecorder.recordingEnabledKey)
  private var healthKitWorkoutRecordingEnabled = false
  @AppStorage("liftCoachProvider") private var liftCoachProvider = LiftCoachProvider.deterministic
    .rawValue
  @AppStorage("liftCoachOpenAIConsent") private var liftCoachOpenAIConsent = false
  @AppStorage(WeeklyCoachingNotificationCoordinator.enabledKey) private
    var weeklyCoachReminderEnabled = false
  @AppStorage(WeeklyCoachingNotificationCoordinator.weekdayKey) private
    var weeklyCoachReminderWeekday = 2
  @AppStorage(WeeklyCoachingNotificationCoordinator.hourKey) private var weeklyCoachReminderHour = 9
  @AppStorage(WeeklyCoachingNotificationCoordinator.minuteKey) private
    var weeklyCoachReminderMinute = 0
  @State private var showingNewPerson = false
  @State private var showingHevyImporter = false
  @State private var isRequestingHealthAuthorization = false
  @State private var healthAuthorizationMessage: String?
  @State private var openAIKeyInput = ""
  @State private var liftCoachSettingsMessage: String?

  var body: some View {
    List {
      Section {
        ForEach(PersonProfile.ordered(people.filter { !$0.isArchived })) { person in
          NavigationLink {
            PersonEditor(person: person)
          } label: {
            HStack(spacing: 12) {
              InitialBadge(name: person.name, colorHex: person.colorHex, size: 38)
              Text(person.name).font(.headline)
            }
            .padding(.vertical, 3)
          }
        }
        Button("Add person", systemImage: "person.badge.plus") { showingNewPerson = true }
      } header: {
        Text("People")
      } footer: {
        Text(
          "Choose who appears each time you start a routine. Names on past sessions stay unchanged."
        )
      }

      Section {
        Picker("Coaching provider", selection: $liftCoachProvider) {
          ForEach(LiftCoachProvider.allCases) { provider in
            Text(provider.title).tag(provider.rawValue)
          }
        }
        .accessibilityIdentifier("lift-coach-provider-picker")
        if liftCoachProvider == LiftCoachProvider.openAI.rawValue {
          SecureField("OpenAI API key", text: $openAIKeyInput)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          HStack {
            Button("Save key") { saveLiftCoachKey() }.disabled(
              openAIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if LiftCoachKeychain.read() != nil {
              Button("Remove key", role: .destructive) {
                LiftCoachKeychain.remove()
                liftCoachSettingsMessage = "Saved key removed from this device."
              }
            }
          }
          Toggle("Allow OpenAI to receive coaching context", isOn: $liftCoachOpenAIConsent)
          Text(
            "When you generate a report, the app sends weekly workout totals plus routine and exercise names. It excludes participant names and private notes. Review the provider’s data policies before enabling."
          )
          .font(.footnote).foregroundStyle(.secondary)
        }
        if let liftCoachSettingsMessage {
          Text(liftCoachSettingsMessage).font(.footnote).foregroundStyle(.secondary)
        }
      } header: {
        Text("Lift Coach")
      } footer: {
        Text(
          "Facts are calculated on this device. On-device model support requires iOS 26 and an available Apple Intelligence model. OpenAI is optional and uses the key stored in Keychain."
        )
      }

      Section {
        Toggle(
          "Weekly Progress reminder",
          isOn: Binding(
            get: { weeklyCoachReminderEnabled },
            set: { enabled in
              Task {
                do { try await WeeklyCoachingNotificationCoordinator.setEnabled(enabled) } catch {
                  liftCoachSettingsMessage =
                    "Couldn’t schedule the reminder: \(error.localizedDescription)"
                }
              }
            }))
        if weeklyCoachReminderEnabled {
          Picker("Day", selection: $weeklyCoachReminderWeekday) {
            ForEach(1...7, id: \.self) { weekday in
              Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
            }
          }
          DatePicker(
            "Time",
            selection: Binding(
              get: {
                Calendar.current.date(
                  from: DateComponents(
                    hour: weeklyCoachReminderHour, minute: weeklyCoachReminderMinute)) ?? .now
              },
              set: {
                weeklyCoachReminderHour = Calendar.current.component(.hour, from: $0)
                weeklyCoachReminderMinute = Calendar.current.component(.minute, from: $0)
                Task { try? await WeeklyCoachingNotificationCoordinator.schedule() }
              }
            ), displayedComponents: .hourAndMinute)
        }
        Button("Open Progress") {
          NotificationCenter.default.post(name: .openWeeklyCoachingReport, object: nil)
        }
      } header: {
        Text("Weekly report")
      } footer: {
        Text(
          "The reminder opens Progress at your weekly report. If notifications are denied, enable them for Lift Chase in iOS Settings."
        )
      }

      if people.contains(where: \.isArchived) {
        Section("Archived") {
          ForEach(PersonProfile.ordered(people.filter(\.isArchived))) { person in
            Button {
              person.isArchived = false
            } label: {
              LabeledContent(person.name, value: "Restore")
            }
          }
        }
      }

      Section {
        Stepper(value: $defaultWorkoutSets, in: 1...12) {
          LabeledContent("Default sets", value: "\(defaultWorkoutSets)")
        }
        Stepper(value: $defaultWorkoutReps, in: 1...30) {
          LabeledContent("Default reps", value: "\(defaultWorkoutReps)")
        }
        Toggle("Rest timer notifications", isOn: $restTimerNotificationsEnabled)
      } header: {
        Text("Workouts")
      } footer: {
        Text(
          "Used for new exercises and for people without completed-set history. When enabled, Lift Chase can notify you when a rest timer ends."
        )
      }

      Section {
        Toggle(
          "Record Workouts in Apple Health",
          isOn: Binding(
            get: { healthKitWorkoutRecordingEnabled },
            set: setHealthKitWorkoutRecordingEnabled
          )
        )
        .accessibilityIdentifier("apple-health-workout-export-toggle")
        .disabled(
          isRequestingHealthAuthorization || !HealthKitWorkoutRecorder.isHealthDataAvailable)

        if isRequestingHealthAuthorization {
          SwiftUI.ProgressView("Requesting Health access…")
        } else if let healthAuthorizationMessage {
          Text(healthAuthorizationMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else if !HealthKitWorkoutRecorder.isHealthDataAvailable {
          Text("Apple Health is unavailable on this device.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Apple Health")
      } footer: {
        Text(
          "When enabled, completed workouts with at least one completed set can be saved to Apple Health. Lift Chase only writes workout records and does not read Health data. Turn this off to stop future workout exports."
        )
      }

      Section("Data") {
        Button("Import Hevy CSV", systemImage: "square.and.arrow.down") {
          showingHevyImporter = true
        }
      }

      Section("About") {
        LabeledContent("Catalog", value: "Free Exercise DB")
        LabeledContent("Exercises", value: "\(exerciseCount)")
        NavigationLink("Data source notes") { ResearchSummaryView() }
      }

      #if DEBUG
        Section("Developer") {
          NavigationLink {
            DeveloperMenuView()
          } label: {
            Label("Developer Menu", systemImage: "hammer.fill")
          }
        }
      #endif
    }
    .navigationTitle("Settings")
    .onAppear {
      refreshHealthAuthorizationMessage()
      if weeklyCoachReminderEnabled {
        Task { try? await WeeklyCoachingNotificationCoordinator.schedule() }
      }
    }
    .sheet(isPresented: $showingNewPerson) { NewPersonSheet() }
    .fileImporter(
      isPresented: $showingHevyImporter,
      allowedContentTypes: [.commaSeparatedText],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first { importCoordinator.open(url) }
      case .failure(let error):
        importCoordinator.notice = HevyImportNotice(
          title: "Couldn’t Open CSV", message: error.localizedDescription)
      }
    }
  }

  private var exerciseCount: Int {
    let descriptor = FetchDescriptor<Exercise>(
      predicate: #Predicate<Exercise> { $0.deletedAt == nil })
    return (try? context.fetchCount(descriptor)) ?? 0
  }

  private func setHealthKitWorkoutRecordingEnabled(_ enabled: Bool) {
    guard !isRequestingHealthAuthorization else { return }
    guard enabled else {
      healthKitWorkoutRecordingEnabled = false
      healthAuthorizationMessage = nil
      return
    }

    guard HealthKitWorkoutRecorder.isHealthDataAvailable else {
      healthKitWorkoutRecordingEnabled = false
      healthAuthorizationMessage = "Apple Health is unavailable on this device."
      return
    }

    healthKitWorkoutRecordingEnabled = true
    isRequestingHealthAuthorization = true
    healthAuthorizationMessage = nil
    Task {
      defer { isRequestingHealthAuthorization = false }
      do {
        if try await HealthKitWorkoutRecorder.requestWorkoutWriteAuthorization() {
          healthKitWorkoutRecordingEnabled = true
          healthAuthorizationMessage = "Enabled. Completed workouts can be saved to Apple Health."
        } else {
          healthKitWorkoutRecordingEnabled = false
          healthAuthorizationMessage =
            "Permission wasn’t granted. Allow Lift Chase to add workouts in Apple Health, then turn this on again."
        }
      } catch {
        healthKitWorkoutRecordingEnabled = false
        healthAuthorizationMessage = "Couldn’t request Apple Health access. Try again later."
      }
    }
  }

  private func refreshHealthAuthorizationMessage() {
    guard healthKitWorkoutRecordingEnabled else {
      healthAuthorizationMessage = nil
      return
    }
    if HealthKitWorkoutRecorder.hasWorkoutWriteAuthorization {
      healthAuthorizationMessage = "Enabled. Completed workouts can be saved to Apple Health."
    } else {
      healthAuthorizationMessage =
        "Workout access is off in Apple Health. Allow Lift Chase to add workouts there to resume saving, or turn off recording here."
    }
  }

  private func saveLiftCoachKey() {
    let key = openAIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard LiftCoachKeychain.save(key) else {
      liftCoachSettingsMessage = "Couldn’t save the key to Keychain."
      return
    }
    openAIKeyInput = ""
    liftCoachSettingsMessage = "OpenAI key saved to this device’s Keychain."
  }
}

#if DEBUG
  struct DeveloperMenuView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(DeveloperPreferences.activeWorkoutFrameMonitorEnabledKey)
    private var activeWorkoutFrameMonitorEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var loadHarness = DebugLoadHarness.shared
    @State private var cpuLoadEnabled = false
    @State private var memoryLoadEnabled = false
    @State private var diskLoadEnabled = false
    @State private var celebrationSummary: WorkoutCelebrationSummary?
    @State private var celebrationPreviewMessage: String?

    var body: some View {
      List {
        Section {
          NavigationLink("Preview Progress before coaching") {
            ProgressView(previewMode: .learning)
          }
          .accessibilityIdentifier("developer-preview-progress-learning")
          NavigationLink("Preview generated Lift Coach") { ProgressView(previewMode: .generated) }
            .accessibilityIdentifier("developer-preview-progress-generated")
        } header: {
          Text("Lift Coach previews")
        } footer: {
          Text(
            "Sample screens are read-only and never save reports, call a provider, or request notification permission."
          )
        }

        Section {
          Button("Preview Workout Celebration", systemImage: "party.popper.fill") {
            previewLatestWorkoutCelebration()
          }
          .accessibilityIdentifier("developer-preview-workout-celebration")
        } header: {
          Text("Workout Celebration")
        } footer: {
          Text(
            "Replays the most recently completed workout with confetti. Workout history stays unchanged."
          )
        }

        Section {
          Toggle(
            "Active Workout Frame Monitor",
            isOn: $activeWorkoutFrameMonitorEnabled
          )
          .accessibilityIdentifier("active-workout-frame-monitor-toggle")
        } header: {
          Text("Diagnostics")
        } footer: {
          Text(
            "Shows FPS, hitch count, and worst-frame duration on the active workout and writes one sample per second to the debug console. Leave this off outside a profiling session."
          )
        }

        Section {
          Toggle("CPU load", isOn: $cpuLoadEnabled)
            .accessibilityIdentifier("debug-load-cpu-toggle")
          Toggle("Memory load (64 MiB)", isOn: $memoryLoadEnabled)
            .accessibilityIdentifier("debug-load-memory-toggle")
          Toggle("Temporary-file I/O (up to 4 MiB/s)", isOn: $diskLoadEnabled)
            .accessibilityIdentifier("debug-load-disk-toggle")
          HStack {
            Button("Start 30-second load") {
              loadHarness.start(
                cpu: cpuLoadEnabled,
                memory: memoryLoadEnabled,
                disk: diskLoadEnabled)
            }
            .disabled(!cpuLoadEnabled && !memoryLoadEnabled && !diskLoadEnabled)
            .accessibilityIdentifier("debug-load-start")
            Button("Stop", role: .destructive) {
              loadHarness.stop()
              cpuLoadEnabled = false
              memoryLoadEnabled = false
              diskLoadEnabled = false
            }
            .disabled(!loadHarness.isRunning)
            .accessibilityIdentifier("debug-load-stop")
          }
          Text(loadHarness.isRunning ? "Load is running" : "Load is stopped")
            .accessibilityIdentifier("debug-load-status")
        } header: {
          Text("Bounded Device Load")
        } footer: {
          Text(
            "Debug only. CPU uses one worker at about 40% duty cycle; memory holds 64 MiB; file I/O uses an 8 MiB temporary file at up to 4 MiB/s. Runs stop after 30 seconds, when stopped, when the app backgrounds, or when the active workout closes. File I/O does not guarantee physical flash pressure."
          )
        }

        Section {
          Button("Replay First-Time Experience", systemImage: "arrow.counterclockwise") {
            hasCompletedOnboarding = false
          }
        } header: {
          Text("Onboarding")
        } footer: {
          Text(
            "Shows onboarding again with your existing people and routines filled in. Workout history, exercises, and configuration are preserved."
          )
        }
      }
      .navigationTitle("Developer")
      .navigationBarTitleDisplayMode(.inline)
      .fullScreenCover(item: $celebrationSummary) { summary in
        WorkoutCelebrationView(
          summary: summary,
          onDone: { celebrationSummary = nil },
          doneButtonTitle: "Back to Developer Menu")
      }
      .alert(
        "Workout Celebration",
        isPresented: Binding(
          get: { celebrationPreviewMessage != nil },
          set: { if !$0 { celebrationPreviewMessage = nil } })
      ) {
        Button("OK", role: .cancel) { celebrationPreviewMessage = nil }
      } message: {
        Text(celebrationPreviewMessage ?? "")
      }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active {
          loadHarness.stop()
          cpuLoadEnabled = false
          memoryLoadEnabled = false
          diskLoadEnabled = false
        }
      }
    }

    private func previewLatestWorkoutCelebration() {
      var latest = FetchDescriptor<WorkoutSession>(
        predicate: #Predicate<WorkoutSession> {
          !$0.isActive && $0.deletedAt == nil && $0.endedAt != nil
        },
        sortBy: [SortDescriptor(\WorkoutSession.endedAt, order: .reverse)])
      latest.fetchLimit = 1
      do {
        guard let session = try context.fetch(latest).first else {
          celebrationPreviewMessage = "Complete a workout first to preview its celebration."
          return
        }
        let history = try context.fetch(
          FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.deletedAt == nil }))
        let people = try context.fetch(FetchDescriptor<PersonProfile>())
        let routines = try context.fetch(FetchDescriptor<Routine>())
        let routineName =
          routines.first { $0.id == session.routineID }?.name
          ?? (session.routineName.isEmpty ? "Workout" : session.routineName)
        celebrationSummary = WorkoutCelebrationSummary.make(
          session: session,
          allSessions: history,
          routineName: routineName,
          colorHexByName: Dictionary(uniqueKeysWithValues: people.map { ($0.name, $0.colorHex) }))
      } catch {
        celebrationPreviewMessage = "Couldn’t load workout history. Try again."
      }
    }
  }

  @MainActor
  final class DebugLoadHarness: ObservableObject {
    static let shared = DebugLoadHarness()

    @Published private(set) var isRunning = false
    private var workers: [Task<Void, Never>] = []
    private var timeoutTask: Task<Void, Never>?

    func start(cpu: Bool, memory: Bool, disk: Bool) {
      stop()
      guard cpu || memory || disk else { return }
      isRunning = true
      if cpu {
        workers.append(
          Task.detached(priority: .utility) {
            await runBoundedCPULoad()
          })
      }
      if memory {
        workers.append(
          Task.detached(priority: .utility) {
            await runBoundedMemoryLoad()
          })
      }
      if disk {
        workers.append(
          Task.detached(priority: .utility) {
            await runBoundedDiskLoad()
          })
      }
      timeoutTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(30))
        guard !Task.isCancelled else { return }
        self?.stop()
      }
    }

    func stop() {
      for worker in workers {
        worker.cancel()
      }
      workers.removeAll()
      timeoutTask?.cancel()
      timeoutTask = nil
      isRunning = false
    }
  }

  private func runBoundedCPULoad() async {
    let end = ContinuousClock.now.advanced(by: .seconds(30))
    var value: UInt64 = 0x9E37_79B9_7F4A_7C15
    while !Task.isCancelled && ContinuousClock.now < end {
      let sliceEnd = ContinuousClock.now.advanced(by: .milliseconds(40))
      while !Task.isCancelled && ContinuousClock.now < sliceEnd {
        value = (value &* 2_862_933_555_777_941_757) &+ 3_037_000_493
      }
      try? await Task.sleep(for: .milliseconds(60))
    }
    _ = value
  }

  private func runBoundedMemoryLoad() async {
    var bytes = [UInt8](repeating: 0, count: 64 * 1024 * 1024)
    let end = ContinuousClock.now.advanced(by: .seconds(30))
    while !Task.isCancelled && ContinuousClock.now < end {
      for offset in stride(from: 0, to: bytes.count, by: 4096) {
        bytes[offset] &+= 1
      }
      try? await Task.sleep(for: .milliseconds(250))
    }
    _ = bytes.first
  }

  private func runBoundedDiskLoad() async {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("active-workout-load-\(UUID().uuidString).tmp")
    let chunk = Data(repeating: 0xA5, count: 1024 * 1024)
    do {
      try Data(repeating: 0xA5, count: 8 * 1024 * 1024).write(to: url, options: .atomic)
      let handle = try FileHandle(forUpdating: url)
      defer {
        try? handle.close()
        try? FileManager.default.removeItem(at: url)
      }
      let end = ContinuousClock.now.advanced(by: .seconds(30))
      while !Task.isCancelled && ContinuousClock.now < end {
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: chunk)
        try handle.seek(toOffset: 0)
        _ = try handle.read(upToCount: chunk.count)
        try await Task.sleep(for: .milliseconds(500))
      }
    } catch {
      try? FileManager.default.removeItem(at: url)
      print("DEBUG_ACTIVE_WORKOUT_LOAD disk_error=\(error.localizedDescription)")
    }
  }
#endif

struct PersonEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var person: PersonProfile
  @State private var kidsWatchShare: CKShare?
  @State private var isPreparingKidsWatchShare = false
  @State private var kidsWatchShareError: String?
  private let colors = ["FF5A45", "59A8FA", "45D1A8", "A778F5", "F5B942", "E96BA8"]

  var body: some View {
    Form {
      Section("Profile") {
        TextField("Name", text: $person.name)
        HStack {
          ForEach(colors, id: \.self) { hex in
            Button {
              person.colorHex = hex
            } label: {
              Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                .overlay {
                  if person.colorHex == hex {
                    Image(systemName: "checkmark").foregroundStyle(.white).fontWeight(.bold)
                  }
                }
            }
            .buttonStyle(.plain)
          }
        }
      }
      Section {
        Button {
          prepareKidsWatchShare()
        } label: {
          if isPreparingKidsWatchShare {
            SwiftUI.ProgressView("Preparing link…")
          } else {
            Label("Share with Kids Watch", systemImage: "applewatch")
          }
        }
        .disabled(isPreparingKidsWatchShare)
        Text(
          "Create one private link for \(person.name). Their watch shows this person’s current exercise and set details whenever they’re active in a workout."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      } header: {
        Text("Kids Watch")
      }
      Section {
        Button("Archive person", role: .destructive) {
          person.isArchived = true
          dismiss()
        }
      }
    }
    .navigationTitle(person.name)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(
      isPresented: Binding(
        get: { kidsWatchShare != nil },
        set: { if !$0 { kidsWatchShare = nil } }
      )
    ) {
      if let kidsWatchShare {
        KidsWatchShareSheet(share: kidsWatchShare)
      }
    }
    .alert(
      "Kids Watch Sharing",
      isPresented: Binding(
        get: { kidsWatchShareError != nil },
        set: { if !$0 { kidsWatchShareError = nil } }
      )
    ) {
      Button("OK", role: .cancel) { kidsWatchShareError = nil }
    } message: {
      Text(kidsWatchShareError ?? "")
    }
  }

  private func prepareKidsWatchShare() {
    isPreparingKidsWatchShare = true
    Task {
      defer { isPreparingKidsWatchShare = false }
      do {
        kidsWatchShare = try await KidsWatchCloudStore.share(for: person.id, name: person.name)
      } catch {
        kidsWatchShareError = error.localizedDescription
      }
    }
  }
}

struct NewPersonSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query(sort: \PersonProfile.sortOrder) private var people: [PersonProfile]
  @State private var name = ""

  var body: some View {
    NavigationStack {
      Form { TextField("Name", text: $name) }
        .navigationTitle("Add Person")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
              context.insert(
                PersonProfile(
                  name: name.trimmingCharacters(in: .whitespacesAndNewlines), colorHex: "A778F5",
                  sortOrder: (people.map(\.sortOrder).max() ?? -1) + 1))
              _ = saveAndRefreshProgressWidget(context)
              dismiss()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }
  }
}

struct ResearchSummaryView: View {
  var body: some View {
    List {
      Section("Bundled source") {
        Text(
          "Free Exercise DB provides 800+ public-domain exercises, instructions, muscle and equipment metadata, and two-pose imagery. StrengthLog ships a compact derived catalog and phone-optimized images for fully offline use."
        )
      }
      Section("Why this source") {
        Label("No API key or runtime dependency", systemImage: "key.slash")
        Label("Unlicense / public-domain dedication", systemImage: "checkmark.shield")
        Label("Form instructions and imagery", systemImage: "photo.on.rectangle")
      }
      Section("Production note") {
        Text(
          "Exercise names and form cues should receive a trainer-led safety review before a public launch. The catalog is reference material, not medical advice."
        )
      }
    }
    .navigationTitle("Catalog Notes")
  }
}
