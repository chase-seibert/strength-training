#if DEBUG
  import QuartzCore
  import SwiftData
  import SwiftUI
  import UIKit
  import os.signpost

  // Opt-in diagnostics for disposable simulator fixtures; no production data or telemetry.
  @MainActor
  final class WorkoutPerformanceProbe: NSObject, ObservableObject {
    static let shared = WorkoutPerformanceProbe()
    static let enabled = ProcessInfo.processInfo.arguments.contains("-workoutPerformanceProbe")
    static let log = OSLog(subsystem: "com.cseibert.StrengthLog.performance", category: "Workout")
    @Published var status = "ready"
    private var action: [String: Any]?
    private var beganAt = 0.0
    private var targets: Set<UUID> = []
    private var observed: Set<UUID> = []
    private var link: CADisplayLink?
    private var frameWait = 0
    private weak var window: UIWindow?
    private var scrollStart: Double?
    private var lastFrame: Double?
    private var intervals: [Double] = []
    private var expectedIntervals: [Double] = []
    private weak var scrollingView: UIScrollView?
    private var motionIntervals: [Double] = []
    private var motionExpectedIntervals: [Double] = []
    private var wasMoving = false
    private var sequence = 0
    let origin = CACurrentMediaTime()
    let launchToken = UInt32.random(in: 1...UInt32.max)
    private(set) var actionElapsedMilliseconds: UInt32 = 0
    private(set) var actionSequence: UInt32 = 0
    weak var opticalView: UIView?
    private var targetRects: [String: [Double]] = [:]
    var fixture: [String: Any] = [:]

    private var directory: URL {
      let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("WorkoutPerformance", isDirectory: true)
      try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      return url
    }

    func begin(_ kind: String, completing: Bool = true) {
      guard Self.enabled else { return }
      sequence += 1
      beganAt = CACurrentMediaTime()
      actionElapsedMilliseconds = UInt32((beganAt - origin) * 1_000)
      actionSequence = UInt32(sequence)
      targetRects = [:]
      targets = []
      observed = []
      frameWait = 0
      action = [
        "type": "completion", "kind": kind, "completing": completing,
        "sequence": sequence, "action_uptime_s": beganAt, "phases_ms": [String: Double](),
      ]
      os_signpost(.begin, log: Self.log, name: "SetCompletion")
    }

    func expect(_ set: WorkoutSet) {
      guard Self.enabled else { return }
      targets.insert(set.id)
    }

    func phase<T>(_ name: String, _ work: () throws -> T) rethrows -> T {
      let start = CACurrentMediaTime()
      let result = try work()
      if Self.enabled, action != nil {
        var phases = action?["phases_ms"] as? [String: Double] ?? [:]
        phases[name, default: 0] += (CACurrentMediaTime() - start) * 1_000
        action?["phases_ms"] = phases
      }
      return result
    }

    func recordPhase(_ name: String, since start: Double) {
      guard Self.enabled, action != nil else { return }
      var phases = action?["phases_ms"] as? [String: Double] ?? [:]
      phases[name, default: 0] += (CACurrentMediaTime() - start) * 1_000
      action?["phases_ms"] = phases
    }

    func willSave(_ context: ModelContext) {
      guard Self.enabled, action != nil else { return }
      var saves = action?["saves"] as? [[String: Any]] ?? []
      saves.append([
        "changed_models": context.changedModelsArray.count,
        "inserted_models": context.insertedModelsArray.count,
        "deleted_models": context.deletedModelsArray.count,
      ])
      action?["saves"] = saves
    }

    func handlerFinished() {
      guard Self.enabled, action != nil else { return }
      action?["handler_ms"] = (CACurrentMediaTime() - beganAt) * 1_000
      action?["changed_set_count"] = targets.count
      os_signpost(.end, log: Self.log, name: "SetCompletion")
    }

    func viewUpdated(setID: UUID, view: UIView) {
      guard Self.enabled, action != nil, targets.contains(setID) else { return }
      guard let window = view.window else { return }
      let rect = view.convert(view.bounds, to: window)
      targetRects[setID.uuidString] = [rect.minX, rect.minY, rect.width, rect.height]
      observed.insert(setID)
      guard observed == targets, link == nil else { return }
      self.window = window
      action?["view_update_ms"] = (CACurrentMediaTime() - beganAt) * 1_000
      let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
      link.add(to: .main, forMode: .common)
      self.link = link
    }

    @objc private func frame(_ displayLink: CADisplayLink) {
      if let scrollStart {
        let moving = scrollingView?.isDragging == true || scrollingView?.isDecelerating == true
        if let lastFrame {
          let interval = displayLink.timestamp - lastFrame
          let expected = displayLink.targetTimestamp - displayLink.timestamp
          intervals.append(interval)
          expectedIntervals.append(expected)
          if wasMoving {
            motionIntervals.append(interval)
            motionExpectedIntervals.append(expected)
          }
        }
        wasMoving = moving
        lastFrame = displayLink.timestamp
        _ = scrollStart
        return
      }
      guard action != nil else {
        stopLink()
        return
      }
      frameWait += 1
      if frameWait == 1 {
        action?["next_frame_callback_ms"] = (CACurrentMediaTime() - beganAt) * 1_000
      }
      // Allow a full transaction to commit, then capture the actual rendered window.
      // This is an upper bound for rendered content, not a GPU presentation timestamp.
      guard frameWait >= 2, let window else { return }
      if !ProcessInfo.processInfo.arguments.contains("-workoutPerformanceSnapshots") {
        action?["render_checkpoint_succeeded"] = true
        action?["observed_set_count"] = observed.count
        action?["second_frame_callback_ms"] = (CACurrentMediaTime() - beganAt) * 1_000
        if let action { append(action) }
        self.action = nil
        status = "captured \(sequence)"
        stopLink()
        return
      }
      let captureStart = CACurrentMediaTime()
      let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
      var drew = false
      let image = renderer.image { _ in
        drew = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
      }
      action?["rendered_snapshot_ms"] = (CACurrentMediaTime() - beganAt) * 1_000
      action?["snapshot_capture_ms"] = (CACurrentMediaTime() - captureStart) * 1_000
      action?["snapshot_succeeded"] = drew
      action?["observed_set_count"] = observed.count
      let filename = "completion-\(UUID().uuidString).png"
      if drew, let bytes = image.pngData() {
        try? bytes.write(to: directory.appendingPathComponent(filename))
        action?["snapshot"] = filename
      }
      if let action { append(action) }
      self.action = nil
      status = "captured \(sequence)"
      stopLink()
    }

    func startScroll() {
      guard Self.enabled else { return }
      stopLink()
      action = nil
      func verticalScrollView(in view: UIView) -> UIScrollView? {
        guard !view.isHidden, view.alpha > 0.01 else { return nil }
        if let scroll = view as? UIScrollView, scroll.isScrollEnabled,
          scroll.contentSize.height > scroll.bounds.height
        {
          return scroll
        }
        for child in view.subviews {
          if let found = verticalScrollView(in: child) { return found }
        }
        return nil
      }
      scrollingView = opticalView?.window.flatMap { verticalScrollView(in: $0) }
      scrollStart = CACurrentMediaTime()
      motionIntervals = []
      motionExpectedIntervals = []
      wasMoving = false
      lastFrame = nil
      intervals = []
      expectedIntervals = []
      let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
      link.add(to: .main, forMode: .common)
      self.link = link
      status = "scrolling"
    }

    func endScroll() {
      guard let scrollStart else { return }
      let elapsed = CACurrentMediaTime() - scrollStart
      let hitchDurations = zip(intervals, expectedIntervals).compactMap { actual, expected in
        actual > expected * 1.5 ? max(0, actual - expected) : nil
      }
      let motionDuration = motionIntervals.reduce(0, +)
      let motionHitches = zip(motionIntervals, motionExpectedIntervals).compactMap {
        actual, expected in
        actual > expected * 1.5 ? max(0, actual - expected) : nil
      }
      append([
        "type": "scroll", "duration_s": elapsed,
        "scroll_view_found": scrollingView != nil,
        "motion_duration_s": motionDuration,
        "motion_callback_fps": Double(motionIntervals.count) / max(motionDuration, 0.001),
        "motion_callback_hitch_count": motionHitches.count,
        "motion_callback_hitch_ratio_ms_per_s": motionHitches.reduce(0, +) * 1_000
          / max(motionDuration, 0.001),
        "motion_callback_worst_ms": (motionIntervals.max() ?? 0) * 1_000,
        "motion_intervals_ms": motionIntervals.map { $0 * 1_000 },
        "callback_fps": Double(intervals.count) / max(intervals.reduce(0, +), 0.001),
        "callback_hitch_count": hitchDurations.count,
        "callback_hitch_ratio_ms_per_s": hitchDurations.reduce(0, +) * 1_000 / elapsed,
        "callback_worst_ms": (intervals.max() ?? 0) * 1_000,
        "frame_intervals_ms": intervals.map { $0 * 1_000 },
        "expected_intervals_ms": expectedIntervals.map { $0 * 1_000 },
      ])
      self.scrollStart = nil
      status = "scroll captured"
      stopLink()
    }

    func cancel() {
      stopLink()
      action = nil
      scrollStart = nil
      scrollingView = nil
      window = nil
    }

    private func stopLink() {
      link?.invalidate()
      link = nil
    }

    private func append(_ values: [String: Any]) {
      var record = values
      let arguments = ProcessInfo.processInfo.arguments
      record["timestamp"] = ISO8601DateFormatter().string(from: .now)
      record["schema_version"] = 2
      record["launch_token"] = launchToken
      record["action_elapsed_ms"] = actionElapsedMilliseconds
      record["target_rects"] = targetRects
      if let view = opticalView, let window = view.window {
        let rect = view.convert(view.bounds, to: window)
        record["optical_rect"] = [rect.minX, rect.minY, rect.width, rect.height]
        record["window_size"] = [window.bounds.width, window.bounds.height]
      }
      record["arguments"] = arguments
      record["fixture"] = fixture
      record["store"] = arguments.contains("-diskWorkoutPerformanceFixture") ? "sqlite" : "memory"
      record["timer"] = "rest-countdown-and-workout-elapsed"
      record["scenario"] =
        ProcessInfo.processInfo.environment["WORKOUT_PROFILE_SCENARIO"] ?? "unknown"
      guard var data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
      else { return }
      data.append(0x0a)
      let url = directory.appendingPathComponent("samples.jsonl")
      if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
      }
      if let file = try? FileHandle(forWritingTo: url) {
        defer { try? file.close() }
        try? file.seekToEnd()
        try? file.write(contentsOf: data)
      }
    }
  }

  // Binary optical clock travels in the same simulator video frames as the set badges.
  // Decoder reads device-relative milliseconds, eliminating host/video-start alignment error.
  final class WorkoutOpticalClockView: UIView {
    private var link: CADisplayLink?
    private var milliseconds: UInt32 = 0
    override func didMoveToWindow() {
      super.didMoveToWindow()
      link?.invalidate()
      link = nil
      guard window != nil else { return }
      WorkoutPerformanceProbe.shared.opticalView = self
      let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
      link.add(to: .main, forMode: .common)
      self.link = link
    }
    @objc private func tick(_ link: CADisplayLink) {
      milliseconds = UInt32(max(0, link.timestamp - WorkoutPerformanceProbe.shared.origin) * 1_000)
      setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
      guard let context = UIGraphicsGetCurrentContext() else { return }
      let probe = WorkoutPerformanceProbe.shared
      let words: [UInt32] = [
        0xA55A_5AA5, probe.launchToken, probe.actionSequence,
        probe.actionElapsedMilliseconds, milliseconds,
      ]
      for (row, word) in words.enumerated() {
        for column in 0..<32 {
          context.setFillColor(
            ((word >> (31 - column)) & 1) == 1
              ? UIColor.white.cgColor : UIColor.black.cgColor)
          context.fill(CGRect(x: column * 8, y: row * 6, width: 8, height: 6))
        }
      }
    }
  }

  struct WorkoutOpticalClock: UIViewRepresentable {
    func makeUIView(context: Context) -> WorkoutOpticalClockView {
      let view = WorkoutOpticalClockView()
      view.isUserInteractionEnabled = false
      view.isAccessibilityElement = false
      return view
    }
    func updateUIView(_ view: WorkoutOpticalClockView, context: Context) {}
  }

  struct CompletionRenderObserver: UIViewRepresentable {
    let setID: UUID
    let completed: Bool
    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.isUserInteractionEnabled = false
      return view
    }
    func updateUIView(_ view: UIView, context: Context) {
      // Reading completed makes this observer participate in the same state update as the badge.
      _ = completed
      WorkoutPerformanceProbe.shared.viewUpdated(setID: setID, view: view)
    }
  }

  struct WorkoutPerformanceControls: View {
    @ObservedObject private var probe = WorkoutPerformanceProbe.shared
    var body: some View {
      HStack {
        Button("Profile scroll") { probe.startScroll() }
          .accessibilityIdentifier("profile-scroll-start")
        Button("End profile") { probe.endScroll() }
          .accessibilityIdentifier("profile-scroll-end")
        Text(probe.status).accessibilityIdentifier("profile-status")
      }
      .font(.system(size: 9))
      .padding(4)
      .background(.ultraThinMaterial)
    }
  }

#endif
