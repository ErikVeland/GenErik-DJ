import TDJCore
import Testing

@testable import TDJInterface

@Test(arguments: [
    (TraktorFactoryModel.x1MK1, 24, 1, UInt8(1), TraktorFactoryControl.play),
    (.x1MK2, 31, 22, 1, .play),
    (.f1, 22, 1, 0x80, .sample(0)),
    (.d2, 17, 8, 0x10, .play),
    (.z2, 9, 4, 1, .load),
    (.s5, 30, 9, 4, .play),
    (.s8, 41, 9, 0x10, .play),
    (.mx2, 80, 4, 0x20, .play),
])
func traktorFactoryButtonEdge(
    model: TraktorFactoryModel, count: Int, byte: Int, mask: UInt8, control: TraktorFactoryControl
) {
    var controller = TraktorFactoryControls(model)
    var report = [UInt8](repeating: 0, count: count)
    report[0] = 1
    #expect(!controller.consume(report).contains { $0.control == control })
    report[byte] = mask
    #expect(controller.consume(report).contains(.init(target: .surface(0), control: control, value: 1)))
    #expect(controller.consume(report).isEmpty)
    report[byte] = 0
    #expect(controller.consume(report).contains(.init(target: .surface(0), control: control, value: 0)))
}

@Test func traktorFactoryPotsAndEncoderKeepSeparateReports() {
    var controller = TraktorFactoryControls(.s8)
    var buttons = [UInt8](repeating: 0, count: 41)
    var analogs = [UInt8](repeating: 0, count: 109)
    buttons[0] = 1
    buttons[1] = 0x0f
    analogs[0] = 2
    _ = controller.consume(buttons)
    #expect(controller.consume(analogs).isEmpty)
    buttons[1] = 0
    #expect(controller.consume(buttons) == [.init(target: .surface(0), control: .loopSize, value: 1)])
    analogs[33] = 0xff
    analogs[34] = 0x0f
    #expect(controller.consume(analogs) == [.init(target: .channel(.a), control: .pot(.levelA), value: 1)])
}

@Test(arguments: TraktorFactoryModel.allCases)
func traktorFactoryLightReportsFitEveryMappedLamp(model: TraktorFactoryModel) {
    let profile = TraktorFactoryProfile.factory(model)
    var lights = TraktorFactoryLights(model)
    for light in profile.lights { lights.lamp(light.lamp, level: 127) }
    for meter in profile.meters { lights.meter(first: meter.first, count: meter.count, peak: 1) }
    for pulse in profile.pulses { lights.pulse(pulse, blue: 1, amber: nil) }
    let blue = lights.reports
    #expect(blue.map(\.count) == model.lightSizes)
    #expect(blue.compactMap(\.first) == model.lightSizes.indices.map { UInt8(0x80 + $0) })
    for pulse in profile.pulses { lights.pulse(pulse, blue: 1, amber: 1) }
    #expect(lights.reports != blue)
}

@Test func traktorFactoryFragmentsRejectLostAndChangedChunks() throws {
    let raw: [UInt8] = [1] + (1..<118).map { UInt8($0 + 100) }
    let payloads = TraktorFactoryFragments.payloads(raw)
    var decoder = ControllerBridgeDecoder()
    var assembly = TraktorFactoryFragments()
    let packets = try payloads.map { try ControllerBridgeFrame(kind: .factoryInput, payload: $0).encoded }
    #expect(packets.allSatisfy { $0.count <= 128 })
    #expect(assembly.append(payloads[1]) == nil)
    #expect(assembly.append(payloads[0]) == nil)
    var invalid = payloads[1]
    invalid[1] += 1
    #expect(assembly.append(invalid) == nil)
    let reports = decoder.append(packets.flatMap { $0 }).compactMap { assembly.append($0.payload) }
    #expect(reports == [raw])
}

