import Foundation
import Security
import SwiftData

#if canImport(FoundationModels)
  import FoundationModels
#endif

struct LiftCoachFacts: Codable, Equatable {
  let workoutCount: Int
  let completedSetCount: Int
  let poundsVolume: Double
  let routineNames: [String]
  let topExercises: [String]
  let totalDurationSeconds: Int
  let dailyVolume: [LiftCoachDailyVolume]
  let routines: [LiftCoachRoutineSummary]
  let rest: LiftCoachRestFacts
  let progressionCandidates: [LiftCoachProgressionCandidate]
  let previousWeekWorkoutCount: Int
  let previousWeekCompletedSetCount: Int
  let previousWeekPoundsVolume: Double

  var factualSummary: String {
    "\(workoutCount) workouts, \(completedSetCount) completed sets, "
      + "\(Int(poundsVolume.rounded())) lb × reps. Previous week: "
      + "\(previousWeekWorkoutCount) workouts, \(previousWeekCompletedSetCount) sets, "
      + "\(Int(previousWeekPoundsVolume.rounded())) lb × reps."
  }

  var restAssessment: LiftCoachRestAssessment {
    if rest.highEffortSetCount > 0 || rest.belowTargetSetCount > 0 {
      return .considerMoreRest
    }
    if rest.configuredRestSeconds != nil && rest.ratedSetCount >= 3 {
      return .appearsAdequate
    }
    return .insufficientData
  }
}

struct LiftCoachDailyVolume: Codable, Equatable, Identifiable {
  let day: Date
  let poundsVolume: Double
  var id: Date { day }
}

struct LiftCoachRoutineSummary: Codable, Equatable, Identifiable {
  let routineID: UUID
  let name: String
  let workoutCount: Int
  var id: UUID { routineID }
}

struct LiftCoachRestFacts: Codable, Equatable {
  let configuredRestSeconds: Int?
  let ratedSetCount: Int
  let highEffortSetCount: Int
  let belowTargetSetCount: Int
}

struct LiftCoachProgressionCandidate: Codable, Equatable, Identifiable {
  let id: String
  let currentExercise: String
  let suggestedExercise: String
  let routineID: UUID
  let routineName: String
  let evidence: String
  let rationale: String
}

enum LiftCoachRestAssessment: String, Codable, CaseIterable {
  case appearsAdequate
  case considerMoreRest
  case insufficientData
}

struct LiftCoachStructuredResponse: Codable, Equatable {
  let overallPattern: String
  let whatsNext: String
  let restAssessment: LiftCoachRestAssessment
  let restExplanation: String
  let progressionCandidateID: String
  let progressionExplanation: String

  static let empty = LiftCoachStructuredResponse(
    overallPattern: "", whatsNext: "", restAssessment: .insufficientData,
    restExplanation: "", progressionCandidateID: "none", progressionExplanation: "")
}

enum LiftCoachProvider: String, CaseIterable, Identifiable {
  case deterministic
  case foundationModels
  case openAI

  var id: String { rawValue }
  var title: String {
    switch self {
    case .deterministic: "Facts only"
    case .foundationModels: "On-device model"
    case .openAI: "OpenAI API"
    }
  }
}

enum ProgressPreviewMode: String, Identifiable {
  case learning
  case generated

  var id: String { rawValue }
}

enum LiftCoachError: LocalizedError {
  case modelUnavailable(String)
  case missingAPIKey
  case invalidResponse
  case server(String)

  var errorDescription: String? {
    switch self {
    case .modelUnavailable(let reason): reason
    case .missingAPIKey: "Add an OpenAI API key in Settings to use cloud coaching."
    case .invalidResponse: "The coaching service returned an unreadable response."
    case .server(let message): message
    }
  }
}

enum LiftCoachNarrator {
  static func generate(_ facts: LiftCoachFacts, provider: LiftCoachProvider) async throws
    -> LiftCoachStructuredResponse?
  {
    switch provider {
    case .deterministic:
      return nil
    case .foundationModels:
      return try await onDeviceResponse(facts)
    case .openAI:
      return try await openAIResponse(facts)
    }
  }

