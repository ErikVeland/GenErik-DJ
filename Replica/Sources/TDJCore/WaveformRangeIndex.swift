import Foundation

/// Exact min/max range queries avoid rescanning a whole track when drawing its overview.
public struct WaveformRangeIndex: Sendable {
    public struct Extent: Sendable, Equatable {
        public var minimum: Float = 0
        public var maximum: Float = 0
        /// Loudest RMS in the range. Drawn as the body inside the peak outline.
        public var rms: Float = 0
        public init(minimum: Float = 0, maximum: Float = 0, rms: Float = 0) {
            self.minimum = minimum
            self.maximum = maximum
            self.rms = rms
        }
        mutating func include(_ other: Extent) {
            minimum = min(minimum, other.minimum)
            maximum = max(maximum, other.maximum)
            rms = max(rms, other.rms)
        }
    }
    public let count: Int
    private let nodes: [Extent]
    public var storageBytes: Int { nodes.count * MemoryLayout<Extent>.stride }
    public init(_ bins: [WaveformBin]) {
        count = bins.count
        var tree = [Extent](repeating: Extent(), count: bins.count * 2)
        for (i, bin) in bins.enumerated() {
            tree[bins.count + i] = Extent(
                minimum: min(0, bin.minimum), maximum: max(0, bin.maximum), rms: max(0, bin.rms))
        }
        if bins.count > 1 {
            for i in stride(from: bins.count - 1, through: 1, by: -1) {
                tree[i] = tree[i * 2]
                tree[i].include(tree[i * 2 + 1])
            }
        }
        nodes = tree
    }
    public func extent(from lower: Int, to upper: Int) -> Extent {
        var low = max(0, min(count, lower)) + count
        var high = max(0, min(count, upper)) + count
        var result = Extent()
        while low < high {
            if low % 2 == 1 {
                result.include(nodes[low])
                low += 1
            }
            if high % 2 == 1 {
                high -= 1
                result.include(nodes[high])
            }
            low /= 2
            high /= 2
        }
        return result
    }
}
