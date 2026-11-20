import Foundation

/// Standard ID3 and iTunes fields keep the tracklist and artwork inside the audio file.
enum RecordingExportTags {
    static func number(_ value: UInt32) -> Data {
        var value = value.bigEndian
        return withUnsafeBytes(of: &value) { Data($0) }
    }
    static func integer(_ data: Data) -> UInt32 {
        data.reduce(0) { ($0 << 8) | UInt32($1) }
    }
    static func atom(_ name: String, _ payload: Data) -> Data {
        number(UInt32(payload.count + 8)) + name.data(using: .isoLatin1)! + payload
    }
    static func id3(_ metadata: RecordingExportMetadata) -> Data {
        func frame(_ name: String, _ payload: Data) -> Data {
            Data(name.utf8) + number(UInt32(payload.count)) + Data([0, 0]) + payload
        }
        func unicode(_ text: String) -> Data { text.data(using: .utf16)! }
        var frames = Data()
        for (key, value) in metadata.fields.sorted(by: { $0.key < $1.key }) {
            let names = ["title": "TIT2", "artist": "TPE1", "album": "TALB", "genre": "TCON", "encoder": "TSSE"]
            if key == "comment" {
                frames += frame("COMM", Data([1]) + Data("eng".utf8) + Data([0xff, 0xfe, 0, 0]) + unicode(value))
            } else if let name = names[key] {
                frames += frame(name, Data([1]) + unicode(value))
            } else {
                frames += frame("TXXX", Data([1]) + unicode(key) + Data([0, 0]) + unicode(value))
            }
        }
        frames += frame("USLT", Data([1]) + Data("eng".utf8) + Data([0xff, 0xfe, 0, 0]) + unicode(metadata.tracklist))
        frames += frame("APIC", Data([0]) + Data("image/png".utf8) + Data([0, 3, 0]) + metadata.artwork)
        let size = frames.count
        let syncSafe = Data([
            UInt8((size >> 21) & 127), UInt8((size >> 14) & 127), UInt8((size >> 7) & 127), UInt8(size & 127),
        ])
        return Data("ID3".utf8) + Data([3, 0, 0]) + syncSafe + frames
    }
    static func iTunes(_ metadata: RecordingExportMetadata) -> Data {
        func value(_ bytes: Data, kind: UInt32 = 1) -> Data {
            atom("data", number(kind) + number(0) + bytes)
        }
        var list = Data()
        let names = [
            "title": "©nam", "artist": "©ART", "album": "©alb", "genre": "©gen", "date": "©day", "encoder": "©too",
            "comment": "©cmt",
        ]
        for (key, text) in metadata.fields.sorted(by: { $0.key < $1.key }) {
            if let name = names[key] {
                list += atom(name, value(Data(text.utf8)))
            } else {
                list += atom(
                    "----",
                    atom("mean", number(0) + Data("com.apple.iTunes".utf8))
                        + atom("name", number(0) + Data(key.utf8)) + value(Data(text.utf8)))
            }
        }
        list += atom("©lyr", value(Data(metadata.tracklist.utf8)))
        list += atom("covr", value(metadata.artwork, kind: 14))
        let handler = atom(
            "hdlr", number(0) + number(0) + Data("mdir".utf8) + Data("appl".utf8) + Data(repeating: 0, count: 9))
        return atom("udta", atom("meta", number(0) + handler + atom("ilst", list)))
    }
    static func attachAIFF(_ url: URL, metadata: RecordingExportMetadata) throws {
        let file = try FileHandle(forUpdating: url)
        defer { try? file.close() }
        let size = try file.seekToEnd()
        var chunk = atom("ID3 ", id3(metadata))
        // AIFF chunk lengths exclude their eight-byte header.
        chunk.replaceSubrange(0..<4, with: Data("ID3 ".utf8))
        chunk.replaceSubrange(4..<8, with: number(UInt32(chunk.count - 8)))
        if chunk.count % 2 != 0 { chunk.append(0) }
        guard size + UInt64(chunk.count) - 8 <= UInt32.max else { throw RecordingExportError.fileTooLarge }
        try file.write(contentsOf: chunk)
        try file.seek(toOffset: 4)
        try file.write(contentsOf: number(UInt32(size + UInt64(chunk.count) - 8)))
    }
    private static func merge(_ existing: Data, _ incoming: Data) throws -> Data {
        func children(_ bytes: Data) throws -> [(String, Data)] {
            var result: [(String, Data)] = []
            var offset = 0
            while offset < bytes.count {
                guard offset + 8 <= bytes.count else { throw RecordingExportError.invalidContainer }
                let size = Int(integer(bytes.subdata(in: offset..<offset + 4)))
                guard size >= 8, size <= bytes.count - offset,
                    let name = String(data: bytes.subdata(in: offset + 4..<offset + 8), encoding: .isoLatin1)
                else { throw RecordingExportError.invalidContainer }
                result.append((name, bytes.subdata(in: offset + 8..<offset + size)))
                offset += size
            }
            return result
        }
        var result = try children(existing)
        for (name, payload) in try children(incoming) {
            if name != "----", let index = result.firstIndex(where: { $0.0 == name }) {
                if ["udta", "meta", "ilst"].contains(name) {
                    let prefix = name == "meta" ? 4 : 0
                    guard result[index].1.count >= prefix, payload.count >= prefix else {
                        throw RecordingExportError.invalidContainer
                    }
                    let combined = try merge(Data(result[index].1.dropFirst(prefix)), Data(payload.dropFirst(prefix)))
                    result[index].1 = Data(result[index].1.prefix(prefix)) + combined
                } else if name != "hdlr" {
                    result[index].1 = payload
                }
            } else {
                result.append((name, payload))
            }
        }
        return result.reduce(into: Data()) { $0 += atom($1.0, $1.1) }
    }
    static func attachM4A(_ url: URL, metadata: RecordingExportMetadata) throws {
        let file = try FileHandle(forUpdating: url)
        defer { try? file.close() }
        let end = try file.seekToEnd()
        var offset: UInt64 = 0
        while offset + 8 <= end {
            try file.seek(toOffset: offset)
            let header = try file.read(upToCount: 8) ?? Data()
            guard header.count == 8 else { break }
            var size = UInt64(integer(header.prefix(4)))
            var headerSize: UInt64 = 8
            if size == 1 {
                let wide = try file.read(upToCount: 8) ?? Data()
                guard wide.count == 8 else { throw RecordingExportError.invalidContainer }
                size = wide.reduce(0) { ($0 << 8) | UInt64($1) }
                headerSize = 16
            } else if size == 0 {
                size = end - offset
            }
            guard size >= headerSize, size <= end - offset else { throw RecordingExportError.invalidContainer }
            if String(data: header.suffix(4), encoding: .ascii) == "moov" {
                guard size < 64 * 1024 * 1024 else { throw RecordingExportError.invalidContainer }
                let movie = try file.read(upToCount: Int(size - headerSize)) ?? Data()
                guard movie.count == Int(size - headerSize) else { throw RecordingExportError.invalidContainer }
                // Leave audio offsets unchanged. Replace the old movie atom with free space.
                try file.seekToEnd()
                try file.write(contentsOf: atom("moov", try merge(movie, iTunes(metadata))))
                try file.seek(toOffset: offset + 4)
                try file.write(contentsOf: Data("free".utf8))
                return
            }
            offset += size
        }
        throw RecordingExportError.invalidContainer
    }
}