  private static func onDeviceResponse(_ facts: LiftCoachFacts) async throws
    -> LiftCoachStructuredResponse
  {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        guard SystemLanguageModel.default.isAvailable else {
          throw LiftCoachError.modelUnavailable(
            "The on-device model is unavailable on this device or language.")
        }
        let session = LanguageModelSession()
        let response = try await session.respond(
          to: prompt(for: facts), generating: GeneratedLiftCoachResponse.self)
        guard let generated = response.content.structuredResponse else {
          throw LiftCoachError.invalidResponse
        }
        return try validate(generated, against: facts)
      }
    #endif
    throw LiftCoachError.modelUnavailable(
      "On-device coaching requires a supported Apple Intelligence device and iOS 26 or later.")
  }

  private static func openAIResponse(_ facts: LiftCoachFacts) async throws
    -> LiftCoachStructuredResponse
  {
    guard let key = LiftCoachKeychain.read() else { throw LiftCoachError.missingAPIKey }
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 25
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let candidateIDs = ["none"] + facts.progressionCandidates.map(\.id)
    let schema: [String: Any] = [
      "type": "object",
      "properties": [
        "overall_pattern": ["type": "string"],
        "whats_next": ["type": "string"],
        "rest_assessment": [
          "type": "string", "enum": LiftCoachRestAssessment.allCases.map(\.rawValue),
        ],
        "rest_explanation": ["type": "string"],
        "progression_candidate_id": ["type": "string", "enum": candidateIDs],
        "progression_explanation": ["type": "string"],
      ],
      "required": [
        "overall_pattern", "whats_next", "rest_assessment", "rest_explanation",
        "progression_candidate_id", "progression_explanation",
      ],
      "additionalProperties": false,
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": "gpt-4.1-mini",
      "store": false,
      "max_output_tokens": 420,
      "text": [
        "format": [
          "type": "json_schema", "name": "lift_coach_weekly_report", "strict": true,
          "schema": schema,
        ]
      ],
      "input": [
        [
          "role": "developer",
          "content":
            "Return structured coaching sections using only the supplied facts. Keep each section concise. "
            + "Never invent facts, prescribe medical treatment, diagnose exercise form, or mention names. "
            + "Assess rest cautiously: exact rest intervals are not measured; use only the configured rest target, RPE and target performance, and choose insufficientData when evidence is sparse. "
            + "Choose progression_candidate_id only from the supplied eligible candidate IDs; otherwise use none. "
            + "Do not add numerical claims beyond the supplied facts. The supplied data follows as JSON: "
            + prompt(for: facts),
        ]
      ],
    ])
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw LiftCoachError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
      throw LiftCoachError.server(
        "OpenAI request failed (HTTP \(http.statusCode)). Check the API key, quota, or connection.")
    }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let output = root["output"] as? [[String: Any]]
    else { throw LiftCoachError.invalidResponse }
    if root["status"] as? String == "incomplete"
      || output.flatMap({ $0["content"] as? [[String: Any]] ?? [] })
        .contains(where: { $0["type"] as? String == "refusal" })
    {
      throw LiftCoachError.invalidResponse
    }
    let text =
      output
      .flatMap { $0["content"] as? [[String: Any]] ?? [] }
      .compactMap { $0["text"] as? String }
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= 2_000, let data = text.data(using: .utf8) else {
      throw LiftCoachError.invalidResponse
    }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let decoded = try decoder.decode(LiftCoachStructuredResponse.self, from: data)
    return try validate(decoded, against: facts)
  }

  private static func validate(
    _ response: LiftCoachStructuredResponse, against facts: LiftCoachFacts
  ) throws -> LiftCoachStructuredResponse {
    guard response.overallPattern.count <= 300, response.whatsNext.count <= 300,
      response.restExplanation.count <= 240, response.progressionExplanation.count <= 240,
      ["none"].contains(response.progressionCandidateID)
        || facts.progressionCandidates.contains(where: { $0.id == response.progressionCandidateID })
    else { throw LiftCoachError.invalidResponse }
    let evidence = facts.factualSummary + " " + prompt(for: facts)
    let claims =
      response.overallPattern + response.whatsNext + response.restExplanation
      + response.progressionExplanation
    let numberPattern = #"\d+(?:\.\d+)?%?"#
    let expression = try NSRegularExpression(pattern: numberPattern)
    func numbers(in value: String) -> Set<String> {
      let range = NSRange(value.startIndex..., in: value)
      return Set(
        expression.matches(in: value, range: range).compactMap {
          Range($0.range, in: value).map { String(value[$0]) }
        })
    }
    guard numbers(in: claims).isSubset(of: numbers(in: evidence)) else {
      throw LiftCoachError.invalidResponse
    }
    return LiftCoachStructuredResponse(
      overallPattern: response.overallPattern, whatsNext: response.whatsNext,
      restAssessment: facts.restAssessment, restExplanation: response.restExplanation,
      progressionCandidateID: response.progressionCandidateID,
      progressionExplanation: response.progressionExplanation)
  }

  private static func prompt(for facts: LiftCoachFacts) -> String {
    let candidates = facts.progressionCandidates.map {
      "\($0.id): \($0.currentExercise) to \($0.suggestedExercise) in \($0.routineName). \($0.evidence) \($0.rationale)"
    }.joined(separator: "\n")
    return
      "Create concise sections named overall pattern, what's next, rest assessment, and a progression candidate. "
      + "Use only these computed facts. Exact rest intervals are not measured, so be cautious and choose insufficientData if set RPE/target evidence is missing. "
      + "The progression candidate ID must be one of these eligible reviewed choices, or none. Explain only its supplied evidence. "
      + "Facts: \(facts.factualSummary) Routine frequency: \(facts.routines.map { "\($0.name): \($0.workoutCount)" }.joined(separator: ", ")). "
      + "Rest evidence: configured seconds \(facts.rest.configuredRestSeconds.map(String.init) ?? "none"), rated sets \(facts.rest.ratedSetCount), high-effort sets \(facts.rest.highEffortSetCount), below-target sets \(facts.rest.belowTargetSetCount). "
      + "Eligible progressions:\n\(candidates.isEmpty ? "none" : candidates)"
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, *)
  @Generable
  private struct GeneratedLiftCoachResponse {
    @Guide(description: "One concise observation about the user's overall routine pattern.")
    let overallPattern: String
    @Guide(description: "One cautious next coaching focus based on supplied facts.")
    let whatsNext: String
    @Guide(description: "Must be appearsAdequate, considerMoreRest, or insufficientData.")
    let restAssessment: String
    @Guide(description: "Brief rest assessment grounded in available data.")
    let restExplanation: String
    @Guide(description: "An eligible supplied ID, or none.")
    let progressionCandidateID: String
    @Guide(description: "Brief explanation for the selected eligible progression, or blank.")
    let progressionExplanation: String

    var structuredResponse: LiftCoachStructuredResponse? {
      guard let status = LiftCoachRestAssessment(rawValue: restAssessment) else { return nil }
      return LiftCoachStructuredResponse(
        overallPattern: overallPattern, whatsNext: whatsNext, restAssessment: status,
        restExplanation: restExplanation, progressionCandidateID: progressionCandidateID,
        progressionExplanation: progressionExplanation)
    }
  }
