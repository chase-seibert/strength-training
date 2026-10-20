import Foundation

/// The compact Watch payload: one selected exercise, participant cards, and a bounded
/// personal progress summary. History entries omit exercise details and are person-scoped.
struct KidsWatchSnapshot: Codable, Equatable, Identifiable {
  struct WeeklyVolume: Codable, Equatable, Identifiable {
    var weekStart: Date
    var volume: Double
    var id: Date { weekStart }
  }

  struct PersonProgress: Codable, Equatable, Identifiable {
    var personID: UUID
    var name: String
    var colorHex: String
    var weeklyVolume: [WeeklyVolume]
    var id: UUID { personID }
  }

  struct WorkoutHistory: Codable, Equatable, Identifiable {
    struct ParticipantSummary: Codable, Equatable, Identifiable {
      var personID: UUID
      var name: String
      var completedSets: Int
      var totalSets: Int
      var id: UUID { personID }
    }

    var id: UUID
    var routineName: String
    var startedAt: Date
    var participants: [ParticipantSummary]
  }

  struct SetProgress: Codable, Equatable, Identifiable {
    var id: UUID
    var number: Int
    var target: Int
    var measurement: Double?
    var durationSeconds: Double?
    var distanceMiles: Double?
    var isCompleted: Bool
    var isSkipped: Bool
  }

  struct ParticipantCard: Codable, Equatable, Identifiable {
    /// Profile ID when unambiguous; otherwise a stable ID for this legacy workout log.
    var id: UUID
    var personID: UUID?
    var name: String
    var colorHex: String?
    var measurement: Double
    var sets: [SetProgress]

    var completedSetCount: Int { sets.filter(\.isCompleted).count }
    var activeSetCount: Int { sets.filter { !$0.isSkipped }.count }
  }

  var id: UUID { sessionID }
  var sessionID: UUID
  var exerciseID: UUID
  var exerciseName: String
  var unit: String
  var usesPerDumbbellLoad: Bool
  var exerciseTimerEndDate: Date?
  var updatedAt: Date
  var participants: [ParticipantCard]
  var progress: [PersonProgress]?
  var recentWorkouts: [WorkoutHistory]?

  #if os(iOS)
    static func makeProgressSummary(
      history: [WorkoutSession], people: [PersonProfile], routines: [Routine],
      updatedAt: Date = .now
    ) -> KidsWatchProgressSnapshot {
      KidsWatchProgressSnapshot(
        updatedAt: updatedAt,
        progress: makeProgress(history: history, people: people, now: updatedAt),
        recentWorkouts: makeRecentWorkouts(history: history, people: people, routines: routines))
    }

    /// Binds a name-only log only when exactly one profile matches. Duplicate and
    /// unmatched legacy names are left untouched, so they cannot attach to the wrong person.
    @discardableResult
    static func bindUnambiguousLegacyPeople(
      in session: WorkoutSession, people: [PersonProfile]
    ) -> Bool {
      let profilesByName = Dictionary(grouping: people, by: { $0.name.lowercased() })
      var changed = false
      for participant in session.exercises.flatMap(\.participants) where participant.personID == nil
      {
        guard let matches = profilesByName[participant.participantName.lowercased()],
          matches.count == 1,
          let profile = matches.first
        else { continue }
        participant.personID = profile.id
        changed = true
      }
      return changed
    }

