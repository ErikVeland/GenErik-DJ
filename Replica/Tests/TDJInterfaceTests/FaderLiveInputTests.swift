import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@Test @MainActor func faderLiveInputReadsOnlyWhenCapturingATemporaryBaseline() {
    let session = FaderGestureSession()
    var reads = 0
    let fader = TouchFader(
        value: 1, range: 0...2, reset: 1, axis: .vertical,
        readValue: {
            reads += 1
            return 1
        }
    ) { _ in }
    let first = SurfacePoint(id: 1, x: 0.5, y: 0.28)
    let second = SurfacePoint(id: 2, x: 0.5, y: 0.72)
    fader.handleTouch(.init(phase: .cancelled, points: [], ending: []), length: 100, using: session)
    fader.handleTouch(.init(phase: .began, points: [first], ending: []), length: 100, using: session)
    fader.handleTouch(.init(phase: .moved, points: [first], ending: []), length: 100, using: session)
    #expect(reads == 0)
    fader.handleTouch(.init(phase: .began, points: [first, second], ending: []), length: 100, using: session)
    #expect(reads == 1)
    fader.handleTouch(.init(phase: .moved, points: [first, second], ending: []), length: 100, using: session)
    fader.handleTouch(.init(phase: .cancelled, points: [], ending: []), length: 100, using: session)
    #expect(reads == 1)
}

@MainActor private func liveFaderModel(withTracks: Bool = false) throws -> (ReplicaModel, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    if withTracks {
        let store = try WorkspaceStore(root: root)
        var library = LibrarySnapshot()
        for sample in UInt8(1)...2 {
            let file = store.mediaDirectory.appendingPathComponent("fader-\(sample).wav")
            var data = Data()
            func text(_ value: String) { data.append(contentsOf: value.utf8) }
            func word(_ value: UInt16) {
                var v = value.littleEndian
                withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            }
            func long(_ value: UInt32) {
                var v = value.littleEndian
                withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            }
            text("RIFF")
            long(36 + 192000)
            text("WAVEfmt ")
            long(16)
            word(1)
            word(2)
            long(48000)
            long(192000)
            word(4)
            word(16)
            text("data")
            long(192000)
            data.append(Data(repeating: sample, count: 192000))
            try data.write(to: file)
            let analysis = AudioAnalysis(
                implementation: "Synthetic fader fixture", configurationID: "fader-fixture",
                contentSHA256: try AudioAnalyzer.sha256(url: file), sampleRate: 48000, frameCount: 48000,
                channelCount: 2, waveformFramesPerBin: 512,
                waveform: (0..<94).map { _ in WaveformBin(minimum: 0, maximum: 0, rms: 0) }, bpm: 120,
                beatAnchorFrame: 0, tempoConfidence: 0, key: nil, keyConfidence: 0, chroma: [], timbre: [])
            library.tracks.append(
                try Track(title: "Fader \(sample)", mediaFilename: file.lastPathComponent, analysis: analysis))
        }
        _ = try store.save(library)
    }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.pauseVisualUpdates()
    return (model, root)
}

@Test(arguments: ["release", "cancel", "all-release"], [MixerParameter.low, .mid, .high, .volume]) @MainActor
func faderLiveInputRestoresPrimaryTargetBeforeDisplayRefresh(_ ending: String, _ parameter: MixerParameter) async throws
{
    let (model, root) = try liveFaderModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = FaderGestureSession()
    let upper = parameter == .volume ? 1.0 : 2.0
    func nativeValue(_ state: DeckMixerSnapshot) -> Double {
        switch parameter {
        case .low: state.low
        case .mid: state.mid
        case .high: state.high
        default: state.volume
        }
    }
    let fader = TouchFader(
        value: 1, range: 0...upper, reset: parameter == .volume ? nil : 1, axis: .vertical,
        readValue: { model.mixerFaderValue(parameter, deck: .a) ?? 1 }
    ) { model.setMixer(parameter, value: $0, deck: .a) }
    let first = SurfacePoint(id: 1, x: 0.5, y: 0.28)
    let second = SurfacePoint(id: 2, x: 0.5, y: 0.72)
    fader.handleTouch(.init(phase: .began, points: [first], ending: []), length: 100, using: session)
    #expect(abs(nativeValue(try #require(model.playback.core.snapshot()).a.mixer) - upper * 0.75) < 0.000001)
    fader.handleTouch(.init(phase: .began, points: [first, second], ending: []), length: 100, using: session)
    #expect(abs(nativeValue(try #require(model.playback.core.snapshot()).a.mixer) - upper * 0.25) < 0.000001)
    fader.handleTouch(
        .init(
            phase: ending == "cancel" ? .cancelled : .ended, points: [first, second],
            ending: ending == "all-release" ? [1, 2] : [2]), length: 100, using: session)
    let state = try #require(model.playback.core.snapshot())
    #expect(abs(nativeValue(state.a.mixer) - upper * 0.75) < 0.000001)
    #expect(nativeValue(state.b.mixer) == 1)
    await model.finishForShutdown()
}

