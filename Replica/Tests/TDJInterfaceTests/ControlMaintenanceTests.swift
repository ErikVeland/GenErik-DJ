import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@Test @MainActor func controlMaintenanceProgressesWithoutVisualPollingAndStopsCleanly() async throws {
    let controller = try PlaybackController(offline: true)
    #expect(controller.playbackTimingActivityActive != true)
    controller.startControlMaintenance()
    try controller.core.setMasterBPM(0)
    controller.core.processControlsWhileIdle()
    try await Task.sleep(for: .milliseconds(50))
    #expect(controller.rejectedCommandCount == 1)
    #expect(controller.playbackTimingActivityActive != true)
    controller.stopAudio()
    #expect(controller.playbackTimingActivityActive != true)
    let count = controller.rejectedCommandCount
    try controller.core.setMasterBPM(0)
    controller.core.processControlsWhileIdle()
    try await Task.sleep(for: .milliseconds(50))
    #expect(controller.rejectedCommandCount == count)
    let (_, messages) = controller.snapshotAndMessages()
    #expect(controller.rejectedCommandCount == count + 1)
    #expect(messages.last?.error == .invalid)
}

@Test @MainActor func controlFeedbackStaysBoundedAndPreservesErrorsWithoutAView() throws {
    let controller = try PlaybackController(offline: true)
    for _ in 0..<20 {
        for _ in 0..<64 { try controller.core.setMixer(.master, value: 0.5) }
        controller.core.processControlsWhileIdle()
        controller.maintainControlState()
    }
    try controller.core.setMasterBPM(0)
    controller.core.processControlsWhileIdle(); controller.maintainControlState()
    for _ in 0..<8 {
        for _ in 0..<64 { try controller.core.setMixer(.master, value: 0.5) }
        controller.core.processControlsWhileIdle(); controller.maintainControlState()
    }
    let (_, messages) = controller.snapshotAndMessages()
    #expect(messages.count == PlaybackController.maximumPendingMessages)
    #expect(messages.compactMap(\.error) == [.invalid])
    #expect(controller.rejectedCommandCount == 1)
    #expect(controller.snapshotAndMessages().1.isEmpty)
}

@Test @MainActor func controlMaintenanceDoesNotRetainItsController() async throws {
    var controller: PlaybackController? = try PlaybackController(offline: true)
    weak var released = controller
    controller?.startControlMaintenance()
    await Task.yield()
    controller = nil
    try await Task.sleep(for: .milliseconds(30))
    #expect(released == nil)
}
