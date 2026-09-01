import SwiftData
import SwiftUI

struct HomeView: View {
  @Environment(\.modelContext) private var context
  let isCoveredByActiveWorkout: Bool
  let onOpenWorkout: (WorkoutSession) -> Void
  let onReturnHome: () -> Void
  @Query(filter: #Predicate<Routine> { $0.deletedAt == nil }, sort: \Routine.createdAt)
  private var routines: [Routine]
  @Query private var allRoutines: [Routine]
  @Query(filter: #Predicate<WorkoutSession> { $0.isActive && $0.deletedAt == nil })
  private var activeSessions: [WorkoutSession]
  @Query(
    filter: #Predicate<WorkoutSession> { $0.deletedAt == nil },
    sort: \WorkoutSession.startedAt,
    order: .reverse)
  private var sessions: [WorkoutSession]
  @Query(filter: #Predicate<WorkoutSession> { $0.deletedAt != nil })
  private var deletedSessions: [WorkoutSession]
  @Query private var catalog: [Exercise]
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  init(
    isCoveredByActiveWorkout: Bool = false,
    onOpenWorkout: @escaping (WorkoutSession) -> Void = { _ in },
    onReturnHome: @escaping () -> Void = {}
  ) {
    self.isCoveredByActiveWorkout = isCoveredByActiveWorkout
    self.onOpenWorkout = onOpenWorkout
    self.onReturnHome = onReturnHome
  }

  var body: some View {
    Group {
      if isCoveredByActiveWorkout {
        Color.clear
      } else {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              let recentSessions = recentlyCompletedSessions(at: timeline.date)
              if !recentSessions.isEmpty {
                recentResumeSection(sessions: recentSessions)
              }
              if let activeSession = activeSessions.first {
                TimelineView(.animation(minimumInterval: 1, paused: false)) { activeTimeline in
                  activeWorkoutCard(activeSession, now: activeTimeline.date)
                }
              }
              routineSection
              activityCard
              if !deletedSessions.isEmpty { deletedWorkoutsLink }
            }
            .padding()
          }
        }
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Workout")
    .toolbarTitleDisplayMode(.large)
  }

  private func recentlyCompletedSessions(at now: Date) -> [WorkoutSession] {
    let cutoff = now.addingTimeInterval(-WorkoutSession.resumeWindow)
    return sessions.filter { session in
      !session.isActive && session.endedAt != nil && session.startedAt >= cutoff
    }
  }

  private func recentResumeSection(sessions: [WorkoutSession]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Resume workout")
        .font(.title3.bold())
      Text("Continue a workout started within the last two hours.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      ForEach(sessions) { session in
        Button {
          resume(session)
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.forward.circle.fill")
              .font(.title3)
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .background(Theme.coral, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
              Text(routineName(for: session))
                .font(.headline)
                .foregroundStyle(.primary)
              Text(resumeSummary(for: session))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.bold())
              .foregroundStyle(.secondary)
          }
          .padding(14)
          .background(Theme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("resume-completed-workout-\(session.id.uuidString)")
      }
    }
  }

  private func activeWorkoutCard(_ session: WorkoutSession, now: Date) -> some View {
    Button {
      onOpenWorkout(session)
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "figure.strengthtraining.traditional")
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background(Theme.coral, in: Circle())
        VStack(alignment: .leading, spacing: 3) {
          Text("Active workout")
            .font(.headline)
            .foregroundStyle(.primary)
          Text(routineName(for: session))
            .font(.subheadline)
            .foregroundStyle(.secondary)
          if let duration = session.workoutDuration(at: now) {
            Text("Length \(duration.workoutDurationText)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          if let remaining = session.restTimerRemaining(at: max(now, .now)) {
            Text("Rest \(Int(ceil(remaining)))s")
              .font(.caption.monospacedDigit().weight(.semibold))
              .foregroundStyle(Theme.coral)
          }
        }
        Spacer()
        Image(systemName: "chevron.up")
          .font(.caption.bold())
          .foregroundStyle(.secondary)
      }
      .padding(14)
      .background(Theme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("resume-active-workout")
  }

  private var activityCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      ActivityGrid(sessions: sessions, routines: allRoutines, onReturnHome: onReturnHome)
    }
    .padding()
    .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private var routineSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Quick start").font(.title3.bold())
        Spacer()
        NavigationLink("All routines") { RoutinesView(onOpenWorkout: onOpenWorkout) }
          .font(.subheadline.weight(.semibold))
      }
      if routines.isEmpty {
        NavigationLink {
          RoutinesView(onOpenWorkout: onOpenWorkout)
        } label: {
          HStack(spacing: 14) {
            Image(systemName: "plus")
              .font(.title2.bold())
              .foregroundStyle(Theme.coral)
              .frame(width: 48, height: 48)
              .background(Theme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
              Text("Create your first routine").font(.headline)
              Text("Add exercises and set up your crew")
                .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
          }
          .padding(14)
          .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
      } else {
        ForEach(routines.prefix(3)) { routine in
          Button {
            if let session = WorkoutSessionStarter.start(
              routine: routine, people: people, sessions: sessions, catalog: catalog, in: context)
            {
              onOpenWorkout(session)
            }
          } label: {
            HStack(spacing: 14) {
              Image(systemName: routine.symbol)
                .font(.title2)
                .foregroundStyle(Color(hex: routine.colorHex))
                .frame(width: 48, height: 48)
                .background(
                  Color(hex: routine.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 14)
                )
              VStack(alignment: .leading, spacing: 4) {
                Text(routine.name).font(.headline).foregroundStyle(.primary)
                Text(exerciseCountText(routine.exercises.count))
                  .font(.subheadline).foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: "play.fill")
                .foregroundStyle(.white)
                .padding(11)
                .background(Theme.coral, in: Circle())
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("start-routine-\(routine.name)")
        }
      }
    }
  }

  private var deletedWorkoutsLink: some View {
    NavigationLink {
      DeletedWorkoutsView()
    } label: {
      Label("Deleted Workouts (\(deletedSessions.count))", systemImage: "trash")
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
  }

  private func routineName(for session: WorkoutSession) -> String {
    allRoutines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }

  private func resumeSummary(for session: WorkoutSession) -> String {
    let sets = "\(session.completedSetCount) of \(session.totalSetCount) sets completed"
    let started = "Started \(session.startedAt.formatted(date: .omitted, time: .shortened))"
    if let duration = session.workoutDuration {
      return "\(sets) · \(started) · Length \(duration.workoutDurationText)"
    }
    return "\(sets) · \(started)"
  }

  private func resume(_ session: WorkoutSession) {
    session.endedAt = nil
    session.isActive = true
    session.restTimerStartedAt = nil
    session.restTimerDurationSeconds = nil
    try? context.save()
    LiveActivityManager.shared.end()
    onOpenWorkout(session)
  }
}

struct DeletedWorkoutsView: View {
  @Environment(\.modelContext) private var context
  @Query private var routines: [Routine]
  @Query(
    filter: #Predicate<WorkoutSession> { $0.deletedAt != nil },
    sort: \WorkoutSession.startedAt,
    order: .reverse)
  private var sessions: [WorkoutSession]

  var body: some View {
    Group {
      if sessions.isEmpty {
        ContentUnavailableView(
          "No Deleted Workouts",
          systemImage: "trash",
          description: Text("Deleted workouts will appear here and can be restored."))
      } else {
        List(sessions) { session in
          HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
              .foregroundStyle(Theme.navy)
              .frame(width: 38, height: 38)
              .background(Theme.mint.opacity(0.24), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
              Text(routineName(for: session)).font(.headline)
              if let deletedAt = session.deletedAt {
                Text("Deleted \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            Button("Restore") { restore(session) }
              .buttonStyle(.bordered)
              .accessibilityIdentifier("restore-workout-\(routineName(for: session))")
          }
          .padding(.vertical, 3)
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Restore", systemImage: "arrow.uturn.backward") { restore(session) }
              .tint(Theme.mint)
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Deleted Workouts")
  }

  private func restore(_ session: WorkoutSession) {
    session.deletedAt = nil
    try? context.save()
  }

  private func routineName(for session: WorkoutSession) -> String {
    routines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }
}

struct ActivityGrid: View {
  let sessions: [WorkoutSession]
  let routines: [Routine]
  let onReturnHome: () -> Void
  @State private var periodOffset = 0
  @State private var personalRecordCountsBySessionID: [UUID: Int] = [:]
  private let calendar = Calendar.current
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
  private let weekdayNames = [
    (short: "S", full: "Sunday"),
    (short: "M", full: "Monday"),
    (short: "T", full: "Tuesday"),
    (short: "W", full: "Wednesday"),
    (short: "T", full: "Thursday"),
    (short: "F", full: "Friday"),
    (short: "S", full: "Saturday"),
  ]

  private var today: Date { calendar.startOfDay(for: .now) }

  private var currentWeekStart: Date {
    let daysFromSunday = calendar.component(.weekday, from: today) - 1
    return calendar.date(byAdding: .day, value: -daysFromSunday, to: today) ?? today
  }

  private var periodStart: Date {
    calendar.date(
      byAdding: .day,
      value: -21 + (periodOffset * 28),
      to: currentWeekStart) ?? currentWeekStart
  }

  private var periodEnd: Date {
    calendar.date(byAdding: .day, value: 27, to: periodStart) ?? periodStart
  }

  private var periodEndExclusive: Date {
    calendar.date(byAdding: .day, value: 28, to: periodStart) ?? periodEnd
  }

  private var calendarDays: [Date] {
    (0..<28).compactMap { calendar.date(byAdding: .day, value: $0, to: periodStart) }
  }

  private var sessionsByDay: [Date: [WorkoutSession]] {
    Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
  }

  /// Personal-record calculation walks every exercise, participant, and set in workout
  /// history. Keep it out of the grid's cell builder: SwiftUI can reevaluate those cells
  /// while Home is covered by the active-workout navigation destination.
  private var personalRecordHistoryRevision: [ActivityHistoryRevision] {
    sessions.map {
      ActivityHistoryRevision(
        sessionID: $0.id,
        startedAt: $0.startedAt,
        endedAt: $0.endedAt,
        isActive: $0.isActive,
        deletedAt: $0.deletedAt)
    }
  }

  private var visibleWorkoutCount: Int {
    sessions.filter { $0.startedAt >= periodStart && $0.startedAt < periodEndExclusive }.count
  }

  private var periodLabel: String {
    let start = periodStart.formatted(.dateTime.month(.abbreviated).day())
    let end = periodEnd.formatted(.dateTime.month(.abbreviated).day())
    return "\(start) – \(end)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          SectionEyebrow(text: "Last 4 weeks")
          Text(
            "\(visibleWorkoutCount) workout\(visibleWorkoutCount == 1 ? "" : "s")"
          )
          .font(.title3.bold())
          Text(periodLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        HStack(spacing: 8) {
          Button {
            periodOffset -= 1
          } label: {
            Image(systemName: "chevron.left")
              .frame(width: 30, height: 30)
          }
          .buttonStyle(.bordered)
          .accessibilityLabel("Previous 4 weeks")
          .accessibilityIdentifier("activity-previous-period")

          Button {
            periodOffset += 1
          } label: {
            Image(systemName: "chevron.right")
              .frame(width: 30, height: 30)
          }
          .buttonStyle(.bordered)
          .disabled(periodOffset >= 0)
          .accessibilityLabel("Next 4 weeks")
          .accessibilityIdentifier("activity-next-period")
        }
      }

      LazyVGrid(columns: columns, spacing: 4) {
        ForEach(weekdayNames, id: \.full) { weekday in
          Text(weekday.short)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(weekday.full)
        }

        ForEach(calendarDays, id: \.self) { day in
          if day <= today {
            let daySessions = sessionsByDay[day, default: []]
            let markers = routineMarkers(for: daySessions)
            let participantCount = participantCount(for: daySessions)
            let personalRecordCount = daySessions.reduce(into: 0) { count, session in
              count += personalRecordCountsBySessionID[session.id, default: 0]
            }
            NavigationLink {
              if daySessions.count > 1 {
                DayWorkoutPickerView(
                  day: day,
                  sessions: daySessions,
                  routines: routines,
                  onReturnHome: onReturnHome)
              } else {
                DayWorkoutSummaryView(
                  day: day,
                  sessions: daySessions,
                  routines: routines,
                  onReturnHome: onReturnHome)
              }
            } label: {
              ActivityDayCell(
                workoutCount: daySessions.count,
                routineMarkers: markers,
                participantCount: participantCount,
                personalRecordCount: personalRecordCount,
                isToday: calendar.isDateInToday(day))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
              "\(day.formatted(date: .abbreviated, time: .omitted)): \(daySessions.count) workout\(daySessions.count == 1 ? "" : "s")"
            )
            .accessibilityValue(
              markers.map(\.name).joined(separator: ", ")
                + (participantCount > 1 ? "; Multiple people" : "")
                + (personalRecordCount > 0
                  ? "; \(personalRecordCount) personal record\(personalRecordCount == 1 ? "" : "s")"
                  : "")
            )
            .accessibilityHint("Shows workout details for this day")
          } else {
            ActivityPaddingDayCell()
              .accessibilityHidden(true)
          }
        }
      }
      .id(periodOffset)
    }
    .task(id: personalRecordHistoryRevision) {
      personalRecordCountsBySessionID = Dictionary(
        grouping: PersonalRecords.achievements(in: sessions), by: \.sessionID
      ).mapValues(\.count)
    }
  }

  private func routineMarkers(for daySessions: [WorkoutSession]) -> [ActivityRoutineMarker] {
    var markers: [ActivityRoutineMarker] = []
    for session in daySessions.sorted(by: { $0.startedAt < $1.startedAt }) {
      let routine = routines.first(where: { $0.id == session.routineID })
      let name = routine?.name ?? session.exercises.first?.exerciseName ?? "Workout"
      let symbol = routine?.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
      let marker = ActivityRoutineMarker(
        id: session.routineID,
        name: name,
        symbol: symbol?.isEmpty == false ? symbol : nil,
        acronym: acronym(for: name),
        colorHex: routine?.colorHex ?? "FF5A45")
      if !markers.contains(where: { $0.id == marker.id }) { markers.append(marker) }
    }
    return markers
  }

  private func participantCount(for daySessions: [WorkoutSession]) -> Int {
    Set(
      daySessions.flatMap(\.participantNames).map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      }
    ).count
  }

  private func acronym(for name: String) -> String {
    let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
    if words.count > 1 {
      return words.prefix(3).compactMap(\.first).map(String.init).joined().uppercased()
    }
    return String(words.first?.prefix(2) ?? "W").uppercased()
  }
}

private struct ActivityHistoryRevision: Hashable {
  let sessionID: UUID
  let startedAt: Date
  let endedAt: Date?
  let isActive: Bool
  let deletedAt: Date?
}

private struct ActivityRoutineMarker: Identifiable {
  let id: UUID
  let name: String
  let symbol: String?
  let acronym: String
  let colorHex: String
}

private struct ActivityPaddingDayCell: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
      .fill(Color.secondary.opacity(0.04))
      .aspectRatio(1.25, contentMode: .fit)
  }
}

private struct ActivityDayCell: View {
  let workoutCount: Int
  let routineMarkers: [ActivityRoutineMarker]
  let participantCount: Int
  let personalRecordCount: Int
  let isToday: Bool

  private var accentColor: Color {
    routineMarkers.first.map { Color(hex: $0.colorHex) } ?? Theme.coral
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(workoutCount == 0 ? Color.secondary.opacity(0.10) : accentColor.opacity(0.16))
        .overlay {
          if isToday {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(accentColor, lineWidth: 1.5)
          }
        }

      if workoutCount > 0 {
        HStack(spacing: 3) {
          ForEach(routineMarkers.prefix(3)) { marker in
            if let symbol = marker.symbol {
              Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: marker.colorHex))
            } else {
              Text(marker.acronym)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Color(hex: marker.colorHex))
            }
          }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .padding(.horizontal, workoutCount > 1 ? 10 : 4)
      }

      if workoutCount > 1 {
        Text("\(workoutCount)")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.white)
          .frame(minWidth: 16, minHeight: 16)
          .background(accentColor, in: Circle())
          .padding(3)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      }

      if participantCount > 1 {
        Image(systemName: "person.2.fill")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(accentColor)
          .frame(width: 16, height: 16)
          .background(.background.opacity(0.92), in: Circle())
          .padding(3)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .accessibilityHidden(true)
      }

      if personalRecordCount > 0 {
        HStack(spacing: 3) {
          Image(systemName: "trophy.fill")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(Theme.prYellow)
            .frame(width: 14, height: 14)
            .background(.background.opacity(0.92), in: Circle())
          if personalRecordCount > 0 {
            Text("+\(personalRecordCount)")
              .font(.system(size: 7, weight: .bold))
              .foregroundStyle(.black)
              .padding(.horizontal, 2)
              .background(Theme.prYellow, in: Capsule())
          }
        }
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityHidden(true)
      }
    }
    .aspectRatio(1.25, contentMode: .fit)
    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

private struct DayWorkoutPickerView: View {
  @Environment(\.dismiss) private var dismiss
  let day: Date
  let sessions: [WorkoutSession]
  let routines: [Routine]
  let onReturnHome: () -> Void

  private var orderedSessions: [WorkoutSession] {
    sessions.filter { $0.deletedAt == nil }.sorted { $0.startedAt < $1.startedAt }
  }

  var body: some View {
    List(orderedSessions) { session in
      NavigationLink {
        DayWorkoutSummaryView(
          day: day,
          sessions: [session],
          routines: routines,
          onReturnHome: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
              dismiss()
              onReturnHome()
            }
          })
      } label: {
        workoutRow(for: session)
      }
      .accessibilityIdentifier("select-completed-workout-\(session.id.uuidString)")
    }
    .listStyle(.insetGrouped)
    .navigationTitle(
      "\(orderedSessions.count) Workout\(orderedSessions.count == 1 ? "" : "s")"
    )
    .navigationBarTitleDisplayMode(.inline)
  }

  private func workoutRow(for session: WorkoutSession) -> some View {
    let routine = routines.first(where: { $0.id == session.routineID })
    let name = routine?.name ?? session.exercises.first?.exerciseName ?? "Workout"
    let symbol = routine?.symbol ?? "dumbbell.fill"
    let color = Color(hex: routine?.colorHex ?? "FF5A45")
    let peopleCount = session.participantNames.count

    return HStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundStyle(color)
        .frame(width: 44, height: 44)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

      VStack(alignment: .leading, spacing: 2) {
        Text(name)
          .font(.headline)
          .foregroundStyle(.primary)
        Group {
          Text(session.startedAt.formatted(date: .omitted, time: .shortened))
          Text("\(peopleCount) \(peopleCount == 1 ? "person" : "people")")
          Text(
            "\(session.completedSetCount) of \(session.totalSetCount) sets completed"
          )
          if let duration = session.workoutDuration {
            Text("Length \(duration.workoutDurationText)")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct DayWorkoutSummaryView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query(sort: \PersonProfile.sortOrder) private var people: [PersonProfile]
  @Query(filter: #Predicate<WorkoutSession> { $0.deletedAt == nil })
  private var workoutHistory: [WorkoutSession]
  let day: Date
  let sessions: [WorkoutSession]
  let routines: [Routine]
  let onReturnHome: () -> Void
  @State private var didDeleteUncompletedSets = false
  @State private var pendingWorkoutDeletion: WorkoutSession?
  @State private var showingDestructiveConfirmation = false

  private var orderedSessions: [WorkoutSession] {
    sessions.filter { $0.deletedAt == nil }.sorted { $0.startedAt < $1.startedAt }
  }

  var body: some View {
    Group {
      if orderedSessions.isEmpty {
        ContentUnavailableView(
          "No Workouts",
          systemImage: "calendar",
          description: Text("There are no workouts recorded for this day."))
      } else {
        List {
          ForEach(orderedSessions) { session in
            Section {
              completedRoutineTile(for: session)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

              completedWorkoutBody(for: session)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
          }

          if uncompletedSetCount > 0 && !didDeleteUncompletedSets {
            Section {
              uncompletedSetsCleanup
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
          }

          Color.clear
            .frame(height: 56)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle(summaryTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if orderedSessions.count == 1, let session = orderedSessions.first {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Delete Workout", systemImage: "trash", role: .destructive) {
            requestWorkoutDelete(session)
          }
          .accessibilityIdentifier("delete-completed-workout")
        }
      }
    }
    .alert(
      pendingWorkoutDeletion == nil ? "Delete uncompleted sets?" : "Delete workout?",
      isPresented: $showingDestructiveConfirmation
    ) {
      if pendingWorkoutDeletion == nil {
        Button("Delete Sets", role: .destructive, action: deleteAllUncompletedSets)
      } else {
        Button("Delete Workout", role: .destructive, action: deletePendingWorkout)
      }
      Button("Cancel", role: .cancel) { pendingWorkoutDeletion = nil }
    } message: {
      if let session = pendingWorkoutDeletion {
        Text(
          "This moves the \(routineName(for: session)) workout from \(session.startedAt.formatted(date: .abbreviated, time: .shortened)) to Deleted Workouts, where it can be restored."
        )
      } else {
        Text(
          "This removes \(uncompletedSetCount) uncompleted set\(uncompletedSetCount == 1 ? "" : "s") from this workout. Completed sets will stay intact."
        )
      }
    }
  }

  private var summaryTitle: String {
    guard orderedSessions.count == 1, let session = orderedSessions.first else {
      return "\(orderedSessions.count) Workouts"
    }
    return routineName(for: session)
  }

  private var uncompletedSetCount: Int {
    orderedSessions.reduce(0) { count, session in
      count
        + session.exercises.flatMap(\.participants)
        .filter { session.isParticipantActive($0.participantName) }
        .flatMap(\.sets)
        .filter { !$0.isCompleted && !$0.isSkipped }
        .count
    }
  }

  private func deleteAllUncompletedSets() {
    for session in orderedSessions {
      for exercise in session.exercises {
        for participant in exercise.participants
        where session.isParticipantActive(participant.participantName) {
          let uncompletedSets = participant.sets.filter { !$0.isCompleted && !$0.isSkipped }
          let uncompletedIDs = Set(uncompletedSets.map(\.id))
          participant.sets.removeAll { uncompletedIDs.contains($0.id) }
          for set in uncompletedSets { context.delete(set) }
          for (index, set) in participant.orderedSets.enumerated() { set.sortOrder = index }
        }
      }
    }
    try? context.save()
    showingDestructiveConfirmation = false
    didDeleteUncompletedSets = true
  }

  private func completedWorkoutBody(for session: WorkoutSession) -> some View {
    let exercises = completedExercises(in: session)
    let achievements = PersonalRecords.achievements(in: workoutHistory)
    let sessionAchievements = achievements.filter { $0.sessionID == session.id }

    return VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Label(
          session.startedAt.formatted(date: .omitted, time: .shortened),
          systemImage: "clock")
        Label(peopleSummary(for: session), systemImage: "person.2")
        Label(
          "\(session.completedSetCount) set\(session.completedSetCount == 1 ? "" : "s") completed",
          systemImage: "checkmark.circle")
        if let duration = session.workoutDuration {
          Label("Length \(duration.workoutDurationText)", systemImage: "hourglass")
        }
        if !sessionAchievements.isEmpty {
          Label(
            "\(sessionAchievements.count) personal record\(sessionAchievements.count == 1 ? "" : "s")",
            systemImage: "trophy.fill"
          )
          .foregroundStyle(Theme.prYellow)
        }
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)

      ForEach(Array(exercises.enumerated()), id: \.element.id) { exerciseIndex, exercise in
        Divider()

        VStack(alignment: .leading, spacing: 12) {
          Text(exercise.exerciseName)
            .font(.headline)

          ForEach(
            exercise.participants.filter {
              session.isParticipantActive($0.participantName)
                && $0.sets.contains(where: \.isCompleted)
            }
          ) { participant in
            let participantColor = color(for: participant.participantName)
            let completedSets = participant.orderedSets.enumerated().filter(\.element.isCompleted)
            VStack(alignment: .leading, spacing: 7) {
              Text(participant.participantName)
                .font(.subheadline.weight(.semibold))

              ForEach(completedSets, id: \.element.id) { index, set in
                let isPersonalRecord = sessionAchievements.contains {
                  $0.setID == set.id
                    && $0.personName.caseInsensitiveCompare(participant.participantName)
                      == .orderedSame
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text("Set \(index + 1)")
                    .foregroundStyle(.secondary)
                  Spacer(minLength: 8)
                  Text(setSummary(set, participant: participant, unit: exercise.unit))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                  ZStack(alignment: .topTrailing) {
                    Image(systemName: "checkmark")
                      .font(.caption2.bold())
                      .foregroundStyle(.white)
                      .frame(width: 26, height: 24)
                      .background(
                        participantColor,
                        in: RoundedRectangle(cornerRadius: 7)
                      )
                      .accessibilityLabel("Completed")
                    if isPersonalRecord {
                      Image(systemName: "trophy.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.prYellow)
                        .background(Color(.systemBackground), in: Circle())
                        .offset(x: 5, y: -5)
                        .accessibilityLabel("Personal record")
                    }
                  }
                }
                .font(.caption)
              }
            }
          }
        }
        .padding(.bottom, exerciseIndex == exercises.count - 1 ? 0 : 2)
      }
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding(.bottom, 4)
  }

  private var uncompletedSetsCleanup: some View {
    Button(role: .destructive) {
      pendingWorkoutDeletion = nil
      showingDestructiveConfirmation = true
    } label: {
      Label("Delete Uncompleted Sets", systemImage: "trash")
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .accessibilityIdentifier("delete-uncompleted-sets")
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding(.vertical, 4)
  }

  private func completedRoutineTile(for session: WorkoutSession) -> some View {
    let routine = routines.first(where: { $0.id == session.routineID })
    let name = routine?.name ?? "Unknown Routine"
    let symbol = routine?.symbol ?? "dumbbell.fill"
    let color = Color(hex: routine?.colorHex ?? "FF5A45")
    let exerciseCount = completedExercises(in: session).count

    return HStack(spacing: 14) {
      Image(systemName: symbol)
        .font(.title2)
        .foregroundStyle(color)
        .frame(width: 48, height: 48)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(name)
          .font(.headline)
          .foregroundStyle(.primary)
        Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding(.vertical, 4)
  }

  private func routineName(for session: WorkoutSession) -> String {
    routines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }

  private func completedExercises(in session: WorkoutSession) -> [ExerciseLog] {
    session.exercises
      .filter { exercise in
        exercise.participants.contains { participant in
          session.isParticipantActive(participant.participantName)
            && participant.sets.contains(where: \.isCompleted)
        }
      }
      .sorted(by: { $0.sortOrder < $1.sortOrder })
  }

  private func requestWorkoutDelete(_ session: WorkoutSession) {
    pendingWorkoutDeletion = session
    showingDestructiveConfirmation = true
  }

  private func deletePendingWorkout() {
    guard let session = pendingWorkoutDeletion else { return }
    session.deletedAt = .now
    session.isActive = false
    session.endedAt = session.endedAt ?? .now
    try? context.save()
    pendingWorkoutDeletion = nil
    showingDestructiveConfirmation = false
    dismiss()
    onReturnHome()
  }

  private func peopleSummary(for session: WorkoutSession) -> String {
    let names = session.participantNames
    return names.isEmpty ? "No people recorded" : names.joined(separator: ", ")
  }

  private func color(for participantName: String) -> Color {
    let colorHex =
      people.first {
        $0.name.caseInsensitiveCompare(participantName) == .orderedSame
      }?.colorHex ?? "FF5A45"
    return Color(hex: colorHex)
  }

  private func setSummary(
    _ set: WorkoutSet, participant: ParticipantLog, unit: TrackingUnit
  ) -> String {
    var parts: [String] = []
    if let measurement = set.measurement
      ?? (participant.measurement == 0 ? nil : participant.measurement)
    {
      parts.append("\(measurement.tidy) \(unit.label)")
    }
    if set.reps > 0 { parts.append("\(set.reps) reps") }
    if let distance = set.distanceMiles { parts.append("\(distance.tidy) mi") }
    if let duration = set.durationSeconds { parts.append("\(duration.tidy) sec") }
    if let rpe = set.rpe { parts.append("RPE \(rpe.tidy)") }
    return parts.isEmpty ? "No metrics" : parts.joined(separator: " × ")
  }
}
