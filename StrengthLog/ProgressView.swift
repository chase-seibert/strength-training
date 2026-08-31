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
  @State private var selectedRange: ProgressRange = .fourWeeks

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
              Chart(volumePoints) { point in
                LineMark(
                  x: .value("Date", point.startedAt, unit: .day),
                  y: .value("Volume", point.volume),
                  series: .value("Person", point.personName)
                )
                .foregroundStyle(by: .value("Person", point.personName))
                .interpolationMethod(.catmullRom)
                PointMark(
                  x: .value("Date", point.startedAt, unit: .day),
                  y: .value("Volume", point.volume)
                )
                .foregroundStyle(by: .value("Person", point.personName))
              }
              .chartForegroundStyleScale(
                domain: progressPeople,
                range: progressPeople.map { Color(hex: colorHex(for: $0)) }
              )
              .chartLegend(position: .bottom, alignment: .leading)
              .frame(height: 220)
              .chartYAxisLabel("lb × reps")
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
    var names: [String] = []
    for session in filteredSessions {
      for name in session.participantNames
      where !names.contains(where: {
        $0.caseInsensitiveCompare(name) == .orderedSame
      }) {
        names.append(name)
      }
    }
    return names.sorted { lhs, rhs in
      let leftOrder =
        people.first(where: { $0.name.caseInsensitiveCompare(lhs) == .orderedSame })?.sortOrder
        ?? Int.max
      let rightOrder =
        people.first(where: { $0.name.caseInsensitiveCompare(rhs) == .orderedSame })?.sortOrder
        ?? Int.max
      if leftOrder != rightOrder { return leftOrder < rightOrder }
      return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
  }

  private var volumePoints: [PersonVolumePoint] {
    chronological.flatMap { session in
      session.participantNames.compactMap { name in
        let volume = volume(for: session, participantName: name)
        guard volume > 0 else { return nil }
        return PersonVolumePoint(
          sessionID: session.id, personName: name, startedAt: session.startedAt, volume: volume)
      }
    }
  }

  private func volume(for session: WorkoutSession, participantName: String) -> Double {
    session.exercises.filter { $0.unit == .pounds }.flatMap(\.participants).reduce(0) {
      total, participant in
      guard participant.participantName.caseInsensitiveCompare(participantName) == .orderedSame
      else {
        return total
      }
      return total
        + participant.sets.filter(\.isCompleted).reduce(0) {
          $0 + Double($1.reps) * ($1.measurement ?? participant.measurement)
        }
    }
  }

  private func colorHex(for name: String) -> String {
    people.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.colorHex
      ?? "6B7280"
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
    try? context.save()
    pendingDeletion = nil
  }

  private func routineName(for session: WorkoutSession) -> String {
    routines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }
}

private enum ProgressRange: String, CaseIterable, Identifiable {
  case fourWeeks = "4W"
  case twelveWeeks = "12W"
  case all = "All"

  var id: Self { self }

  var title: String {
    switch self {
    case .fourWeeks: "4 weeks"
    case .twelveWeeks: "12 weeks"
    case .all: "All time"
    }
  }

  var startDate: Date? {
    let days: Int
    switch self {
    case .fourWeeks: days = 28
    case .twelveWeeks: days = 84
    case .all: return nil
    }
    return Calendar.current.date(byAdding: .day, value: -days, to: .now)
  }
}

private struct PersonVolumePoint: Identifiable {
  let sessionID: UUID
  let personName: String
  let startedAt: Date
  let volume: Double

  var id: String { "\(sessionID.uuidString)-\(personName)" }
}

struct SessionDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query private var routines: [Routine]
  @Bindable var session: WorkoutSession
  @State private var showingDeleteConfirmation = false

  var body: some View {
    List {
      Section {
        LabeledContent(
          "Date", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
        LabeledContent(
          "Completed", value: "\(session.completedSetCount) of \(session.totalSetCount) sets")
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
            VStack(alignment: .leading, spacing: 5) {
              Text(participant.participantName).font(.subheadline.bold())
              Text(setSummary(participant, unit: exercise.unit))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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
    try? context.save()
  }

  private func delete() {
    session.deletedAt = .now
    session.isActive = false
    session.endedAt = session.endedAt ?? .now
    try? context.save()
    dismiss()
  }

  private var routineName: String {
    routines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }

  private func setSummary(_ participant: ParticipantLog, unit: TrackingUnit) -> String {
    participant.sets.sorted(by: { $0.sortOrder < $1.sortOrder }).map { set in
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
      return parts.joined(separator: " × ") + (set.isCompleted ? " ✓" : " ○")
    }.joined(separator: "  ·  ")
  }
}
