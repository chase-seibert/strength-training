import CloudKit
import Foundation

enum KidsWatchCloudStore {
  static let recordType = "KidsWatchCurrentExercise"
  static let containerIdentifier = "iCloud.com.cseibert.StrengthLog"
  private static let recordNamePrefix = "kids-watch-person-"
  private static let zoneID = CKRecordZone.ID(
    zoneName: "StrengthLogKidsWatch", ownerName: CKCurrentUserDefaultName)

  static var container: CKContainer { CKContainer(identifier: containerIdentifier) }
  static var privateDatabase: CKDatabase { container.privateCloudDatabase }

  static func recordID(for personID: UUID) -> CKRecord.ID {
    CKRecord.ID(recordName: recordNamePrefix + personID.uuidString, zoneID: zoneID)
  }

  private static func ensureZone() async throws {
    do {
      _ = try await privateDatabase.recordZone(for: zoneID)
    } catch let error as CKError where error.code == .zoneNotFound {
      _ = try await privateDatabase.save(CKRecordZone(zoneID: zoneID))
    }
  }

  /// Saves only this person's card in the shared, stable person record.
  static func publish(_ snapshot: KidsWatchSnapshot, for personID: UUID) async throws {
    try await ensureZone()
    let database = privateDatabase
    let record = try await personRecord(for: personID)
    record["personID"] = personID.uuidString as CKRecordValue
    record["sessionID"] = snapshot.sessionID.uuidString as CKRecordValue
    record["exerciseID"] = snapshot.exerciseID.uuidString as CKRecordValue
    record["updatedAt"] = snapshot.updatedAt as CKRecordValue
    record["payload"] = try JSONEncoder().encode(snapshot) as CKRecordValue
    if let progress = try? JSONEncoder().encode(
      KidsWatchProgressSnapshot(
        updatedAt: snapshot.updatedAt,
        progress: snapshot.progress ?? [],
        recentWorkouts: snapshot.recentWorkouts ?? []))
    {
      record["progressPayload"] = progress as CKRecordValue
    }
    _ = try await database.save(record)
  }

  static func publish(_ progress: KidsWatchProgressSnapshot, for personID: UUID) async throws {
    try await ensureZone()
    let database = privateDatabase
    let record = try await personRecord(for: personID)
    record["personID"] = personID.uuidString as CKRecordValue
    record["sessionID"] = nil
    record["exerciseID"] = nil
    record["updatedAt"] = progress.updatedAt as CKRecordValue
    record["payload"] = nil
    record["progressPayload"] = try JSONEncoder().encode(progress) as CKRecordValue
    _ = try await database.save(record)
  }

  /// Clears current workout data but preserves the share so it works for future workouts.
  static func clear(personID: UUID, progress: KidsWatchProgressSnapshot? = nil) async throws {
    let record = try await privateDatabase.record(for: recordID(for: personID))
    record["sessionID"] = nil
    record["exerciseID"] = nil
    record["updatedAt"] = Date.now as CKRecordValue
    record["payload"] = nil
    record["progressPayload"] = try progress.map { try JSONEncoder().encode($0) } as CKRecordValue?
    _ = try await privateDatabase.save(record)
  }

  /// Creates or returns a stable private share attached to the person's record.
  static func share(for personID: UUID, name: String) async throws -> CKShare {
    try await ensureZone()
    let database = privateDatabase
    let root = try await personRecord(for: personID)
    if let existingShare = root.share {
      let record = try await database.record(for: existingShare.recordID)
      guard let share = record as? CKShare else {
        throw NSError(
          domain: "KidsWatchCloudStore", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "The workout share record is unavailable."])
      }
      return share
    }
    let share = CKShare(rootRecord: root)
    share[CKShare.SystemFieldKey.title] = "StrengthLog for \(name)" as CKRecordValue
    share.publicPermission = .none
    _ = try await database.modifyRecords(saving: [root, share], deleting: [])
    return share
  }

  private static func personRecord(for personID: UUID) async throws -> CKRecord {
    let id = recordID(for: personID)
    do {
      return try await privateDatabase.record(for: id)
    } catch let error as CKError where error.code == .unknownItem {
      return CKRecord(recordType: recordType, recordID: id)
    }
  }
}
