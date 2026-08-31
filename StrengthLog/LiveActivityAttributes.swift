import ActivityKit
import Foundation

struct LiftChaseLiveActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var restEndDate: Date
    var exerciseName: String
    var setProgress: String
    var effort: String

    private enum CodingKeys: String, CodingKey {
      case restEndDate
      case exerciseName
      case setProgress
      case effort
    }

    init(
      restEndDate: Date,
      exerciseName: String = "Workout",
      setProgress: String = "",
      effort: String = ""
    ) {
      self.restEndDate = restEndDate
      self.exerciseName = exerciseName
      self.setProgress = setProgress
      self.effort = effort
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      restEndDate = try container.decode(Date.self, forKey: .restEndDate)
      exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? "Workout"
      setProgress = try container.decodeIfPresent(String.self, forKey: .setProgress) ?? ""
      effort = try container.decodeIfPresent(String.self, forKey: .effort) ?? ""
    }
  }

  var sessionID: String
  var routineName: String
}
