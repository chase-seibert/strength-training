import SwiftData
import SwiftUI

struct HomeView: View {
  @Environment(\.modelContext) private var context
  let onOpenWorkout: (WorkoutSession) -> Void
  @Query(filter: #Predicate<Routine> { $0.deletedAt == nil }, sort: \Routine.createdAt)
  private var routines: [Routine]
  @Query private var allRoutines: [Routine]
  @Query(filter: #Predicate<WorkoutSession> { $0.isActive })
  private var activeSessions: [WorkoutSession]
  @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
  @Query private var catalog: [Exercise]
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @State private var pendingDeletion: WorkoutSession?
  @State private var showingDeleteConfirmation = false

  init(onOpenWorkout: @escaping (WorkoutSession) -> Void = { _ in }) {
    self.onOpenWorkout = onOpenWorkout
  }

  private var workoutsThisMonth: Int {
    let threshold =
      Calendar.current.date(byAdding: .day, value: -29, to: .now.startOfDay) ?? .distantPast
    return sessions.filter { $0.startedAt >= threshold }.count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if let activeSession = activeSessions.first {
          activeWorkoutCard(activeSession)
        }
        routineSection
        activityCard
        if !sessions.isEmpty { recentWorkoutsSection }
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Workout")
    .toolbarTitleDisplayMode(.large)
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
          "This permanently deletes the \(routineName(for: session)) workout from \(session.startedAt.formatted(date: .abbreviated, time: .shortened))."
        )
      }
    }
  }

  private func activeWorkoutCard(_ session: WorkoutSession) -> some View {
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
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          SectionEyebrow(text: "Last 30 days")
          Text("\(workoutsThisMonth) workouts")
            .font(.title3.bold())
        }
      }
      ActivityGrid(sessions: sessions)
    }
    .padding()
    .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private var routineSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Choose a routine").font(.title3.bold())
        Spacer()
        NavigationLink("See all") { RoutinesView(onOpenWorkout: onOpenWorkout) }
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
                Text("\(routine.exercises.count) exercises")
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

  private var recentWorkoutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Recent workouts").font(.title3.bold())
      VStack(spacing: 0) {
        ForEach(Array(sessions.prefix(3).enumerated()), id: \.element.id) { index, session in
          Button {
            open(session)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(Theme.navy)
                .frame(width: 38, height: 38)
                .background(Theme.mint.opacity(0.24), in: Circle())
              VStack(alignment: .leading, spacing: 3) {
                Text(routineName(for: session))
                  .font(.headline)
                  .foregroundStyle(.primary)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Text("\(session.completedSetCount)/\(session.totalSetCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("resume-recent-workout-\(routineName(for: session))")
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) {
              requestDelete(session)
            }
          }

          if index < min(sessions.count, 3) - 1 {
            Divider().padding(.leading, 64)
          }
        }
      }
      .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
  }

  private func open(_ session: WorkoutSession) {
    for activeSession in activeSessions where activeSession.id != session.id {
      activeSession.endedAt = activeSession.endedAt ?? .now
      activeSession.isActive = false
    }
    session.endedAt = nil
    session.isActive = true
    try? context.save()
    onOpenWorkout(session)
  }

  private func requestDelete(_ session: WorkoutSession) {
    pendingDeletion = session
    showingDeleteConfirmation = true
  }

  private func deletePending() {
    guard let session = pendingDeletion else { return }
    context.delete(session)
    try? context.save()
    pendingDeletion = nil
  }

  private func routineName(for session: WorkoutSession) -> String {
    allRoutines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }
}

struct ActivityGrid: View {
  let sessions: [WorkoutSession]
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 10)

  private var days: [Date] {
    (0..<30).compactMap {
      Calendar.current.date(byAdding: .day, value: $0 - 29, to: .now.startOfDay)
    }
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: 5) {
      ForEach(days, id: \.self) { day in
        let count = sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
          .count
        RoundedRectangle(cornerRadius: 4)
          .fill(
            count == 0
              ? Color.secondary.opacity(0.12)
              : Theme.coral.opacity(min(1, 0.48 + Double(count) * 0.25))
          )
          .aspectRatio(1, contentMode: .fit)
          .accessibilityLabel(
            "\(day.formatted(date: .abbreviated, time: .omitted)): \(count) workouts")
      }
    }
  }
}
