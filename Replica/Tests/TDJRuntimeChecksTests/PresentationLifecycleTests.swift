import Foundation
import Testing
@testable import TDJRuntimeChecks

@MainActor private final class PresentationLifecycleState {
    var task: Task<AudioRuntimeCheckOutcome, Error>?
    var cancelTask: Task<Void,Never>?
    var checkStopped: (@MainActor () -> Bool)?
    var prepared=false,cleared=false,stoppedWhenCleared=false
}

extension RuntimeCheckLifecycleTests {
    @Test func presentationClearsAfterCancelledPlaybackHasStopped() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let state=PresentationLifecycleState()
        defer {
            state.task?.cancel();state.cancelTask?.cancel();state.checkStopped=nil
            try? FileManager.default.removeItem(at:root)
        }
        state.task=Task { @MainActor in
            try await AudioRuntimeChecks.run(outputDirectory:root,seconds:60,searchCatalogTracks:64,
                presentation:.init { model in
                    if let model {
                        state.prepared=true
                        state.checkStopped={ !model.playback.outputActive && !model.playback.isRecording && !model.playback.recordingFinishing }
                        state.cancelTask=Task { @MainActor in
                            try? await Task.sleep(for:.milliseconds(100))
                            state.task?.cancel()
                        }
                    } else {
                        state.cleared=true;state.stoppedWhenCleared=state.checkStopped?() == true
                    }
                })
        }
        do { _=try await state.task?.value;Issue.record("Cancelled presentation completed normally.") }
        catch { #expect(error is CancellationError) }
        state.task=nil
        #expect(state.prepared && state.cleared && state.stoppedWhenCleared)
        #expect(!FileManager.default.fileExists(atPath:root.appendingPathComponent("result.json").path))
        let failure=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("failure.json"))) as? [String:Any]
        #expect(failure?["cancelled"] as? Bool == true)
    }
}