@Test @MainActor func faderLiveInputIncludesDecodedZ1ChangesBeforeSecondContact() async throws {
    let (model, root) = try liveFaderModel()
    defer { try? FileManager.default.removeItem(at: root) }
    func report(_ mid: UInt16) throws -> Z1InputReport {
        var bytes = [UInt8](repeating: 0, count: 30)
        bytes[0] = 1
        for offset in stride(from: 1, to: 29, by: 2) {
            bytes[offset] = 0xff
            bytes[offset + 1] = 7
        }
        bytes[5] = UInt8(mid & 255)
        bytes[6] = UInt8(mid >> 8)
        return try Z1InputReport(bytes: bytes)
    }
    model.receiveZ1(try report(2047))
    let other = try #require(model.playback.core.snapshot()).b.mixer.mid
    let session = FaderGestureSession()
    let fader = TouchFader(
        value: 1, range: 0...2, reset: 1, axis: .vertical, readValue: { model.mixerFaderValue(.mid, deck: .a) ?? 1 }
    ) { model.setMixer(.mid, value: $0, deck: .a) }
    let first = SurfacePoint(id: 1, x: 0.5, y: 0.28)
    let second = SurfacePoint(id: 2, x: 0.5, y: 0.72)
    fader.handleTouch(.init(phase: .began, points: [first], ending: []), length: 100, using: session)
    model.receiveZ1(try report(3583))
    fader.handleTouch(.init(phase: .began, points: [first, second], ending: []), length: 100, using: session)
    fader.handleTouch(.init(phase: .ended, points: [first, second], ending: [2]), length: 100, using: session)
    let state = try #require(model.playback.core.snapshot())
    #expect(abs(state.a.mixer.mid - 2 * Double(3583) / 4095) < 0.000001)
    #expect(state.b.mixer.mid == other)
    await model.finishForShutdown()
}

@Test @MainActor func faderLiveInputFollowsMixerLifetimeAcrossLoadsAndExplicitReset() async throws {
    let (model, root) = try liveFaderModel(withTracks: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let firstTrack = try #require(model.library.tracks.first)
    let secondTrack = try #require(model.library.tracks.last)
    try #require(firstTrack.id != secondTrack.id)
    model.setMixer(.low, value: 1.5, deck: .a)
    model.setMixer(.low, value: 0.75, deck: .b)
    for (deck, track) in [(DeckID.a, firstTrack), (DeckID.b, secondTrack), (DeckID.a, secondTrack)] {
        model.load(trackID: track.id, deck: deck)
        await model.playbackLoads?.value
        #expect(model.loaded[deck] == track.id)
        let state = try #require(model.playback.core.snapshot())
        #expect(state.a.mixer.low == 1.5 && state.b.mixer.low == 0.75)
        #expect(model.mixerFaderValue(.low, deck: .a) == 1.5)
        #expect(model.mixerFaderValue(.low, deck: .b) == 0.75)
    }
    let session = FaderGestureSession()
    let fader = TouchFader(
        value: 1.5, range: 0...2, reset: 1, axis: .vertical, readValue: { model.mixerFaderValue(.low, deck: .a) ?? 1.5 }
    ) { model.setMixer(.low, value: $0, deck: .a) }
    let first = SurfacePoint(id: 1, x: 0.5, y: 0.28)
    let second = SurfacePoint(id: 2, x: 0.5, y: 0.72)
    fader.handleTouch(.init(phase: .began, points: [first], ending: []), length: 100, using: session)
    model.resetEQ(deck: .a)
    fader.handleTouch(.init(phase: .began, points: [first, second], ending: []), length: 100, using: session)
    fader.handleTouch(.init(phase: .ended, points: [first, second], ending: [2]), length: 100, using: session)
    model.stopAudio()
    let state = try #require(model.playback.core.snapshot())
    #expect(state.a.mixer.low == 1 && state.b.mixer.low == 0.75)
    #expect(model.mixerFaderValue(.low, deck: .a) == 1)
    await model.finishForShutdown()
}

@Test @MainActor func faderLiveInputCanPrecedeTheNativeSnapshotWithoutRendering() throws {
    let controller = try PlaybackController(offline: true)
    let input = MixerFaderInputValues()
    try controller.core.setMixer(.low, value: 1.5, deck: .a)
    input.accept(.low, value: 1.5, deck: .a)
    #expect(try #require(controller.core.snapshot()).a.mixer.low == 1)
    #expect(input.value(.low, deck: .a) == 1.5)
    controller.core.processControlsWhileIdle()
    #expect(try #require(controller.core.snapshot()).a.mixer.low == 1.5)
}

@Test @MainActor func faderLiveInputDoesNotChangeTheOtherPlayingDeckAudio() async throws {
    let (model, root) = try liveFaderModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let reference = try SampleTransport()
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.2, count: 32768), sampleRate: 48000)
    for core in [model.playback.core, reference] {
        let generation = try core.load(asset, deck: .b, grid: nil, synced: false)
        core.processControlsWhileIdle()
        try core.play(deck: .b, generation: generation)
        try core.setMixer(.crossfader, value: 1)
        core.processControlsWhileIdle()
        _ = core.renderOffline(frames: 512)
    }
    let session = FaderGestureSession()
    let fader = TouchFader(
        value: 1, range: 0...2, reset: 1, axis: .vertical, readValue: { model.mixerFaderValue(.low, deck: .a) ?? 1 }
    ) { model.setMixer(.low, value: $0, deck: .a) }
    let first = SurfacePoint(id: 1, x: 0.5, y: 0.28)
    let second = SurfacePoint(id: 2, x: 0.5, y: 0.72)
    for _ in 0..<32 {
        for event in [
            SurfaceEvent(phase: .began, points: [first], ending: []),
            .init(phase: .began, points: [first, second], ending: []),
            .init(phase: .ended, points: [first, second], ending: [2]),
            .init(phase: .ended, points: [first], ending: [1]),
        ] {
            fader.handleTouch(event, length: 100, using: session)
            let actual = model.playback.core.renderOffline(frames: 64)
            let expected = reference.renderOffline(frames: 64)
            #expect(actual.left == expected.left && actual.right == expected.right)
            #expect(actual.left.contains { $0 != 0 })
            #expect(try #require(model.playback.core.snapshot()).b.phase == .playing)
        }
    }
    await model.finishForShutdown()
}

