import CloudKit
import Foundation
import Testing

@Test func offlineLibraryTransferKeepsDeviceLimitsSeparate() {
    let normal = CloudPreparationTransferLimits(automatic: true, offlineLibrary: false)
    #expect(normal.imports == 32)
    #expect(normal.uploads == 32)
    #expect(normal.batch == 1)
    let offline = CloudPreparationTransferLimits(automatic: true, offlineLibrary: true)
    #if os(macOS)
    #expect(offline.imports == 512)
    #expect(offline.uploads == 512)
    #expect(offline.batch == 32)
    #else
    #expect(offline.imports == normal.imports)
    #expect(offline.uploads == normal.uploads)
    #expect(offline.batch == normal.batch)
    #endif
    #expect(CloudPreparationTransferLimits(automatic: false, offlineLibrary: false).uploads == nil)
}
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