@Test func traktorFactoryScreenTruncatesTitlesAtUTF8Boundaries() throws {
    let title = String(repeating: "🎧", count: 20)
    let screen = TraktorFactoryScreen(side: 1, deck: 3, flags: 7, position: 13, duration: 300, bpm: 124.5, title: title)
    let payload = screen.payload
    #expect(payload.count == 64)
    #expect(Array(payload.prefix(10)) == [1, 3, 7, 13, 0, 44, 1, 221, 4, 52])
    #expect(String(decoding: payload[10..<62], as: UTF8.self) == String(repeating: "🎧", count: 13))
}

@Test func traktorFactoryRecognisesOnlyWiredMixerGadgets() {
    for model in TraktorFactoryModel.allCases {
        let wired = AudioOutputDevice(name: model.bridgeName, wired: true)
        let wireless = AudioOutputDevice(name: model.bridgeName, wired: false)
        if [.z2, .s5, .s8, .mx2].contains(model) {
            #expect(wired.automaticSplitOutputName == "\(model.rawValue) Bridge")
        } else {
            #expect(wired.automaticSplitOutputName == nil)
        }
        #expect(wireless.automaticSplitOutputName == nil)
    }
}

@Test func traktorFactoryOriginalX1HotcueLayerUsesAllEightButtons() {
    let controls: [TraktorFactoryControl] = [
        .loopMark(false), .jump(-1), .cue, .play, .loopMark(true), .jump(1), .cuePlay, .sync,
    ]
    #expect(controls.compactMap(\.x1HotcueSlot) == Array(0..<8))
}

@Test func traktorFactoryD2AndF1UseTheirNativeRGBOrder() {
    var d2 = TraktorFactoryLights(.d2)
    d2.lamp(.rgb(0), level: 100)
    #expect(Array(d2.reports[0].prefix(4)) == [0x80, 100, 25, 0])
    var f1 = TraktorFactoryLights(.f1)
    f1.lamp(.rgb(24), level: 100)
    #expect(Array(f1.reports[0][25..<28]) == [100, 0, 25])
}

@Test func traktorPerformanceBrowserAndPatternPackets() {
    let rows = ["First", "Café 🎧", String(repeating: "🎧", count: 10), "Fourth"]
    let packet = TraktorFactoryScreenContent.browser(side: 1, rows: rows, selected: 2)
    #expect(packet.count == 103)
    #expect(Array(packet.prefix(3)) == [1, 1, 2])
    #expect(String(decoding: packet[53..<77], as: UTF8.self) == String(repeating: "🎧", count: 6))
    let waveform = TraktorFactoryScreenContent.waveform(side: 0, analysis: nil, progress: 0.5)
    #expect(waveform.count == 103)
    #expect(Array(waveform.prefix(4)) == [0, 0, 0, 128])

    var pattern = TraktorPatternUnit()
    let first = pattern.button(0, shifted: true)
    let second = pattern.button(0, shifted: true)
    #expect(first && second)
    pattern.selectPage(shifted: false)
    pattern.selectPage(shifted: false)
    pattern.selectPage(shifted: true)
    pattern.toggleStep(3)
    #expect(pattern.steps == 0x0800)
    let enabled = pattern.button(0, shifted: false)
    #expect(enabled)
    #expect(pattern.settings == 0)
    pattern.decks = [.b]
    #expect(pattern.settings & 0x3fffff == 0x120800)
}

@Test(arguments: [(TraktorFactoryModel.d2, 17, 3, 4, 0), (.s8, 41, 13, 14, 1)])
func traktorFactoryStemSendPageUsesTheNativePerformanceArrows(
    model: TraktorFactoryModel, count: Int, right: Int, left: Int, side: Int
) {
    var controls = TraktorFactoryControls(model)
    var report: [UInt8] = [1] + .init(repeating: 0, count: count - 1)
    _ = controls.consume(report)
    report[right] = 0x40
    #expect(controls.consume(report).contains { $0.target == .surface(side) && $0.control == .stemSendPage(true) && $0.value == 1 })
    report[right] = 0
    report[left] = 0x40
    #expect(controls.consume(report).contains { $0.target == .surface(side) && $0.control == .stemSendPage(false) && $0.value == 1 })
}
