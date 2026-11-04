import CTDJTransport

extension BeatGridMap {
    var native: tdj_beatgrid_map {
        var value = tdj_beatgrid_map()
        value.count = UInt32(clamping: anchors.count)
        value.sample_rate = sampleRate
        value.downbeat = Int32(clamping: downbeatOffset)
        withUnsafeMutableBytes(of: &value.beats) { bytes in
            let buffer = bytes.bindMemory(to: Double.self)
            for (i, a) in anchors.prefix(Self.maximumAnchorCount).enumerated() { buffer[i] = a.beat }
        }
        withUnsafeMutableBytes(of: &value.frames) { bytes in
            let buffer = bytes.bindMemory(to: Double.self)
            for (i, a) in anchors.prefix(Self.maximumAnchorCount).enumerated() { buffer[i] = a.frame }
        }
        return value
    }
    init?(native: tdj_beatgrid_map) {
        guard native.count >= 2, native.count <= Self.maximumAnchorCount else { return nil }
        var value = native
        let beats = withUnsafeBytes(of: &value.beats) { Array($0.bindMemory(to: Double.self).prefix(Int(value.count))) }
        let frames = withUnsafeBytes(of: &value.frames) {
            Array($0.bindMemory(to: Double.self).prefix(Int(value.count)))
        }
        self.init(
            anchors: zip(beats, frames).map { .init(beat: $0, frame: $1) }, sampleRate: value.sample_rate,
            downbeatOffset: Int(value.downbeat))
    }
}