@Test @MainActor func faderLiveInputIncludesHardwareChangesBetweenContacts() async throws {
    let (model, root) = try liveFaderModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = FaderGestureSession()
    let fader = TouchFader(
        value: 1, range: 0...2, reset: 1, axis: .vertical, readValue: { model.mixerFaderValue(.mid, deck: .a) ?? 1 }
    ) { model.setMixer(.mid, value: $0, deck: .a) }
    let first = SurfacePoint(id: 1, x: 0.5, y: 0.28)
    let second = SurfacePoint(id: 2, x: 0.5, y: 0.72)
    fader.handleTouch(.init(phase: .began, points: [first], ending: []), length: 100, using: session)
    model.setMixer(.mid, value: 1.75, deck: .a)
    model.setMixer(.mid, value: 0.75, deck: .b)
    fader.handleTouch(.init(phase: .began, points: [first, second], ending: []), length: 100, using: session)
    fader.handleTouch(.init(phase: .ended, points: [first, second], ending: [2]), length: 100, using: session)
    let state = try #require(model.playback.core.snapshot())
    #expect(state.a.mixer.mid == 1.75)
    #expect(state.b.mixer.mid == 0.75)
    await model.finishForShutdown()
}

@Test @MainActor func faderLiveInputIgnoresRefusedCommands() async throws {
    let (model, root) = try liveFaderModel()
    defer { try? FileManager.default.removeItem(at: root) }
    model.setMixer(.high, value: 1.5, deck: .a)
    var queueWasFull = false
    for _ in 0..<16384 {
        do { try model.playback.core.setMixer(.master, value: 0.5) } catch TransportError.queueFull {
            queueWasFull = true
            break
        }
    }
    try #require(queueWasFull)
    #expect(!model.submitMixer(.high, value: 0.25, deck: .a))
    #expect(model.mixerFaderValue(.high, deck: .a) == 1.5)
    model.playback.core.processControlsWhileIdle()
    let session = FaderGestureSession()
    let fader = TouchFader(
        value: 1, range: 0...2, reset: 1, axis: .vertical, readValue: { model.mixerFaderValue(.high, deck: .a) ?? 1 }
    ) { model.setMixer(.high, value: $0, deck: .a) }
    fader.handleTouch(
        .init(phase: .began, points: [.init(id: 1, x: 0.5, y: 0.28), .init(id: 2, x: 0.5, y: 0.72)], ending: []),
        length: 100, using: session)
    fader.handleTouch(.init(phase: .cancelled, points: [], ending: []), length: 100, using: session)
    #expect(try #require(model.playback.core.snapshot()).a.mixer.high == 1.5)
    await model.finishForShutdown()
}

@Test @MainActor func faderLiveInputKeepsAcceptedTargetsWhenDisplayIsOlder() async throws {
    let (model, root) = try liveFaderModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let previous = try #require(model.playback.core.snapshot())
    model.setMixer(.volume, value: 0.75, deck: .b)
    model.controlDisplay.update(previous)
    #expect(model.controlDisplay[.b].mixer.volume == 1)
    #expect(model.mixerFaderValue(.volume, deck: .b) == 0.75)
    #expect(model.mixerFaderValue(.volume, deck: .a) == 1)
    #expect(model.mixerFaderValue(.master, deck: .a) == nil)
    await model.finishForShutdown()
}

@Test @MainActor func faderLiveInputUsesExistingMixerBeforeFirstModelCommand() async throws {
    let (model, root) = try liveFaderModel()
    defer { try? FileManager.default.removeItem(at: root) }
    try model.playback.core.setMixer(.low, value: 1.25, deck: .b)
    model.playback.core.processControlsWhileIdle()
    model.refreshPlayback()
    #expect(model.mixerFaderValue(.low, deck: .b) == 1.25)
    #expect(model.mixerFaderValue(.low, deck: .a) == 1)
    await model.finishForShutdown()
}
