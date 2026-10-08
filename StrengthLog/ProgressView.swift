import Charts
import SwiftData
import SwiftUI

struct ProgressView: View {
  @Environment(\.modelContext) private var context
  @Query private var routines: [Routine]
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @Query(
    filter: #Predicate<WorkoutSession> { $0.deletedAt == nil },
    sort: \WorkoutSession.startedAt,
    order: .reverse)
  private var sessions: [WorkoutSession]
  @State private var pendingDeletion: WorkoutSession?
  @State private var showingDeleteConfirmation = false
  @State private var selectedRange: ProgressRange = .twelveWeeks

  private var filteredSessions: [WorkoutSession] {
    sessions.filter { session in
      let matchesRange = selectedRange.startDate.map { session.startedAt >= $0 } ?? true
      return matchesRange
    }
  }

  private var chronological: [WorkoutSession] {
    filteredSessions.sorted { $0.startedAt < $1.startedAt }
  }

  var body: some View {
    Group {
      if sessions.isEmpty {
        EmptyStateView(
          symbol: "chart.xyaxis.line", title: "Your progress starts here",
          message: "Start a routine to see volume and workout history.")
      } else {
        List {
          Section("Training volume") {
            if chronological.isEmpty {
              Text("No workouts match these filters.")
                .foregroundStyle(.secondary)
            } else {
              Chart {
                ForEach(volumePoints) { point in
                  LineMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Volume", point.volume),
                    series: .value("Person", point.personName)
                  )
                  .foregroundStyle(by: .value("Person", point.personName))
                  .interpolationMethod(.catmullRom)
                  PointMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Volume", point.volume)
                  )
                  .foregroundStyle(by: .value("Person", point.personName))
                }
              }
              .chartForegroundStyleScale(
                domain: progressPeople,
                range: progressPeople.map { Color(hex: colorHex(for: $0)) }
              )
              .chartLegend(position: .bottom, alignment: .leading)
              .frame(height: 220)
              .accessibilityIdentifier("progress-volume-chart")
              .chartYAxisLabel("lb × reps")
              .chartYScale(domain: 0...max(volumePoints.map(\.volume).max() ?? 1, 1))

            }
          }

          Section("Workout history") {
            if filteredSessions.isEmpty {
              Text("No workouts match these filters.")
                .foregroundStyle(.secondary)
            } else {
              ForEach(filteredSessions) { session in
                NavigationLink {
                  SessionDetailView(session: session)
                } label: {
                  HStack {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(routineName(for: session)).font(.headline)
                      Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    let prCount = personalRecordCounts[session.id] ?? 0
                    if prCount > 0 {
                      PersonalRecordBadge(count: prCount)
                    }
                    Text("\(session.completedSetCount)/\(session.totalSetCount) sets")
                      .font(.caption).foregroundStyle(.secondary)
                  }
                }
                .accessibilityIdentifier("workout-history-\(routineName(for: session))")
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  Button("Delete", systemImage: "trash", role: .destructive) {
                    requestDelete(session)
                  }
                }
              }
              .onDelete(perform: requestDelete)
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Progress")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          ForEach(ProgressRange.allCases) { range in
            Button {
              selectedRange = range
            } label: {
              Label(range.title, systemImage: selectedRange == range ? "checkmark" : "circle")
            }
          }
        } label: {
          Label(selectedRange.title, systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityIdentifier("progress-range-menu")
      }
    }
    .alert(
      "Delete workout?",
      isPresented: $showingDeleteConfirmation
    ) {
      Button("Delete Workout", role: .destructive, action: deletePending)
      Button("Cancel", role: .cancel) { pendingDeletion = nil }
    } message: {
      if let session = pendingDeletion {
        Text(
          "This moves the \(routineName(for: session)) workout from \(session.startedAt.formatted(date: .abbreviated, time: .shortened)) to Deleted Workouts, where it can be restored."
        )
      }
    }
  }

  private var progressPeople: [String] {
    ProgressSummaryBuilder.participantNames(in: filteredSessions, people: people)
  }

  private var volumePoints: [ProgressVolumePoint] {
    ProgressSummaryBuilder.volumePoints(sessions: chronological)
  }

  private var personalRecordCounts: [UUID: Int] {
    ProgressSummaryBuilder.personalRecordCounts(in: sessions)
  }

  private func colorHex(for name: String) -> String {
    ProgressSummaryBuilder.colorHex(for: name, people: people)
  }

  private func requestDelete(_ offsets: IndexSet) {
    guard let offset = offsets.first, filteredSessions.indices.contains(offset) else { return }
    requestDelete(filteredSessions[offset])
  }

  private func requestDelete(_ session: WorkoutSession) {
    pendingDeletion = session
    showingDeleteConfirmation = true
  }

  private func deletePending() {
    guard let session = pendingDeletion else { return }
    session.deletedAt = .now
    session.isActive = false
    session.endedAt = session.endedAt ?? .now
    session.restTimerStartedAt = nil
    session.restTimerDurationSeconds = nil
    _ = saveAndRefreshProgressWidget(context)
    LiveActivityManager.shared.end()
    pendingDeletion = nil
  }

