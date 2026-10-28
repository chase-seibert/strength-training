import Compression
import CryptoKit
import Foundation
import Observation

enum AnalyticsAudience: String, Codable, CaseIterable, Sendable {
  case debug, test, beta, production
}

struct AnalyticsConfiguration: Sendable {
  let baseURL: URL
  let appName: String
  let appVersion: String
  let audience: AnalyticsAudience
  let keyID: String
  let secret: Data

  var namespace: String { baseURL.lastPathComponent }

  init?(values: [String: Any], bundle: Bundle = .main) {
    let isEnabled =
      (values["analyticsEnabled"] as? Bool)
      ?? ((values["analyticsEnabled"] as? String).map {
        ["yes", "true", "1"].contains($0.lowercased())
      } ?? false)
    guard
      isEnabled,
      let rawURL = values["analyticsBaseUrl"] as? String,
      let url = URL(string: rawURL), url.scheme == "https", url.host != nil,
      url.lastPathComponent.range(of: "^[a-z0-9][a-z0-9-]{0,62}$", options: .regularExpression)
        != nil,
      let appName = values["appName"] as? String,
      appName.range(of: "^[a-z0-9][a-z0-9-]{0,62}$", options: .regularExpression) != nil,
      let keyID = values["analyticsKeyId"] as? String, keyID == url.lastPathComponent,
      let secretText = values["analyticsSecret"] as? String,
      secretText.count >= 32, !secretText.lowercased().contains("placeholder"),
      let audience = AnalyticsAudience(rawValue: values["audience"] as? String ?? "debug")
    else { return nil }
    self.baseURL = url
    self.appName = appName
    self.appVersion =
      (values["appVersion"] as? String)
      ?? bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    self.audience = audience
    self.keyID = keyID
    self.secret = Data(secretText.utf8)
  }
}

enum AnalyticsEventType: String, Codable, Sendable {
  case appOpen = "app.open"
  case onboardingCompleted = "onboarding.completed"
  case routineStarted = "routine.started"
  case workoutCompleted = "workout.completed"
  case workoutDiscarded = "workout.discarded"
  case routineCreated = "routine.created"
  case routineEdited = "routine.edited"
  case exerciseCreated = "exercise.created"
  case hevyImportCompleted = "hevy_import.completed"
  case healthKitExportSettingChanged = "healthkit.export_setting_changed"
}

enum AnalyticsValue {
  static func durationBucket(_ duration: TimeInterval) -> String {
    switch max(0, duration) {
    case ..<300: "under_5m"
    case ..<900: "5_15m"
    case ..<1800: "15_30m"
    case ..<3600: "30_60m"
    default: "60m_plus"
    }
  }
}

struct AnalyticsEvent: Codable, Identifiable, Sendable {
  let id: String
  let type: AnalyticsEventType
  let occurredAt: Date
  let audience: AnalyticsAudience
  let properties: [String: StringOrNumber]
  var state = "queued"

  init(
    _ type: AnalyticsEventType, audience: AnalyticsAudience,
    properties: [String: StringOrNumber] = [:]
  ) {
    self.id = UUID().uuidString.lowercased()
    self.type = type
    self.occurredAt = .now
    self.audience = audience
    self.properties = Self.sanitize(type, properties)
  }

