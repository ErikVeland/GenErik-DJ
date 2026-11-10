import CTDJTransport
import Foundation
import Testing

@Test(arguments: [false, true], [Int32(0), Int32(3)])
func sourceStarvationRefillsWithoutStoppingEitherDeck(synced: Bool, sourceDeck: Int32) throws {
    let engine = try #require(tdj_engine_create(48000, 1))
    if sourceDeck == 3 { try #require(tdj_engine_prepare_extra_decks(engine)) }
    let resident = try #require((0..<(48000 * 20 * 2)).map { $0.isMultiple(of: 2) ? Float(0.25) : 0 }
        .withUnsafeBufferPointer { tdj_asset_create($0.baseAddress, 48000 * 20, 48000) })
    var config = tdj_stream_config(output_rate: 48000, forward_seconds: 2, backward_seconds: 1,
                                   max_output_frames: 512, reserved: sourceDeck == 3 ? TDJ_STREAM_COMPACT_POOL : 0)
    var error: Int32 = 0
    let stream = try #require(tdj_asset_open_decoder(48000 * 4, 48000, &config, { _, _, frames, stereo in
        guard let stereo else { return TDJ_STREAM_INVALID.rawValue }
        for frame in 0..<Int(frames) {
            stereo[frame * 2] = 0
            stereo[frame * 2 + 1] = 0.4
        }
        return TDJ_STREAM_READY.rawValue
    }, { _ in }, nil, &error))
    defer {
        tdj_engine_destroy(engine)
        tdj_asset_destroy(stream)
        tdj_asset_destroy(resident)
    }

    func render() -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: 512)
        var right = left
        #expect(tdj_render(engine, 512, &left, &right))
        var message = tdj_message()
        while tdj_read_message(engine, &message) { #expect(message.status == TDJ_OK) }
        return (left, right)
    }
    func snapshot() throws -> tdj_snapshot {
        var state = tdj_snapshot()
        try #require(tdj_read_snapshot(engine, &state))
        return state
    }
    func missing() -> UInt64 {
        var telemetry = tdj_stream_telemetry()
        tdj_asset_stream_telemetry(stream, &telemetry)
        return telemetry.missing_output_frames
    }
    func send(_ kind: Int32, deck: Int32, flag: Int32 = 0, asset: OpaquePointer? = nil,
              bpm: Double = 0, ticket: UInt64 = 0) {
        var command = tdj_command()
        command.kind = kind
        command.deck = deck
        command.flag = flag
        command.id = UInt64(kind * 2 + deck)
        command.generation = UInt64(deck + 1)
        command.asset = asset
        command.value2 = bpm
        command.preparation_ticket = ticket
        #expect(tdj_submit(engine, command))
    }

    send(TDJ_LOAD, deck: 1, flag: 1, asset: resident, bpm: 120)
    send(TDJ_PLAY, deck: 1)
    _ = render()
    var target = tdj_stream_target(position: 0, source_speed: synced ? 1.2 : 1, performance_rate: 1,
                                  loop_start: 0, loop_end: 0, continuing_position: 0, keylock: 1,
                                  reserve_continuing: 0)
    var request = tdj_stream_request()
    try #require(tdj_asset_plan_target(stream, &target, 1, UInt64(sourceDeck + 1), &request) == TDJ_STREAM_READY.rawValue)
    let ticket = tdj_asset_request_prepare(stream, &request)
    try #require(ticket != 0)
    try #require(tdj_asset_service(stream, 32) == TDJ_STREAM_READY.rawValue)
    send(TDJ_LOAD, deck: sourceDeck, flag: synced ? 9 : 8, asset: stream, bpm: 100, ticket: ticket)
    var fader = tdj_command()
    fader.kind = TDJ_MIXER
    fader.deck = sourceDeck
    fader.flag = TDJ_MIX_VOLUME
    fader.value = 1
    try #require(tdj_submit(engine, fader))
    send(TDJ_PLAY, deck: sourceDeck)
    _ = render()
    tdj_asset_release_preparation(stream, ticket)

    // Withhold read-ahead until the stream empties. The resident deck provides the reference clock.
    for _ in 0..<600 {
        _ = render()
        if missing() > 0 { break }
    }
    try #require(missing() > 0)
    let held = try snapshot()
    for _ in 0..<480 {
        let output = render()
        #expect(output.left.allSatisfy { $0 > 0.15 })
    }
    let waiting = try snapshot()
    #expect((sourceDeck == 0 ? waiting.a : waiting.d).state == TDJ_PLAYING)
    #expect((sourceDeck == 0 ? waiting.a : waiting.d).source_frame == (sourceDeck == 0 ? held.a : held.d).source_frame)
    #expect((sourceDeck == 0 ? waiting.a : waiting.d).synced == (synced ? 1 : 0))
    #expect(waiting.b.source_frame - held.b.source_frame == 480 * 512)
    #expect(waiting.master_beat > held.master_beat + 10)

    var recovered = false
    for _ in 0..<100 {
        #expect(tdj_asset_service(stream, 2) >= 0)
        let output = render()
        #expect(output.left.allSatisfy { $0 > 0.15 })
        if output.right.suffix(64).allSatisfy({ $0 > 0.15 }) {
            recovered = true
            break
        }
    }
    #expect(recovered)
    let after = try snapshot()
    #expect((sourceDeck == 0 ? after.a : after.d).state == TDJ_PLAYING)
    #expect((sourceDeck == 0 ? after.a : after.d).synced == (synced ? 1 : 0))
    #expect((sourceDeck == 0 ? after.a : after.d).last_start_frame == (sourceDeck == 0 ? held.a : held.d).last_start_frame)
    if synced {
        let phase = (sourceDeck == 0 ? after.a : after.d).source_frame / 28800 - after.master_beat
        #expect(abs(phase - phase.rounded()) < 0.0001)
    }
    let missesAtRecovery = missing()
    for _ in 0..<16 {
        #expect(tdj_asset_service(stream, 16) >= 0)
        _ = render()
    }
    #expect(missing() == missesAtRecovery)
}