#endif

enum LiftCoachKeychain {
  private static let service = "com.cseibert.StrengthLog.lift-coach"
  private static let account = "openai-api-key"

  static func read() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  @discardableResult
  static func save(_ value: String) -> Bool {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    let update = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if update == errSecSuccess { return true }
    var add = query
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
  }

  static func remove() {
    SecItemDelete(
      [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
      ] as CFDictionary)
  }
}

enum LiftCoachReportBuilder {
  static func facts(
    for person: PersonProfile, people: [PersonProfile], sessions: [WorkoutSession],
    routines: [Routine], exercises: [Exercise], reports: [WeeklyCoachingReport],
    in interval: DateInterval
  ) -> LiftCoachFacts {
    let nameIsUnique =
      people.filter {
        $0.name.caseInsensitiveCompare(person.name) == .orderedSame
      }.count == 1
    let legacyIdentityIsUnambiguous = sessions.flatMap(\.exercises).flatMap(\.participants)
      .filter { $0.participantName.caseInsensitiveCompare(person.name) == .orderedSame }
      .allSatisfy { $0.personID == nil }
    func belongsToPerson(_ session: WorkoutSession) -> Bool {
      session.exercises.contains { exercise in
        exercise.participants.contains { participant in
          let matchesPerson =
            participant.personID == person.id
            || (participant.personID == nil && nameIsUnique && legacyIdentityIsUnambiguous
              && participant.participantName.caseInsensitiveCompare(person.name) == .orderedSame)
          return matchesPerson && session.isParticipantActive(participant.participantName)
            && participant.sets.contains { $0.isCompleted && !$0.isSkipped }
        }
      }
    }
    func filteredSessions(in interval: DateInterval) -> [WorkoutSession] {
      sessions.filter { session in
        !session.isActive && session.deletedAt == nil
          && session.startedAt >= interval.start && session.startedAt < interval.end
          && belongsToPerson(session)
      }
    }
    let included = filteredSessions(in: interval)
    let previousStart =
      Calendar.current.date(
        byAdding: .weekOfYear, value: -1, to: interval.start) ?? interval.start
    let previousInterval = DateInterval(start: previousStart, end: interval.start)
    let previousWeek = filteredSessions(in: previousInterval)
    var previousSetCount = 0
    var previousVolume = 0.0
    for session in previousWeek {
      for exercise in session.exercises {
        guard
          let participant = exercise.participants.first(where: {
            session.isParticipantActive($0.participantName)
              && ($0.personID == person.id
                || ($0.personID == nil && nameIsUnique && legacyIdentityIsUnambiguous
                  && $0.participantName.caseInsensitiveCompare(person.name) == .orderedSame))
          })
        else { continue }
        let completed = participant.sets.filter { $0.isCompleted && !$0.isSkipped }
        previousSetCount += completed.count
        if exercise.unit == .pounds {
          let multiplier = exercise.repCountingMode == .perSide ? 2.0 : 1.0
          for set in completed {
            let load: Double = set.measurement ?? participant.measurement
            previousVolume += Double(set.reps) * multiplier * load
          }
        }
      }
    }
    var setCount = 0
    var volume = 0.0
    var exerciseCounts: [String: Int] = [:]
    var dailyVolumes: [Date: Double] = [:]
    var ratedSetCount = 0
    var highEffortSetCount = 0
    var belowTargetSetCount = 0
    for session in included {
      let day = Calendar.current.startOfDay(for: session.startedAt)
      for exercise in session.exercises {
        guard
          let participant = exercise.participants.first(where: {
            session.isParticipantActive($0.participantName)
              && ($0.personID == person.id
                || ($0.personID == nil && nameIsUnique && legacyIdentityIsUnambiguous
                  && $0.participantName.caseInsensitiveCompare(person.name) == .orderedSame))
          })
        else { continue }
        let completed = participant.sets.filter { $0.isCompleted && !$0.isSkipped }
        setCount += completed.count
        if exercise.unit == .pounds {
          let multiplier = exercise.repCountingMode == .perSide ? 2.0 : 1.0
          var exerciseVolume = 0.0
          for set in completed {
            let load: Double = set.measurement ?? participant.measurement
            exerciseVolume += Double(set.reps) * multiplier * load
          }
          volume += exerciseVolume
          dailyVolumes[day, default: 0] += exerciseVolume
        }
        ratedSetCount += completed.filter { $0.rpe != nil }.count
        highEffortSetCount += completed.filter { ($0.rpe ?? 0) >= 9 }.count
        if nameIsUnique,
          let routine = routines.first(where: { $0.id == session.routineID && $0.deletedAt == nil }
          ),
          let routineExercise = routine.exercises.first(where: {
            ($0.exerciseID != nil && $0.exerciseID == exercise.exerciseID)
              || ($0.exerciseID == nil
                && $0.exerciseName.caseInsensitiveCompare(exercise.exerciseName) == .orderedSame)
          }),
          let prescription = routineExercise.prescriptions.first(where: {
            $0.participantName.caseInsensitiveCompare(person.name) == .orderedSame
          })
        {
          let targetReps = prescription.sets.sorted { $0.sortOrder < $1.sortOrder }.map(\.reps)
          belowTargetSetCount += max(0, targetReps.count - completed.count)
          for set in completed {
            guard targetReps.indices.contains(set.sortOrder) else { continue }
            if set.reps < targetReps[set.sortOrder] { belowTargetSetCount += 1 }
          }
        }
        exerciseCounts[exercise.exerciseName, default: 0] += completed.count
      }
    }
    let names = Set(
      included.map { session in
        routines.first(where: { $0.id == session.routineID })?.name ?? session.routineName
      }.filter { !$0.isEmpty })
    let topExercises = exerciseCounts.sorted {
      if $0.value != $1.value { return $0.value > $1.value }
      return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
    }.prefix(3).map(\.key)
    let routineSummaries = Dictionary(grouping: included, by: \.routineID).compactMap {
      routineID, workouts -> LiftCoachRoutineSummary? in
      guard let routine = routines.first(where: { $0.id == routineID && $0.deletedAt == nil })
      else {
        return nil
      }
      return LiftCoachRoutineSummary(
        routineID: routineID, name: routine.name, workoutCount: workouts.count)
    }.sorted { $0.workoutCount > $1.workoutCount }
    let configuredRests = included.compactMap { session in
      routines.first(where: { $0.id == session.routineID && $0.deletedAt == nil })?
        .restDurationSeconds
    }.filter { $0 > 0 }.sorted()
    let medianRest = configuredRests.isEmpty ? nil : configuredRests[configuredRests.count / 2]
    let eligibleHistory = sessions.filter { !$0.isActive && $0.deletedAt == nil }
    let progressionCandidates = progressionCandidates(
      person: person, people: people, sessions: eligibleHistory, routines: routines,
      exercises: exercises, reports: reports, firstReportBaseline: interval.start)
    return LiftCoachFacts(
      workoutCount: included.count, completedSetCount: setCount, poundsVolume: volume,
      routineNames: names.sorted(), topExercises: topExercises,
      totalDurationSeconds: included.compactMap(\.workoutDuration).reduce(0) {
        $0 + Int($1.rounded())
      },
      dailyVolume: dailyVolumes.map { LiftCoachDailyVolume(day: $0.key, poundsVolume: $0.value) }
        .sorted { $0.day < $1.day },
      routines: routineSummaries,
      rest: LiftCoachRestFacts(
        configuredRestSeconds: medianRest, ratedSetCount: ratedSetCount,
        highEffortSetCount: highEffortSetCount, belowTargetSetCount: belowTargetSetCount),
      progressionCandidates: progressionCandidates,
      previousWeekWorkoutCount: previousWeek.count,
      previousWeekCompletedSetCount: previousSetCount,
      previousWeekPoundsVolume: previousVolume)
  }

