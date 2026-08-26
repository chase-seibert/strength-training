import Charts
import SwiftData
import SwiftUI

struct ProgressView: View {
  @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

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
                    Text(session.routineName).font(.headline)
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text("\(session.completedSetCount)/\(session.totalSetCount) sets")
                    .font(.caption).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Progress")
  }

  private func volume(_ session: WorkoutSession) -> Double {
    session.exercises.filter { $0.unit == .pounds }.flatMap(\.participants).reduce(0) {
      total, participant in
      total
        + participant.sets.filter(\.isCompleted).reduce(0) {
          $0 + Double($1.reps) * ($1.measurement ?? participant.measurement)
        }
    }
  }
}

struct SessionDetailView: View {
  @Environment(\.modelContext) private var context
  @Bindable var session: WorkoutSession

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
          ForEach(exercise.participants) { participant in
            VStack(alignment: .leading, spacing: 5) {
              Text(participant.participantName).font(.subheadline.bold())
              Text(setSummary(participant, unit: exercise.unit))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .navigationTitle(session.routineName)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Open", systemImage: "arrow.right") { open() }
      }
    }
  }

  private func open() {
    session.endedAt = nil
    session.isActive = true
    try? context.save()
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
