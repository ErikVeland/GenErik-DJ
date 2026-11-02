import Foundation
import Testing
@testable import TDJRuntimeChecks

@MainActor private final class CheckCancellation {
    var task: Task<AudioRuntimeCheckOutcome, any Error>?
    var delayedCancellation: Task<Void, Never>?
    func cancel(after delay: Duration) {
        if delay == .zero { task?.cancel(); return }
        delayedCancellation = Task { [weak self] in
            try? await Task.sleep(for:delay)
            self?.task?.cancel()
        }
    }
}

@Suite(.serialized) @MainActor struct RuntimeCheckLifecycleTests {
    @Test func syntheticCatalogIsRepeatableCompleteAndMixed() throws {
        for count in [1,2,17,4096] {
            let order = try AudioRuntimeChecks.catalogOrder(count:count)
            let repeated = try AudioRuntimeChecks.catalogOrder(count:count)
            #expect(order == repeated)
            #expect(order.sorted() == Array(0..<count))
            if count > 2 {
                #expect(order != Array(0..<count))
                #expect(order != Array((0..<count).reversed()))
            }
        }
    }
    @Test func invalidChecksDoNotCreateOutput() async {
        for (seconds,sequential,count) in [(Double.nan,false,1),(4.0,false,1),(5.0,true,1),(5.0,false,0)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            do {
                _ = try await AudioRuntimeChecks.run(outputDirectory:root,seconds:seconds,
                    sequential:sequential,searchCatalogTracks:count)
                Issue.record("Invalid check was accepted.")
            } catch {}
            #expect(!FileManager.default.fileExists(atPath:root.path))
        }
    }
    @Test func existingOutputIsRetained() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let original = Data("Retain this file".utf8)
        try original.write(to:root.appendingPathComponent("sentinel"))
        do {
            _ = try await AudioRuntimeChecks.run(outputDirectory:root,seconds:5,searchCatalogTracks:1)
            Issue.record("Existing output was accepted.")
        } catch {}
        #expect(try Data(contentsOf:root.appendingPathComponent("sentinel")) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath:root.path) == ["sentinel"])
    }
    @Test func alreadyCancelledCheckCreatesNoOutput() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let task = Task { @MainActor in
            try await AudioRuntimeChecks.run(outputDirectory:root,seconds:5,searchCatalogTracks:1)
        }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled check was accepted.") }
        catch { #expect(error is CancellationError) }
        #expect(!FileManager.default.fileExists(atPath:root.path))
    }
    @Test func activeCancellationFinishesRecordingAndAllowsAnotherCheck() async throws {
        for (stage,delay) in [("Running playback and recording",Duration.milliseconds(100)),
                              ("Preparing the synthetic audio source",Duration.zero)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at:root) }
            let cancellation = CheckCancellation()
            cancellation.task = Task { @MainActor in
                try await AudioRuntimeChecks.run(outputDirectory:root,seconds:60,searchCatalogTracks:64) { phase in
                    if phase == stage { cancellation.cancel(after:delay) }
                }
            }
            do {
                _ = try await cancellation.task?.value
                Issue.record("Cancelled check completed normally.")
            } catch { #expect(error is CancellationError) }
            cancellation.task = nil
            cancellation.delayedCancellation?.cancel()
            let failure = try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("failure.json"))) as? [String:Any]
            #expect(failure?["cancelled"] as? Bool == true)
            #expect(failure?["passed"] as? Bool == false)
            #expect(!FileManager.default.fileExists(atPath:root.appendingPathComponent("result.json").path))
            let recordings = root.appendingPathComponent("Workspace/Recordings")
            if FileManager.default.fileExists(atPath:recordings.path) {
                #expect(try FileManager.default.contentsOfDirectory(atPath:recordings.path).allSatisfy { !$0.contains(".incomplete.") })
            }
        }
    }
    @Test func preparationImportRuntimeIncludesItsRequiredReport() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let outcome=try await AudioRuntimeChecks.run(outputDirectory:root,seconds:5,searchCatalogTracks:64,
            controlConfiguration:.init(preparationImport:true))
        let result=try #require(JSONSerialization.jsonObject(with:Data(contentsOf:outcome.resultURL)) as? [String:Any])
        let report=try #require(result["preparationImport"] as? [String:Any])
        #expect(report["entriesPerCollection"] as? Int == 10_000)
        let passed=try #require(report["passed"] as? Bool)
        let completed=try #require(report["completedImports"] as? Int)
        if passed {
            #expect(completed>0 && report["failures"] as? Int == 0)
            #expect(report["activePreparationUnchanged"] as? Bool == true)
            #expect(report["fullAnalysisRetained"] as? Bool == true)
        } else { #expect(!outcome.passed) }
        print("PREPARATION_IMPORT_RUNTIME completed=\(completed) importPassed=\(passed) overallPassed=\(outcome.passed)")
    }
}