    static func make(
      session: WorkoutSession,
      exercise: ExerciseLog,
      people: [PersonProfile],
      history: [WorkoutSession] = [],
      routines: [Routine] = [],
      updatedAt: Date = .now
    ) -> KidsWatchSnapshot {
      let profilesByID = Dictionary(
        people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
      let profilesByName = Dictionary(grouping: people, by: { $0.name.lowercased() })
      let logsByName = Dictionary(
        exercise.participants.map { ($0.participantName.lowercased(), $0) },
        uniquingKeysWith: { first, _ in first })
      let cards = session.participantNames.compactMap { activeName -> ParticipantCard? in
        guard let participant = logsByName[activeName.lowercased()] else { return nil }
        let profile =
          participant.personID.flatMap { profilesByID[$0] }
          ?? profilesByName[participant.participantName.lowercased()]?.only
        let sets = participant.orderedSets.map { set in
          SetProgress(
            id: set.id,
            number: set.sortOrder + 1,
            target: set.reps,
            measurement: set.measurement,
            durationSeconds: set.durationSeconds,
            distanceMiles: set.distanceMiles,
            isCompleted: set.isCompleted,
            isSkipped: set.isSkipped)
        }
        return ParticipantCard(
          id: profile?.id ?? participant.id,
          personID: profile?.id,
          name: profile?.name ?? participant.participantName,
          colorHex: profile?.colorHex,
          measurement: participant.measurement,
          sets: sets)
      }
      return KidsWatchSnapshot(
        sessionID: session.id,
        exerciseID: exercise.exerciseID ?? exercise.id,
        exerciseName: exercise.exerciseName,
        unit: exercise.unit.rawValue,
        usesPerDumbbellLoad: exercise.usesPerDumbbellLoad,
        exerciseTimerEndDate: session.exerciseTimerExerciseID == exercise.id
          ? session.exerciseTimerEndDate : nil,
        updatedAt: updatedAt,
        participants: cards,
        progress: makeProgress(history: history, people: people, now: updatedAt),
        recentWorkouts: makeRecentWorkouts(history: history, people: people, routines: routines))
    }

    private static func makeProgress(
      history: [WorkoutSession], people: [PersonProfile], now: Date
    ) -> [PersonProgress] {
      let calendar = Calendar.current
      let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
      let weeks = (0..<12).compactMap {
        calendar.date(byAdding: .weekOfYear, value: $0 - 11, to: currentWeek)
      }
      return people.compactMap { person in
        var volumeByWeek: [Date: Double] = [:]
        for session in history where session.startedAt >= (weeks.first ?? currentWeek) {
          let weekStart =
            calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start
            ?? calendar.startOfDay(for: session.startedAt)
          let volume = session.exercises.reduce(0.0) { total, exercise in
            guard exercise.unit == .pounds else { return total }
            let multiplier = exercise.repCountingMode == .perSide ? 2.0 : 1.0
            let exerciseVolume = exercise.participants
              .filter {
                session.isParticipantActive($0.participantName)
                  && matches($0, to: person, among: people)
              }
              .reduce(0.0) { participantTotal, participant in
                participantTotal
                  + participant.sets
                  .filter { $0.isCompleted && !$0.isSkipped }
                  .reduce(0.0) {
                    $0 + Double($1.reps) * multiplier
                      * ($1.measurement ?? participant.measurement)
                  }
              }
            return total + exerciseVolume
          }
          if volume > 0 { volumeByWeek[weekStart, default: 0] += volume }
        }
        guard volumeByWeek.values.contains(where: { $0 > 0 }) else { return nil }
        return PersonProgress(
          personID: person.id,
          name: person.name,
          colorHex: person.colorHex,
          weeklyVolume: weeks.map {
            WeeklyVolume(weekStart: $0, volume: volumeByWeek[$0] ?? 0)
          })
      }
    }

    private static func makeRecentWorkouts(
      history: [WorkoutSession], people: [PersonProfile], routines: [Routine]
    ) -> [WorkoutHistory] {
      let sessionsByID = Dictionary(
        history.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
      let recentSessionIDs = Set(
        people.flatMap { person in
          history.sorted { $0.startedAt > $1.startedAt }
            .filter { session in
              session.exercises.flatMap(\.participants)
                .contains {
                  session.isParticipantActive($0.participantName)
                    && matches($0, to: person, among: people)
                }
            }
            .prefix(5)
            .map(\.id)
        })
      return recentSessionIDs.compactMap { sessionsByID[$0] }
        .sorted { $0.startedAt > $1.startedAt }
        .map { session in
          let participants = people.compactMap { person -> WorkoutHistory.ParticipantSummary? in
            let logs = session.exercises.flatMap(\.participants).filter {
              session.isParticipantActive($0.participantName)
                && matches($0, to: person, among: people)
            }
            guard !logs.isEmpty else { return nil }
            let sets = logs.flatMap(\.sets)
            return WorkoutHistory.ParticipantSummary(
              personID: person.id,
              name: person.name,
              completedSets: sets.filter { $0.isCompleted && !$0.isSkipped }.count,
              totalSets: sets.filter { !$0.isSkipped }.count)
          }
          return WorkoutHistory(
            id: session.id,
            routineName: routines.first(where: { $0.id == session.routineID })?.name
              ?? session.routineName,
            startedAt: session.startedAt,
            participants: participants)
        }
    }

    private static func matches(
      _ participant: ParticipantLog,
      to person: PersonProfile,
      among people: [PersonProfile]
    ) -> Bool {
      if let personID = participant.personID { return personID == person.id }
      let nameMatches = people.filter {
        $0.name.caseInsensitiveCompare(participant.participantName) == .orderedSame
      }
      return nameMatches.count == 1 && nameMatches.first?.id == person.id
    }
  #endif
}

#if os(iOS)
  extension KidsWatchSnapshot {
    func forPerson(_ personID: UUID) -> KidsWatchSnapshot? {
      let personalCards = participants.filter { $0.personID == personID }
      guard !personalCards.isEmpty else { return nil }
      var snapshot = self
      snapshot.participants = personalCards
      snapshot.progress = (progress ?? []).filter { $0.personID == personID }
      snapshot.recentWorkouts = (recentWorkouts ?? []).compactMap { workout in
        var personalWorkout = workout
        personalWorkout.participants = workout.participants.filter { $0.personID == personID }
        return personalWorkout.participants.isEmpty ? nil : personalWorkout
      }
      return snapshot
    }
  }

  extension Array {
    fileprivate var only: Element? { count == 1 ? first : nil }
  }
#endif

struct KidsWatchProgressSnapshot: Codable, Equatable {
  var updatedAt: Date
  var progress: [KidsWatchSnapshot.PersonProgress]
  var recentWorkouts: [KidsWatchSnapshot.WorkoutHistory]

  func forPerson(_ personID: UUID) -> KidsWatchProgressSnapshot {
    KidsWatchProgressSnapshot(
      updatedAt: updatedAt,
      progress: progress.filter { $0.personID == personID },
      recentWorkouts: recentWorkouts.compactMap { workout in
        var personalWorkout = workout
        personalWorkout.participants = workout.participants.filter { $0.personID == personID }
        return personalWorkout.participants.isEmpty ? nil : personalWorkout
      })
  }
}
