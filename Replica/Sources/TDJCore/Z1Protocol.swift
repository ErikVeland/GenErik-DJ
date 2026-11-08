import Foundation

/// Original Z1 (17cc:1210) HID report facts, independently encoded from the Mixxx protocol notes.
/// This does not establish TDJ1's analogue response, takeover or iPad accessory protocol.
public struct Z1InputReport: Equatable, Sendable {
    public let controls: [UInt16]
    public let buttons: UInt8
    public init(bytes: [UInt8]) throws {
        guard bytes.count == 30, bytes[0] == 1 else { throw TransportError.invalid }
        controls = stride(from: 1, to: 29, by: 2).map { UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8 }
        guard controls.allSatisfy({ $0 <= 4095 }), bytes[29] & ~0x1f == 0 else { throw TransportError.invalid }
        buttons = bytes[29]
    }
    public var mode: Bool { buttons & 2 != 0 }
}

public struct Z1CrossfaderCalibration: Equatable, Sendable {
    public let minimum: UInt16
    public let maximum: UInt16
    public init(minimum: UInt16, maximum: UInt16) throws {
        guard minimum < maximum, maximum <= 4095 else { throw TransportError.invalid }
        self.minimum = minimum
        self.maximum = maximum
    }
    /// D2 payload is 32 bytes without its report ID. Last two words describe crossfader endpoints.
    public init(featureD2: [UInt8]) throws {
        guard featureD2.count == 32 else { throw TransportError.invalid }
        try self.init(
            minimum: UInt16(featureD2[28]) | UInt16(featureD2[29]) << 8,
            maximum: UInt16(featureD2[30]) | UInt16(featureD2[31]) << 8)
    }
    public func normalise(_ raw: UInt16) -> Double {
        min(1, max(0, (Double(raw) - Double(minimum)) / Double(maximum - minimum)))
    }
}

public enum Z1Action: Equatable, Sendable {
    case mixer(MixerParameter, Double, DeckID)
    case play(DeckID)
    case cue(DeckID)
    case filter(DeckID)
    case fxMode(DeckID)
    case effectParameter(Double, DeckID)
    case effectToggle(DeckID)
}

public struct Z1ControlMapper: Sendable {
    public var calibration: Z1CrossfaderCalibration?
    private var previous: Z1InputReport?
    public private(set) var fxDecks: Set<DeckID> = []
    public init(calibration: Z1CrossfaderCalibration? = nil) { self.calibration = calibration }
    public mutating func reset() {
        previous = nil
        fxDecks = []
    }
    public mutating func consume(_ report: Z1InputReport) -> [Z1Action] {
        var actions: [Z1Action] = []
        let rising = previous.map { report.buttons & ~$0.buttons } ?? 0
        if report.mode {
            for (mask, deck) in [(UInt8(4), DeckID.a), (UInt8(8), DeckID.b)] where rising & mask != 0 {
                if fxDecks.contains(deck) { fxDecks.remove(deck) } else { fxDecks.insert(deck) }
            }
        }
        for index in report.controls.indices where previous?.controls[index] != report.controls[index] {
            let value = Double(report.controls[index]) / 4095
            let deck: DeckID = index < 5 ? .a : .b
            switch index {
            case 0, 5: actions.append(.mixer(.gain, pow(4, 2 * value - 1), deck))
            case 1, 6: actions.append(.mixer(.high, 2 * value, deck))
            case 2, 7: actions.append(.mixer(.mid, 2 * value, deck))
            case 3, 8: actions.append(.mixer(.low, 2 * value, deck))
            case 4, 9:
                actions.append(
                    fxDecks.contains(deck) ? .effectParameter(value, deck) : .mixer(.filterX, 2 * value - 1, deck))
            case 10: actions.append(.mixer(.cueBlend, value, .a))
            case 11: actions.append(.mixer(.volume, value, .a))
            case 12: actions.append(.mixer(.volume, value, .b))
            case 13:
                if let calibration {
                    actions.append(.mixer(.crossfader, calibration.normalise(report.controls[index]), .a))
                }
            default: break
            }
        }
        // Connection establishes button state without firing buttons already held.
        if previous != nil {
            for (mask, deck) in [(UInt8(0x10), DeckID.a), (UInt8(1), DeckID.b)] where rising & mask != 0 {
                actions.append(report.mode ? .play(deck) : .cue(deck))
            }
            for (mask, deck) in [(UInt8(4), DeckID.a), (UInt8(8), DeckID.b)] where rising & mask != 0 {
                actions.append(
                    report.mode ? .fxMode(deck) : fxDecks.contains(deck) ? .effectToggle(deck) : .filter(deck))
            }
        }
        previous = report
        return actions
    }
}

