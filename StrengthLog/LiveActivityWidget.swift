import ActivityKit
import SwiftUI
import WidgetKit

struct LiftChaseLiveActivityWidget: Widget {
  private let coral = Color(red: 1.0, green: 0.31, blue: 0.21)
  private let navy = Color(red: 0.05, green: 0.08, blue: 0.14)

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiftChaseLiveActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 5) {
        Text("Lift Chase")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.75))
        HStack(spacing: 10) {
          Text(context.state.exerciseName)
            .font(.headline)
            .lineLimit(1)
          Spacer()
          Text(timerInterval: Date.now...context.state.restEndDate, countsDown: true)
            .font(.title3.monospacedDigit().weight(.bold))
            .foregroundStyle(coral)
        }
        if !context.state.setProgress.isEmpty || !context.state.effort.isEmpty {
          HStack(spacing: 6) {
            if !context.state.setProgress.isEmpty {
              Text(context.state.setProgress)
            }
            if !context.state.setProgress.isEmpty && !context.state.effort.isEmpty {
              Text("·")
            }
            if !context.state.effort.isEmpty {
              Text(context.state.effort)
            }
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.75))
          .lineLimit(1)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .activityBackgroundTint(navy)
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          Text(timerInterval: Date.now...context.state.restEndDate, countsDown: true)
            .font(.headline.monospacedDigit().weight(.bold))
            .foregroundStyle(coral)
        }
      } compactLeading: {
        EmptyView()
      } compactTrailing: {
        Text(timerInterval: Date.now...context.state.restEndDate, countsDown: true)
          .monospacedDigit()
          .foregroundStyle(coral)
      } minimal: {
        Image(systemName: "timer")
          .foregroundStyle(coral)
      }
      .keylineTint(coral)
      .contentMargins(.all, 0, for: .expanded)
    }
  }
}

@main
struct LiftChaseLiveActivityWidgetBundle: WidgetBundle {
  var body: some Widget {
    LiftChaseLiveActivityWidget()
  }
}
