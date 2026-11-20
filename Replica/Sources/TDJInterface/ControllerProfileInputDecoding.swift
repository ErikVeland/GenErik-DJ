import Foundation
import TDJCore

extension ControllerProfileData.Input: Decodable {
    private enum Field: String, CodingKey {
        case action, kind, channel, number, encoding, inverted, targetDeck, anyChannel, argument, releaseOnly,
            requiredMode, shifted, shiftInput, holdInput, shiftChannel, lowNumber, pulse, requiresTouch,
            directionStep, deckBank
        case a, k, c, n, e, i, d, w, g, r, m, s, t, h, z, l, p, u, v, b
    }

    /**
     * Decodes full review rows or compact bundled rows into the same control contract.
     */
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Field.self)
        let compact = values.contains(.a)
        guard values.allKeys.allSatisfy({ ($0.rawValue.count == 1) == compact }) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Controller input fields use mixed formats."))
        }
        func optional<T: Decodable>(_ type: T.Type, _ full: Field, _ short: Field) throws -> T? {
            try values.decodeIfPresent(type, forKey: compact ? short : full)
        }
        func required<T: Decodable>(_ type: T.Type, _ full: Field, _ short: Field, default fallback: T) throws -> T {
            let key = compact ? short : full
            if compact && !values.contains(key) { return fallback }
            return try values.decode(type, forKey: key)
        }
        self.init(
            action: try values.decode(ControllerAction.self, forKey: compact ? .a : .action),
            kind: try required(ControllerMIDIMessage.Kind.self, .kind, .k, default: .note),
            channel: try values.decode(UInt8.self, forKey: compact ? .c : .channel),
            number: try values.decode(UInt8.self, forKey: compact ? .n : .number),
            encoding: try required(ControllerMIDIEncoding.self, .encoding, .e, default: .absolute),
            inverted: try required(Bool.self, .inverted, .i, default: false),
            targetDeck: try optional(DeckID.self, .targetDeck, .d),
            anyChannel: try optional(Bool.self, .anyChannel, .w),
            argument: try optional(Double.self, .argument, .g),
            releaseOnly: try optional(Bool.self, .releaseOnly, .r),
            requiredMode: try optional(UInt8.self, .requiredMode, .m),
            shifted: try optional(Bool.self, .shifted, .s),
            shiftInput: try optional(UInt8.self, .shiftInput, .t),
            holdInput: try optional(UInt8.self, .holdInput, .h),
            shiftChannel: try optional(UInt8.self, .shiftChannel, .z),
            lowNumber: try optional(UInt8.self, .lowNumber, .l),
            pulse: try optional(Bool.self, .pulse, .p),
            requiresTouch: try optional(Bool.self, .requiresTouch, .u),
            directionStep: try optional(Double.self, .directionStep, .v),
            deckBank: try optional(UInt8.self, .deckBank, .b))
    }
}