public enum Z1OutputReport {
    /// Meter thresholds are a development choice; report positions are protocol facts.
    public static func bytes(
        snapshot: PlaybackSnapshot, mode: Bool, fxDecks: Set<DeckID> = [], enabledEffects: Set<DeckID> = [],
        sourceFrames: (a: UInt64?, b: UInt64?) = (nil, nil)
    ) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 22)
        bytes[0] = 0x80
        for (index, deck) in [DeckID.a, .b].enumerated() {
            let state = snapshot[deck].mixer
            let decibels = 20 * log10(max(1e-12, state.peak))
            for (segment, threshold) in [-30.0, -20, -12, -6, -3, 0, 3].enumerated() {
                bytes[1 + index * 7 + segment] = decibels >= threshold ? 0x7f : 0
            }
            bytes[15 + index] = state.cue ? 0x7f : 0x0a
            if fxDecks.contains(deck) {
                bytes[index == 0 ? 17 : 20] = enabledEffects.contains(deck) ? 0x7f : 0x0a
            } else {
                bytes[index == 0 ? 18 : 21] = state.filterEnabled ? 0x7f : 0x0a
            }
            applyPlaybackLights(
                to: &bytes, state: snapshot[deck], frameCount: index == 0 ? sourceFrames.a : sourceFrames.b,
                amberIndex: index == 0 ? 17 : 20, blueIndex: index == 0 ? 18 : 21)
        }
        bytes[19] = mode ? 0x7f : 0x0a
        return bytes
    }

    private static func applyPlaybackLights(
        to bytes: inout [UInt8], state: DeckPlaybackSnapshot, frameCount: UInt64?, amberIndex: Int, blueIndex: Int
    ) {
        guard state.phase == .playing, !state.touchActive, !state.braking, state.performanceRate == 1,
            state.speed.isFinite, state.speed > 0, let timing = state.timing
        else { return }
        let beat = timing.beat(atFrame: state.sourceFrame)
        guard beat.isFinite else { return }

        let bluePulse = pulse(phase: beat, width: 0.2)
        let blueBase = bytes[blueIndex] == 0x7f ? 0x60 : Double(bytes[blueIndex])
        let bluePeak = bytes[blueIndex] == 0x7f ? 0x7f : blueBase + 0x18
        bytes[blueIndex] = brightness(base: blueBase, peak: bluePeak, pulse: bluePulse)

        guard !state.loopEnabled, let frameCount, frameCount > 0 else { return }
        let remaining: Double
        if state.synced, state.adaptiveMap != nil {
            remaining = (timing.beat(atFrame: Double(frameCount)) - beat) * 60 / (state.sourceBPM * state.speed)
        } else {
            remaining = (Double(frameCount) - state.sourceFrame) / (timing.fixed.sampleRate * state.speed)
        }
        guard remaining.isFinite, remaining > 0, remaining <= 30 else { return }
        let beatsPerPulse = remaining <= 10 ? 1.0 : 4.0
        let amberPulse = pulse(phase: (beat - Double(timing.downbeatOffset)) / beatsPerPulse, width: 0.5)
        let amberBase = bytes[amberIndex] == 0x7f ? 0x20 : Double(bytes[amberIndex])
        bytes[amberIndex] = brightness(base: amberBase, peak: 0x7f, pulse: amberPulse)
        // Keep the warning prominent while blue still marks each beat.
        bytes[blueIndex] = brightness(base: 0, peak: 0x18, pulse: bluePulse)
    }

    private static func pulse(phase: Double, width: Double) -> Double {
        let position = phase - floor(phase)
        guard position < width else { return 0 }
        return 0.5 * (1 + cos(.pi * position / width))
    }

    private static func brightness(base: Double, peak: Double, pulse: Double) -> UInt8 {
        UInt8((base + (peak - base) * pulse).rounded())
    }
}
