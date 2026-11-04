import Foundation
import Testing

@testable import TDJCore

private func z1Bytes(buttons: UInt8 = 0) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 30)
    bytes[0] = 1
    for offset in stride(from: 1, to: 29, by: 2) {
        bytes[offset] = 0xff
        bytes[offset + 1] = 7
    }
    bytes[29] = buttons
    return bytes
}
@Test func z1ReportValidatesBytesAndFiresOnlyButtonEdges() throws {
    var mapper = Z1ControlMapper()
    let initial = try Z1InputReport(bytes: z1Bytes(buttons: 0x10))
    #expect(!mapper.consume(initial).contains(.cue(.a)))
    #expect(mapper.consume(initial).isEmpty)
    _ = mapper.consume(try Z1InputReport(bytes: z1Bytes()))
    #expect(mapper.consume(initial) == [.cue(.a)])
    _ = mapper.consume(try Z1InputReport(bytes: z1Bytes(buttons: 2)))
    #expect(mapper.consume(try Z1InputReport(bytes: z1Bytes(buttons: 0x13))) == [.play(.a), .play(.b)])
    #expect(throws: TransportError.invalid) { try Z1InputReport(bytes: [1, 2, 3]) }
    var invalid = z1Bytes()
    invalid[2] = 0x10
    #expect(throws: TransportError.invalid) { try Z1InputReport(bytes: invalid) }
}
@Test func z1CrossfaderRequiresDeviceCalibrationAndKeepsDecksDistinct() throws {
    let calibration = try Z1CrossfaderCalibration(minimum: 100, maximum: 3900)
    #expect(calibration.normalise(0) == 0)
    #expect(calibration.normalise(4095) == 1)
    #expect(calibration.normalise(2000) == 0.5)
    var mapper = Z1ControlMapper(calibration: calibration)
    _ = mapper.consume(try Z1InputReport(bytes: z1Bytes()))
    var changed = z1Bytes()
    changed[25] = 0
    changed[26] = 0
    #expect(mapper.consume(try Z1InputReport(bytes: changed)) == [.mixer(.volume, 0, .b)])
    changed[27] = 100
    changed[28] = 0
    #expect(mapper.consume(try Z1InputReport(bytes: changed)) == [.mixer(.crossfader, 0, .a)])
}
@Test func z1OutputContainsCueAndFilterFeedbackWithoutInventingFX() throws {
    let core = try SampleTransport()
    try core.setMixer(.cue, value: 1, deck: .b)
    try core.setMixer(.filterEnabled, value: 1, deck: .a)
    core.processControlsWhileIdle()
    let bytes = Z1OutputReport.bytes(snapshot: try #require(core.snapshot()), mode: true)
    #expect(bytes.count == 22 && bytes[0] == 0x80)
    #expect(bytes[15] == 0x0a && bytes[16] == 0x7f)
    #expect(bytes[18] == 0x7f && bytes[21] == 0x0a)
    #expect(bytes[17] == 0 && bytes[20] == 0 && bytes[19] == 0x7f)
}

@Test func z1FXModeIsPerDeckAndRoutesOnlyItsKnobAndOnButton() throws {
    var mapper = Z1ControlMapper()
    _ = mapper.consume(try Z1InputReport(bytes: z1Bytes()))
    #expect(mapper.consume(try Z1InputReport(bytes: z1Bytes(buttons: 6))) == [.fxMode(.a)])
    #expect(mapper.fxDecks == [.a])
    _ = mapper.consume(try Z1InputReport(bytes: z1Bytes()))
    #expect(mapper.consume(try Z1InputReport(bytes: z1Bytes(buttons: 4))) == [.effectToggle(.a)])
    var knobs = z1Bytes()
    knobs[9] = 0xff
    knobs[10] = 0x0f
    knobs[19] = 0
    knobs[20] = 0
    #expect(mapper.consume(try Z1InputReport(bytes: knobs)) == [.effectParameter(1, .a), .mixer(.filterX, -1, .b)])
    mapper.reset()
    #expect(mapper.fxDecks.isEmpty)
}

@Test func z1FXFeedbackUsesDocumentedIndependentColourBytes() throws {
    let core = try SampleTransport()
    let bytes = Z1OutputReport.bytes(
        snapshot: try #require(core.snapshot()), mode: false, fxDecks: [.a, .b], enabledEffects: [.a])
    #expect(bytes[17] == 0x7f && bytes[20] == 0x0a)
    #expect(bytes[18] == 0 && bytes[21] == 0)
}
