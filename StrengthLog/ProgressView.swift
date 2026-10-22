import Charts
import SwiftData
import SwiftUI

struct ProgressView: View {
  @Environment(\.modelContext) private var context
  @Query private var routines: [Routine]
  @Query private var exerciseCatalog: [Exercise]
  @Query(filter: #Predicate<PersonProfile> { !$0.isArchived }, sort: \PersonProfile.sortOrder)
  private var people: [PersonProfile]
  @Query(
    filter: #Predicate<WorkoutSession> { $0.deletedAt == nil },
    sort: \WorkoutSession.startedAt,
    order: .reverse)
  private var sessions: [WorkoutSession]
  @Query private var reports: [WeeklyCoachingReport]
  @AppStorage("liftCoachProvider") private var providerRaw = LiftCoachProvider.deterministic
    .rawValue
  @AppStorage("liftCoachOpenAIConsent") private var openAIConsent = false
  @State private var pendingDeletion: WorkoutSession?
  @State private var showingDeleteConfirmation = false
  @State private var selectedRange: ProgressRange = .twelveWeeks
  @State private var isGeneratingReport = false
  @State private var coachingError: String?
  @State private var reportToast: String?
  let previewMode: ProgressPreviewMode?

  init(previewMode: ProgressPreviewMode? = nil) { self.previewMode = previewMode }

  private var provider: LiftCoachProvider {
    LiftCoachProvider(rawValue: providerRaw) ?? .deterministic
  }
  private var primaryPerson: PersonProfile? {
    PersonProfile.ordered(people.filter { !$0.isArchived }).first
  }
  private var primarySessions: [WorkoutSession] {
    guard let primaryPerson else { return [] }
    return filteredSessions.filter { belongsToPrimaryPerson($0, person: primaryPerson) }
  }
  private var currentReport: WeeklyCoachingReport? {
    guard let person = primaryPerson else { return nil }
    let interval = LiftCoachReportBuilder.currentWeek()
    return reports.first {
      $0.personID == person.id && $0.weekStart == interval.start && $0.weekEnd == interval.end
    }
  }

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
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          progressHeader.id("progress-top")
          volumeCard
          coachingCard
            .id("weekly-coaching-section")
          recentWorkoutsCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
      .background(Theme.coachBackground.ignoresSafeArea())
      .onReceive(NotificationCenter.default.publisher(for: .openWeeklyCoachingReport)) { _ in
        withAnimation { proxy.scrollTo("weekly-coaching-section", anchor: .top) }
        UserDefaults.standard.removeObject(
          forKey: WeeklyCoachingNotificationCoordinator.pendingRouteKey)
      }
      .onAppear {
        if previewMode != nil {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            proxy.scrollTo("progress-top", anchor: .top)
          }
          return
        }
        let openReport = UserDefaults.standard.bool(
          forKey: WeeklyCoachingNotificationCoordinator.pendingRouteKey)
        refreshLocalReportFactsIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
          if openReport {
            withAnimation { proxy.scrollTo("weekly-coaching-section", anchor: .top) }
            UserDefaults.standard.removeObject(
              forKey: WeeklyCoachingNotificationCoordinator.pendingRouteKey)
          } else {
            proxy.scrollTo("progress-top", anchor: .top)
          }
        }
      }
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(Theme.coachBackground, for: .navigationBar, .tabBar)
    .toolbarBackground(.visible, for: .navigationBar, .tabBar)
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
    .alert(
      "Weekly report",
      isPresented: Binding(get: { reportToast != nil }, set: { if !$0 { reportToast = nil } })
    ) {
      Button("OK", role: .cancel) { reportToast = nil }
    } message: {
      Text(reportToast ?? "")
    }
  }

  private var progressHeader: some View {
    HStack(alignment: .center) {
      Text("Progress")
        .font(.largeTitle.weight(.bold))
        .foregroundStyle(.primary)
      Spacer()
      Menu {
        ForEach(ProgressRange.allCases) { range in
          Button {
            selectedRange = range
          } label: {
            Label(range.title, systemImage: selectedRange == range ? "checkmark" : "circle")
          }
        }
      } label: {
        HStack(spacing: 10) {
          Text(selectedRange.rawValue)
          Image(systemName: "chevron.down").font(.caption.weight(.bold))
        }
        .font(.headline)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.coachCard, in: Capsule())
      }
      .accessibilityIdentifier("progress-range-menu")
    }
  }

  private var volumeCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: "chart.bar.fill").foregroundStyle(Theme.coral)
        Text("TRAINING VOLUME")
          .font(.headline.weight(.bold)).tracking(1.3)
      }
      .foregroundStyle(.primary)
      Text(
        "\(previewMode == nil ? volumeSubtitle : "You and partner · lb × reps")"
      )
      .font(.subheadline).foregroundStyle(Theme.coachSecondary)
      if let previewMode {
        previewVolumeChart(previewMode)
      } else {
        if volumePoints.isEmpty {
          ContentUnavailableView(
            "No training volume yet", systemImage: "chart.xyaxis.line",
            description: Text("Completed workouts with everyone will appear here.")
          )
          .frame(height: 170)
          .tint(Theme.coachSecondary)
        } else {
          volumeChart(volumePoints)
        }
      }
    }
    .padding(18)
    .coachCard()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Training volume chart")
    .accessibilityIdentifier("progress-volume-chart")
  }

  @ViewBuilder private func volumeChart(_ points: [ProgressVolumePoint]) -> some View {
    Chart {
      ForEach(points) { point in
        LineMark(
          x: .value("Week", point.weekStart, unit: .weekOfYear),
          y: .value("Volume", point.volume),
          series: .value("Person", point.personName)
        ).foregroundStyle(by: .value("Person", point.personName))
          .interpolationMethod(.catmullRom).lineStyle(
            StrokeStyle(lineWidth: 3, lineCap: .round))
        PointMark(
          x: .value("Week", point.weekStart, unit: .weekOfYear),
          y: .value("Volume", point.volume)
        ).foregroundStyle(by: .value("Person", point.personName))
      }
    }
    .chartForegroundStyleScale(
      domain: progressPeople,
      range: progressPeople.map { Color(hex: colorHex(for: $0)) }
    )
    .chartLegend(position: .bottom, alignment: .leading)
    .chartYScale(domain: 0...max(points.map(\.volume).max() ?? 1, 1))
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine().foregroundStyle(Theme.coachGrid)
        AxisValueLabel().foregroundStyle(Theme.coachSecondary)
      }
    }
    .chartXAxis {
      AxisMarks { value in
        AxisGridLine().foregroundStyle(Theme.coachGrid)
        AxisValueLabel().foregroundStyle(Theme.coachSecondary)
      }
    }
    .frame(height: 190)
  }

  @ViewBuilder private func previewVolumeChart(_ mode: ProgressPreviewMode) -> some View {
    let points = sampleVolumePoints
    Chart {
      ForEach(points) { point in
        LineMark(
          x: .value("Week", point.weekStart), y: .value("Volume", point.volume),
          series: .value("Person", point.personName)
        )
        .foregroundStyle(by: .value("Person", point.personName))
        .interpolationMethod(.catmullRom).lineStyle(
          StrokeStyle(lineWidth: 3, lineCap: .round))
        PointMark(x: .value("Week", point.weekStart), y: .value("Volume", point.volume))
          .foregroundStyle(by: .value("Person", point.personName))
      }
    }
    .chartForegroundStyleScale(domain: ["You", "Partner"], range: [Theme.coral, Theme.sky])
    .chartLegend(position: .bottom, alignment: .leading)
    .chartYAxis {
      AxisMarks(position: .leading) { _ in
        AxisGridLine().foregroundStyle(Theme.coachGrid)
        AxisValueLabel().foregroundStyle(Theme.coachSecondary)
      }
    }
    .chartXAxis {
      AxisMarks { _ in
        AxisGridLine().foregroundStyle(Theme.coachGrid)
        AxisValueLabel().foregroundStyle(Theme.coachSecondary)
      }
    }
    .frame(height: 190)
  }

  private var coachingCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let previewMode {
        previewCoachingContent(previewMode)
      } else if let report = currentReport {
        weeklyReportContent(report)
        if let coachingError { Text(coachingError).font(.footnote).foregroundStyle(.red) }
        Button("Refresh weekly report", systemImage: "arrow.clockwise") {
          Task { await generateReport() }
        }.disabled(isGeneratingReport)
      } else {
        learningHabitsContent
        if let coachingError { Text(coachingError).font(.footnote).foregroundStyle(.red) }
        Button(
          isGeneratingReport ? "Generating…" : "Generate this week’s report",
          systemImage: "sparkles"
        ) { Task { await generateReport() } }
        .buttonStyle(.borderedProminent)
        .tint(Theme.coral)
        .disabled(isGeneratingReport || primaryPerson == nil)
        .accessibilityIdentifier("generate-weekly-coaching-report")
      }
      if previewMode != nil {
        Text("SAMPLE DATA · Read-only preview")
          .font(.caption.weight(.bold)).tracking(1).foregroundStyle(Theme.coachSecondary)
          .padding(.top, 2)
      }
    }
    .padding(18)
    .coachCard()
  }

  @ViewBuilder private func weeklyReportContent(_ report: WeeklyCoachingReport) -> some View {
    let facts = LiftCoachReportBuilder.savedFacts(for: report)
    let response = LiftCoachReportBuilder.structuredResponse(for: report)
    HStack(spacing: 9) {
      Image(systemName: "sparkles").foregroundStyle(Theme.coral)
      Text("WEEKLY REPORT")
        .font(.headline.weight(.bold)).tracking(1.3).foregroundStyle(.primary)
      Spacer()
      Text(
        report.weekStart.formatted(.dateTime.month(.abbreviated).day()) + "–"
          + report.weekEnd.addingTimeInterval(-1).formatted(.dateTime.day())
      )
      .font(.caption).foregroundStyle(Theme.coachSecondary)
    }
    if let facts {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        reportMetric("\(facts.workoutCount)", label: "workouts", icon: "dumbbell.fill")
        reportMetric(
          "\(facts.completedSetCount)", label: "completed sets", icon: "square.stack.3d.up.fill")
        reportMetric(
          Int(facts.poundsVolume.rounded()).formatted(), label: "lb × reps", icon: "chart.bar.fill")
        reportMetric(
          formattedDuration(facts.totalDurationSeconds), label: "total time", icon: "clock")
      }
      dailyVolumeChart(facts.dailyVolume, weekStart: report.weekStart)
      if !facts.routines.isEmpty {
        VStack(alignment: .leading, spacing: 7) {
          coachSectionTitle("ROUTINES YOU FOLLOWED")
          ForEach(facts.routines) { routine in
            HStack {
              Image(systemName: "dumbbell.fill").foregroundStyle(Theme.coral)
              Text(routine.name).foregroundStyle(.primary)
              Spacer()
              Text("\(routine.workoutCount) \(routine.workoutCount == 1 ? "workout" : "workouts")")
                .font(.subheadline).foregroundStyle(Theme.coachSecondary)
            }
            .padding(10)
            .background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 12))
          }
        }
      }
    } else {
      Text("Weekly totals are being refreshed from workout history.")
        .font(.subheadline).foregroundStyle(Theme.coachSecondary)
    }
    if let response {
      if !response.overallPattern.isEmpty {
        reportTextSection(
          "OVERALL PATTERN", text: response.overallPattern, icon: "chart.line.uptrend.xyaxis")
      }
      if !response.whatsNext.isEmpty {
        reportTextSection("WHAT’S NEXT", text: response.whatsNext, icon: "list.bullet.clipboard")
      }
      if let candidate = facts?.progressionCandidates.first(where: {
        $0.id == response.progressionCandidateID
      }) {
        progressionSuggestion(candidate, explanation: response.progressionExplanation)
      }
      let providerText =
        report.provider == LiftCoachProvider.foundationModels.rawValue
        ? "on device"
        : report.provider == LiftCoachProvider.openAI.rawValue
          ? "with OpenAI" : "from workout history"
      Text("Generated \(providerText) · based on completed workouts")
        .font(.caption).foregroundStyle(Theme.coachSecondary)
    } else if let narrative = report.narrative, !narrative.isEmpty {
      reportTextSection("OVERALL PATTERN", text: narrative, icon: "chart.line.uptrend.xyaxis")
    } else {
      reportTextSection(
        "WHAT’S NEXT",
        text:
          "Your report is based on completed workouts. Generate a coaching update for personalized observations.",
        icon: "list.bullet.clipboard")
    }
    if let facts {
      restAssessmentSection(response: response, facts: facts)
    }
  }

  private func reportMetric(_ value: String, label: String, icon: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon).font(.title3).foregroundStyle(Theme.coral)
        .frame(width: 34, height: 34)
      VStack(alignment: .leading, spacing: 2) {
        Text(value).font(.headline.weight(.bold)).foregroundStyle(.primary)
        Text(label).font(.caption).foregroundStyle(Theme.coachSecondary)
      }
      Spacer(minLength: 0)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 12))
  }

  private func dailyVolumeChart(_ values: [LiftCoachDailyVolume], weekStart: Date) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Daily workout volume").font(.headline).foregroundStyle(.primary)
        Spacer()
        Text(
          "Total: \(Int(values.reduce(0) { $0 + $1.poundsVolume }.rounded()).formatted()) lb × reps"
        )
        .font(.caption).foregroundStyle(Theme.coachSecondary)
      }
      Chart {
        ForEach(0..<7, id: \.self) { offset in
          let day = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
          let volume =
            values.first(where: { Calendar.current.isDate($0.day, inSameDayAs: day) })?.poundsVolume
            ?? 0
          BarMark(x: .value("Day", day, unit: .day), y: .value("lb × reps", volume))
            .foregroundStyle(Theme.coral.gradient)
            .cornerRadius(4)
        }
      }
      .chartYAxis { AxisMarks(position: .leading) }
      .chartXAxis {
        AxisMarks(values: .stride(by: .day)) { _ in
          AxisValueLabel(format: .dateTime.weekday(.narrow))
        }
      }
      .frame(height: 150)
    }
    .padding(12)
    .background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 14))
  }

  private func reportTextSection(_ title: String, text: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      coachSectionTitle(title)
      HStack(alignment: .top, spacing: 11) {
        Image(systemName: icon).font(.title3).foregroundStyle(Theme.mint)
          .frame(width: 36, height: 36)
          .background(Theme.mint.opacity(0.14), in: Circle())
        Text(text).font(.body).foregroundStyle(.primary).fixedSize(
          horizontal: false, vertical: true)
      }
      .padding(12)
      .background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  @ViewBuilder private func restAssessmentSection(
    response: LiftCoachStructuredResponse?, facts: LiftCoachFacts
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      coachSectionTitle("REST BETWEEN EXERCISES")
      VStack(alignment: .leading, spacing: 7) {
        Label(facts.restAssessment.title, systemImage: facts.restAssessment.symbol)
          .font(.headline).foregroundStyle(facts.restAssessment.color)
        let fallback =
          facts.rest.highEffortSetCount > 0 || facts.rest.belowTargetSetCount > 0
          ? "Some sets were high effort or below target. Consider a longer pause and compare the next workouts."
          : facts.restAssessment == .appearsAdequate
            ? "RPE and target performance look steady alongside your configured rest."
            : "Log RPE and set a rest target to build a useful recovery picture."
        let explanation = response?.restExplanation ?? ""
        Text(explanation.isEmpty ? fallback : explanation)
          .font(.subheadline).foregroundStyle(.primary)
        let target =
          facts.rest.configuredRestSeconds.map { "\($0)s configured" }
          ?? "No rest timer configured"
        Text(
          "\(target) · \(facts.rest.ratedSetCount) sets with RPE · exact rest intervals aren’t recorded"
        )
        .font(.caption).foregroundStyle(Theme.coachSecondary)
      }
      .padding(12)
      .background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  private func progressionSuggestion(
    _ candidate: LiftCoachProgressionCandidate, explanation: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      coachSectionTitle("TRY A NEW EXERCISE")
      VStack(alignment: .leading, spacing: 8) {
        Text(candidate.suggestedExercise).font(.headline).foregroundStyle(.primary)
        Text("A step up from your current \(candidate.currentExercise)")
          .font(.subheadline).foregroundStyle(Theme.coachSecondary)
        Text(explanation.isEmpty ? candidate.evidence : explanation)
          .font(.subheadline).foregroundStyle(.primary)
        Divider().overlay(Theme.coachGrid)
        Label(
          "In \(candidate.routineName): replace \(candidate.currentExercise)",
          systemImage: "arrow.left.arrow.right"
        )
        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
        Text(candidate.rationale).font(.caption).foregroundStyle(Theme.coachSecondary)
        Button("Preview workout", systemImage: "eye") {
          reportToast =
            "Preview only: \(candidate.routineName) with \(candidate.suggestedExercise) in place of \(candidate.currentExercise). No routine changes were saved."
        }
        .buttonStyle(.borderedProminent).tint(Theme.coral)
        Text("Suggestion only · not saved").font(.caption).foregroundStyle(Theme.coachSecondary)
      }
      .padding(12)
      .background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  private func formattedDuration(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let hours = minutes / 60
    return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
  }

  private var learningHabitsContent: some View {
    VStack(spacing: 12) {
      ZStack {
        Circle().fill(Theme.coachCard.opacity(0.9)).frame(width: 118, height: 72)
        Image(systemName: "dumbbell.fill")
          .font(.system(size: 47, weight: .medium)).foregroundStyle(Theme.coachSecondary)
        Image(systemName: "sparkle")
          .font(.title2.weight(.bold)).foregroundStyle(Theme.mint)
          .offset(x: 0, y: -49)
        Image(systemName: "sparkle")
          .font(.caption.weight(.bold)).foregroundStyle(Theme.mint)
          .offset(x: -38, y: -31)
        Image(systemName: "sparkle")
          .font(.caption.weight(.bold)).foregroundStyle(Theme.mint)
          .offset(x: 38, y: -31)
      }
      .padding(.top, 12)
      Text("Lift Coach is learning your habits")
        .font(.title3.weight(.bold)).multilineTextAlignment(.center).foregroundStyle(.primary)
      Text(
        "Keep logging workouts across your routines. After a few more workouts, Lift Coach will share insights and ideas here."
      )
      .font(.body).multilineTextAlignment(.center).foregroundStyle(Theme.coachSecondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 4)
  }

  private var recentWorkoutsCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "clock").font(.title3).foregroundStyle(Theme.coral)
        Text("RECENT WORKOUTS").font(.headline.weight(.bold)).tracking(1.4)
          .foregroundStyle(.primary).accessibilityLabel("Recent workouts")
      }
      if previewMode == nil && primarySessions.isEmpty {
        Text("No recent workouts for the primary person.").foregroundStyle(Theme.coachSecondary)
      } else if previewMode == nil {
        ForEach(Array(primarySessions.prefix(6).enumerated()), id: \.element.id) { index, session in
          if index > 0 { Divider().overlay(Theme.coachGrid) }
          HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
              .font(.headline).foregroundStyle(Theme.coral)
              .frame(width: 48, height: 48)
              .background(Theme.coachCard, in: RoundedRectangle(cornerRadius: 14))
            NavigationLink {
              SessionDetailView(session: session)
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(routineName(for: session)).font(.headline).foregroundStyle(.primary)
                  Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline).foregroundStyle(Theme.coachSecondary)
                }
                Spacer(minLength: 5)
                VStack(alignment: .trailing, spacing: 5) {
                  let prCount = personalRecordCounts[session.id] ?? 0
                  if prCount > 0 { PersonalRecordBadge(count: prCount) }
                  Text(workoutSetSummary(for: session)).font(.subheadline)
                    .foregroundStyle(.primary)
                }
              }
            }
            .buttonStyle(.plain)
            Menu {
              Button("Delete workout", systemImage: "trash", role: .destructive) {
                requestDelete(session)
              }
            } label: {
              Image(systemName: "chevron.right").foregroundStyle(Theme.coachSecondary)
                .padding(.leading, 4)
            }
          }
          .accessibilityIdentifier("workout-history-\(routineName(for: session))")
        }
      } else {
        sampleWorkoutRow("Upper A", date: "Today", sets: "18/18 sets")
        Divider().overlay(Theme.coachGrid)
        sampleWorkoutRow("Lower A", date: "Mon", sets: "16/16 sets")
        Divider().overlay(Theme.coachGrid)
        sampleWorkoutRow("Full Body", date: "Sat", sets: "21/21 sets")
      }
    }
    .padding(18)
    .coachCard()
  }

  private func sampleWorkoutRow(_ name: String, date: String, sets: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "dumbbell.fill").font(.headline).foregroundStyle(Theme.coral)
        .frame(width: 48, height: 48).background(
          Theme.coachCard, in: RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 4) {
        Text(name).font(.headline).foregroundStyle(.primary)
        Text(date).font(.subheadline).foregroundStyle(Theme.coachSecondary)
      }
      Spacer()
      Text(sets).font(.subheadline).foregroundStyle(.primary)
      Image(systemName: "chevron.right").foregroundStyle(Theme.coachSecondary)
    }
  }

  private var volumePoints: [ProgressVolumePoint] {
    ProgressSummaryBuilder.volumePoints(sessions: chronological)
  }

  private var progressPeople: [String] {
    ProgressSummaryBuilder.participantNames(in: filteredSessions, people: people)
  }

  private var volumeSubtitle: String {
    switch progressPeople.count {
    case 0: "Everyone · lb × reps"
    case 1: "\(progressPeople[0]) · lb × reps"
    default: "Everyone · lb × reps"
    }
  }

  private func colorHex(for name: String) -> String {
    ProgressSummaryBuilder.colorHex(for: name, people: people)
  }

  private var personalRecordCounts: [UUID: Int] {
    guard let person = primaryPerson else { return [:] }
    return PersonalRecords.counts(for: person, people: people, in: primarySessions)
  }

  private var sampleVolumePoints: [ProgressVolumePoint] {
    let values: [[Double]] = [
      [18400, 20100, 19300, 22900, 21800, 24700, 23900, 27400],
      [13200, 14800, 14100, 15900, 15300, 17200, 16800, 18100],
    ]
    return ["You", "Partner"].enumerated().flatMap { series, name in
      values[series].enumerated().map { offset, volume in
        ProgressVolumePoint(
          id: "sample-\(series)-\(offset)", personName: name,
          weekStart: Calendar.current.date(byAdding: .weekOfYear, value: offset - 7, to: .now)
            ?? .now, volume: volume)
      }
    }
  }

  @ViewBuilder private func previewCoachingContent(_ mode: ProgressPreviewMode) -> some View {
    if mode == .learning {
      learningHabitsContent
    } else {
      HStack(spacing: 9) {
        Image(systemName: "sparkles").foregroundStyle(Theme.coral)
        Text("LIFT COACH · SINCE YOUR LAST REPORT")
          .font(.headline.weight(.bold)).tracking(1.3).foregroundStyle(Theme.coachSecondary)
      }
      Text("WEEKLY REPORT · SAMPLE DATA")
        .font(.headline.weight(.bold)).tracking(1.2).foregroundStyle(Theme.coachSecondary)
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        reportMetric("3", label: "workouts", icon: "dumbbell.fill")
        reportMetric("42", label: "completed sets", icon: "square.stack.3d.up.fill")
        reportMetric("12,600", label: "lb × reps", icon: "chart.bar.fill")
        reportMetric("2h 10m", label: "total time", icon: "clock")
      }
      let weekStart = LiftCoachReportBuilder.currentWeek().start
      dailyVolumeChart(
        [
          LiftCoachDailyVolume(
            day: Calendar.current.date(byAdding: .day, value: 1, to: weekStart) ?? weekStart,
            poundsVolume: 4_100),
          LiftCoachDailyVolume(
            day: Calendar.current.date(byAdding: .day, value: 3, to: weekStart) ?? weekStart,
            poundsVolume: 2_800),
          LiftCoachDailyVolume(
            day: Calendar.current.date(byAdding: .day, value: 5, to: weekStart) ?? weekStart,
            poundsVolume: 5_700),
        ], weekStart: weekStart)
      reportTextSection(
        "WHAT’S NEXT",
        text:
          "Keep following your current routine. Your weekly pattern will include new workouts in the next report.",
        icon: "list.bullet.clipboard")
      Text("12 workouts · 3 active routines")
        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.coachSecondary)
      VStack(alignment: .leading, spacing: 8) {
        coachSectionTitle("YOUR ACTIVE REGIMEN")
        regimenRow("Upper A", workouts: "5 workouts", trend: "steady", icon: "dumbbell.fill")
        regimenRow(
          "Lower A", workouts: "4 workouts", trend: "building",
          icon: "figure.strengthtraining.traditional")
        regimenRow(
          "Full Body", workouts: "3 workouts", trend: "consistent", icon: "figure.mixed.cardio")
      }
      VStack(alignment: .leading, spacing: 8) {
        coachSectionTitle("EXERCISE TRENDS")
        HStack(spacing: 10) {
          trendTile("Bench Press", sessions: "4 sessions")
          trendTile("Squat", sessions: "3 sessions")
        }
      }
      VStack(alignment: .leading, spacing: 8) {
        coachSectionTitle("OVERALL PATTERN")
        HStack(spacing: 14) {
          Image(systemName: "chart.line.uptrend.xyaxis")
            .font(.title2.weight(.bold)).foregroundStyle(Theme.mint)
            .frame(width: 52, height: 52).background(Theme.mint.opacity(0.16), in: Circle())
          Text("Volume is rising across the routines you already follow.")
            .font(.headline).foregroundStyle(.primary)
        }
      }
      VStack(alignment: .leading, spacing: 8) {
        coachSectionTitle("TRY A NEW EXERCISE")
        VStack(alignment: .leading, spacing: 9) {
          HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill").font(.title2).foregroundStyle(Theme.coral)
              .frame(width: 52, height: 52).background(
                Theme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
              Text("Incline Dumbbell Press").font(.headline).foregroundStyle(.primary)
              Text("A step up from your current Barbell Bench Press")
                .font(.subheadline).foregroundStyle(Theme.coachSecondary)
            }
          }
          Text(
            "You met all 3 × 8 bench targets in 2 workouts. This incline variation keeps the chest press pattern and adds a new angle."
          )
          .font(.subheadline).foregroundStyle(Theme.coachSecondary)
          Divider().overlay(Theme.coachGrid)
          Label("In Upper A: replace Barbell Bench Press", systemImage: "arrow.left.arrow.right")
            .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
          Button("Preview workout", systemImage: "eye") {
            reportToast = "Preview only. No routine changes were saved."
          }
          .buttonStyle(.borderedProminent).tint(Theme.coral)
          Text("Suggestion only · not saved").font(.caption).foregroundStyle(Theme.coachSecondary)
        }
      }
      VStack(alignment: .leading, spacing: 8) {
        coachSectionTitle("REST BETWEEN EXERCISES")
        Label("Not enough recovery data yet", systemImage: "questionmark.circle")
          .font(.headline).foregroundStyle(.secondary)
        Text(
          "Your routine has a configured rest timer, but exact rest intervals aren’t recorded. Set RPE helps identify when recovery may need a closer look."
        )
        .font(.subheadline).foregroundStyle(Theme.coachSecondary)
      }
      VStack(alignment: .leading, spacing: 8) {
        coachSectionTitle("COACHING PROVIDER")
        HStack(spacing: 12) {
          Image(systemName: "cpu.fill").foregroundStyle(Theme.sky)
          Text("On-device").font(.headline).foregroundStyle(.primary)
          Spacer()
          Text("Settings").font(.headline).foregroundStyle(Theme.sky)
          Image(systemName: "chevron.right").foregroundStyle(Theme.coachSecondary)
        }
        .padding(14).background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 16))
      }
      Button("Generate coaching update", systemImage: "sparkles") {
        reportToast = "Sample preview only. No AI request was sent."
      }
      .font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 14)
      .buttonStyle(.borderedProminent).tint(Theme.coral)
    }
  }

  private func coachSectionTitle(_ title: String) -> some View {
    Text(title).font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(Theme.coachSecondary)
      .padding(.top, 4)
  }

  private func regimenRow(_ name: String, workouts: String, trend: String, icon: String)
    -> some View
  {
    HStack(spacing: 12) {
      Image(systemName: icon).font(.title3).foregroundStyle(Theme.coral)
        .frame(width: 42, height: 42).background(
          Theme.coachInset, in: RoundedRectangle(cornerRadius: 13))
      VStack(alignment: .leading, spacing: 3) {
        Text(name).font(.headline).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.85)
        Text(workouts).font(.subheadline).foregroundStyle(Theme.coachSecondary).lineLimit(1)
          .minimumScaleFactor(0.85)
      }
      .frame(minWidth: 82, maxWidth: .infinity, alignment: .leading)
      HStack(alignment: .bottom, spacing: 3) {
        ForEach(1...5, id: \.self) { bar in
          Capsule().fill(Theme.mint).frame(width: 4, height: CGFloat(8 + bar * 4))
        }
      }
      Text(trend).font(.caption).foregroundStyle(Theme.coachSecondary).frame(
        width: 55, alignment: .leading
      ).lineLimit(1).minimumScaleFactor(0.85)
      Image(systemName: "chevron.right").foregroundStyle(Theme.coachSecondary)
    }
    .padding(12)
    .background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 16))
  }

  private func trendTile(_ name: String, sessions: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(name).font(.headline).foregroundStyle(.primary)
      HStack {
        Text(sessions).font(.subheadline).foregroundStyle(Theme.coachSecondary)
        Spacer(minLength: 3)
        Image(systemName: "chart.bar.fill").foregroundStyle(Theme.mint)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Theme.coachInset, in: RoundedRectangle(cornerRadius: 16))
  }

  private func belongsToPrimaryPerson(_ session: WorkoutSession, person: PersonProfile) -> Bool {
    guard !session.isActive, session.completedSetCount > 0 else { return false }
    let legacyNameIsUnique =
      people.filter { $0.name.caseInsensitiveCompare(person.name) == .orderedSame }.count == 1
    return session.exercises.contains { exercise in
      exercise.participants.contains { participant in
        let matchesPerson =
          participant.personID == person.id
          || (participant.personID == nil && legacyNameIsUnique
            && participant.participantName.caseInsensitiveCompare(person.name) == .orderedSame)
        return matchesPerson && session.isParticipantActive(participant.participantName)
          && participant.sets.contains { $0.isCompleted && !$0.isSkipped }
      }
    }
  }

  private func reportFactsText(_ report: WeeklyCoachingReport) -> String {
    guard report.workoutCount > 0 else { return "No completed workouts this week yet." }
    return
      "You logged \(report.workoutCount) workouts and \(report.completedSetCount) completed sets this week."
  }

  @MainActor private func generateReport() async {
    guard let person = primaryPerson else { return }
    isGeneratingReport = true
    coachingError = nil
    defer { isGeneratingReport = false }
    let interval = LiftCoachReportBuilder.currentWeek()
    let facts = LiftCoachReportBuilder.facts(
      for: person, people: people, sessions: sessions, routines: routines,
      exercises: exerciseCatalog, reports: reports, in: interval)
    var structuredResponse: LiftCoachStructuredResponse?
    if provider != .deterministic && facts.workoutCount > 0 {
      guard provider != .openAI || openAIConsent else {
        coachingError = "Enable cloud data sharing in Settings before using OpenAI coaching."
        return
      }
      do {
        structuredResponse = try await LiftCoachNarrator.generate(facts, provider: provider)
      } catch {
        coachingError = error.localizedDescription
      }
    }
    do {
      let saved = try LiftCoachReportBuilder.upsert(
        facts: facts, person: person, interval: interval, reports: reports,
        structuredResponse: structuredResponse,
        provider: structuredResponse == nil ? .deterministic : provider,
        context: context)
      reportToast =
        "Saved weekly report · \(saved.workoutCount) workouts, \(saved.completedSetCount) sets."
    } catch { coachingError = "Couldn’t save the weekly report: \(error.localizedDescription)" }
  }

  @MainActor private func refreshLocalReportFactsIfNeeded() {
    guard let report = currentReport, let person = primaryPerson else { return }
    do {
      let changed = try LiftCoachReportBuilder.refreshLocalFacts(
        for: report, person: person, people: people, sessions: sessions, routines: routines,
        exercises: exerciseCatalog, reports: reports, context: context)
      if changed {
        coachingError =
          "Weekly report facts refreshed from workout history. Generate a new coaching update to refresh its sections."
      }
    } catch {
      coachingError = "Couldn’t refresh weekly report facts: \(error.localizedDescription)"
    }
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

  private func workoutSetSummary(for session: WorkoutSession) -> String {
    let completed = session.completedSetCount
    let total = session.totalSetCount
    return "\(completed)/\(total) sets"
  }
}

extension View {
  fileprivate func coachCard() -> some View {
    background(Theme.coachCard, in: RoundedRectangle(cornerRadius: 22))
      .overlay {
        RoundedRectangle(cornerRadius: 22)
          .stroke(Color.primary.opacity(0.06), lineWidth: 1)
      }
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

extension LiftCoachRestAssessment {
  fileprivate var title: String {
    switch self {
    case .appearsAdequate: "Rest looks adequate from the available signals"
    case .considerMoreRest: "Consider taking more rest"
    case .insufficientData: "Not enough recovery data yet"
    }
  }

  fileprivate var symbol: String {
    switch self {
    case .appearsAdequate: "checkmark.circle.fill"
    case .considerMoreRest: "pause.circle.fill"
    case .insufficientData: "questionmark.circle"
    }
  }

  fileprivate var color: Color {
    switch self {
    case .appearsAdequate: Theme.mint
    case .considerMoreRest: Theme.coral
    case .insufficientData: .secondary
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
      participant: participant, unit: exercise.unit, repCountingMode: exercise.repCountingMode,
      usesPerDumbbellLoad: exercise.usesPerDumbbellLoad)
      + (set.isCompleted ? " ✓" : " ○")
  }
}
