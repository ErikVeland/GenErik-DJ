import Testing

@testable import TDJCore

private func z1NativePacket(_ id: UInt8, _ payload: [UInt8], legacy: Bool = false) -> [UInt8] {
    if legacy { return [0x33, 0xc3, id] + payload }
    let size = payload.count + 1
    return [0x33, 0xc3, 0, UInt8(size & 255), UInt8(size >> 8), id] + payload
}

private func z1NativeCalibration() -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 32)
    bytes[28] = 100
    bytes[30] = 0x3c
    bytes[31] = 0x0f
    return bytes
}

@Test func z1NativeRequestsAndLightsMatchRecoveredWireBytes() throws {
    #expect(Z1AccessoryProtocol.identifier == "com.native-instruments.traktordj.kontrolz1")
    #expect(Z1AccessoryProtocol.request(0xd0, framing: .lengthPrefixed) == [0x33, 0xc3, 0, 1, 0, 0xd0])
    #expect(Z1AccessoryProtocol.request(0xd2, framing: .legacy) == [0x33, 0xc3, 0xd2])
    #expect(Z1AccessoryProtocol.request(1, framing: .lengthPrefixed) == [0x33, 0xc3, 0, 1, 0, 1])
    let lights = [UInt8(0x80)] + Array(UInt8(0)...UInt8(20))
    #expect(try Z1AccessoryProtocol.feedback(lights, framing: .legacy) == [0xb3, 0xc3] + lights)
    #expect(try Z1AccessoryProtocol.feedback(lights, framing: .lengthPrefixed) == [0xb3, 0xc3, 0, 22, 0] + lights)
    #expect(throws: (any Error).self) { try Z1AccessoryProtocol.feedback([0x80], framing: .legacy) }
}

@Test func z1NativeFirmwareSelectsTheRecoveredRevisionBoundary() {
    #expect(Z1AccessoryProtocol.Framing(firmwareRevision: "0.0.7") == .legacy)
    #expect(Z1AccessoryProtocol.Framing(firmwareRevision: "0.0.8") == .lengthPrefixed)
    #expect(Z1AccessoryProtocol.Framing(firmwareRevision: "1.0.10") == .lengthPrefixed)
    #expect(Z1AccessoryProtocol.Framing(firmwareRevision: "unknown") == .lengthPrefixed)
}

@Test func z1NativeDecoderRetainsEverySplitAndSeparatesCombinedFrames() throws {
    for framing in [Z1AccessoryProtocol.Framing.legacy, .lengthPrefixed] {
        let payload = z1NativeCalibration()
        let first = z1NativePacket(0xd2, payload, legacy: framing == .legacy)
        let input = [UInt8](repeating: 0, count: 29)
        let second = z1NativePacket(1, input, legacy: framing == .legacy)
        let bytes = first + second
        let expected = [
            Z1AccessoryProtocol.Frame(reportID: 0xd2, payload: payload), .init(reportID: 1, payload: input),
        ]
        for split in 0...bytes.count {
            var decoder = Z1AccessoryProtocol.Decoder(framing: framing)
            let a = try decoder.append(Array(bytes.prefix(split)))
            let b = try decoder.append(Array(bytes.dropFirst(split)))
            #expect(a + b == expected)
        }
        var decoder = Z1AccessoryProtocol.Decoder(framing: framing)
        var frames: [Z1AccessoryProtocol.Frame] = []
        for byte in bytes { frames += try decoder.append([byte]) }
        #expect(frames == expected)
    }
}

@Test func z1NativeStartupRequiresOrderedCalibrationBeforeOperatingTheMixer() throws {
    var startup = Z1AccessoryProtocol.Startup()
    let calibration = z1NativeCalibration()
    #expect(try startup.consume(.init(reportID: 0xd2, payload: calibration)) == nil)
    #expect(try startup.input(.init(reportID: 1, payload: Array(repeating: 0, count: 29))) == nil)
    #expect(try startup.consume(.init(reportID: 0xd0, payload: calibration)) == 0xd1)
    #expect(try startup.consume(.init(reportID: 0xd1, payload: calibration)) == 0xd2)
    #expect(try startup.consume(.init(reportID: 0xd2, payload: calibration)) == 1)
    #expect(startup.ready)
    #expect(startup.calibration?.minimum == 100)
    #expect(startup.calibration?.maximum == 3900)
    #expect(try startup.consume(.init(reportID: 0xd2, payload: calibration)) == nil)
    var mapper = Z1ControlMapper(calibration: startup.calibration)
    var payload = [UInt8](repeating: 0, count: 29)
    payload[22] = 0xff
    payload[23] = 0x0f
    payload[26] = 0xd0
    payload[27] = 0x07
    payload[28] = 0x10
    let report = try #require(try startup.input(.init(reportID: 1, payload: payload)))
    let initial = mapper.consume(report)
    #expect(initial.contains(.mixer(.volume, 1, .a)))
    #expect(initial.contains(.mixer(.crossfader, 0.5, .a)))
    #expect(!initial.contains(.cue(.a)))
    payload[28] = 0
    _ = mapper.consume(try #require(try startup.input(.init(reportID: 1, payload: payload))))
    payload[28] = 0x10
    #expect(mapper.consume(try #require(try startup.input(.init(reportID: 1, payload: payload)))).contains(.cue(.a)))
}

@Test func z1NativeRejectsMalformedFramesCalibrationAndOverload() throws {
    for bytes: [UInt8] in [
        [0, 0, 0], [0x33, 0xc3, 4], [0x33, 0xc3, 0, 0, 0, 1], [0x33, 0xc3, 0, 1, 4, 1],
        Array(repeating: 0, count: 4097),
    ] {
        var decoder = Z1AccessoryProtocol.Decoder(framing: .lengthPrefixed)
        #expect(throws: (any Error).self) { try decoder.append(bytes) }
    }
    var legacy = Z1AccessoryProtocol.Decoder(framing: .legacy)
    #expect(throws: (any Error).self) { try legacy.append([0x33, 0xc3, 0x77]) }
    var decoder = Z1AccessoryProtocol.Decoder(framing: .lengthPrefixed)
    let flood = [[UInt8]](repeating: [UInt8(0x33), 0xc3, 0, 1, 0, 0x77], count: 129).flatMap { $0 }
    #expect(throws: (any Error).self) { try decoder.append(flood) }
    var startup = Z1AccessoryProtocol.Startup()
    #expect(throws: (any Error).self) { try startup.consume(.init(reportID: 0xd0, payload: [])) }
    _ = try startup.consume(.init(reportID: 0xd0, payload: z1NativeCalibration()))
    _ = try startup.consume(.init(reportID: 0xd1, payload: z1NativeCalibration()))
    #expect(throws: (any Error).self) {
        try startup.consume(.init(reportID: 0xd2, payload: Array(repeating: 0, count: 32)))
    }
    #expect(!startup.ready)
}
