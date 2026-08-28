import Charts
import SwiftData
import SwiftUI

struct ProgressView: View {
  @Environment(\.modelContext) private var context
  @Query private var routines: [Routine]
  @Query(
    filter: #Predicate<WorkoutSession> { $0.deletedAt == nil },
    sort: \WorkoutSession.startedAt,
    order: .reverse)
  private var sessions: [WorkoutSession]
  @State private var pendingDeletion: WorkoutSession?
  @State private var showingDeleteConfirmation = false

  private var chronological: [WorkoutSession] { sessions.sorted { $0.startedAt < $1.startedAt } }

  var body: some View {
    Group {
      if sessions.isEmpty {
        EmptyStateView(
          symbol: "chart.xyaxis.line", title: "Your progress starts here",
          message: "Start a routine to see volume and workout history.")
      } else {
        List {
          Section("Pounds volume") {
            Chart(chronological.suffix(14)) { session in
              BarMark(
                x: .value("Date", session.startedAt, unit: .day),
                y: .value("Volume", volume(session))
              )
              .foregroundStyle(Theme.coral.gradient)
              .cornerRadius(4)
            }
            .frame(height: 190)
            .chartYAxisLabel("lb × reps")
          }

          Section("Workout history") {
            ForEach(sessions) { session in
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
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Progress")
    .confirmationDialog(
      "Delete workout?",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
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

  private func volume(_ session: WorkoutSession) -> Double {
    session.exercises.filter { $0.unit == .pounds }.flatMap(\.participants).reduce(0) {
      total, participant in
      guard session.isParticipantActive(participant.participantName) else { return total }
      return total
        + participant.sets.filter(\.isCompleted).reduce(0) {
          $0 + Double($1.reps) * ($1.measurement ?? participant.measurement)
        }
    }
  }

  private func requestDelete(_ offsets: IndexSet) {
    guard let offset = offsets.first, sessions.indices.contains(offset) else { return }
    requestDelete(sessions[offset])
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
    .confirmationDialog(
      "Delete workout?",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
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