  private static func sanitize(_ type: AnalyticsEventType, _ values: [String: StringOrNumber])
    -> [String: StringOrNumber]
  {
    let categorical: [String: Set<String>] = [
      "source": ["home", "routine_detail", "shortcut", "app_intent", "active_workout"],
      "routine_kind": ["built_in", "custom"],
      "duration_bucket": ["under_5m", "5_15m", "15_30m", "30_60m", "60m_plus"],
    ]
    let allowedKeys: Set<String> =
      switch type {
      case .routineStarted: ["source", "routine_kind", "routine_name", "exercise_ids"]
      case .workoutCompleted:
        ["duration_bucket", "exercise_count", "completed_sets", "skipped_sets", "exercise_ids"]
      case .workoutDiscarded: ["source"]
      case .onboardingCompleted: ["starter_routines_added", "starter_routine_count"]
      case .routineCreated, .routineEdited: ["exercise_count", "routine_name"]
      case .exerciseCreated:
        [
          "exercise_name", "category", "equipment", "primary_muscle", "unit", "rep_counting_mode",
          "duplicated",
        ]
      case .healthKitExportSettingChanged: ["enabled"]
      case .hevyImportCompleted:
        ["routine_count", "workout_count", "mapped_exercises", "unmapped_exercises"]
      default: []
      }
    var result: [String: StringOrNumber] = [:]
    for key in allowedKeys {
      guard let value = values[key] else { continue }
      switch value {
      case .string(let text) where categorical[key]?.contains(text) == true: result[key] = value
      case .string(let text) where ["routine_name", "exercise_name"].contains(key):
        let bounded = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        if !bounded.isEmpty { result[key] = .string(bounded) }
      case .string(let text)
      where ["category", "equipment", "primary_muscle", "unit"].contains(key):
        if text.range(of: "^[a-zA-Z0-9 _-]{1,40}$", options: .regularExpression) != nil {
          result[key] = .string(text.lowercased())
        }
      case .string(let text) where key == "rep_counting_mode":
        if ["standard", "per_side"].contains(text) { result[key] = value }
      case .strings(let ids) where key == "exercise_ids":
        let stableIDs = ids.filter {
          $0.range(of: "^[A-Za-z0-9_-]{1,80}$", options: .regularExpression) != nil
        }
        var seenIDs = Set<String>()
        let uniqueIDs = stableIDs.filter { seenIDs.insert($0).inserted }
        if !uniqueIDs.isEmpty { result[key] = .strings(Array(uniqueIDs.prefix(100))) }
      case .number(let number) where number >= 0 && number <= 1_000: result[key] = value
      case .bool where key == "enabled" || key == "starter_routines_added" || key == "duplicated":
        result[key] = value
      default: break
      }
    }
    return result
  }

  var safePropertiesSummary: String {
    properties.keys.sorted().compactMap { key in
      guard let value = properties[key] else { return nil }
      return "\(key)=\(value.diagnosticValue)"
    }.joined(separator: ", ")
  }
}

enum StringOrNumber: Codable, Sendable {
  case string(String)
  case strings([String])
  case number(Int)
  case bool(Bool)

  var diagnosticValue: String {
    switch self {
    case .string(let value): value
    case .strings(let values): "\(values.count) IDs"
    case .number(let value): String(value)
    case .bool(let value): String(value)
    }
  }

