import Foundation


struct TraktorFactoryFragments {
    private static let chunk = 100
    private static let maximum = 128
    private var pending: [UInt8] = []
    private var expected = 0

    static func payloads(_ report: [UInt8]) -> [[UInt8]] {
        guard let id = report.first, report.count <= maximum else { return [] }
        return stride(from: 0, to: report.count, by: chunk).map { offset in
            let count = min(chunk, report.count - offset)
            return [id, UInt8(report.count), UInt8(offset)] + Array(report[offset..<(offset + count)])
                + [UInt8](repeating: 0, count: chunk - count)
        }
    }

    mutating func append(_ payload: [UInt8]) -> [UInt8]? {
        guard payload.count == Self.chunk + 3 else {
            pending.removeAll(keepingCapacity: true)
            return nil
        }
        let id = payload[0]
        let size = Int(payload[1])
        let offset = Int(payload[2])
        if offset == 0 {
            pending.removeAll(keepingCapacity: true)
            expected = size
        }
        guard size <= Self.maximum, size == expected, offset < size, offset == pending.count,
            (offset == 0 ? payload[3] : pending.first) == id
        else {
            pending.removeAll(keepingCapacity: true)
            return nil
        }
        pending += payload[3..<(3 + min(Self.chunk, size - offset))]
        guard pending.count == size else { return nil }
        defer { pending.removeAll(keepingCapacity: true) }
        return pending
    }
}

struct TraktorFactoryScreen {
    let side: UInt8
    let deck: UInt8
    let flags: UInt8
    let position: Double
    let duration: Double
    let bpm: Double
    let title: String

    var payload: [UInt8] {
        func word(_ number: Double) -> [UInt8] {
            let value = number.isFinite ? UInt16(min(Double(UInt16.max), max(0, number))) : 0
            return [UInt8(truncatingIfNeeded: value), UInt8(value >> 8)]
        }
        var text = Array(title.utf8.prefix(54))
        while String(bytes: text, encoding: .utf8) == nil { text.removeLast() }
        return [side, deck, flags] + word(position) + word(duration) + word(bpm * 10)
            + [UInt8(text.count)] + text + [UInt8](repeating: 0, count: 54 - text.count)
    }
}
