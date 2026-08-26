import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(\.modelContext) private var context
  @Environment(HevyImportCoordinator.self) private var importCoordinator
  @Query(sort: \PersonProfile.sortOrder) private var people: [PersonProfile]
  @State private var showingNewPerson = false
  @State private var showingHevyImporter = false

  var body: some View {
    List {
      Section {
        ForEach(PersonProfile.ordered(people.filter { !$0.isArchived })) { person in
          NavigationLink {
            PersonEditor(person: person)
          } label: {
            HStack(spacing: 12) {
              InitialBadge(name: person.name, colorHex: person.colorHex, size: 38)
              Text(person.name).font(.headline)
            }
            .padding(.vertical, 3)
          }
        }
        Button("Add person", systemImage: "person.badge.plus") { showingNewPerson = true }
      } header: {
        Text("People")
      } footer: {
        Text(
          "Choose who appears each time you start a routine. Names on past sessions stay unchanged."
        )
      }

      if people.contains(where: \.isArchived) {
        Section("Archived") {
          ForEach(PersonProfile.ordered(people.filter(\.isArchived))) { person in
            Button {
              person.isArchived = false
            } label: {
              LabeledContent(person.name, value: "Restore")
            }
          }
        }
      }

      Section("Data") {
        Button("Import Hevy CSV", systemImage: "square.and.arrow.down") {
          showingHevyImporter = true
        }
      }

      Section("About") {
        LabeledContent("Catalog", value: "Free Exercise DB")
        LabeledContent("Exercises", value: "\(exerciseCount)")
        NavigationLink("Data source notes") { ResearchSummaryView() }
      }

      #if DEBUG
        Section("Developer") {
          NavigationLink {
            DeveloperMenuView()
          } label: {
            Label("Developer Menu", systemImage: "hammer.fill")
          }
        }
      #endif
    }
    .navigationTitle("Settings")
    .sheet(isPresented: $showingNewPerson) { NewPersonSheet() }
    .fileImporter(
      isPresented: $showingHevyImporter,
      allowedContentTypes: [.commaSeparatedText],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first { importCoordinator.open(url) }
      case .failure(let error):
        importCoordinator.notice = HevyImportNotice(
          title: "Couldn’t Open CSV", message: error.localizedDescription)
      }
    }
  }

  private var exerciseCount: Int {
    (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
  }
}

#if DEBUG
  struct DeveloperMenuView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
      List {
        Section {
          Button("Replay First-Time Experience", systemImage: "arrow.counterclockwise") {
            hasCompletedOnboarding = false
          }
        } header: {
          Text("Onboarding")
        } footer: {
          Text(
            "Shows onboarding again with your existing people and routines filled in. Workout history, exercises, and configuration are preserved."
          )
        }
      }
      .navigationTitle("Developer")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
#endif

struct PersonEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var person: PersonProfile
  private let colors = ["FF5A45", "59A8FA", "45D1A8", "A778F5", "F5B942", "E96BA8"]

  var body: some View {
    Form {
      Section("Profile") {
        TextField("Name", text: $person.name)
        HStack {
          ForEach(colors, id: \.self) { hex in
            Button {
              person.colorHex = hex
            } label: {
              Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                .overlay {
                  if person.colorHex == hex {
                    Image(systemName: "checkmark").foregroundStyle(.white).fontWeight(.bold)
                  }
                }
            }
            .buttonStyle(.plain)
          }
        }
      }
      Section {
        Button("Archive person", role: .destructive) {
          person.isArchived = true
          dismiss()
        }
      }
    }
    .navigationTitle(person.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct NewPersonSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query(sort: \PersonProfile.sortOrder) private var people: [PersonProfile]
  @State private var name = ""

  var body: some View {
    NavigationStack {
      Form { TextField("Name", text: $name) }
        .navigationTitle("Add Person")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
              context.insert(
                PersonProfile(
                  name: name.trimmingCharacters(in: .whitespacesAndNewlines), colorHex: "A778F5",
                  sortOrder: (people.map(\.sortOrder).max() ?? -1) + 1))
              try? context.save()
              dismiss()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }
  }
}

struct ResearchSummaryView: View {
  var body: some View {
    List {
      Section("Bundled source") {
        Text(
          "Free Exercise DB provides 800+ public-domain exercises, instructions, muscle and equipment metadata, and two-pose imagery. StrengthLog ships a compact derived catalog and phone-optimized images for fully offline use."
        )
      }
      Section("Why this source") {
        Label("No API key or runtime dependency", systemImage: "key.slash")
        Label("Unlicense / public-domain dedication", systemImage: "checkmark.shield")
        Label("Form instructions and imagery", systemImage: "photo.on.rectangle")
      }
      Section("Production note") {
        Text(
          "Exercise names and form cues should receive a trainer-led safety review before a public launch. The catalog is reference material, not medical advice."
        )
      }
    }
    .navigationTitle("Catalog Notes")
  }
}