  private static func progressionCandidates(
    person: PersonProfile, people: [PersonProfile], sessions: [WorkoutSession],
    routines: [Routine], exercises: [Exercise], reports: [WeeklyCoachingReport],
    firstReportBaseline: Date
  ) -> [LiftCoachProgressionCandidate] {
    let uniquePersonName =
      people.filter { $0.name.caseInsensitiveCompare(person.name) == .orderedSame }.count == 1
    guard uniquePersonName else { return [] }
    let latestReport = reports.filter { $0.personID == person.id }.max {
      $0.createdAt < $1.createdAt
    }
    let baseline = latestReport?.createdAt ?? firstReportBaseline
    let rules = [
      (
        id: "bench-to-incline-dumbbell", source: "Barbell_Bench_Press_-_Medium_Grip",
        candidate: "Incline_Dumbbell_Press",
        rationale:
          "The incline dumbbell press keeps the chest-press pattern and adds an incline angle with independent arm control."
      )
    ]
    let activeRoutineIDs = Set(routines.filter { $0.deletedAt == nil }.map(\.id))
    let usedCandidateIDs = Set(
      routines.filter { $0.deletedAt == nil }.flatMap(\.exercises).compactMap { entry in
        exercises.first(where: { $0.id == entry.exerciseID })?.sourceID
      })
    return rules.compactMap { rule in
      guard !usedCandidateIDs.contains(rule.candidate),
        let currentExercise = exercises.first(where: {
          $0.sourceID == rule.source && $0.deletedAt == nil
        }),
        let candidateExercise = exercises.first(where: {
          $0.sourceID == rule.candidate && $0.deletedAt == nil
        })
      else { return nil }
      for routine in routines where activeRoutineIDs.contains(routine.id) {
        guard let entry = routine.exercises.first(where: { $0.exerciseID == currentExercise.id }),
          let prescription = entry.prescriptions.first(where: {
            $0.participantName.caseInsensitiveCompare(person.name) == .orderedSame
          })
        else { continue }
        let targets = prescription.sets.sorted { $0.sortOrder < $1.sortOrder }.map(\.reps)
        guard !targets.isEmpty else { continue }
        let exerciseSessions = sessions.filter { session in
          session.routineID == routine.id
            && session.exercises.contains(where: { $0.exerciseID == currentExercise.id })
        }.sorted { $0.startedAt > $1.startedAt }
        let qualifying = exerciseSessions.prefix(2).filter { session in
          guard
            let loggedExercise = session.exercises.first(where: {
              $0.exerciseID == currentExercise.id
            }),
            let participant = loggedExercise.participants.first(where: {
              $0.personID == person.id
                || ($0.personID == nil
                  && uniquePersonName
                  && $0.participantName.caseInsensitiveCompare(person.name) == .orderedSame)
            })
          else { return false }
          let setsByOrder = Dictionary(
            participant.sets.filter { $0.isCompleted && !$0.isSkipped }.map { ($0.sortOrder, $0) },
            uniquingKeysWith: { first, _ in first })
          return targets.enumerated().allSatisfy { index, target in
            guard let set = setsByOrder[index] else { return false }
            let load = set.measurement ?? participant.measurement
            return set.reps >= target && load >= prescription.measurement
          }
        }
        guard qualifying.count == 2 else { continue }
        let candidateWasRecentlyUsed = sessions.contains { session in
          session.startedAt >= baseline
            && session.exercises.contains {
              $0.exerciseID == candidateExercise.id
            }
        }
        guard !candidateWasRecentlyUsed else { continue }
        let targetDescription = targets.map(String.init).joined(separator: ", ")
        let load = prescription.measurement.tidy
        return LiftCoachProgressionCandidate(
          id: rule.id, currentExercise: currentExercise.name,
          suggestedExercise: candidateExercise.name, routineID: routine.id,
          routineName: routine.name,
          evidence:
            "Reached all \(targets.count) prescribed sets (\(targetDescription) reps) in two recent workouts at or above the saved \(load) \(currentExercise.unit.label) target.",
          rationale: rule.rationale)
      }
      return nil
    }
  }

