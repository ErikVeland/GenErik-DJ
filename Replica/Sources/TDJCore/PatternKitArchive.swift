import Foundation

package struct PatternKitArchive: Codable, Sendable {
    struct Sound: Codable, Sendable {
        let name: String
        let pcm: Data
        let presets: [[Double]]
    }

    struct Kit: Codable, Sendable {
        let id: String
        let name: String
        let sounds: [Sound]

        var info: Info {
            .init(name: name, sounds: sounds.map(\.name), presets: sounds.map(\.presets))
        }
    }

    package struct Info: Sendable {
        package let name: String
        package let sounds: [String]
        package let presets: [[[Double]]]
    }

    enum ImportError: LocalizedError {
        case invalid, capacity

        var errorDescription: String? {
            switch self {
            case .invalid: "Choose a Pattern Player kit file from the Traktor exporter."
            case .capacity: "The Pattern Player library can hold 24 kits and 24 MB of sample audio."
            }
        }
    }

    var version = 1
    var kits: [Kit] = []
    private static let archiveLimit = 34 * 1024 * 1024
    private static let pcmLimit = 24 * 1024 * 1024

    private static func read(_ url: URL) throws -> Self {
        let stream = try FileHandle(forReadingFrom: url)
        defer { try? stream.close() }
        let data = try stream.read(upToCount: archiveLimit + 1) ?? Data()
        guard data.count <= archiveLimit else { throw ImportError.capacity }
        guard let archive = try? JSONDecoder().decode(Self.self, from: data) else { throw ImportError.invalid }
        try archive.validate()
        return archive
    }

    private func validateCapacity() throws {
        let size = kits.reduce(0) { count, kit in count + kit.sounds.reduce(0) { $0 + $1.pcm.count } }
        guard kits.count <= 24, size <= Self.pcmLimit else { throw ImportError.capacity }
    }

    private func validate() throws {
        guard version == 1, Set(kits.map(\.id)).count == kits.count else { throw ImportError.invalid }
        try validateCapacity()
        for kit in kits {
            guard (1...80).contains(kit.id.utf8.count),
                kit.id.utf8.allSatisfy({ $0 == 95 || (48...57).contains($0) || (97...122).contains($0) }),
                (1...160).contains(kit.name.utf8.count), kit.sounds.count == 8
            else { throw ImportError.invalid }
            for sound in kit.sounds {
                try Task.checkCancellation()
                guard (1...80).contains(sound.name.utf8.count), sound.pcm.count.isMultiple(of: 4),
                    (4...(44100 * 5 * 4)).contains(sound.pcm.count), sound.presets.count == 8
                else { throw ImportError.invalid }
                let valid = sound.pcm.withUnsafeBytes { bytes in
                    stride(from: 0, to: bytes.count, by: 4).allSatisfy { offset in
                        let bits = bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                        return abs(Float(bitPattern: UInt32(littleEndian: bits))) <= 1.001
                    }
                }
                guard valid else { throw ImportError.invalid }
                for notes in sound.presets {
                    guard (1...16).contains(notes.count), notes.allSatisfy({ (0..<4).contains(Float($0)) }),
                        zip(notes, notes.dropFirst()).allSatisfy({ Float($0.0) < Float($0.1) })
                    else { throw ImportError.invalid }
                }
            }
        }
    }

    package static func load(from directory: URL, importing url: URL? = nil, core: SampleTransport) throws -> [Info] {
        let saved = directory.appendingPathComponent("pattern-kits.json")
        var archive = FileManager.default.fileExists(atPath: saved.path) ? try read(saved) : .init()
        if let url {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let incoming = try read(url)
            guard !incoming.kits.isEmpty else { throw ImportError.invalid }
            var ids = Set(archive.kits.map(\.id))
            let newKits = incoming.kits.filter { ids.insert($0.id).inserted }
            if !newKits.isEmpty {
                archive.kits.append(contentsOf: newKits)
                try archive.validateCapacity()
                try JSONEncoder().encode(archive).write(to: saved, options: .atomic)
            }
        }
        for (slot, kit) in archive.kits.enumerated() {
            try Task.checkCancellation()
            try core.registerPatternKit(kit, slot: UInt32(slot))
        }
        return archive.kits.map(\.info)
    }
}
