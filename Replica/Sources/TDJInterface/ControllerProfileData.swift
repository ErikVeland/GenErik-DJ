import Foundation
import TDJCore

struct ControllerProfileData: Decodable, Sendable {
    enum AudioOutput: String, Decodable, Sendable {
        case masterAndHeadphones
    }

    struct Input: Decodable, Sendable {
        let action: ControllerAction
        let kind: ControllerMIDIMessage.Kind
        let channel: UInt8
        let number: UInt8
        let encoding: ControllerMIDIEncoding
        let inverted: Bool
        let targetDeck: DeckID?
        let anyChannel: Bool?
        let argument: Double?
        let releaseOnly: Bool?
        let requiredMode: UInt8?
        let shifted: Bool?
        let shiftInput: UInt8?
        let shiftChannel: UInt8?
        let lowNumber: UInt8?
        let pulse: Bool?
        let requiresTouch: Bool?

        func binding(source: Int32) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number,
                parameter: nil, noteNumber: nil, action: action, encoding: encoding,
                inverted: inverted, shifted: shifted ?? false, targetDeck: targetDeck, layerIndependent: shifted == nil,
                anyChannel: anyChannel, argument: argument, releaseOnly: releaseOnly, requiredMode: requiredMode,
                shiftChannel: shiftChannel, shiftInput: shiftInput, lowNumber: lowNumber, pulse: pulse,
                requiresTouch: requiresTouch)
        }
    }

    struct InputMode: Decodable, Sendable {
        let channel: UInt8
        let initial: UInt8
        let numbers: [UInt8]
        let onValue: UInt8
        let offValue: UInt8

        var isValid: Bool {
            channel < 16 && !numbers.isEmpty && numbers.count <= 16
                && numbers.allSatisfy { $0 < 128 } && Set(numbers).count == numbers.count
                && numbers.contains(initial) && onValue < 128 && offValue < 128
        }
    }

    struct BankChange: Decodable, Sendable {
        let kind: ControllerMIDIMessage.Kind?
        let channel: UInt8
        let number: UInt8
        let onValue: UInt8?
        let decks: [DeckID]
        let releaseShiftChannels: [UInt8]?

        var isValid: Bool {
            (kind == nil || kind == .note || kind == .control)
                && channel < 16 && number < 128
                && (onValue.map { $0 < 128 && (kind == .control || $0 > 0) } ?? (kind == .control))
                && (kind != .control || releaseShiftChannels == nil)
                && !decks.isEmpty && decks.count <= 4 && Set(decks).count == decks.count
                && (releaseShiftChannels.map {
                    $0.count <= 16 && $0.allSatisfy { $0 < 16 } && Set($0).count == $0.count
                } ?? true)
        }
    }

    struct Output: Decodable, Sendable {
        let action: ControllerAction
        let kind: ControllerFeedbackKind
        let channel: UInt8
        let number: UInt8
        let onValue: UInt8
        let offValue: UInt8
        let offUsesNoteOn: Bool
        let offNumber: UInt8?
        let targetDeck: DeckID?

        func binding(destination: Int32) -> ControllerFeedbackBinding {
            .init(
                destination: destination, action: action, kind: kind, channel: channel, number: number,
                offValue: offValue, onValue: onValue, offUsesNoteOn: offUsesNoteOn, targetDeck: targetDeck,
                offNumber: offNumber)
        }
    }

    let id: String
    let aliases: [String]
    let excludedAliases: [String]?
    let inputs: [Input]
    let outputs: [Output]
    let startup: [[UInt8]]
    let shutdown: [[UInt8]]
    let autoSelect: Bool
    let scope: String
    let source: String
    let role: String?
    let inputModes: [InputMode]?
    let bankChanges: [BankChange]?
    let audioOutput: AudioOutput?
    let portAliases: [String]?

    var isValid: Bool {
        (role == nil || role == "player" || role == "accessory") && !id.isEmpty && id.count <= 128 && !aliases.isEmpty
            && aliases.count <= 24
            && aliases.allSatisfy { !$0.isEmpty && $0.count <= 128 }
            && (portAliases.map { !$0.isEmpty && $0.count <= 16 && $0.allSatisfy { !$0.isEmpty && $0.count <= 128 } }
                ?? true)
            && (excludedAliases?.count ?? 0) <= 24
            && (excludedAliases ?? []).allSatisfy { !$0.isEmpty && $0.count <= 128 }
            && validInputModes && validBankChanges && (audioOutput == nil || autoSelect)
            && inputs.allSatisfy { input in
                guard let channel = input.shiftChannel else { return true }
                return channel < 16 && inputs.contains { $0.action == .shift && $0.shiftChannel == channel }
            }
            && inputs.allSatisfy { input in
                guard input.requiresTouch == true else { return true }
                let touch: ControllerAction = input.action.deck == .a ? .jogTouchA : .jogTouchB
                return inputs.contains { $0.action == touch && $0.targetDeck == input.targetDeck }
            }
            && !inputs.isEmpty && inputs.count <= 512 && outputs.count <= 128
            && inputs.allSatisfy {
                $0.channel < 16 && $0.number < 128
                    && ($0.encoding.isPairedCC
                        ? $0.kind == .control && ($0.lowNumber.map { $0 < 128 } ?? ($0.number < 32))
                            && $0.lowNumber != $0.number
                        : $0.lowNumber == nil)
                    && ($0.anyChannel != true || role == "player")
                    && ($0.requiresTouch != true || ($0.action.isJog && $0.encoding.isRelative))
                    && ($0.encoding != .touchGate
                        || ($0.kind == .note && [.jogTouchA, .jogTouchB].contains($0.action)))
                    && ($0.encoding != .lc6000Jog || $0.action.isJog)
                    && ($0.encoding != .readyTempo || [.tempoA, .tempoB].contains($0.action))
                    && ($0.releaseOnly != true || ($0.kind == .note && $0.action.isButton && $0.action != .shift))
                    && ($0.pulse != true
                        || ($0.kind == .note && $0.encoding == .absolute && $0.action.isButton
                            && !$0.action.isMomentary && $0.action != .shift && $0.releaseOnly != true))
                    && ($0.shiftInput == nil
                        || ($0.shiftInput! < 16 && $0.action == .shift && $0.kind == .note))
                    && ($0.encoding != .centredPitch || ($0.kind == .pitch && $0.number == 0))
                    && (![.mixstreamJog, .cyclic14BitJog, .vci100MK2Tempo, .lc6000Jog, .readyTempo].contains(
                        $0.encoding)
                        || $0.lowNumber != nil)
                    && Self.validArgument($0)
                    && (![
                        .centreDetent, .binaryStep, .binaryDirection, .signedStep, .dj2go2Jog, .mc7000Jog, .denonJog,
                        .zeroForward,
                        .numarkPlatinumJog,
                        .cdjPlatterSpeed, .cdjRingSpeed,
                        .cdj350PlatterSpeed, .cdjTempo, .needlePosition,
                    ].contains($0.encoding)
                        || $0.kind == .control)
            }
            && outputs.allSatisfy {
                $0.binding(destination: 0).isValid
            }
            && (startup + shutdown).count <= 32
            && (startup + shutdown).allSatisfy(Self.validSetupMessage)
    }

    private var validBankChanges: Bool {
        let changes = bankChanges ?? []
        return changes.count <= 16 && (changes.isEmpty || role != "player")
            && changes.allSatisfy { $0.isValid }
            && changes.allSatisfy { change in
                (change.releaseShiftChannels ?? []).allSatisfy { channel in
                    inputs.contains { $0.action == .shift && $0.shiftChannel == channel }
                }
            }
            && Set(changes.map { "\(($0.kind ?? .note).rawValue):\($0.channel):\($0.number)" }).count == changes.count
    }

    private var validInputModes: Bool {
        let modes = inputModes ?? []
        return modes.count <= 16 && modes.allSatisfy { $0.isValid }
            && Set(modes.map(\.channel)).count == modes.count
            && inputs.allSatisfy { input in
                guard let required = input.requiredMode else { return true }
                return input.kind == .note && input.action.isButton && !input.action.isMomentary
                    && input.anyChannel != true
                    && modes.contains { $0.channel == input.channel && $0.numbers.contains(required) }
            }
    }

    static func validSetupMessage(_ bytes: [UInt8]) -> Bool {
        if bytes.count == 3 {
            return (0x80...0xEF).contains(bytes[0]) && bytes[1] < 128 && bytes[2] < 128
        }
        return (4...128).contains(bytes.count) && bytes.first == 0xF0 && bytes.last == 0xF7
            && bytes.dropFirst().dropLast().allSatisfy { $0 < 128 }
    }

    private static func validArgument(_ input: Input) -> Bool {
        switch input.action {
        case .jogA, .jogB, .wheelJogA, .wheelJogB:
            return input.argument.map { input.encoding.isRelative && ControllerCountJogMotion.validResolution($0) }
                ?? true
        case .loopSizeA, .loopSizeB:
            return input.kind == .control && [.twosComplement, .binaryStep, .binaryDirection].contains(input.encoding)
                && input.argument == nil
        case .loopA, .loopB:
            return input.argument.map { PerformancePreparation.loopSizes.contains($0) } ?? true
        case .toggleFixedLoopA, .toggleFixedLoopB, .fixedLoopA, .fixedLoopB:
            return input.argument.map { PerformancePreparation.loopSizes.contains($0) } ?? false
        case .fixedJumpA, .fixedJumpB:
            return input.argument.map { $0.isFinite && $0 != 0 && abs($0) <= 64 } ?? false
        default: return input.argument == nil
        }
    }
}

struct ControllerProfileCatalogue: Decodable, Sendable {
    let schemaVersion: Int
    let profiles: [ControllerProfileData]

    private static let loaded: Result<Self, Error> = Result {
        guard let url = Bundle.module.url(forResource: "factory-controller-profiles", withExtension: "json")
        else { throw TransportError.invalid }
        return try decode(Data(contentsOf: url))
    }
    static let shared: Self = (try? loaded.get()) ?? .init(schemaVersion: 1, profiles: [])
    static var loadFailure: String? {
        if case .failure = loaded { return "The bundled controller catalogue could not load." }
        return nil
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 4 * 1024 * 1024 else { throw TransportError.invalid }
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard result.schemaVersion == 1, result.profiles.count <= 512,
            Set(result.profiles.map(\.id)).count == result.profiles.count,
            result.profiles.allSatisfy(\.isValid)
        else { throw TransportError.invalid }
        return result
    }
}