  static func upsert(
    facts: LiftCoachFacts, person: PersonProfile, interval: DateInterval,
    reports: [WeeklyCoachingReport], structuredResponse: LiftCoachStructuredResponse?,
    provider: LiftCoachProvider,
    context: ModelContext
  ) throws -> WeeklyCoachingReport {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let factsJSON = try String(data: encoder.encode(facts), encoding: .utf8)
    let responseJSON: String?
    if let structuredResponse {
      responseJSON = try String(data: encoder.encode(structuredResponse), encoding: .utf8)
    } else {
      responseJSON = nil
    }
    let fingerprint = factsJSON ?? "\(facts.workoutCount):\(facts.completedSetCount)"
    let report =
      reports.first {
        $0.personID == person.id && $0.weekStart == interval.start && $0.weekEnd == interval.end
      }
      ?? WeeklyCoachingReport(
        personID: person.id, weekStart: interval.start, weekEnd: interval.end,
        workoutCount: facts.workoutCount, completedSetCount: facts.completedSetCount,
        poundsVolume: facts.poundsVolume)
    report.workoutCount = facts.workoutCount
    report.completedSetCount = facts.completedSetCount
    report.poundsVolume = facts.poundsVolume
    report.narrative = structuredResponse?.overallPattern
    report.factsJSON = factsJSON
    report.structuredCoachingJSON = responseJSON
    report.provider = provider.rawValue
    report.modelName = provider == .openAI ? "gpt-4.1-mini" : provider.rawValue
    report.inputFingerprint = fingerprint
    report.schemaVersion = 2
    if report.modelContext == nil { context.insert(report) }
    try context.save()
    return report
  }

