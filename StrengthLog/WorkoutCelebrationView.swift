import SwiftUI

struct WorkoutCelebrationSummary: Identifiable {
  struct PersonalRecord: Identifiable {
    let id: String
    let exerciseName: String
    let value: Double
    let unitLabel: String
  }

  struct PersonSummary: Identifiable {
    let id: String
    let name: String
    let colorHex: String
    let workoutVolume: Double
    let completedSetCount: Int
    let recentWorkoutCount: Int
    let recentVolume: Double
    let personalRecords: [PersonalRecord]
  }

  let id: UUID
  let routineName: String
  let completedAt: Date
  let duration: TimeInterval?
  let people: [PersonSummary]
  let totalVolume: Double
  let recentWorkoutCount: Int
  let recentVolume: Double
  let message: String

  static func make(
    session: WorkoutSession,
    allSessions: [WorkoutSession],
    routineName: String,
    colorHexByName: [String: String]
  ) -> WorkoutCelebrationSummary {
    let history = allSessions.filter { $0.deletedAt == nil }
    let previousHistory = history.filter { $0.id != session.id }
    let currentAchievements = PersonalRecords.achievements(in: history)
      .filter { $0.sessionID == session.id }
    let previousAchievements = PersonalRecords.achievements(in: previousHistory)
    let recentCutoff = session.startedAt.addingTimeInterval(-28 * 24 * 60 * 60)
    let recentSessions = history.filter {
      !$0.isActive && $0.startedAt >= recentCutoff && $0.startedAt <= session.startedAt
    }

    let people = session.participantNames.map { name in
      let personalRecords =
        currentAchievements
        .filter { $0.personName.caseInsensitiveCompare(name) == .orderedSame }
        .filter { achievement in
          let previousBest =
            previousAchievements
            .filter {
              $0.personName.caseInsensitiveCompare(achievement.personName) == .orderedSame
                && $0.exerciseKey == achievement.exerciseKey
            }
            .map(\.value)
            .max()
          return previousBest == nil || achievement.value > (previousBest ?? 0)
        }
        .sorted {
          $0.exerciseName.localizedCaseInsensitiveCompare($1.exerciseName) == .orderedAscending
        }
        .map { achievement in
          PersonalRecord(
            id: achievement.id,
            exerciseName: achievement.exerciseName,
            value: achievement.value,
            unitLabel: session.exercises.first {
              PersonalRecords.key(for: $0) == achievement.exerciseKey
            }.map { $0.unit == .repetitions ? $0.targetLabel : $0.unit.label } ?? "lb")
        }
      let personSessions = recentSessions.filter {
        $0.isParticipantActive(name)
      }
      let colorHex =
        colorHexByName.first {
          $0.key.caseInsensitiveCompare(name) == .orderedSame
        }?.value ?? "FF5A45"
      return PersonSummary(
        id: name.lowercased(),
        name: name,
        colorHex: colorHex,
        workoutVolume: poundsVolume(in: session, for: name),
        completedSetCount: completedSetCount(in: session, for: name),
        recentWorkoutCount: personSessions.count,
        recentVolume: personSessions.reduce(0) {
          $0 + poundsVolume(in: $1, for: name)
        },
        personalRecords: personalRecords)
    }
    let totalVolume = people.reduce(0) { $0 + $1.workoutVolume }
    let recentVolume = people.reduce(0) { $0 + $1.recentVolume }
    let recentWorkoutCount = recentSessions.count
    let message: String
    if currentAchievements.isEmpty {
      message = "Workout complete. Showing up is a win."
    } else if people.reduce(0, { $0 + $1.personalRecords.count }) > 0 {
      message = "Personal records are on the board. Keep that momentum going."
    } else if totalVolume > 0 {
      message = "That work counts. You built another strong session."
    } else {
      message = "Workout complete. Every session moves you forward."
    }
    return WorkoutCelebrationSummary(
      id: session.id,
      routineName: routineName,
      completedAt: session.endedAt ?? .now,
      duration: session.workoutDuration,
      people: people,
      totalVolume: totalVolume,
      recentWorkoutCount: recentWorkoutCount,
      recentVolume: recentVolume,
      message: message)
  }

  private static func poundsVolume(in session: WorkoutSession, for name: String) -> Double {
    session.exercises.reduce(0) { $0 + $1.completedPoundsVolume(for: name) }
  }

  private static func completedSetCount(in session: WorkoutSession, for name: String) -> Int {
    session.exercises.flatMap(\.participants).filter {
      session.isParticipantActive($0.participantName)
        && $0.participantName.caseInsensitiveCompare(name) == .orderedSame
    }.flatMap(\.sets).filter { $0.isCompleted && !$0.isSkipped }.count
  }
}

