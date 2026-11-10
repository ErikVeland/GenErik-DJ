import Foundation
import TDJCore

struct TraktorPatternUnit {
    var mode = 0
    var enabled = false
    var decks: Set<DeckID> = []
    var ducking = false
    var kit = 0
    var sound = 0
    var page: Int?
    var pitch = 0.5
    var decay = 0.5
    var level = 0.6
    var steps: UInt16 = 0x1111
    private var preset: Int? = 0

    private static let builtInSteps: [UInt16] = [
        0x1111, 0x5555, 0x1010, 0x4242, 0x2929, 0xa5a5, 0x8088, 0xffff,
    ]

    func labels(kits: [PatternKitArchive.Info]) -> (kit: String, sound: String) {
        if kit >= 2, kits.indices.contains(kit - 2) {
            let info = kits[kit - 2]
            return (info.name, info.sounds[sound])
        }
        return (kit == 0 ? "Classic" : "Modern", ["Kick", "Snare", "Hat", "Percussion"][sound])
    }

    private mutating func select(_ selection: Int, kits: [PatternKitArchive.Info]) {
        preset = selection
        if kit >= 2, kits.indices.contains(kit - 2) {
            steps = kits[kit - 2].presets[sound][selection].reduce(0) {
                $0 | (1 << min(15, Int($1 * 4)))
            }
        } else {
            steps = Self.builtInSteps[selection]
        }
    }

    mutating func button(_ slot: Int, shifted: Bool, kits: [PatternKitArchive.Info] = []) -> Bool {
        if slot == 0 && shifted {
            mode = (mode + 1) % 3
            if mode != 2 { page = nil }
            return true
        }
        guard mode == 2 else { return false }
        switch slot {
        case 0: enabled.toggle()
        case 1, 2:
            let direction = slot == 1 ? -1 : 1
            let previousKit = kit
            if shifted {
                let count = 2 + kits.count
                kit = (kit + count + direction) % count
                if kit >= 2 || sound >= 4 { sound = 0 }
            } else {
                let count = kit < 2 ? 4 : kits[kit - 2].sounds.count
                sound = (sound + count + direction) % count
            }
            if kit >= 2 || previousKit >= 2 { select(0, kits: kits) }
        case 3: ducking.toggle()
        default: break
        }
        return true
    }

    mutating func knob(_ slot: Int, value: Double, kits: [PatternKitArchive.Info] = []) {
        switch slot {
        case 0: level = value
        case 1: select(min(7, Int(value * 8)), kits: kits)
        case 2: pitch = value
        case 3: decay = value
        default: break
        }
    }

    mutating func selectPage(shifted: Bool) {
        guard mode == 2 else { return }
        if shifted {
            steps = 0
            preset = nil
        } else { page = page.map { 1 - $0 } ?? 0 }
    }

    mutating func toggleStep(_ slot: Int) {
        guard let page, (0..<8).contains(slot) else { return }
        steps ^= 1 << (page * 8 + slot)
        preset = nil
    }

    var settings: UInt64 {
        guard mode == 2, enabled, !decks.isEmpty else { return 0 }
        let assign = decks.reduce(UInt64(0)) { $0 | (1 << ($1.transportIndex + 16)) }
        func byte(_ value: Double) -> UInt64 { UInt64((min(1, max(0, value)) * 255).rounded()) }
        let source = kit < 2
            ? UInt64(kit * 4 + sound) << 24
            : UInt64(kit - 1) << 51 | UInt64(sound) << 56 | UInt64(preset.map { $0 + 1 } ?? 0) << 59
        return UInt64(steps) | assign | (1 << 20) | (ducking ? 1 << 21 : 0) | source
            | byte(pitch) << 27 | byte(decay) << 35 | byte(level) << 43
    }
}


struct X1PatternScreen {
    static func payload(side: Int, mode: Bool, kit: String, sound: String, steps: UInt16,
                        cursor: Int?, ducking: Bool) -> [UInt8] {
        guard (0..<2).contains(side) else { return [] }
        guard mode else { return [UInt8(side)] + .init(repeating: 0, count: 63) }
        func label(_ value: String) -> [UInt8] {
            var result: [UInt8] = []
            for scalar in value.unicodeScalars {
                let bytes = String(scalar).utf8
                guard result.count + bytes.count <= 29 else { break }
                result.append(contentsOf: bytes)
            }
            return result + .init(repeating: 0, count: 29 - result.count)
        }
        let step = cursor.flatMap { (0..<16).contains($0) ? UInt8($0) : nil } ?? 0xff
        return [UInt8(side), 1, UInt8(truncatingIfNeeded: steps), UInt8(steps >> 8), step, ducking ? 1 : 0]
            + label(kit) + label(sound)
    }
}


#if os(iOS)
    extension ReplicaModel {
        func startPatternKitLoad() {
            guard patternKitLoad == nil, playbackSnapshot?.anyDeckActive != true else { return }
            let root = store.root
            let core = playback.core
            patternKitLoad = Task { [weak self] in
                do {
                    let kits = try await Task.detached(priority: .utility) {
                        try PatternKitArchive.load(from: root, core: core)
                    }.value
                    self?.patternKits = kits
                } catch {
                    self?.status = error.localizedDescription
                }
            }
        }

        func importPatternKits(_ url: URL) async throws -> Int {
            guard !patternKitImporting else { throw TransportError.cache("Wait for the current kit import.") }
            patternKitImporting = true
            defer { patternKitImporting = false }
            startPatternKitLoad()
            await patternKitLoad?.value
            guard playbackSnapshot?.anyDeckActive != true else {
                throw TransportError.cache("Pause the decks before importing kits.")
            }
            let root = store.root
            let core = playback.core
            patternKits = try await Task.detached(priority: .utility) {
                try PatternKitArchive.load(from: root, importing: url, core: core)
            }.value
            return patternKits.count
        }
    }
#endif
