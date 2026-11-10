import Foundation
import Testing
@testable import TDJInterface

@Test func macSourceTransferAcceptsOnlyVersionedNativeIdentifiers() throws {
    let id = UUID()
    #expect(MacAnalysisSourceRequest(version: 1, id: id, sourceID: "42").valid)
    #expect(MacAnalysisSourceRequest(version: 1, id: id, sourceID: nil).valid)
    #expect(!MacAnalysisSourceRequest(version: 2, id: id, sourceID: "42").valid)
    #expect(!MacAnalysisSourceRequest(version: 1, id: id, sourceID: "../../library.json").valid)
    #expect(MacAnalysisSourceRequest(version: 1, id: id, sourceID: "42").filename == id.uuidString + ".caf")
}

@Test @MainActor func macSourceTransferPausesCloudAdmissionAndCancelsWithPlayback() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root)
    #expect(model.canSyncCloud)
    model.macSourceTransferActive = true
    #expect(!model.canSyncCloud)
    let task = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
    model.macSourceTransferWork = task
    model.cancelCloudSyncForPlayback()
    #expect(task.isCancelled)
}

@Test @MainActor func macSourceTransferCancelsWhenBackgroundedOrUnplugged() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root)
    let background = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
    model.macSourceTransferWork = background
    model.setLibraryAnalysisBackgrounded(true)
    #expect(background.isCancelled)
    model.updateLibraryAnalysisConditions(.init(externalPower: true, thermalState: .nominal))
    let unplugged = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
    model.macSourceTransferWork = unplugged
    model.updateLibraryAnalysisConditions(.init(externalPower: false, thermalState: .nominal))
    #expect(unplugged.isCancelled)
}
