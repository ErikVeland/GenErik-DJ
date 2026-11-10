import TDJCore

enum TraktorFactoryModel: String, CaseIterable {
    case x1MK1 = "X1 Mk1", x1MK2 = "X1 Mk2", f1 = "F1", d2 = "D2", z2 = "Z2"
    case s5 = "S5", s8 = "S8", mx2 = "MX2"

    var bridgeName: String { "GenErik \(rawValue) Bridge" }

    var lightSizes: [Int] {
        switch self {
        case .x1MK1: [33]
        case .x1MK2: [52, 91]
        case .f1: [81]
        case .d2: [123]
        case .z2: [95, 41]
        case .s5: [105, 105, 74]
        case .s8: [119, 119, 74]
        case .mx2: [106]
        }
    }

    var defaultDecks: [DeckID] {
        switch self {
        case .f1: [.c]
        case .d2: [.a]
        default: [.a, .b]
        }
    }
}

enum TraktorFactoryControl: Equatable {
    case shift, play, cue, sync, keylock, flux, reverse, clockMaster
    case layer(DeckID?), browser, browse, load, preview
    case loop, loopSize, loopMark(Bool), move, tempo, masterTempo, jump(Int)
    case pad(Int), hotcues, samples, freeze, grid, quantize
    case sample(Int), stopSampleColumn(Int)
    case fxButton(Int), fxKnob(Int), fxAssign(Int), mixerFX(Int)
    case pot(ControllerAction), mixerButton(ControllerAction), mixerSwitch(ControllerAction), crossfaderAssign
    case jog, jogTouch, strip
}

struct TraktorFactoryProfile {
    enum Target: Hashable {
        case surface(Int)
        case channel(DeckID)
    }

    enum Encoding {
        case bit(UInt8), switchField(Int, UInt8), nibble(Int), pot(bigEndian: Bool), wheel, strip(shared: Bool)
    }

    struct Input {
        let report: UInt8
        let byte: Int
        let encoding: Encoding
        let target: Target
        let control: TraktorFactoryControl
    }

    enum Lamp {
        case mono(Int), rgb(Int), palette(Int)
    }

    struct Light {
        let lamp: Lamp
        let target: Target
        let control: TraktorFactoryControl
    }

    enum Pulse {
        case mono(beat: Int, warning: Int)
        case rgb(Int)
        case paired(blue: Int, amber: Int, count: Int, stride: Int)
        case palette(first: Int, count: Int)
    }

    var inputs: [Input] = []
    var lights: [Light] = []
    var pulses: [Pulse] = []
    var meters: [(DeckID, first: Int, count: Int)] = []

    mutating func button(
        _ byte: Int, _ mask: UInt8, _ target: Target, _ control: TraktorFactoryControl, _ lamp: Lamp? = nil
    ) {
        inputs.append(.init(report: 1, byte: byte, encoding: .bit(mask), target: target, control: control))
        if let lamp { lights.append(.init(lamp: lamp, target: target, control: control)) }
    }

    mutating func bit(
        _ first: Int, _ index: Int, _ target: Target, _ control: TraktorFactoryControl, _ lamp: Lamp? = nil
    ) {
        button(first + index / 8, 1 << (index % 8), target, control, lamp)
    }

    mutating func turn(_ byte: Int, high: Bool = false, _ target: Target, _ control: TraktorFactoryControl) {
        inputs.append(.init(report: 1, byte: byte, encoding: .nibble(high ? 4 : 0), target: target, control: control))
    }

    mutating func pot(
        _ byte: Int, report: UInt8 = 2, bigEndian: Bool = false, _ target: Target, _ control: TraktorFactoryControl
    ) {
        inputs.append(.init(report: report, byte: byte, encoding: .pot(bigEndian: bigEndian), target: target, control: control))
    }
}

struct TraktorFactoryControls {
    struct Event: Equatable {
        let target: TraktorFactoryProfile.Target
        let control: TraktorFactoryControl
        let value: Double
    }

    let profile: TraktorFactoryProfile
    private var previous: [UInt8: [UInt8]] = [:]
    private var lastPot: [Int: Int] = [:]

    init(_ model: TraktorFactoryModel) { profile = .factory(model) }

    mutating func consume(_ report: [UInt8]) -> [Event] {
        guard let id = report.first else { return [] }
        let prior = previous.updateValue(report, forKey: id)
        var events: [Event] = []
        for (index, input) in profile.inputs.enumerated() where input.report == id {
            let byte = input.byte
            guard byte < report.count else { continue }
            let old = prior.flatMap { byte < $0.count ? $0[byte] : nil }
            let value: Double
            switch input.encoding {
            case .bit(let mask):
                guard let old, old & mask != report[byte] & mask else { continue }
                value = report[byte] & mask == 0 ? 0 : 1
            case .switchField(let shift, let mask):
                let current = (report[byte] >> shift) & mask
                guard old.map({ ($0 >> shift) & mask }) != current else { continue }
                value = Double(current)
            case .nibble(let shift):
                guard let old else { continue }
                let current = Int((report[byte] >> shift) & 15)
                let last = Int((old >> shift) & 15)
                let delta = ((current - last + 24) % 16) - 8
                guard delta != 0 else { continue }
                value = Double(delta)
            case .pot(let bigEndian):
                guard let raw = Self.word(report, byte, bigEndian: bigEndian) else { continue }
                let now = raw & 0x0fff
                guard let last = lastPot[index] else {
                    lastPot[index] = now
                    continue
                }
                guard now != last, abs(now - last) >= 4 || now == 0 || now == 4095 else { continue }
                lastPot[index] = now
                value = Double(now) / 4095
            case .wheel:
                guard let prior, byte + 4 <= min(prior.count, report.count) else { continue }
                func counter(_ bytes: [UInt8]) -> UInt32 {
                    UInt32(bytes[byte]) | UInt32(bytes[byte + 1]) << 8
                        | UInt32(bytes[byte + 2]) << 16 | UInt32(bytes[byte + 3]) << 24
                }
                let delta = Int32(bitPattern: counter(report) &- counter(prior))
                guard delta != 0, (-512...512).contains(delta) else { continue }
                value = Double(delta)
            case .strip(let shared):
                guard let prior, let now = Self.word(report, byte), let last = Self.word(prior, byte),
                    (15...1009).contains(now), (15...1009).contains(last), abs(now - last) < 200, now != last
                else { continue }
                if shared {
                    let left = now < 487 && last < 487
                    let right = now > 537 && last > 537
                    guard input.target == .surface(0) ? left : right else { continue }
                }
                value = Double(now - last) / 4
            }
            events.append(.init(target: input.target, control: input.control, value: value))
        }
        return events
    }

    private static func word(_ report: [UInt8], _ byte: Int, bigEndian: Bool = false) -> Int? {
        guard byte + 1 < report.count else { return nil }
        return bigEndian ? Int(report[byte]) << 8 | Int(report[byte + 1]) : Int(report[byte]) | Int(report[byte + 1]) << 8
    }
}
