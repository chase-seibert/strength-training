import Charts
import SwiftUI
import WidgetKit

private struct ProgressTimelineEntry: TimelineEntry {
  let date: Date
  let snapshot: ProgressWidgetSnapshot?
  let errorMessage: String?
}

private struct ProgressTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> ProgressTimelineEntry {
    ProgressTimelineEntry(date: .now, snapshot: nil, errorMessage: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (ProgressTimelineEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(
    in context: Context, completion: @escaping (Timeline<ProgressTimelineEntry>) -> Void
  ) {
    let entry = loadEntry()
    let nextRefresh =
      Calendar.current.date(byAdding: .hour, value: 12, to: .now) ?? .now.addingTimeInterval(43_200)
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }

  private func loadEntry() -> ProgressTimelineEntry {
    do {
      return ProgressTimelineEntry(
        date: .now, snapshot: try ProgressWidgetSnapshotStore.load(), errorMessage: nil)
    } catch {
      return ProgressTimelineEntry(
        date: .now, snapshot: nil, errorMessage: error.localizedDescription)
    }
  }
}

struct ProgressWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: ProgressWidgetConfiguration.kind, provider: ProgressTimelineProvider()
    ) { entry in
      ProgressWidgetView(entry: entry)
    }
    .configurationDisplayName("StrengthLog")
    .description("Weekly training volume and recent workouts with personal records.")
    .supportedFamilies([.systemMedium, .systemLarge])
    .contentMarginsDisabled()
  }
}

private struct ProgressWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ProgressTimelineEntry

  private var isLarge: Bool { family == .systemLarge }

  var body: some View {
    Group {
      if let errorMessage = entry.errorMessage {
        unavailable(message: "Widget data unavailable", detail: errorMessage)
      } else if let snapshot = entry.snapshot {
        content(snapshot)
      } else {
        unavailable(
          message: "Open StrengthLog to load progress",
          detail: "Your workout data stays on your iPhone.")
      }
    }
    .containerBackground(.background, for: .widget)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func content(_ snapshot: ProgressWidgetSnapshot) -> some View {
    let points = snapshot.points(asOf: entry.date)
    let history = Array(snapshot.history(asOf: entry.date).prefix(3))
    return VStack(alignment: .leading, spacing: isLarge ? 7 : 4) {
      HStack(alignment: .firstTextBaseline) {
        Text("StrengthLog").font(.headline)
        Spacer(minLength: 4)
        Text("Updated \(snapshot.generatedAt, style: .time)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if points.isEmpty {
        ContentUnavailableView("No pounds volume yet", systemImage: "chart.xyaxis.line")
          .frame(maxWidth: .infinity, maxHeight: isLarge ? 130 : 85)
      } else {
        Chart(points) { point in
          LineMark(
            x: .value("Week", point.weekStart, unit: .weekOfYear),
            y: .value("Volume", point.volume),
            series: .value("Person", point.personName)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(by: .value("Person", point.personName))
          PointMark(
            x: .value("Week", point.weekStart, unit: .weekOfYear),
            y: .value("Volume", point.volume)
          )
          .foregroundStyle(by: .value("Person", point.personName))
        }
        .chartForegroundStyleScale(
          domain: snapshot.participants.map(\.name),
          range: snapshot.participants.map { progressWidgetColor($0.colorHex) }
        )
        .chartLegend(.hidden)
        .chartYAxisLabel("lb × reps")
        .chartYScale(domain: 0...max(points.map(\.volume).max() ?? 1, 1))
        .chartYAxis {
          AxisMarks(position: .trailing, values: .automatic(desiredCount: isLarge ? 5 : 3)) {
            value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
              if let volume = value.as(Double.self) {
                Text(volume.formatted(.number.precision(.fractionLength(0))))
                  .font(.system(size: isLarge ? 10 : 9))
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        .frame(height: isLarge ? 112 : 86)
        .accessibilityLabel("Weekly training volume in pounds times reps")
        participantLegend(snapshot.participants)
      }

      if isLarge {
        if !history.isEmpty {
          Divider()
          VStack(alignment: .leading, spacing: 5) {
            ForEach(history) { row in
              historyRow(row)
            }
          }
        } else {
          Text("No workouts in the last 12 weeks")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(16)
  }

  private func participantLegend(_ participants: [ProgressWidgetParticipant]) -> some View {
    let displayed = Array(participants.prefix(3))
    return HStack(spacing: 9) {
      ForEach(displayed) { participant in
        HStack(spacing: 4) {
          Circle().fill(progressWidgetColor(participant.colorHex)).frame(width: 7, height: 7)
          Text(participant.name).lineLimit(1)
        }
      }
      if participants.count > displayed.count {
        Text("+\(participants.count - displayed.count)").foregroundStyle(.secondary)
      }
    }
    .font(.caption2)
    .accessibilityElement(children: .combine)
  }

  private func historyRow(_ row: ProgressWidgetHistoryRow) -> some View {
    HStack(spacing: 5) {
      VStack(alignment: .leading, spacing: 1) {
        Text(row.routineName).font(.caption.weight(.semibold)).lineLimit(1)
        Text(
          "\(row.startedAt.formatted(date: .abbreviated, time: .omitted)) · \(row.completedSetCount)/\(row.totalSetCount) sets"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }
      Spacer(minLength: 2)
      if row.personalRecordCount > 0 {
        HStack(spacing: 5) {
          Image(systemName: "trophy.fill")
            .frame(width: 14)
          Text("\(row.personalRecordCount)")
            .frame(width: 18, alignment: .trailing)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(progressWidgetColor("D69E00"))
        .frame(width: 40, alignment: .trailing)
        .accessibilityLabel(
          "\(row.personalRecordCount) personal record\(row.personalRecordCount == 1 ? "" : "s")")
      }
    }
  }

  private func unavailable(message: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(message, systemImage: "chart.xyaxis.line")
        .font(.headline)
      Text(detail).font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

private func progressWidgetColor(_ hex: String) -> Color {
  let value = UInt64(hex, radix: 16) ?? 0x6B7280
  return Color(
    .sRGB,
    red: Double((value >> 16) & 0xFF) / 255,
    green: Double((value >> 8) & 0xFF) / 255,
    blue: Double(value & 0xFF) / 255,
    opacity: 1)
}