  init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer()
    if let v = try? value.decode([String].self) {
      self = .strings(v)
    } else if let v = try? value.decode(String.self) {
      self = .string(v)
    } else if let v = try? value.decode(Int.self) {
      self = .number(v)
    } else {
      self = .bool(try value.decode(Bool.self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var value = encoder.singleValueContainer()
    switch self {
    case .string(let v): try value.encode(v)
    case .strings(let v): try value.encode(v)
    case .number(let v): try value.encode(v)
    case .bool(let v): try value.encode(v)
    }
  }
}

private struct AnalyticsBatch: Codable {
  struct App: Codable {
    let name: String
    let version: String
    var platform = "iOS"
  }
  var schemaVersion = 1
  let batchId: String
  let sentAt: Date
  let app: App
  let events: [AnalyticsEvent]
}

struct PreparedAnalyticsBatch: Codable, Sendable {
  let id: String
  let eventIDs: [String]
  let gzipBytes: Data
  let sha256: String
  let signature: String
}

struct AnalyticsQueue: Codable, Sendable {
  var events: [AnalyticsEvent] = []
  var prepared: PreparedAnalyticsBatch?
  var retryAttempt = 0
  var nextRetryAt: Date?
  var redirectBaseURL: URL?
  var stopLogging = false
  var recent: [AnalyticsEvent] = []
  var successfulUploadEventCount = 0

  private enum CodingKeys: String, CodingKey {
    case events, prepared, retryAttempt, nextRetryAt, redirectBaseURL, stopLogging, recent
    case successfulUploadEventCount
  }

  init() {}

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    events = try values.decodeIfPresent([AnalyticsEvent].self, forKey: .events) ?? []
    prepared = try values.decodeIfPresent(PreparedAnalyticsBatch.self, forKey: .prepared)
    retryAttempt = try values.decodeIfPresent(Int.self, forKey: .retryAttempt) ?? 0
    nextRetryAt = try values.decodeIfPresent(Date.self, forKey: .nextRetryAt)
    redirectBaseURL = try values.decodeIfPresent(URL.self, forKey: .redirectBaseURL)
    stopLogging = try values.decodeIfPresent(Bool.self, forKey: .stopLogging) ?? false
    recent = try values.decodeIfPresent([AnalyticsEvent].self, forKey: .recent) ?? []
    successfulUploadEventCount =
      try values.decodeIfPresent(Int.self, forKey: .successfulUploadEventCount) ?? 0
  }
}

private actor AnalyticsQueueStore {
  let config: AnalyticsConfiguration
  let fileURL: URL
  var queue = AnalyticsQueue()

  init(config: AnalyticsConfiguration) {
    self.config = config
    let root =
      (try? FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
      ?? FileManager.default.temporaryDirectory
    let directory = root.appendingPathComponent("Analytics", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    fileURL = directory.appendingPathComponent("queue.json")
    if let data = try? Data(contentsOf: fileURL),
      let decoded = try? JSONDecoder.analytics.decode(AnalyticsQueue.self, from: data)
    {
      queue = decoded
    }
    Self.excludeFromBackup(directory)
  }

  func enqueue(_ event: AnalyticsEvent) {
    guard !queue.stopLogging else { return }
    queue.events.append(event)
    queue.recent.append(event)
    queue.recent = Array(queue.recent.suffix(100))
    evictIfNeeded()
    persist()
  }

  func snapshot() -> AnalyticsQueue { queue }

  func flush() async {
    guard !queue.stopLogging, Date() >= (queue.nextRetryAt ?? .distantPast) else { return }
    guard !queue.events.isEmpty else { return }
    if queue.prepared == nil { prepareBatch() }
    guard let batch = queue.prepared else { return }
    var request = URLRequest(
      url: (queue.redirectBaseURL ?? config.baseURL).appendingPathComponent("v1/events"))
    request.httpMethod = "POST"
    request.httpBody = batch.gzipBytes
    request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(batch.id, forHTTPHeaderField: "X-App-Analytics-Batch-ID")
    request.setValue(batch.sha256, forHTTPHeaderField: "X-App-Analytics-Payload-SHA256")
    request.setValue(config.keyID, forHTTPHeaderField: "X-App-Analytics-Key-ID")
    request.setValue(batch.signature, forHTTPHeaderField: "X-App-Analytics-Signature")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse else {
        scheduleRetry()
        return
      }
      let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
      let action = body["action"] as? String ?? "continue"
      let code = (body["error"] as? [String: Any])?["code"] as? String
      if action == "stop_logging" {
        queue.stopLogging = true
        persist()
        return
      }
      if response.statusCode == 429 || action == "pause_uploads" || code == "INGEST_PAUSED" {
        scheduleRetry(
          serverDelay: body["retryAfterSeconds"] as? TimeInterval ?? Self.retryAfter(response))
        return
      }
      if action == "redirect", let raw = body["redirectBaseUrl"] as? String,
        let url = URL(string: raw), url.scheme == "https"
      {
        queue.redirectBaseURL = url
      }
      if response.statusCode == 202
        || (response.statusCode == 200 && body["duplicate"] as? Bool == true)
      {
        let uploaded = Set(batch.eventIDs)
        queue.successfulUploadEventCount += batch.eventIDs.count
        queue.events.removeAll { uploaded.contains($0.id) }
        queue.prepared = nil
        queue.retryAttempt = 0
        queue.nextRetryAt = nil
        for index in queue.recent.indices where uploaded.contains(queue.recent[index].id) {
          queue.recent[index].state = "uploaded"
        }
        if !queue.events.isEmpty {
          persist()
          await flush()
        } else {
          persist()
        }
      } else if response.statusCode >= 500 {
        scheduleRetry(
          serverDelay: body["retryAfterSeconds"] as? TimeInterval ?? Self.retryAfter(response))
      } else if (400..<500).contains(response.statusCode) {
        markFailed(batch, statusCode: response.statusCode, errorCode: code)
      } else {
        scheduleRetry(serverDelay: Self.retryAfter(response))
      }
    } catch { scheduleRetry() }
  }

  private func prepareBatch() {
    let firstAudience = queue.events.first?.audience
    let events = Array(queue.events.prefix(while: { $0.audience == firstAudience }).prefix(500))
    guard !events.isEmpty, let firstAudience else { return }
    var selected = events
    var compressed = Data()
    var encoded = Data()
    while !selected.isEmpty {
      let batchID = UUID().uuidString.lowercased()
      let payload = AnalyticsBatch(
        batchId: batchID, sentAt: .now,
        app: .init(name: config.appName, version: config.appVersion), events: selected)
      guard let bytes = try? JSONEncoder.analytics.encode(payload), bytes.count <= 5 * 1024 * 1024,
        let zipped = Self.gzip(bytes), zipped.count <= 1024 * 1024
      else {
        selected.removeLast()
        continue
      }
      encoded = bytes
      compressed = zipped
      let digest = SHA256.hash(data: compressed).map { String(format: "%02x", $0) }.joined()
      let signing = "\(config.namespace)\nv1\n\(batchID)\n\(digest)"
      let mac = HMAC<SHA256>.authenticationCode(
        for: Data(signing.utf8), using: SymmetricKey(data: config.secret))
      let signature = Data(mac).map { String(format: "%02x", $0) }.joined()
      queue.prepared = PreparedAnalyticsBatch(
        id: batchID, eventIDs: selected.map(\.id), gzipBytes: compressed, sha256: digest,
        signature: signature)
      break
    }
    _ = encoded
    _ = firstAudience
    persist()
  }

  private func scheduleRetry(serverDelay: TimeInterval? = nil) {
    queue.retryAttempt += 1
    let exponent = min(queue.retryAttempt - 1, 10)
    let cap = min(86_400.0, 60 * pow(2, Double(exponent)))
    let delay = max(60, Double.random(in: (cap * 0.5)...cap), serverDelay ?? 0)
    queue.nextRetryAt = Date().addingTimeInterval(delay)
    persist()
  }

  private func markFailed(
    _ batch: PreparedAnalyticsBatch, statusCode: Int, errorCode: String?
  ) {
    let ids = Set(batch.eventIDs)
    let rejection = "rejected: \(errorCode ?? "HTTP_\(statusCode)") (HTTP \(statusCode))"
    for index in queue.recent.indices where ids.contains(queue.recent[index].id) {
      queue.recent[index].state = rejection
    }
    queue.events.removeAll { ids.contains($0.id) }
    queue.prepared = nil
    queue.nextRetryAt = nil
    persist()
  }

  private func evictIfNeeded() {
    let now = Date()
    queue.events.removeAll {
      $0.audience == .production && now.timeIntervalSince($0.occurredAt) > 90 * 24 * 60 * 60
    }
    while queue.events.count > 10_000
      || ((try? JSONEncoder.analytics.encode(queue).count) ?? 0) > 20 * 1024 * 1024
    {
      let preparedIDs = Set(queue.prepared?.eventIDs ?? [])
      guard let index = queue.events.firstIndex(where: { !preparedIDs.contains($0.id) }) else {
        break
      }
      queue.events.remove(at: index)
    }
  }

  private func persist() {
    guard let data = try? JSONEncoder.analytics.encode(queue) else { return }
    try? data.write(to: fileURL, options: .atomic)
    Self.excludeFromBackup(fileURL)
  }

  private static func excludeFromBackup(_ url: URL) {
    var value = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? value.setResourceValues(values)
  }

  private static func retryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
    guard let raw = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
    if let seconds = TimeInterval(raw) { return seconds }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
    return formatter.date(from: raw).map { max(0, $0.timeIntervalSinceNow) }
  }

  private static func gzip(_ data: Data) -> Data? {
    let capacity = max(1024, data.count + data.count / 4 + 256)
    var zlib = [UInt8](repeating: 0, count: capacity)
    let length = data.withUnsafeBytes { source in
      compression_encode_buffer(
        &zlib, capacity, source.bindMemory(to: UInt8.self).baseAddress!, data.count, nil,
        COMPRESSION_ZLIB)
    }
    guard length > 6 else { return nil }
    let deflate = zlib[0..<length]
    var result: [UInt8] = [0x1f, 0x8b, 0x08, 0, 0, 0, 0, 0, 0, 0xff]
    result.append(contentsOf: deflate)
    let crc = crc32(data)
    for shift in stride(from: 0, to: 32, by: 8) { result.append(UInt8((crc >> shift) & 0xff)) }
    let size = UInt32(truncatingIfNeeded: data.count)
    for shift in stride(from: 0, to: 32, by: 8) { result.append(UInt8((size >> shift) & 0xff)) }
    return Data(result)
  }

  private static func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xffff_ffff
    for byte in data {
      crc ^= UInt32(byte)
      for _ in 0..<8 { crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb8_8320 : crc >> 1 }
    }
    return crc ^ 0xffff_ffff
  }
}