struct WorkoutCelebrationView: View {
  let summary: WorkoutCelebrationSummary
  let onDone: () -> Void

  var body: some View {
    ZStack {
      Theme.navy.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          hero
          workoutSummary
          recentMomentum
          encouragement
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 110)
      }
      .scrollIndicators(.hidden)
    }
    .safeAreaInset(edge: .bottom) {
      Button(action: onDone) {
        Text("Back to Workout Home")
          .font(.headline)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(Theme.coral)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .background(.ultraThinMaterial)
      .accessibilityIdentifier("workout-celebration-done")
    }
  }

  private var hero: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: "party.popper.fill")
        .font(.system(size: 38, weight: .bold))
        .foregroundStyle(Theme.coral)
      Text("Workout complete")
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
      Text(summary.message)
        .font(.title3.weight(.medium))
        .foregroundStyle(.white.opacity(0.88))
      VStack(alignment: .leading, spacing: 4) {
        Text(summary.routineName)
          .font(.headline)
        Text(summary.completedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .foregroundStyle(.white)
    }
  }

  private var workoutSummary: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionEyebrow(text: "This workout")
        .foregroundStyle(.white.opacity(0.65))
      HStack(spacing: 10) {
        celebrationStat(
          title: "Total volume",
          value: "\(summary.totalVolume.tidy) lb",
          detail: "lb × reps")
        celebrationStat(
          title: "Duration",
          value: summary.duration?.workoutDurationText ?? "—",
          detail: "start to last set")
      }
      ForEach(summary.people) { person in
        personWorkoutCard(person)
      }
    }
  }

  private var recentMomentum: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionEyebrow(text: "Recent momentum · 4 weeks")
        .foregroundStyle(.white.opacity(0.65))
      HStack(spacing: 10) {
        celebrationStat(
          title: "Workouts",
          value: "\(summary.recentWorkoutCount)",
          detail: "completed sessions")
        celebrationStat(
          title: "Volume",
          value: "\(summary.recentVolume.tidy) lb",
          detail: "lb × reps")
      }
      ForEach(summary.people) { person in
        HStack(spacing: 12) {
          InitialBadge(name: person.name, colorHex: person.colorHex, size: 34)
          VStack(alignment: .leading, spacing: 2) {
            Text(person.name)
              .font(.headline)
              .foregroundStyle(.white)
              .accessibilityIdentifier("workout-celebration-recent-name-\(person.id)")
            Text(
              "\(person.recentWorkoutCount) workout\(person.recentWorkoutCount == 1 ? "" : "s") · \(person.recentVolume.tidy) lb"
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.72))
          }
          Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("workout-celebration-recent-\(person.id)")
      }
    }
  }

  private func personWorkoutCard(_ person: WorkoutCelebrationSummary.PersonSummary) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        InitialBadge(name: person.name, colorHex: person.colorHex, size: 38)
        VStack(alignment: .leading, spacing: 2) {
          Text(person.name)
            .font(.headline)
            .foregroundStyle(.white)
            .accessibilityIdentifier("workout-celebration-person-name-\(person.id)")
          Text(
            "\(person.completedSetCount) completed set\(person.completedSetCount == 1 ? "" : "s")"
          )
          .font(.caption)
          .foregroundStyle(.white.opacity(0.68))
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(person.workoutVolume.tidy) lb")
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(Color(hex: person.colorHex))
          Text("volume")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.62))
        }
      }
      if person.personalRecords.isEmpty {
        Label("No new personal records this time", systemImage: "checkmark.circle")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.72))
      } else {
        VStack(alignment: .leading, spacing: 6) {
          Label(
            "New personal record\(person.personalRecords.count == 1 ? "" : "s")",
            systemImage: "trophy.fill"
          )
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.prYellow)
          ForEach(person.personalRecords) { record in
            HStack {
              Text(record.exerciseName)
                .lineLimit(1)
              Spacer()
              Text("\(record.value.tidy) \(record.unitLabel)")
                .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.86))
          }
        }
      }
    }
    .padding(14)
    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(hex: person.colorHex).opacity(0.32), lineWidth: 1)
    }
    .accessibilityIdentifier("workout-celebration-person-\(person.id)")
  }

  private func celebrationStat(title: String, value: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.68))
      Text(value)
        .font(.title3.bold().monospacedDigit())
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.52))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
  }

  private var encouragement: some View {
    VStack(spacing: 8) {
      Text("Keep chasing the next one.")
        .font(.headline)
        .foregroundStyle(.white)
      Text("Your recent work is adding up.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.68))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
  }
}
