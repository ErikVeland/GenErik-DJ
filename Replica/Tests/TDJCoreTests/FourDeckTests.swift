import CTDJTransport
import Testing

@testable import TDJCore

@Test func fourDeckTransportMixesAndStopsFourIndependentSources() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    for (i, deck) in [DeckID.a, .b, .c, .d].enumerated() {
        let sample = Float(i + 1) / 20
        let asset = try PCMAsset(interleavedStereo: .init(repeating: sample, count: 64000), sampleRate: 8000)
        let generation = try core.load(asset, deck: deck, grid: grid, synced: false)
        try core.setMixer(.volume, value: 1, deck: deck)
        try core.play(deck: deck, generation: generation)
    }
    core.recording.start()
    let mix = core.renderBusesOffline(frames: 1024)
    #expect(abs((mix.left.last ?? 0) - 0.5) < 0.001)
    let snapshot = try #require(core.snapshot())
    #expect(Set(DeckID.allCases.map { snapshot[$0].generation }).count == 4)
    core.recording.stop()
    let ring = core.recording.nativeAudioRenderPointer
    #expect(tdj_recording_track_count(ring) == 4)
    for i in UInt32(0)..<4 {
        var event = tdj_recorded_track()
        #expect(tdj_recording_track(ring, i, &event))
        #expect(event.deck == i)
        #expect(event.generation == snapshot[DeckID.allCases[Int(i)]].generation)
    }
    try core.play(deck: .c, generation: snapshot[.c].generation)
    let continuing = core.renderBusesOffline(frames: 1024)
    #expect(abs((continuing.left.last ?? 0) - 0.35) < 0.001)
    #expect(core.snapshot()?[.c].phase == .paused)
    #expect(core.snapshot()?[.d].phase == .playing)
}

@Test func fourDeckSyncUsesAnOuterDeckAsTheMasterClockReference() throws {
    let core = try SampleTransport(sampleRate: 8000, outputGain: 1)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 200_000), sampleRate: 8000)
    let reference = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let follower = try BeatGrid(bpm: 100, anchorFrame: 0, sampleRate: 8000)
    let c = try core.load(asset, deck: .c, grid: reference)
    try core.play(deck: .c, generation: c)
    _ = core.renderBusesOffline(frames: 2000)
    for deck in [DeckID.a, .b, .d] {
        let generation = try core.load(asset, deck: deck, grid: follower)
        try core.play(deck: deck, generation: generation)
    }
    _ = core.renderBusesOffline(frames: 512)
    let queued = try #require(core.snapshot())
    #expect(queued[.c].phase == .playing)
    #expect([DeckID.a, .b, .d].allSatisfy { queued[$0].targetBeat == 4 })
    for _ in 0..<30 { _ = core.renderBusesOffline(frames: 512) }
    let aligned = try #require(core.snapshot())
    for deck in DeckID.allCases {
        #expect(aligned[deck].phase == .playing)
        #expect(abs(aligned.syncPhaseError(deck) ?? 1) < 0.0001)
    }
    try core.stopAll()
    core.processControlsWhileIdle()
    let stopped = try #require(core.snapshot())
    #expect(!stopped.anyDeckActive)
    #expect(DeckID.allCases.allSatisfy { stopped[$0].synced })
}

@Test func outerDeckPoolsLeaveRoomForAStoppedDeckReplacement() throws {
    var assets: [OpaquePointer] = []
    let engine = try #require(tdj_engine_create(48000, 1))
    defer {
        tdj_engine_destroy(engine)
        for asset in assets { tdj_asset_destroy(asset) }
    }
    try #require(tdj_engine_prepare_extra_decks(engine))
    try #require(tdj_engine_configure_maximum_output_frames(engine, 512) == TDJ_OK)
    for compact in [false, false, true, true, false] {
        var config = tdj_stream_config(
            output_rate: 48000, forward_seconds: 2, backward_seconds: 1, max_output_frames: 512,
            reserved: compact ? TDJ_STREAM_COMPACT_POOL : 0)
        var error: Int32 = 0
        let asset = try #require(
            tdj_asset_open_decoder(
                48000 * 4, 48000, &config,
                { _, _, frames, stereo in
                    guard let stereo else { return TDJ_STREAM_INVALID.rawValue }
                    for i in 0..<(Int(frames) * 2) { stereo[i] = 0.1 }
                    return TDJ_STREAM_READY.rawValue
                }, { _ in }, nil, &error))
        assets.append(asset)
        var telemetry = tdj_stream_telemetry()
        tdj_asset_stream_telemetry(asset, &telemetry)
        #expect(telemetry.resident_pcm_bytes == (compact ? 16 : 32) * 1024 * 1024)
    }

    func render() throws -> Float {
        var left = [Float](repeating: 0, count: 512)
        var right = left
        try #require(tdj_render(engine, 512, &left, &right))
        var message = tdj_message()
        while tdj_read_message(engine, &message) {
            #expect(message.status == TDJ_OK || message.status == TDJ_RETIRED)
        }
        return left.last ?? 0
    }
    func submit(_ kind: Int32, _ deck: Int32, _ generation: UInt64) throws {
        var command = tdj_command()
        command.kind = kind
        command.deck = deck
        command.generation = generation
        if kind == TDJ_MIXER {
            command.flag = TDJ_MIX_VOLUME
            command.value = 1
        }
        try #require(tdj_submit(engine, command))
    }
    func load(_ asset: OpaquePointer, _ deck: Int32, _ generation: UInt64) throws {
        var target = tdj_stream_target()
        target.source_speed = 1
        target.performance_rate = 1
        var request = tdj_stream_request()
        try #require(tdj_asset_plan_target(asset, &target, 1, generation, &request) == TDJ_STREAM_READY.rawValue)
        let ticket = tdj_asset_request_prepare(asset, &request)
        try #require(ticket != 0)
        defer { tdj_asset_release_preparation(asset, ticket) }
        try #require(tdj_asset_service(asset, 32) == TDJ_STREAM_READY.rawValue)
        var command = tdj_command()
        command.kind = TDJ_LOAD
        command.deck = deck
        command.asset = asset
        command.generation = generation
        command.preparation_ticket = ticket
        try #require(tdj_submit(engine, command))
        _ = try render()
    }
    for i in 0..<4 {
        try load(assets[i], Int32(i), UInt64(i + 1))
        try submit(TDJ_MIXER, Int32(i), UInt64(i + 1))
        try submit(TDJ_PLAY, Int32(i), UInt64(i + 1))
    }
    #expect(abs(try render() - 0.4) < 0.001)
    try submit(TDJ_PLAY, 0, 1)
    #expect(abs(try render() - 0.3) < 0.001)
    try load(assets[4], 0, 5)
    try submit(TDJ_PLAY, 0, 5)
    #expect(abs(try render() - 0.4) < 0.001)
    var snapshot = tdj_snapshot()
    try #require(tdj_read_snapshot(engine, &snapshot))
    #expect(snapshot.a.generation == 5 && snapshot.c.generation == 3 && snapshot.d.generation == 4)
}
