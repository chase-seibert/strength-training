import Foundation

@main
struct ValidateHevyImport {
  static func main() throws {
    let rows = [
      "title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_lbs,reps,distance_miles,duration_seconds,rpe",
      "Core,\"26 Aug 2026, 06:43\",\"26 Aug 2026, 07:24\",\"Controlled, steady\",Deadlift (Dumbbell),,,0,normal,100,8,,,",
      "Core,\"26 Aug 2026, 06:43\",\"26 Aug 2026, 07:24\",\"Controlled, steady\",Deadlift (Dumbbell),,,1,normal,100,8,,,8.5",
      "Core,\"26 Aug 2026, 06:43\",\"26 Aug 2026, 07:24\",,Plank,,,0,normal,,,,60,",
      "Upper Body,\"24 Aug 2026, 06:46\",\"24 Aug 2026, 08:07\",,Pull Up (Band),,,0,normal,,3,,,",
    ]
    let sample = rows.prefix(3).joined(separator: "\r\n") + "\r\n"
      + rows.dropFirst(3).joined(separator: "\n") + "\n"
    let document = try HevyCSVParser.parse(
      data: Data(sample.utf8), filename: "workout_data.csv")
    precondition(document.workouts.count == 2)
    precondition(document.routineNames == ["Core", "Upper Body"])
    precondition(document.exerciseNames == ["Deadlift (Dumbbell)", "Plank", "Pull Up (Band)"])
    precondition(document.rowCount == 4)
    let core = document.workouts.first { $0.title == "Core" }
    precondition(core?.exercises.count == 2)
    precondition(core?.exercises.first?.sets.count == 2)
    precondition(core?.exercises.first?.sets.last?.rpe == 8.5)
    precondition(core?.exercises.last?.sets.first?.durationSeconds == 60)
    print("Hevy CSV parser OK: mixed CRLF/LF, 2 workouts, 3 exercises, 4 sets")
  }
}