  private func routineName(for session: WorkoutSession) -> String {
    routines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }
}

private enum ProgressRange: String, CaseIterable, Identifiable {
  case twelveWeeks = "12W"
  case oneYear = "1Y"

  var id: Self { self }

  var title: String {
    switch self {
    case .twelveWeeks: "12 weeks"
    case .oneYear: "1 year"
    }
  }

  var startDate: Date? {
    switch self {
    case .twelveWeeks: return Calendar.current.date(byAdding: .weekOfYear, value: -12, to: .now)
    case .oneYear: return Calendar.current.date(byAdding: .year, value: -1, to: .now)
    }
  }
}

private struct PersonalRecordBadge: View {
  let count: Int

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "trophy.fill")
        .font(.caption2.weight(.bold))
      Text("+\(count)")
        .font(.caption2.weight(.bold))
    }
    .foregroundStyle(.black)
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(Theme.prYellow, in: Capsule())
    .fixedSize(horizontal: true, vertical: true)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(count) personal record\(count == 1 ? "" : "s")")
  }
}

struct SessionDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query private var routines: [Routine]
  @Query(filter: #Predicate<WorkoutSession> { $0.deletedAt == nil })
  private var workoutHistory: [WorkoutSession]
  @Bindable var session: WorkoutSession
  @State private var showingDeleteConfirmation = false

  var body: some View {
    List {
      Section {
        LabeledContent(
          "Date", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
        LabeledContent(
          "Length", value: session.workoutDuration?.workoutDurationText ?? "—")
        LabeledContent(
          "Completed", value: "\(session.completedSetCount) of \(session.totalSetCount) sets")
        let personalRecordCount = PersonalRecords.count(for: session, in: workoutHistory)
        if personalRecordCount > 0 {
          Label(
            "\(personalRecordCount) personal record\(personalRecordCount == 1 ? "" : "s")",
            systemImage: "trophy.fill"
          )
          .foregroundStyle(Theme.prYellow)
          .font(.subheadline.weight(.semibold))
        }
        if let notes = session.notes, !notes.isEmpty {
          LabeledContent("Notes", value: notes)
        }
      }
      ForEach(session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })) { exercise in
        Section(exercise.exerciseName) {
          if let notes = exercise.notes, !notes.isEmpty {
            Text(notes).font(.caption).foregroundStyle(.secondary)
          }
          ForEach(exercise.participants.filter { session.isParticipantActive($0.participantName) })
          {
            participant in
            let personalRecordSetIDs = Set(
              PersonalRecords.achievements(in: workoutHistory)
                .filter {
                  $0.sessionID == session.id
                    && $0.exerciseKey == PersonalRecords.key(for: exercise)
                    && $0.personName.caseInsensitiveCompare(participant.participantName)
                      == .orderedSame
                }
                .map(\.setID))
            VStack(alignment: .leading, spacing: 5) {
              Text(participant.participantName).font(.subheadline.bold())
              ForEach(participant.sets.sorted(by: { $0.sortOrder < $1.sortOrder })) { set in
                HStack(spacing: 5) {
                  Text(setText(set, participant: participant, exercise: exercise))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                  if personalRecordSetIDs.contains(set.id) {
                    Image(systemName: "trophy.fill")
                      .font(.caption2)
                      .foregroundStyle(Theme.prYellow)
                      .accessibilityLabel("Personal record")
                  }
                }
              }
            }
          }
        }
      }
    }
    .navigationTitle(routineName)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Open", systemImage: "arrow.right") { open() }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Delete Workout", systemImage: "trash", role: .destructive) {
          showingDeleteConfirmation = true
        }
      }
    }
    .alert(
      "Delete workout?",
      isPresented: $showingDeleteConfirmation
    ) {
      Button("Delete Workout", role: .destructive, action: delete)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This moves the \(routineName) workout from \(session.startedAt.formatted(date: .abbreviated, time: .shortened)) to Deleted Workouts, where it can be restored."
      )
    }
  }

  private func open() {
    session.endedAt = nil
    session.isActive = true
    session.restTimerStartedAt = nil
    session.restTimerDurationSeconds = nil
    _ = saveAndRefreshProgressWidget(context)
    LiveActivityManager.shared.end()
  }

  private func delete() {
    session.deletedAt = .now
    session.isActive = false
    session.endedAt = session.endedAt ?? .now
    session.restTimerStartedAt = nil
    session.restTimerDurationSeconds = nil
    _ = saveAndRefreshProgressWidget(context)
    LiveActivityManager.shared.end()
    dismiss()
  }

  private var routineName: String {
    routines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }

  private func setText(_ set: WorkoutSet, participant: ParticipantLog, exercise: ExerciseLog)
    -> String
  {
    set.summary(
      participant: participant, unit: exercise.unit, repCountingMode: exercise.repCountingMode)
      + (set.isCompleted ? " ✓" : " ○")
  }
}
