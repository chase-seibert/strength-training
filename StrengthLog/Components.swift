import SwiftUI
import UIKit

struct SectionEyebrow: View {
  let text: String

  var body: some View {
    Text(text.uppercased())
      .font(.caption.weight(.bold))
      .tracking(1.2)
      .foregroundStyle(.secondary)
  }
}

struct InitialBadge: View {
  let name: String
  let colorHex: String
  var size: CGFloat = 30

  var body: some View {
    Text(String(name.prefix(1)).uppercased())
      .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(Color(hex: colorHex), in: Circle())
      .accessibilityLabel(name)
  }
}

struct MetricTile: View {
  let value: String
  let label: String
  let symbol: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(tint)
        .font(.title3.weight(.semibold))
      Text(value)
        .font(.title2.bold())
        .contentTransition(.numericText())
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

struct EmptyStateView: View {
  let symbol: String
  let title: String
  let message: String

  var body: some View {
    ContentUnavailableView(title, systemImage: symbol, description: Text(message))
  }
}

struct ExerciseArtwork: View {
  let exercise: Exercise

  var body: some View {
    ExerciseRemoteImage(url: exercise.imageURL)
  }
}

struct ExerciseRemoteImage: View {
  let url: URL?

  var body: some View {
    Group {
      if let url, url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        exerciseImagePlaceholder
      }
    }
    .clipped()
  }

  private var exerciseImagePlaceholder: some View {
    ZStack {
      LinearGradient(
        colors: [Theme.navy, Theme.navy.opacity(0.72)], startPoint: .topLeading,
        endPoint: .bottomTrailing)
      Image(systemName: "figure.strengthtraining.traditional")
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(Theme.coral)
    }
  }
}

struct ExerciseImageCarousel: View {
  let exercise: Exercise
  var height: CGFloat = 300
  @State private var selection = 0

  var body: some View {
    ZStack(alignment: .topTrailing) {
      if exercise.imageURLs.isEmpty {
        ExerciseRemoteImage(url: nil)
      } else {
        TabView(selection: $selection) {
          ForEach(Array(exercise.imageURLs.enumerated()), id: \.offset) { index, url in
            ExerciseRemoteImage(url: url)
              .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: exercise.imageURLs.count > 1 ? .always : .never))
      }

      if exercise.imageURLs.count > 1 {
        Text("\(selection + 1) / \(exercise.imageURLs.count)")
          .font(.caption.bold().monospacedDigit())
          .foregroundStyle(.white)
          .padding(.horizontal, 9)
          .padding(.vertical, 6)
          .background(.black.opacity(0.58), in: Capsule())
          .padding(12)
      }
    }
    .frame(height: height)
    .background(Color.secondary.opacity(0.08))
    .clipped()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Form images for \(exercise.name)")
  }
}

struct ExerciseImageSheet: View {
  @Environment(\.dismiss) private var dismiss
  let exercise: Exercise

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        ExerciseImageCarousel(exercise: exercise, height: 460)
          .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        Text("Swipe to compare positions")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding()
      .background(Color(.systemGroupedBackground))
      .navigationTitle(exercise.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
  }
}

extension Date {
  var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}
