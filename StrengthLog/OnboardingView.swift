import SwiftData
import SwiftUI

struct OnboardingView: View {
  @Environment(\.modelContext) private var context
  @Query(sort: \PersonProfile.sortOrder) private var existingPeople: [PersonProfile]
  @Query(filter: #Predicate<Routine> { $0.deletedAt == nil }, sort: \Routine.createdAt)
  private var existingRoutines: [Routine]
  @Binding var hasCompletedOnboarding: Bool
  @State private var step = 0
  @State private var primaryName = ""
  @State private var partnerNames = ["Person 2", "Person 3"]
  @State private var selectedStarterIDs: Set<String> = []
  @State private var hasLoadedExistingData = false

  private let colors = ["FF5A45", "59A8FA", "45D1A8", "A778F5", "F5B942", "E96BA8"]

  var body: some View {
    ZStack {
      Color(.systemGroupedBackground).ignoresSafeArea()
      if step == 0 {
        welcome
      } else if step == 1 {
        peopleSetup
      } else {
        starterRoutineSetup
      }
    }
    .tint(Theme.coral)
    .onAppear { loadExistingDataIfNeeded() }
  }

  private var welcome: some View {
    VStack(spacing: 28) {
      Spacer()
      VStack(alignment: .leading, spacing: 24) {
        Image(systemName: "dumbbell.fill")
          .font(.system(size: 38, weight: .bold))
          .foregroundStyle(Theme.coral)
        VStack(alignment: .leading, spacing: 10) {
          SectionEyebrow(text: "Welcome to StrengthLog")
            .foregroundStyle(.white.opacity(0.62))
          Text("Build strength,\ntogether.")
            .font(.system(size: 43, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
          Text("Fast workout tracking for you and the people you train with.")
            .font(.title3)
            .foregroundStyle(.white.opacity(0.72))
        }
        HStack(spacing: 18) {
          onboardingBenefit("checkmark.circle.fill", "Quick sets")
          onboardingBenefit("person.2.fill", "Shared routines")
          onboardingBenefit("chart.xyaxis.line", "Real progress")
        }
      }
      .padding(28)
      .background {
        ZStack(alignment: .bottomTrailing) {
          Theme.navy
          Circle().fill(Theme.coral.opacity(0.22)).frame(width: 250).offset(x: 90, y: 120)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
      Spacer()
      Button {
        withAnimation(.snappy) { step = 1 }
      } label: {
        Text("Get Started")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(22)
  }

  private func onboardingBenefit(_ symbol: String, _ text: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Image(systemName: symbol).foregroundStyle(Theme.coral)
      Text(text).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var peopleSetup: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 7) {
            SectionEyebrow(text: "Your training crew")
            Text("Who should we track?")
              .font(.largeTitle.bold())
            Text(
              "Start with yourself. Add anyone you regularly train with—you can change this later."
            )
            .foregroundStyle(.secondary)
          }

          VStack(spacing: 12) {
            personField(
              title: "Your first name", text: $primaryName, colorHex: colors[0], isPrimary: true)
            ForEach(partnerNames.indices, id: \.self) { index in
              personField(
                title: "Person \(index + 2)", text: $partnerNames[index],
                colorHex: colors[(index + 1) % colors.count])
            }
            Button("Add another person", systemImage: "person.badge.plus") {
              partnerNames.append("Person \(partnerNames.count + 2)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(partnerNames.count >= 5)
          }
          Spacer(minLength: 40)
          Button {
            withAnimation(.snappy) { step = 2 }
          } label: {
            Label("Choose Starter Routines", systemImage: "arrow.right")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
          }
          .buttonStyle(.borderedProminent)
          .disabled(clean(primaryName).isEmpty)
        }
        .padding(22)
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Back", systemImage: "chevron.left") { withAnimation(.snappy) { step = 0 } }
        }
      }
    }
  }

  private var starterRoutineSetup: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          VStack(alignment: .leading, spacing: 7) {
            SectionEyebrow(text: "Optional head start")
            Text("Pick a routine or three")
              .font(.largeTitle.bold())
            Text(
              "Use any of these as-is, edit them later, or continue without one and make your own."
            )
            .foregroundStyle(.secondary)
          }

          VStack(spacing: 12) {
            if !existingRoutines.isEmpty {
              VStack(alignment: .leading, spacing: 10) {
                SectionEyebrow(text: "Already configured")
                ForEach(existingRoutines) { routine in
                  Label(routine.name, systemImage: routine.symbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                      Color.secondary.opacity(0.07),
                      in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Text("These routines and all workout history will stay exactly as they are.")
                  .font(.caption).foregroundStyle(.secondary)
              }
              .padding(.bottom, 8)
            }

            ForEach(StarterRoutineTemplate.all) { template in
              VStack(alignment: .leading, spacing: 5) {
                StarterRoutineCard(
                  template: template, isSelected: selectedStarterIDs.contains(template.id)
                ) {
                  if !existingStarterIDs.contains(template.id) {
                    toggleStarter(template.id)
                  }
                }
                if existingStarterIDs.contains(template.id) {
                  Label("Already added", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mint)
                    .padding(.leading, 14)
                }
              }
            }
          }

          Button {
            completeOnboarding()
          } label: {
            Label(
              completionButtonTitle,
              systemImage: "arrow.right"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
          }
          .buttonStyle(.borderedProminent)
          .padding(.top, 14)
        }
        .padding(22)
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Back", systemImage: "chevron.left") { withAnimation(.snappy) { step = 1 } }
        }
      }
    }
  }

  private func personField(
    title: String, text: Binding<String>, colorHex: String, isPrimary: Bool = false
  ) -> some View {
    HStack(spacing: 12) {
      InitialBadge(
        name: clean(text.wrappedValue).isEmpty ? "?" : text.wrappedValue, colorHex: colorHex,
        size: 42)
      if isPrimary {
        TextField(title, text: text)
          .textContentType(.givenName)
          .textInputAutocapitalization(.words)
      } else {
        TextField(title, text: text)
          .textContentType(.name)
          .textInputAutocapitalization(.words)
      }
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
  }

  private func completeOnboarding() {
    let names = [primaryName] + partnerNames
    var seen = Set<String>()
    let uniqueNames = names.map(clean).filter {
      !$0.isEmpty && seen.insert($0.lowercased()).inserted
    }
    let currentPeople = orderedExistingPeople
    for (index, name) in uniqueNames.enumerated() {
      if currentPeople.indices.contains(index) {
        currentPeople[index].name = name
        currentPeople[index].sortOrder = index
      } else {
        context.insert(
          PersonProfile(
            name: name, colorHex: colors[index % colors.count], sortOrder: index))
      }
    }
    for (offset, person) in currentPeople.dropFirst(uniqueNames.count).enumerated() {
      person.sortOrder = uniqueNames.count + offset
    }
    for template in StarterRoutineTemplate.all
    where selectedStarterIDs.contains(template.id) && !existingStarterIDs.contains(template.id) {
      context.insert(template.makeRoutine(participantNames: uniqueNames))
    }
    try? context.save()
    hasCompletedOnboarding = true
  }

  private func toggleStarter(_ id: String) {
    if selectedStarterIDs.contains(id) {
      selectedStarterIDs.remove(id)
    } else {
      selectedStarterIDs.insert(id)
    }
  }

  private func clean(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var orderedExistingPeople: [PersonProfile] {
    existingPeople.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
  }

  private var existingStarterIDs: Set<String> {
    let names = Set(existingRoutines.map { $0.name.lowercased() })
    return Set(
      StarterRoutineTemplate.all.filter { names.contains($0.name.lowercased()) }.map(\.id))
  }

  private var newSelectedStarterCount: Int {
    selectedStarterIDs.subtracting(existingStarterIDs).count
  }

  private var completionButtonTitle: String {
    if newSelectedStarterCount > 0 {
      return
        "Add \(newSelectedStarterCount) Starter Routine\(newSelectedStarterCount == 1 ? "" : "s")"
    }
    return existingRoutines.isEmpty ? "Continue Without Starters" : "Continue"
  }

  private func loadExistingDataIfNeeded() {
    guard !hasLoadedExistingData else { return }
    hasLoadedExistingData = true

    let people = orderedExistingPeople
    guard let primary = people.first else { return }
    primaryName = primary.name
    partnerNames = people.dropFirst().map(\.name)
    selectedStarterIDs = existingStarterIDs
  }
}
