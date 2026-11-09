import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@Suite(.serialized) struct StreamedPlaybackIntegrationTests {
    @Test(.timeLimit(.minutes(1))) @MainActor
    func persistentSyncStreamedJumpsAndReleasesMatchPreparedAudio() async throws {
        let (streamed, reference, root, _, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        for controller in [streamed, reference] { try controller.play(.a) }
        _ = streamed.core.renderOffline(frames: 512)
        _ = reference.core.renderOffline(frames: 512)
        try streamed.perform(.jump, deck: .a, value: 12 * 44100 + 1234)
        _ = streamed.snapshotAndMessages()
        #expect(streamed.preparingSourceDecks.contains(.a))
        let ongoing = streamed.core.renderOffline(frames: 512)
        let previous = reference.core.renderOffline(frames: 512)
        #expect(ongoing.left == previous.left && ongoing.right == previous.right)
        await streamed.flushSourcePreparations()
        try reference.perform(.jump, deck: .a, value: 12 * 44100 + 1234)
        for controller in [streamed, reference] {
            #expect(controller.core.snapshot()?.a.synced == true)
            #expect(abs(try #require(controller.core.snapshot()?.syncPhaseError(.a))) < 0.001)
            try controller.perform(.touch, deck: .a, value: 5 * 44100 + 777, touchRate: 0, followsPosition: true)
            await controller.flushSourcePreparations()
            _ = controller.core.renderOffline(frames: 256)
            try controller.perform(.touch, deck: .a, enabled: false)
            await controller.flushSourcePreparations()
            #expect(controller.core.snapshot()?.a.touchActive == false)
            #expect(abs(try #require(controller.core.snapshot()?.syncPhaseError(.a))) < 0.001)
        }
        for controller in [streamed, reference] {
            try controller.perform(.loop, deck: .a, value: 10 * 44100, end: 14 * 44100, quantum: 0.5)
            await controller.flushSourcePreparations()
        }
        for _ in 0..<32 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            #expect(actual.left == expected.left && actual.right == expected.right)
            try await Task.sleep(for: .milliseconds(1))
        }
        let loop = try #require(streamed.core.snapshot()?.a)
        #expect(abs(loop.loopStart - 441000.0) < 0.000001)
        #expect(abs(loop.loopEnd - 617400.0) < 0.000001)
        #expect(abs(try #require(streamed.core.snapshot()?.syncPhaseError(.a))) < 0.001)
        #expect(streamed.sourcePreparationRequests > 0)
        #expect(streamed.sourcePreparationFailures == 0)
        #expect(streamed.rejectedCommandCount == 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }

    @MainActor private func fixture(bpm: Double = 120) async throws -> (
        PlaybackController, PlaybackController, URL, Track, WorkspaceStore
    ) {
        var project = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { project.deleteLastPathComponent() }
        let source = project.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: root) } }
        let store = try WorkspaceStore(root: root)
        try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent("source.wav"))
        let analysis = AudioAnalysis(
            implementation: "stream-loader-fixture", configurationID: "fixture",
            contentSHA256: try AudioAnalyzer.sha256(url: source), sampleRate: 44100, frameCount: 705600,
            channelCount: 2, waveformFramesPerBin: 441, waveform: [], bpm: bpm, beatAnchorFrame: 0, tempoConfidence: 1,
            key: nil, keyConfidence: 0, chroma: [], timbre: [])
        let track = try Track(title: "Stream loader fixture", mediaFilename: "source.wav", analysis: analysis)
        let streamed = try PlaybackController(offline: true, streamingPlayback: true)
        let reference = try PlaybackController(offline: true)
        try await streamed.load(track: track, store: store, deck: .a)
        try await reference.load(track: track, store: store, deck: .a)
        complete = true
        return (streamed, reference, root, track, store)
    }
    @Test(.timeLimit(.minutes(1))) @MainActor func streamedLoaderMatchesReferenceAcrossPCMBlocks() async throws {
        let (streamed, reference, root, _, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        #expect(streamed.core.snapshot()?.a.phase == .ready)
        try streamed.play(.a)
        try reference.play(.a)
        for _ in 0..<64 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            #expect(actual.left == expected.left)
            #expect(actual.right == expected.right)
            try await Task.sleep(for: .milliseconds(1))
        }
        _ = streamed.snapshotAndMessages()
        let summary = streamed.core.streamingSummary()
        #expect(summary.activeAssets == 1)
        #expect(summary.allocatedPCMBytes == PCMStreamingLimits.assetPCMBytes)
        #expect(!summary.continuityFailed)
        #expect(summary.globalReservedPCMBytes <= PCMStreamingLimits.globalPCMBytes)
        #expect(streamed.rejectedCommandCount == 0)
    }
    @Test(.timeLimit(.minutes(1))) @MainActor func coldJumpPreparesWhileCurrentAudioKeepsPlaying() async throws {
        let (streamed, reference, root, _, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.play(.a)
        try reference.play(.a)
        let before = try #require(streamed.core.snapshot()?.a.sourceFrame)
        try streamed.perform(.jump, deck: .a, value: 12 * 44100)
        _ = streamed.snapshotAndMessages()
        #expect(streamed.preparingSourceDecks.contains(.a))
        #expect(streamed.core.snapshot()?.a.sourceFrame == before)
        let continuing = streamed.core.renderOffline(frames: 512)
        let expected = reference.core.renderOffline(frames: 512)
        #expect(continuing.left == expected.left)
        #expect(continuing.right == expected.right)
        await streamed.flushSourcePreparations()
        try reference.perform(.jump, deck: .a, value: 12 * 44100)
        #expect(streamed.core.snapshot()?.a.sourceFrame == reference.core.snapshot()?.a.sourceFrame)
        #expect(abs(try #require(streamed.core.snapshot()?.syncPhaseError(.a))) < 0.001)
        let jumped = streamed.core.renderOffline(frames: 512)
        let expectedJump = reference.core.renderOffline(frames: 512)
        #expect(jumped.left == expectedJump.left)
        #expect(jumped.right == expectedJump.right)
        #expect(streamed.sourcePreparationFailures == 0)
        #expect(streamed.rejectedCommandCount == 0)
        #expect(streamed.core.streamingSummary().rejectedColdCommands > 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }
    @Test(.timeLimit(.minutes(1))) @MainActor func cancelledColdReverseCannotChangeLiveKeylockAudio() async throws {
        let (streamed, reference, root, _, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.setMasterBPM(180)
        try reference.setMasterBPM(180)
        try streamed.play(.a)
        try reference.play(.a)
        for _ in 0..<32 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            #expect(actual.left == expected.left)
            #expect(actual.right == expected.right)
        }
        try streamed.perform(.touch, deck: .a, value: 12 * 44100, end: 13 * 44100, touchRate: -1)
        _ = streamed.snapshotAndMessages()
        #expect(streamed.preparingSourceDecks.contains(.a))
        try streamed.perform(.touch, deck: .a, enabled: false)
        await streamed.flushSourcePreparations()
        for _ in 0..<16 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            let mismatch = actual.left.indices.first {
                actual.left[$0] != expected.left[$0] || actual.right[$0] != expected.right[$0]
            }
            #expect(mismatch == nil)
            if mismatch != nil { break }
        }
        #expect(streamed.core.snapshot()?.a.touchActive == false)
        #expect(streamed.core.snapshot()?.a.performanceRate == 1)
        #expect(streamed.preparingSourceDecks.isEmpty)
        #expect(streamed.sourcePreparationFailures == 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }
    @Test(.timeLimit(.minutes(1))) @MainActor func optionalCueWarmingCannotInterruptThePlayingDeck() async throws {
        let (streamed, reference, root, _, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.play(.a)
        try reference.play(.a)
        let before = streamed.core.streamingSummary().bytesRead
        streamed.warmCuePositions((1...8).map { PerformanceCue(frame: Double($0) * 1.8 * 44100) }, deck: .a)
        for _ in 0..<64 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            let matches = actual.left == expected.left && actual.right == expected.right
            #expect(matches)
            try await Task.sleep(for: .milliseconds(1))
        }
        let summary = streamed.core.streamingSummary()
        #expect(summary.bytesRead > before)
        #expect(!summary.continuityFailed)
        #expect(summary.capacityFailures == 0)
        #expect(summary.allocatedPCMBytes == PCMStreamingLimits.assetPCMBytes)
    }
    @Test(.timeLimit(.minutes(1))) @MainActor func occupiedReplacementBudgetCannotBlockCurrentPlayback() async throws {
        let (streamed, reference, root, track, store) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        let cache = root.appendingPathComponent("PlaybackCache/\(track.id)-stereo-f32-v1.pcm")
        var leases: [PCMAsset] = []
        for _ in 0..<3 {
            leases.append(
                try PCMAsset(
                    streamedFile: cache, frames: UInt64(track.analysis.frameCount),
                    sampleRate: track.analysis.sampleRate))
        }
        try streamed.play(.a)
        try reference.play(.a)
        let incoming = Task { try await streamed.load(track: track, store: store, deck: .b) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(streamed.core.snapshot()?.b.phase == .empty)
        #expect(streamed.core.streamingSummary().globalReservedPCMBytes == PCMStreamingLimits.globalPCMBytes)
        let actual = streamed.core.renderOffline(frames: 512)
        let expected = reference.core.renderOffline(frames: 512)
        let matches = actual.left == expected.left && actual.right == expected.right
        #expect(matches)
        leases.removeLast()
        try await incoming.value
        #expect(streamed.core.snapshot()?.b.phase == .ready)
        #expect(!streamed.core.streamingSummary().continuityFailed)
        #expect(streamed.core.streamingSummary().globalReservedPCMBytes <= PCMStreamingLimits.globalPCMBytes)
    }
    @Test(.timeLimit(.minutes(1)), arguments: [120.0, 150.0, 1000.0]) @MainActor
    func coldRecallStartsAtTheCueWithoutStartingOldAudio(_ bpm: Double) async throws {
        let (streamed, reference, root, _, _) = try await fixture(bpm: bpm)
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.core.configureMaximumOutputFrames(4096)
        try streamed.recallCue(.init(frame: 12 * 44100), deck: .a, quantum: 1)
        _ = streamed.snapshotAndMessages()
        #expect(streamed.preparingSourceDecks.contains(.a))
        #expect(streamed.core.snapshot()?.a.phase == .ready)
        #expect(streamed.core.snapshot()?.a.sourceFrame == 0)
        #expect(streamed.core.snapshot()?.clockRunning == false)
        await streamed.flushSourcePreparations()
        #expect(streamed.core.snapshot()?.a.phase == .playing)
        #expect(streamed.core.snapshot()?.a.sourceFrame == 12.0 * 44100.0)
        try reference.perform(.jump, deck: .a, value: 12 * 44100, end: 1)
        try reference.play(.a)
        let actual = streamed.core.renderOffline(frames: 512)
        let expected = reference.core.renderOffline(frames: 512)
        let matches = actual.left == expected.left && actual.right == expected.right
        #expect(matches)
        #expect(streamed.core.snapshot()?.masterBeat == reference.core.snapshot()?.masterBeat)
        #expect(streamed.sourcePreparationFailures == 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }
    @Test(.timeLimit(.minutes(1))) @MainActor func manualPlayCancelsAnUnpreparedCueStart() async throws {
        let (streamed, reference, root, _, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.recallCue(.init(frame: 12 * 44100), deck: .a, quantum: 1)
        _ = streamed.snapshotAndMessages()
        #expect(streamed.preparingSourceDecks.contains(.a))
        try streamed.play(.a)
        await streamed.flushSourcePreparations()
        #expect(streamed.core.snapshot()?.a.phase == .ready)
        #expect(streamed.core.snapshot()?.a.sourceFrame == 0)
        #expect(streamed.core.snapshot()?.clockRunning == false)
        #expect(streamed.preparingSourceDecks.isEmpty)
        #expect(streamed.core.renderOffline(frames: 512).left.allSatisfy { $0 == 0 })
        #expect(streamed.sourcePreparationFailures == 0)
    }
    @Test(.timeLimit(.minutes(1))) @MainActor func coldSavedLoopRecallMatchesLegacyAcrossItsWrap() async throws {
        let (streamed, reference, root, _, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.recallCue(.init(frame: 12 * 44100, loopEnd: 14 * 44100), deck: .a, quantum: 1)
        _ = streamed.snapshotAndMessages()
        #expect(streamed.core.snapshot()?.a.phase == .ready)
        await streamed.flushSourcePreparations()
        try reference.perform(.loop, deck: .a, value: 12 * 44100, end: 14 * 44100, quantum: 1)
        try reference.play(.a)
        for _ in 0..<200 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            let matches = actual.left == expected.left && actual.right == expected.right
            #expect(matches)
            if !matches { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(streamed.core.snapshot()?.a.loopEnabled == true)
        #expect(streamed.core.snapshot()?.a.sourceFrame == reference.core.snapshot()?.a.sourceFrame)
        #expect(streamed.sourcePreparationFailures == 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }
    @Test(.timeLimit(.minutes(1)), arguments: ["mode", "grid", "freeze"]) @MainActor
    func contextChangesCancelColdAuditionsBeforeTheyStart(_ change: String) async throws {
        let (streamed, reference, root, track, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.setMasterBPM(180)
        try reference.setMasterBPM(180)
        try streamed.play(.a)
        try reference.play(.a)
        for _ in 0..<32 {
            _ = streamed.core.renderOffline(frames: 512)
            _ = reference.core.renderOffline(frames: 512)
        }
        let model = try ReplicaModel(root: root, playback: streamed)
        model.library.tracks = [track]
        model.loaded[.a] = track.id
        model.frozen.insert(.a)
        model.superSlicerFamilies[.a] = .turntablism
        model.viewport[.a] = 12 * 44100
        model.performance.slicerQuantize = false
        model.refreshPlayback()
        let session = WaveformGestureSession()
        let point = SurfacePoint(id: 1, x: 0.55, y: 0.8)
        session.handle(.init(phase: .began, points: [point], ending: []), model: model, deck: .a, span: 8 * 44100)
        #expect(streamed.preparingSourceDecks.contains(.a))
        #expect(model.playbackSnapshot?.a.touchActive == false)
        switch change {
        case "mode": model.selectSuperSlicerFamily(.pitch, deck: .a)
        case "grid": model.toggleGridEditing(deck: .a)
        default: model.toggleFreeze(deck: .a)
        }
        await streamed.flushSourcePreparations()
        session.handle(.init(phase: .ended, points: [point], ending: [1]), model: model, deck: .a, span: 8 * 44100)
        for _ in 0..<16 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            let matches = actual.left == expected.left && actual.right == expected.right
            #expect(matches)
            if !matches { break }
        }
        #expect(streamed.core.snapshot()?.a.touchActive == false)
        #expect(streamed.preparingSourceDecks.isEmpty)
        #expect(streamed.sourcePreparationFailures == 0)
    }
    @Test(.timeLimit(.minutes(1)), arguments: [false, true]) @MainActor
    func coldSavedLoopCanRestartAnEndedTrackWithoutAnOldFluxReturn(_ flux: Bool) async throws {
        let (streamed, reference, root, track, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.perform(.flux, deck: .a, enabled: flux)
        try streamed.perform(.jump, deck: .a, value: Double(track.analysis.frameCount - 256))
        await streamed.flushSourcePreparations()
        try streamed.play(.a)
        _ = streamed.core.renderOffline(frames: 512)
        _ = streamed.snapshotAndMessages()
        #expect(streamed.core.snapshot()?.a.phase == .ended)
        #expect(streamed.core.snapshot()?.clockRunning == false)
        let start = 6.0 * 44100
        let end = 8.0 * 44100
        let ended = try #require(streamed.core.snapshot())
        for loopEnd in [Optional<Double>.none, Optional(end)] {
            let control = SourceControl.cueRecall(.a, ended.a.generation, frame: start, loopEnd: loopEnd, quantum: 1)
            let targets = control.preparationTargets(
                snapshot: ended, deck: .a, frames: UInt64(track.analysis.frameCount))
            #expect(!targets.isEmpty && targets.allSatisfy { $0.continuingPosition == start })
        }
        try streamed.recallCue(.init(frame: start, loopEnd: end), deck: .a, quantum: 1)
        _ = streamed.snapshotAndMessages()
        #expect(streamed.preparingSourceDecks.contains(.a))
        #expect(streamed.core.snapshot()?.a.phase == .ended)
        #expect(streamed.core.snapshot()?.a.sourceFrame == Double(track.analysis.frameCount))
        await streamed.flushSourcePreparations()
        let recalled = try #require(streamed.core.snapshot())
        #expect(recalled.a.phase == .playing && recalled.clockRunning)
        #expect(recalled.a.sourceFrame == start && recalled.a.continuingFrame == start)
        #expect(recalled.a.loopEnabled && recalled.a.loopStart == start && recalled.a.loopEnd == end)
        let audio = streamed.core.renderOffline(frames: 512)
        #expect(audio.left.contains { abs($0) > 0.00001 })
        let looped = try #require(streamed.core.snapshot()?.a)
        try streamed.perform(.loop, deck: .a, enabled: false)
        await streamed.flushSourcePreparations()
        let resumed = try #require(streamed.core.snapshot()?.a)
        #expect(resumed.phase == .playing && !resumed.loopEnabled)
        #expect(resumed.sourceFrame == (flux ? looped.continuingFrame : looped.sourceFrame))
        #expect(resumed.sourceFrame >= start && resumed.sourceFrame < end)
        #expect(streamed.sourcePreparationFailures == 0 && streamed.rejectedCommandCount == 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }

    @Test(.timeLimit(.minutes(1))) @MainActor func playRestartsEndedStreamAfterPreparingTheBeginning() async throws {
        let (streamed, reference, root, track, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.perform(.jump, deck: .a, value: Double(track.analysis.frameCount - 256))
        await streamed.flushSourcePreparations()
        try streamed.play(.a)
        _ = streamed.core.renderOffline(frames: 512)
        _ = streamed.snapshotAndMessages()
        let ended = try #require(streamed.core.snapshot())
        #expect(ended.a.phase == .ended)
        let targets = SourceControl.play(.a, ended.a.generation).preparationTargets(
            snapshot: ended, deck: .a, frames: UInt64(track.analysis.frameCount))
        #expect(!targets.isEmpty && targets.allSatisfy { $0.position == 0 && $0.continuingPosition == 0 })
        try streamed.play(.a)
        await streamed.flushSourcePreparations()
        #expect(streamed.core.snapshot()?.a.phase == .playing)
        let audio = streamed.core.renderOffline(frames: 1024)
        #expect(audio.left.contains { abs($0) > 0.00001 })
        #expect(streamed.sourcePreparationFailures == 0 && streamed.rejectedCommandCount == 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }

    @Test(.timeLimit(.minutes(1))) @MainActor func convertedAndLargeHostBuffersMatchTheReferenceWithoutGrowingThePool()
        async throws
    {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let samples = (0..<32768).flatMap { _ in [Float(0.2), Float(-0.1)] }
        let file = root.appendingPathComponent("large-host-buffer.pcm")
        try samples.withUnsafeBytes { try Data($0).write(to: file) }
        let asset = try PCMAsset(streamedFile: file, frames: 32768, sampleRate: 48000)
        let streamed = try SampleTransport()
        let reference = try SampleTransport()
        try streamed.configureMaximumOutputFrames(16384)
        let generation = try streamed.reserveLoad(asset, deck: .a, grid: nil)
        let ticket = try await asset.prepareSource(.init(position: 0), generation: generation)
        try streamed.submitPreparedLoad(generation: generation, preparationTicket: ticket)
        #expect(streamed.processControlsWhileIdle())
        _ = streamed.acknowledgements()
        let original = try reference.load(PCMAsset(interleavedStereo: samples, sampleRate: 48000), deck: .a, grid: nil)
        try streamed.play(deck: .a, generation: generation)
        try reference.play(deck: .a, generation: original)
        var total = 0
        for count in [8917, 16384] {
            let actual = streamed.renderOffline(frames: count)
            let expected = reference.renderOffline(frames: count)
            #expect(actual.left == expected.left && actual.right == expected.right)
            #expect(actual.left.last == 0.1 && actual.right.last == -0.05)
            total += count
            #expect(streamed.snapshot()?.outputFrame == UInt64(total))
            #expect(streamed.snapshot()?.a.sourceFrame == Double(total))
        }
        #expect(streamed.streamingSummary().allocatedPCMBytes == PCMStreamingLimits.assetPCMBytes)
        #expect(!streamed.streamingSummary().continuityFailed)
    }

    @Test(.timeLimit(.minutes(1))) @MainActor func oversizedPerformanceProfileReportsOnceWithoutStartingPreparation()
        async throws
    {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try WorkspaceStore(root: root)
        let file = store.mediaDirectory.appendingPathComponent("capacity.wav")
        let frames: Int64 = 384000 * 8
        let bytes = UInt32(frames * 4)
        var header = Data("RIFF".utf8)
        func word(_ value: UInt16) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { header.append(contentsOf: $0) }
        }
        func long(_ value: UInt32) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { header.append(contentsOf: $0) }
        }
        long(bytes + 36)
        header.append(Data("WAVEfmt ".utf8))
        long(16)
        word(1)
        word(2)
        long(384000)
        long(384000 * 4)
        word(4)
        word(16)
        header.append(Data("data".utf8))
        long(bytes)
        try header.write(to: file)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seek(toOffset: 44)
        let samples = (0..<65536).map { Int16($0.isMultiple(of: 2) ? 6554 : -6554).littleEndian }
        let chunk = samples.withUnsafeBytes { Data($0) }
        for _ in 0..<12 { try handle.write(contentsOf: chunk) }
        try handle.truncate(atOffset: UInt64(bytes) + 44)
        try handle.close()
        let analysis = AudioAnalysis(
            implementation: "capacity-fixture", configurationID: "fixture",
            contentSHA256: try AudioAnalyzer.sha256(url: file), sampleRate: 384000, frameCount: frames, channelCount: 2,
            waveformFramesPerBin: 3840, waveform: [], bpm: 15, beatAnchorFrame: 0, tempoConfidence: 1, key: nil,
            keyConfidence: 0, chroma: [], timbre: [])
        let track = try Track(title: "Capacity fixture", mediaFilename: "capacity.wav", analysis: analysis)
        let playback = try PlaybackController(offline: true, streamingPlayback: true)
        defer {
            playback.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try playback.core.configureMaximumOutputFrames(8917)
        try await playback.load(track: track, store: store, deck: .a)
        try playback.setMasterBPM(120)
        await playback.flushSourcePreparations()
        try playback.play(.a)
        _ = playback.core.renderOffline(frames: 512)
        try playback.perform(.flux, deck: .a, enabled: true)
        _ = playback.snapshotAndMessages()
        let before = try #require(playback.core.snapshot())
        let requests = playback.sourcePreparationRequests
        try playback.perform(.touch, deck: .a, value: before.a.sourceFrame, touchRate: 2)
        let (_, messages) = playback.snapshotAndMessages()
        #expect(messages.compactMap(\.error) == [.playbackCapacity])
        #expect(playback.preparingSourceDecks.isEmpty && playback.sourcePreparationRequests == requests)
        #expect(playback.core.snapshot()?.a.sourceFrame == before.a.sourceFrame)
        #expect(playback.core.snapshot()?.a.performanceRate == 1 && playback.core.snapshot()?.a.touchActive == false)
        let audio = playback.core.renderOffline(frames: 512)
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(playback.core.snapshot()?.a.phase == .playing)
        #expect(try #require(playback.core.snapshot()?.a.sourceFrame) > before.a.sourceFrame)
        #expect(playback.sourcePreparationFailures == 0 && !playback.core.streamingSummary().continuityFailed)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [UInt32(8917), UInt32(16384)]) @MainActor
    func initialKeylockLoadUsesTheKnownHostBufferBound(_ maximum: UInt32) async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(FileManager.default.createFile(atPath: file.path, contents: nil))
        defer { try? FileManager.default.removeItem(at: file) }
        let handle = try FileHandle(forWritingTo: file)
        let frames: UInt64 = 48000 * 90
        try handle.truncate(atOffset: frames * 8)
        try handle.close()
        let asset = try PCMAsset(streamedFile: file, frames: frames, sampleRate: 48000, maximumOutputFrames: maximum)
        let core = try SampleTransport()
        try core.configureMaximumOutputFrames(maximum)
        try core.setMasterBPM(120)
        core.processControlsWhileIdle()
        let generation = try core.reserveLoad(
            asset, deck: .a, grid: BeatGrid(bpm: 15, anchorFrame: 0, sampleRate: 48000), keylock: true)
        let ticket = try await asset.prepareSource(.init(position: 0, speed: 8, keylock: true), generation: generation)
        try core.submitPreparedLoad(generation: generation, preparationTicket: ticket)
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
        #expect(core.snapshot()?.a.phase == .ready && core.snapshot()?.a.generation == generation)
        #expect(!core.streamingSummary().continuityFailed)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [UInt32(8917), UInt32(16384)]) @MainActor
    func resumedLargeBufferPreparesActiveCoverageBeforeRendering(_ maximum: UInt32) async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(FileManager.default.createFile(atPath: file.path, contents: nil))
        defer { try? FileManager.default.removeItem(at: file) }
        let handle = try FileHandle(forWritingTo: file)
        let frames: UInt64 = 48000 * 90
        try handle.truncate(atOffset: frames * 8)
        try handle.close()
        let asset = try PCMAsset(streamedFile: file, frames: frames, sampleRate: 48000)
        let core = try SampleTransport()
        try core.setMasterBPM(120)
        core.processControlsWhileIdle()
        let generation = try core.reserveLoad(
            asset, deck: .a, grid: BeatGrid(bpm: 15, anchorFrame: 0, sampleRate: 48000), sourceFrame: 480000)
        let ticket = try await asset.prepareSource(
            .init(position: 480000, speed: 8, performanceRate: 4), generation: generation)
        try core.submitPreparedLoad(generation: generation, preparationTicket: ticket)
        core.processControlsWhileIdle()
        try core.submit(.performance(.rate, .a, generation, value: 4, end: 0, enabled: true, quantum: 0))
        try core.play(deck: .a, generation: generation)
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
        #expect(core.snapshot()?.a.speed == 8 && core.snapshot()?.a.performanceRate == 4)
        try core.configureMaximumOutputFrames(maximum)
        #expect(try !core.outputSourcesAreReady())
        let before = core.snapshot()
        try await core.prepareActiveSourcesForOutput()
        #expect(try core.outputSourcesAreReady())
        #expect(core.snapshot() == before)
        _ = core.renderOffline(frames: Int(maximum))
        #expect(!core.streamingSummary().continuityFailed)
        #expect(core.snapshot()?.a.sourceFrame == 480000 + Double(maximum) * 32)
        #expect(core.streamingSummary().allocatedPCMBytes == PCMStreamingLimits.assetPCMBytes)
    }

    @Test(.timeLimit(.minutes(1))) @MainActor func resumedSharedAssetPreparesBothDecksAsOneCoverageRequest()
        async throws
    {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(FileManager.default.createFile(atPath: file.path, contents: nil))
        defer { try? FileManager.default.removeItem(at: file) }
        let handle = try FileHandle(forWritingTo: file)
        let frames: UInt64 = 48000 * 90
        try handle.truncate(atOffset: frames * 8)
        try handle.close()
        let asset = try PCMAsset(streamedFile: file, frames: frames, sampleRate: 48000)
        let core = try SampleTransport()
        for (deck, position) in [(DeckID.a, 480000.0), (DeckID.b, 2400000.0)] {
            let generation = try core.reserveLoad(asset, deck: deck, grid: nil, sourceFrame: position, synced: false)
            let ticket = try await asset.prepareSources([.init(position: position)], generation: generation) {
                #expect(core.processControlsWhileIdle())
            }
            try core.submitPreparedLoad(generation: generation, preparationTicket: ticket)
            core.processControlsWhileIdle()
            _ = core.acknowledgements()
            try core.play(deck: deck, generation: generation)
            core.processControlsWhileIdle()
        }
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
        try core.configureMaximumOutputFrames(16384)
        let before = try #require(core.snapshot())
        try await core.prepareActiveSourcesForOutput()
        #expect(core.snapshot() == before)
        _ = core.renderOffline(frames: 16384)
        #expect(core.snapshot()?.a.sourceFrame == before.a.sourceFrame + 16384)
        #expect(core.snapshot()?.b.sourceFrame == before.b.sourceFrame + 16384)
        #expect(!core.streamingSummary().continuityFailed)
        #expect(core.streamingSummary().allocatedPCMBytes == PCMStreamingLimits.assetPCMBytes)
    }

    @Test(.timeLimit(.minutes(1))) @MainActor func resumedActiveDeckWaitsForAdoptionWhenASharedDeckIsInactive()
        async throws
    {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(FileManager.default.createFile(atPath: file.path, contents: nil))
        defer { try? FileManager.default.removeItem(at: file) }
        let handle = try FileHandle(forWritingTo: file)
        let frames: UInt64 = 48000 * 90
        try handle.truncate(atOffset: frames * 8)
        try handle.close()
        let asset = try PCMAsset(streamedFile: file, frames: frames, sampleRate: 48000)
        let core = try SampleTransport()
        try core.setMasterBPM(120)
        core.processControlsWhileIdle()
        for (deck, position) in [(DeckID.a, 480000.0), (DeckID.b, 2400000.0)] {
            let generation = try core.reserveLoad(
                asset, deck: deck, grid: BeatGrid(bpm: 15, anchorFrame: 0, sampleRate: 48000), sourceFrame: position)
            let ticket = try await asset.prepareSources(
                [.init(position: position, speed: 8, performanceRate: 4)], generation: generation
            ) { #expect(core.processControlsWhileIdle()) }
            try core.submitPreparedLoad(generation: generation, preparationTicket: ticket)
            core.processControlsWhileIdle()
            try core.submit(.performance(.rate, deck, generation, value: 4, end: 0, enabled: true, quantum: 0))
            if deck == .a { try core.play(deck: deck, generation: generation) }
            core.processControlsWhileIdle()
            #expect(core.acknowledgements().allSatisfy { $0.error == nil })
        }
        try core.configureMaximumOutputFrames(16384)
        #expect(try !core.outputSourcesAreReady())
        let before = try #require(core.snapshot())
        #expect(before.a.phase == .playing && before.b.phase == .ready)
        try await core.prepareActiveSourcesForOutput()
        #expect(try core.outputSourcesAreReady())
        #expect(core.snapshot() == before)
        _ = core.renderOffline(frames: 16384)
        #expect(core.snapshot()?.a.sourceFrame == before.a.sourceFrame + 16384 * 32)
        #expect(core.snapshot()?.b.sourceFrame == before.b.sourceFrame && core.snapshot()?.b.phase == .ready)
        #expect(!core.streamingSummary().continuityFailed)
        #expect(core.streamingSummary().allocatedPCMBytes == PCMStreamingLimits.assetPCMBytes)
    }

    @Test(.timeLimit(.minutes(1))) @MainActor func fourHourSparsePCMCacheUsesOneFixedPool() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("four-hour.pcm")
        #expect(FileManager.default.createFile(atPath: file.path, contents: nil))
        let handle = try FileHandle(forWritingTo: file)
        let frames: UInt64 = 4 * 60 * 60 * 48000
        try handle.truncate(atOffset: frames * 8)
        try handle.seek(toOffset: 0)
        let samples = [Float](repeating: 0.2, count: 8192 * 2)
        try samples.withUnsafeBytes { try handle.write(contentsOf: Data($0)) }
        try handle.close()
        #expect(frames * 8 > 4 * 1024 * 1024 * 1024)
        let asset = try PCMAsset(streamedFile: file, frames: frames, sampleRate: 48000)
        let core = try SampleTransport()
        let generation = try core.reserveLoad(asset, deck: .a, grid: nil)
        let ticket = try await asset.prepareSource(.init(position: 0), generation: generation)
        try core.submitPreparedLoad(generation: generation, preparationTicket: ticket)
        #expect(core.processControlsWhileIdle())
        _ = core.acknowledgements()
        try core.play(deck: .a, generation: generation)
        let output = core.renderOffline(frames: 512)
        #expect(output.left.first == 0)
        #expect(output.left.allSatisfy { $0.isFinite && $0 >= 0 })
        #expect(output.left.dropFirst(96).allSatisfy { $0 > 0.001 })
        let summary = core.streamingSummary()
        #expect(summary.activeAssets == 1)
        #expect(summary.allocatedPCMBytes == PCMStreamingLimits.assetPCMBytes)
        #expect(summary.bytesRead < 16 * 1024 * 1024)
        #expect(!summary.continuityFailed)
    }
    @Test(.timeLimit(.minutes(1))) @MainActor func streamedSyncRestorationMatchesResidentSamplesAndKeepsTheClock()
        async throws
    {
        let (streamed, reference, root, _, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        try streamed.play(.a)
        try reference.play(.a)
        let initialStream = streamed.core.renderOffline(frames: 512)
        let initialReference = reference.core.renderOffline(frames: 512)
        #expect(initialStream.left == initialReference.left && initialStream.right == initialReference.right)
        #expect(streamed.core.snapshot()?.outputFrame == reference.core.snapshot()?.outputFrame)
        let running = try #require(streamed.core.snapshot())
        let grid = try #require(running.a.grid)
        let aligned = try #require(
            grid.nearestPhaseAlignedFrame(to: 3 * 44100, masterBeat: running.masterBeat, within: 0..<705600))
        for controller in [streamed, reference] {
            try controller.perform(.jump, deck: .a, value: aligned + grid.framesPerBeat * 0.25)
            await controller.flushSourcePreparations()
            _ = controller.snapshotAndMessages()
        }
        let before = try #require(streamed.core.snapshot())
        #expect(before.syncNeedsAlignment(.a))
        let targets = SourceControl.restoreSync(.a, before.a.generation).preparationTargets(
            snapshot: before, deck: .a, frames: 705600)
        #expect(targets.first?.position == aligned)
        for controller in [streamed, reference] {
            try controller.restoreSync(deck: .a)
            await controller.flushSourcePreparations()
            _ = controller.snapshotAndMessages()
        }
        let restored = try #require(streamed.core.snapshot())
        #expect(restored.outputFrame == reference.core.snapshot()?.outputFrame)
        #expect(restored.a.sourceFrame == reference.core.snapshot()?.a.sourceFrame)
        #expect(restored.a.synced && !restored.syncNeedsAlignment(.a))
        #expect(abs(restored.a.sourceFrame - aligned) < 0.000001)
        #expect(restored.outputFrame == before.outputFrame && restored.masterBeat == before.masterBeat)
        var hadSignal = false
        for _ in 0..<16 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            #expect(actual.left == expected.left && actual.right == expected.right)
            hadSignal =
                hadSignal || actual.left.contains { abs($0) > 0.0001 } || actual.right.contains { abs($0) > 0.0001 }
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(hadSignal)
        #expect(streamed.sourcePreparationFailures == 0 && streamed.rejectedCommandCount == 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }

}

extension StreamedPlaybackIntegrationTests {
    @Test(.timeLimit(.minutes(1))) @MainActor func adaptiveStreamedSyncRestorationWarmsEveryTempoSegment() async throws
    {
        let (streamed, reference, root, track, _) = try await fixture()
        defer {
            streamed.stopAudio()
            reference.stopAudio()
            try? FileManager.default.removeItem(at: root)
        }
        let rate = track.analysis.sampleRate
        let map = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: 4 * rate), .init(beat: 12, frame: 12 * rate)],
            sampleRate: rate)
        for controller in [streamed, reference] {
            try await controller.updateAdaptiveMap(map, deck: .a)
            let generation = try #require(controller.generations[.a])
            try controller.core.setSync(false, deck: .a, generation: generation)
            controller.core.processControlsWhileIdle()
            try controller.play(.a)
            _ = controller.core.renderOffline(frames: 512)
            try controller.restoreSync(deck: .a)
            await controller.flushSourcePreparations()
            #expect(controller.sourcePreparationFailures == 0)
            #expect(controller.core.snapshot()?.a.synced == true)
        }
        for _ in 0..<32 {
            let actual = streamed.core.renderOffline(frames: 512)
            let expected = reference.core.renderOffline(frames: 512)
            #expect(actual.left == expected.left)
            #expect(actual.right == expected.right)
        }
        #expect(streamed.rejectedCommandCount == 0)
        #expect(!streamed.core.streamingSummary().continuityFailed)
    }
}
