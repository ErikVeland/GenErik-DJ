import Foundation

public enum StemPCM {
    public static func prepare(url: URL, canContinue: @Sendable () -> Bool) async throws -> PCMAsset {
        let tracks = try await DecodedAudioSource.stemTracks(url: url)
        let master = tracks[0]
        guard master.frames > 0, master.frames <= 480 * 1024 * 1024 / (5 * 8),
            tracks.allSatisfy({ $0.rate == master.rate && abs($0.frames - master.frames) <= 4096 })
        else { throw TransportError.playbackCapacity }
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: directory) }
        var assets: [PCMAsset] = []
        for (index, track) in tracks.enumerated() {
            try Task.checkCancellation()
            guard canContinue() else { throw TransportError.activePerformance }
            let file = directory.appendingPathComponent("\(index).pcm")
            guard manager.createFile(atPath: file.path, contents: nil) else { throw TransportError.allocation }
            let output = try FileHandle(forWritingTo: file)
            defer { try? output.close() }
            var frame: Int64 = 0
            var buffer = [Float](repeating: 0, count: 16384)
            while frame < master.frames {
                try Task.checkCancellation()
                guard canContinue() else { throw TransportError.activePerformance }
                let count = Int(min(8192, master.frames - frame))
                let available = max(0, min(count, Int(track.frames - frame)))
                if available > 0 {
                    try buffer.withUnsafeMutableBufferPointer {
                        try track.read(first: frame, count: available, into: $0.baseAddress!)
                    }
                }
                if available < count {
                    buffer.withUnsafeMutableBufferPointer {
                        $0.baseAddress!.advanced(by: 2 * available).update(repeating: 0, count: 2 * (count - available))
                    }
                }
                try buffer.withUnsafeBytes {
                    try output.write(contentsOf: Data($0.prefix(count * 8)))
                }
                frame += Int64(count)
            }
            guard canContinue() else { throw TransportError.activePerformance }
            assets.append(try PCMAsset(mappedFile: file, frames: UInt64(master.frames), sampleRate: master.rate))
        }
        return try PCMAsset(master: assets[0], stems: Array(assets.dropFirst()))
    }
}
