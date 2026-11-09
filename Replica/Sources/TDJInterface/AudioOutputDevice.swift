import Foundation

struct AudioOutputDevice: Equatable, Sendable {
    let name: String
    let wired: Bool

    var isOriginalZ1: Bool {
        wired
            && name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare("Traktor Kontrol Z1") == .orderedSame
    }
}