  @discardableResult
  static func refreshLocalFacts(
    for report: WeeklyCoachingReport, person: PersonProfile, people: [PersonProfile],
    sessions: [WorkoutSession], routines: [Routine], exercises: [Exercise],
    reports: [WeeklyCoachingReport], context: ModelContext
  ) throws -> Bool {
    let interval = DateInterval(start: report.weekStart, end: report.weekEnd)
    let facts = facts(
      for: person, people: people, sessions: sessions, routines: routines,
      exercises: exercises, reports: reports, in: interval)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let factsJSON = try String(data: encoder.encode(facts), encoding: .utf8) ?? ""
    guard report.inputFingerprint != factsJSON else { return false }
    let legacyFingerprint =
      "\(report.workoutCount):\(report.completedSetCount):\(Int(report.poundsVolume))"
    let currentLegacyFingerprint =
      "\(facts.workoutCount):\(facts.completedSetCount):\(Int(facts.poundsVolume))"
    let shouldInvalidateCoaching =
      report.factsJSON != nil
      ? report.inputFingerprint != factsJSON
      : legacyFingerprint != currentLegacyFingerprint
    report.workoutCount = facts.workoutCount
    report.completedSetCount = facts.completedSetCount
    report.poundsVolume = facts.poundsVolume
    report.factsJSON = factsJSON
    report.inputFingerprint = factsJSON
    report.schemaVersion = 2
    if shouldInvalidateCoaching {
      report.narrative = nil
      report.structuredCoachingJSON = nil
      report.provider = LiftCoachProvider.deterministic.rawValue
      report.modelName = LiftCoachProvider.deterministic.rawValue
    }
    try context.save()
    return true
  }

  static func currentWeek(calendar: Calendar = .current, now: Date = .now) -> DateInterval {
    calendar.dateInterval(of: .weekOfYear, for: now)
      ?? DateInterval(start: calendar.startOfDay(for: now), duration: 7 * 24 * 60 * 60)
  }

  static func savedFacts(for report: WeeklyCoachingReport) -> LiftCoachFacts? {
    guard let factsJSON = report.factsJSON, let data = factsJSON.data(using: .utf8) else {
      return nil
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(LiftCoachFacts.self, from: data)
  }

  static func structuredResponse(for report: WeeklyCoachingReport)
    -> LiftCoachStructuredResponse?
  {
    guard let json = report.structuredCoachingJSON, let data = json.data(using: .utf8) else {
      return nil
    }
    return try? JSONDecoder().decode(LiftCoachStructuredResponse.self, from: data)
  }
}
