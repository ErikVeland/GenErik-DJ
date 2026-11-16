import Foundation
import TDJCore

struct ControllerProfileData: Decodable, Sendable {
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

        func binding(source: Int32) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number,
                parameter: nil, noteNumber: nil, action: action, encoding: encoding,
                inverted: inverted, shifted: false, targetDeck: targetDeck, layerIndependent: true,
                anyChannel: anyChannel, argument: argument, releaseOnly: releaseOnly)
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
        let targetDeck: DeckID?

        func binding(destination: Int32) -> ControllerFeedbackBinding {
            .init(
                destination: destination, action: action, kind: kind, channel: channel, number: number,
                offValue: offValue, onValue: onValue, offUsesNoteOn: offUsesNoteOn, targetDeck: targetDeck)
        }
    }

    let id: String
    let aliases: [String]
    let inputs: [Input]
    let outputs: [Output]
    let startup: [[UInt8]]
    let shutdown: [[UInt8]]
    let autoSelect: Bool
    let scope: String
    let source: String
    let role: String?

    var isValid: Bool {
        (role == nil || role == "player") && !id.isEmpty && id.count <= 128 && !aliases.isEmpty && aliases.count <= 24
            && aliases.allSatisfy { !$0.isEmpty && $0.count <= 128 }
            && !inputs.isEmpty && inputs.count <= 512 && outputs.count <= 128
            && inputs.allSatisfy {
                $0.channel < 16 && $0.number < 128
                    && (!$0.encoding.isPairedCC || ($0.kind == .control && $0.number < 32))
                    && ($0.anyChannel != true || role == "player")
                    && ($0.releaseOnly != true || ($0.kind == .note && $0.action.isMomentary))
                    && Self.validArgument($0)
                    && (![.cdjPlatterSpeed, .cdjRingSpeed, .cdj350PlatterSpeed, .cdjTempo, .needlePosition].contains($0.encoding)
                        || $0.kind == .control)
            }
            && outputs.allSatisfy {
                $0.channel < 16 && $0.number < 128 && $0.onValue < 128 && $0.offValue < 128
                    && $0.action.supportsFeedback && ($0.kind == .control || $0.action.isButton)
            }
            && (startup + shutdown).count <= 16
            && (startup + shutdown).allSatisfy(Self.validSetupMessage)
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
        case .loopSizeA, .loopSizeB:
            return input.kind == .control && input.encoding == .twosComplement && input.argument == nil
        case .loopA, .loopB:
            return input.argument.map { PerformancePreparation.loopSizes.contains($0) } ?? true
        case .fixedLoopA, .fixedLoopB:
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
