import Foundation

struct AudioOutputDevice: Equatable, Sendable {
    let name: String
    let wired: Bool

    var automaticSplitOutputName: String? {
        guard wired else { return nil }
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "traktor kontrol z1": return "Z1"
        case "traktor kontrol s2 mk2": return "S2 Mk2"
        case "traktor kontrol s2 mk3": return "S2 Mk3"
        case "traktor kontrol s3": return "S3"
        case "traktor kontrol s4 mk2": return "S4 Mk2"
        case "generik s4 mk3 bridge": return "S4 Mk3 Bridge"
        default: return nil
        }
    }
}
