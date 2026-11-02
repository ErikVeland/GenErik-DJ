import Testing
@testable import TDJCore

@Test func cancelledLoadReservationCannotReachTheDeck() throws {
    let core = try SampleTransport()
    weak var released: PCMAsset?
    let cancelled: UInt64
    do {
        let asset = try PCMAsset(interleavedStereo: [0.1, 0.2, 0.3, 0.4], sampleRate: 48000)
        released = asset
        cancelled = try core.reserveLoad(asset, deck: .a, grid: nil)
        core.cancelReservedLoad(generation: cancelled)
    }
    #expect(released == nil)
    #expect(throws: TransportError.stale) { try core.submitPreparedLoad(generation: cancelled) }
    #expect(core.processControlsWhileIdle())
    #expect(core.snapshot()?.a.phase == .empty)
    let replacement = try PCMAsset(interleavedStereo: [0.4, 0.3, 0.2, 0.1], sampleRate: 48000)
    let accepted = try core.load(replacement, deck: .a, grid: nil)
    #expect(accepted > cancelled)
    #expect(core.processControlsWhileIdle())
    #expect(core.snapshot()?.a.generation == accepted)
}

@Test func rejectedLoadSubmissionReleasesItsReservation() throws {
    let core = try SampleTransport()
    var full = false
    for _ in 0..<1024 {
        do { try core.setMixer(.master, value: 1) }
        catch TransportError.queueFull { full = true; break }
    }
    try #require(full)
    weak var released: PCMAsset?
    do {
        let asset = try PCMAsset(interleavedStereo: [0.1, 0.2], sampleRate: 48000)
        released = asset
        let generation = try core.reserveLoad(asset, deck: .b, grid: nil)
        #expect(throws: TransportError.queueFull) { try core.submitPreparedLoad(generation: generation) }
        #expect(throws: TransportError.stale) { try core.submitPreparedLoad(generation: generation) }
    }
    #expect(released == nil)
    #expect(core.processControlsWhileIdle())
    #expect(core.snapshot()?.b.phase == .empty)
}
