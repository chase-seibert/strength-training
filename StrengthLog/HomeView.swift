import SwiftData
import SwiftUI

struct HomeView: View {
  @Environment(\.modelContext) private var context
  let onOpenWorkout: (WorkoutSession) -> Void
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
        if !sessions.isEmpty || !deletedSessions.isEmpty { recentWorkoutsSection }
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Workout")
    .toolbarTitleDisplayMode(.large)
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
      if !sessions.isEmpty {
        VStack(spacing: 0) {
          ForEach(Array(sessions.prefix(3).enumerated()), id: \.element.id) { index, session in
            RecentWorkoutRow(
              session: session,
              routineName: routineName(for: session),
              onOpen: { open(session) },
              onDelete: { softDelete(session) })

            if index < min(sessions.count, 3) - 1 {
              Divider().padding(.leading, 64)
            }
          }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }

      if !deletedSessions.isEmpty {
        NavigationLink {
          DeletedWorkoutsView()
        } label: {
          Label("Deleted Workouts (\(deletedSessions.count))", systemImage: "trash")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
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

  private func softDelete(_ session: WorkoutSession) {
    session.deletedAt = .now
    session.isActive = false
    session.endedAt = session.endedAt ?? .now
    try? context.save()
  }

  private func routineName(for session: WorkoutSession) -> String {
    allRoutines.first(where: { $0.id == session.routineID })?.name ?? "Unknown Routine"
  }
}

private struct RecentWorkoutRow: View {
  let session: WorkoutSession
  let routineName: String
  let onOpen: () -> Void
  let onDelete: () -> Void
  @State private var showingDeleteConfirmation = false
  @State private var isDeleteRevealed = false
  @State private var dragOffset: CGFloat = 0

  private let deleteActionWidth: CGFloat = 92

  var body: some View {
    ZStack(alignment: .trailing) {
      Button(role: .destructive) {
        showingDeleteConfirmation = true
      } label: {
        Label("Delete", systemImage: "trash")
          .labelStyle(.iconOnly)
          .font(.headline)
          .foregroundStyle(.white)
          .frame(width: deleteActionWidth)
          .frame(maxHeight: .infinity)
          .background(.red)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Delete \(routineName) workout")
      .accessibilityIdentifier("delete-recent-workout-\(routineName)")
      .confirmationDialog(
        "Delete workout?",
        isPresented: $showingDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Delete Workout", role: .destructive) {
          onDelete()
          isDeleteRevealed = false
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "This moves the \(routineName) workout from \(session.startedAt.formatted(date: .abbreviated, time: .shortened)) to Deleted Workouts, where it can be restored."
        )
      }

      HStack(spacing: 12) {
        Image(systemName: "clock.arrow.circlepath")
          .font(.headline)
          .foregroundStyle(Theme.navy)
          .frame(width: 38, height: 38)
          .background(Theme.mint.opacity(0.24), in: Circle())
        VStack(alignment: .leading, spacing: 3) {
          Text(routineName)
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
      .background(.background)
      .onTapGesture {
        if isDeleteRevealed {
          withAnimation(.snappy) { isDeleteRevealed = false }
        } else {
          onOpen()
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel(routineName)
      .accessibilityValue(
        "\(session.startedAt.formatted(date: .abbreviated, time: .shortened)), \(session.completedSetCount) of \(session.totalSetCount) sets"
      )
      .accessibilityIdentifier("resume-recent-workout-\(routineName)")
      .accessibilityAction { onOpen() }
      .offset(x: rowOffset)
      .highPriorityGesture(
        DragGesture(minimumDistance: 12)
          .onChanged { value in
            let startingOffset = isDeleteRevealed ? -deleteActionWidth : 0
            dragOffset =
              min(0, max(-deleteActionWidth, startingOffset + value.translation.width))
              - startingOffset
          }
          .onEnded { value in
            let horizontalTravel = min(value.translation.width, value.predictedEndTranslation.width)
            withAnimation(.snappy) {
              if isDeleteRevealed {
                isDeleteRevealed = value.translation.width < deleteActionWidth / 2
              } else {
                isDeleteRevealed = horizontalTravel < -deleteActionWidth / 2
              }
              dragOffset = 0
            }
          })
    }
    .clipped()
  }

  private var rowOffset: CGFloat {
    let base = isDeleteRevealed ? -deleteActionWidth : 0
    return min(0, max(-deleteActionWidth, base + dragOffset))
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
