import Foundation
import TDJCore

struct WaveformWorkPaused: Error {}

enum WaveformWork {
    static func isPaused(_ core: SampleTransport) -> Bool {
        guard let state = core.snapshot() else { return true }
        return DeckID.allCases.contains { state[$0].phase.active || state[$0].touchActive }
    }
    static func check(_ core: SampleTransport) throws {
        try Task.checkCancellation()
        if isPaused(core) { throw WaveformWorkPaused() }
    }
    static func waitUntilIdle(_ core: SampleTransport) async throws {
        try Task.checkCancellation()
        while isPaused(core) { try await Task.sleep(for: .milliseconds(100)) }
        try Task.checkCancellation()
    }
}
