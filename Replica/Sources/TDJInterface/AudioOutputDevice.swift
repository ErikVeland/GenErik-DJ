import Foundation

struct AudioOutputDevice: Equatable, Sendable {
    let name: String
    let wired: Bool

    private var normalizedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    var isS4MK3Direct: Bool { wired && normalizedName == "traktor kontrol s4 mk3" }

    var automaticSplitOutputName: String? {
        guard wired else { return nil }
        switch normalizedName {
        case "traktor kontrol z1": return "Z1"
        case "traktor z1 mk2", "traktor kontrol z1 mk2": return "Z1 Mk2"
        case "generik z1 mk2 bridge": return "Z1 Mk2 Bridge"
        case "generik s2 mk1 bridge": return "S2 Mk1 Bridge"
        case "traktor kontrol s2 mk2": return "S2 Mk2"
        case "traktor kontrol s2 mk3": return "S2 Mk3"
        case "traktor kontrol s3": return "S3"
        case "traktor kontrol s4 mk2": return "S4 Mk2"
        case "generik s4 mk3 bridge": return "S4 Mk3 Bridge"
        default: return nil
        }
    }
}
