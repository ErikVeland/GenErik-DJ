import Foundation

@main struct ControllerBridgeCheck {
    static func main() throws {
        let frame = try ControllerBridgeFrame(kind: .z1Status, payload: [1])
        precondition(frame.encoded == [0xf0, 0x7d, 0x47, 0x44, 0x4a, 1, 4, 1, 0, 1, 6, 0xf7], "Bridge framing must match the independently specified wire format.")
        let raw = (0..<30).map { UInt8(($0 * 37) % 256) }
        let input = try ControllerBridgeFrame(kind: .z1Input, payload: raw)
        precondition(input.encoded.dropFirst().dropLast().allSatisfy { $0 < 128 })
        var decoder = ControllerBridgeDecoder()
        precondition(decoder.append(Array(input.encoded.prefix(10))).isEmpty)
        precondition(decoder.append([0xf8] + Array(input.encoded.dropFirst(10))) == [input])
        var damaged = input.encoded
        damaged[9] ^= 1
        precondition(decoder.append(damaged).isEmpty, "A damaged report must not operate the deck.")
        precondition(decoder.append([0xf0] + Array(repeating: 1, count: 2048) + [0xf7]).isEmpty)
        precondition(decoder.append(frame.encoded) == [frame], "The parser must recover after an oversized frame.")
        precondition(decoder.append([0xf0, 0x00, 0x20, 0x7f, 1, 2, 0xf7]).isEmpty)
        do { _ = try ControllerBridgeFrame(kind: .z1Input, payload: [1]); preconditionFailure("Wrong report length accepted.") }
        catch ControllerBridgeFrame.FrameError.invalid {}
        print("Controller bridge framing checks passed.")
    }
}