extension JSONEncoder {
  fileprivate static var analytics: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}

extension JSONDecoder {
  fileprivate static var analytics: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

@Observable @MainActor
final class AnalyticsClient {
  static let shared = AnalyticsClient()
  let configuration: AnalyticsConfiguration?
  private let store: AnalyticsQueueStore?
  private(set) var diagnostics = AnalyticsQueue()

  init(
    configuration: AnalyticsConfiguration? = AnalyticsConfiguration(
      values: Bundle.main.infoDictionary ?? [:])
  ) {
    self.configuration = configuration
    self.store = configuration.map(AnalyticsQueueStore.init(config:))
    Task { await refresh() }
  }

  func track(_ type: AnalyticsEventType, _ properties: [String: StringOrNumber] = [:]) {
    guard let configuration, let store else { return }
    let event = AnalyticsEvent(type, audience: configuration.audience, properties: properties)
    Task {
      await store.enqueue(event)
      await store.flush()
      await refresh()
    }
  }

  func refresh() async { diagnostics = await store?.snapshot() ?? AnalyticsQueue() }
  func uploadNow() {
    Task {
      await store?.flush()
      await refresh()
    }
  }
  func copySummary() -> String {
    let rejected = diagnostics.recent.filter {
      $0.state == "validation failed" || $0.state.hasPrefix("rejected:")
    }.count
    return
      "Analytics: \(configuration == nil ? "disabled" : diagnostics.stopLogging ? "stopped" : "enabled"); uploaded \(diagnostics.successfulUploadEventCount); queued \(diagnostics.events.count); rejected recently \(rejected); recent \(diagnostics.recent.count); retries \(diagnostics.retryAttempt); next retry \(diagnostics.nextRetryAt?.formatted() ?? "none")"
  }
}
