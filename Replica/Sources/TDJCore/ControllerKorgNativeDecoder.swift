public enum ControllerKorgNativeEvent: Equatable, Sendable {
    case request([UInt8])
    case modeChanged(Bool)
    case sceneChanged
    case message(ControllerMIDIMessage)
}

public struct ControllerKorgNativeDecoder: Sendable {
    public enum Model: UInt8, Sendable { case nanoPad2 = 0x12, nanoKontrol2 = 0x13 }
    private let model: Model
    private var scene: UInt8 = 0
    private var sceneDown = false
    private var heldPads: [UInt8: (number: UInt8, emitted: Bool)] = [:]
    private var heldLoopPads: Set<UInt8> = []
    private enum Phase: Sendable { case searching, entering, ready, closed }
    private var phase: Phase = .searching
    private var globalChannel: UInt8?
    private var packet: [UInt8]?
    private var standard = ControllerMIDIDecoder()
    public static let searchRequest: [UInt8] = [0xF0, 0x42, 0x50, 0, 0x2D, 0xF7]

    public init(model: Model = .nanoKontrol2) { self.model = model }
    public var isReady: Bool { phase == .ready }
    public var exitRequest: [UInt8]? {
        globalChannel.map { Self.modeRequest(channel: $0, model: model, entering: false) }
    }

    private static func modeRequest(channel: UInt8, model: Model, entering: Bool) -> [UInt8] {
        [0xF0, 0x42, 0x40 + channel, 0, 1, model.rawValue, 0, 0, 0, entering ? 1 : 0, 0xF7]
    }

    /**
     * Confirms the model and configured channel before accepting fixed native-mode controls.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        var result: [ControllerKorgNativeEvent] = []
        for byte in bytes {
            if byte >= 0xF8 { continue }
            if byte == 0xF0 {
                packet = [byte]
                _ = standard.append([byte])
                continue
            }
            if let pending = packet {
                if byte == 0xF7 {
                    packet = nil
                    result.append(contentsOf: decode(pending + [byte]))
                    continue
                }
                if byte < 0x80, pending.count < 15 {
                    packet?.append(byte)
                    continue
                }
                packet = nil
            }
            for message in standard.append([byte]) {
                guard isReady else { continue }
                if model == .nanoPad2 {
                    result.append(contentsOf: convertPad(message))
                    continue
                }
                guard message.kind == .control, message.channel == 15 else { continue }
                let number = message.number
                if number < 4 || number == 18 {
                    result.append(.message(.init(kind: .control, channel: 0, number: number, value: message.value)))
                } else if (60...62).contains(number) || (64...67).contains(number) {
                    guard message.value == 0 || message.value == 127 else { continue }
                    result.append(
                        .message(
                            .init(
                                kind: .note, channel: 0, number: number, value: message.value,
                                isNoteOff: message.value == 0)))
                }
            }
        }
        return result
    }

    private mutating func decode(_ data: [UInt8]) -> [ControllerKorgNativeEvent] {
        guard data.last == 0xF7, data.dropFirst().dropLast().allSatisfy({ $0 < 128 }) else { return [] }
        if phase == .searching, data.count == 15, data.prefix(4) == [0xF0, 0x42, 0x50, 1],
            data[4] < 16, data[5] == 0x2D, Array(data[6...9]) == [model.rawValue, 1, 0, 0]
        {
            globalChannel = data[4]
            phase = .entering
            return [.request(Self.modeRequest(channel: data[4], model: model, entering: true))]
        }
        guard let globalChannel, data.count == 11,
            Array(data.prefix(9)) == [0xF0, 0x42, 0x40 + globalChannel, 0, 1, model.rawValue, 0, 0x40, 0]
        else { return [] }
        if data[9] == 3, phase == .entering {
            phase = .ready
            return [.modeChanged(true)] + (model == .nanoPad2 ? sceneLights() : [])
        }
        if data[9] == 2, phase == .entering || phase == .ready {
            phase = .closed
            heldPads.removeAll()
            heldLoopPads.removeAll()
            return [.modeChanged(false)]
        }
        return []
    }
    private func sceneLights() -> [ControllerKorgNativeEvent] {
        (0..<4).map { .request([0xBF, 121 + UInt8($0), UInt8($0) == scene ? 127 : 0]) }
    }

    /**
     * Keeps native pad releases on their original scene and blocks unimplemented held-loop variants.
     */
    private mutating func convertPad(_ message: ControllerMIDIMessage) -> [ControllerKorgNativeEvent] {
        if message.kind == .control, message.channel == 15, message.number == 57 {
            guard message.value == 0 || message.value == 127 else { return [] }
            let pressed = message.value > 0
            defer { sceneDown = pressed }
            guard pressed && !sceneDown else { return [] }
            scene = (scene + 1) % 4
            return [.sceneChanged] + sceneLights()
        }
        guard message.kind == .note, message.channel == 1, (64...79).contains(message.number) else { return [] }
        let pad = message.number
        if message.value == 0 {
            heldLoopPads.remove(pad)
            guard let held = heldPads.removeValue(forKey: pad), held.emitted else { return [] }
            return [.message(.init(kind: .note, channel: 0, number: held.number, value: 0, isNoteOff: true))]
        }
        guard heldPads[pad] == nil else { return [] }
        let index = pad - 64
        let resizing = [0, 1, 8, 9].contains(index)
        let emitted =
            scene == 0 || (scene == 1 && index == 14)
            || (scene == 2
                && ((2...7).contains(index) || (10...13).contains(index)
                    || (resizing && heldLoopPads.isEmpty)))
        if scene == 2, (2...7).contains(index) || index >= 14 { heldLoopPads.insert(pad) }
        let number = 36 + scene * 16 + index
        heldPads[pad] = (number, emitted)
        guard emitted else { return [] }
        return [.message(.init(kind: .note, channel: 0, number: number, value: message.value))]
    }

}

public typealias ControllerNanoKontrol2Decoder = ControllerKorgNativeDecoder
public typealias ControllerNanoKontrol2Event = ControllerKorgNativeEvent
