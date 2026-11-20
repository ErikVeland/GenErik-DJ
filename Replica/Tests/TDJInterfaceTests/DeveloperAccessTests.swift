import Foundation
import Testing

@testable import TDJInterface

@Test @MainActor func developerAccessSurvivesExpiredPreviewAndLongPerformance() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let now = Date()
    let access = StoreAccess(root: root, now: now.addingTimeInterval(-30 * 86_400), developerAccess: true)
    let start = now.addingTimeInterval(-6 * 3600)
    access.beginPerformance(controllerInput: true, now: start)
    access.beginRecording(now: start)
    access.beginPerformance(now: now)
    #expect(!access.previewIsActive)
    for feature in StoreAccessFeature.allCases {
        #expect(access.isUnlocked(feature))
        #expect(!access.hasPurchase(for: feature))
    }
    #expect(access.personalisationIsUnlocked)
    #expect(!access.controllerLimitReached)
    #expect(!access.recordingLimitReached)
    #expect(!access.performanceLimitReached)
    access.endPerformance()
}

@Test @MainActor func developerAccessDoesNotPersistIntoStoreBuild() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let now = Date()
    let developer = StoreAccess(root: root, now: now.addingTimeInterval(-30 * 86_400), developerAccess: true)
    let start = now.addingTimeInterval(-6 * 3600)
    developer.beginPerformance(controllerInput: true, now: start)
    developer.beginRecording(now: start)
    let store = StoreAccess(root: root, developerAccess: false)
    store.beginPerformance(now: now)
    for feature in StoreAccessFeature.allCases { #expect(!store.isUnlocked(feature)) }
    #expect(!store.personalisationIsUnlocked)
    #expect(store.controllerLimitReached)
    #expect(store.recordingLimitReached)
    #expect(store.performanceLimitReached)
    store.endPerformance()
    developer.endPerformance()
}

@Test @MainActor func developerAccessLeavesStorePreviewAvailable() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let access = StoreAccess(root: root, developerAccess: false)
    for feature in StoreAccessFeature.allCases { #expect(access.isUnlocked(feature)) }
    #expect(access.personalisationIsUnlocked)
}
