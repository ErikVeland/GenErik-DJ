import CloudKit
import Foundation
import Testing
@testable import TDJInterface

@Test func cloudUploadConflictRequiresEveryServerRevisionToBeVerified() {
    let id = CKRecord.ID(recordName: String(repeating: "a", count: 64), zoneID: .init(zoneName: "AutomaticAnalysis"))
    let second = CKRecord.ID(recordName: String(repeating: "b", count: 64), zoneID: id.zoneID)
    let changed = NSError(domain: CKErrorDomain, code: CKError.Code.serverRecordChanged.rawValue)
    let error = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue,
                        userInfo: [CKPartialErrorsByItemIDKey: [id: changed]])
    #expect(!CloudPreparationSync.hasOnlyVerifiedConflicts(error, ids: []))
    #expect(CloudPreparationSync.hasOnlyVerifiedConflicts(error, ids: [id]))
    let mixed = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue,
                        userInfo: [CKPartialErrorsByItemIDKey: [id: changed, second: NSError(domain: CKErrorDomain, code: CKError.Code.permissionFailure.rawValue)]])
    #expect(!CloudPreparationSync.hasOnlyVerifiedConflicts(mixed, ids: [id, second]))
    #expect(!CloudPreparationSync.hasOnlyVerifiedConflicts(NSError(domain: CKErrorDomain, code: CKError.Code.networkFailure.rawValue), ids: [id]))
}
