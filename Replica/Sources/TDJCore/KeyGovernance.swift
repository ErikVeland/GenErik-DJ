import CryptoKit
import Foundation

public enum KeyAuthority: String, Codable, Sendable { case manual, mixedInKey, traktor, independent, unknownTag }

public enum KeyNotation: String, Codable, Sendable {
    case camelot, openKey, musical

    public func parse(_ raw: String) throws -> MusicalKey {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if self != .musical {
            let suffix = String(text.suffix(1)).lowercased()
            if let number = Int(text.dropLast()), (1...12).contains(number),
                (self == .camelot ? ["a", "b"] : ["m", "d"]).contains(suffix)
            {
                let open = self == .camelot ? (number + 4) % 12 + 1 : number
                let minor = suffix == "a" || suffix == "m"
                let relativeMajor = ((open - 1) * 7) % 12
                return .init(tonic: (relativeMajor + (minor ? 9 : 0)) % 12, mode: minor ? .minor : .major)
            }
        } else {
            let value = text.replacingOccurrences(of: "♯", with: "#").replacingOccurrences(of: "♭", with: "b")
            let names = [
                "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "Fb": 4, "E#": 5, "F": 5, "F#": 6, "Gb": 6,
                "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11, "Cb": 11, "B#": 0,
            ]
            for (suffix, mode) in [(" minor", MusicalKey.Mode.minor), (" major", .major), ("m", .minor), ("", .major)] {
                guard value.hasSuffix(suffix) else { continue }
                let name = String(value.dropLast(suffix.count))
                if let tonic = names[name] { return .init(tonic: tonic, mode: mode) }
            }
        }
        throw CoreError.invalidAudio("The key does not match its declared notation.")
    }
}

public enum KeyImportSource: String, Codable, Sendable {
    case mixedInKey, traktor, unknownTag
    var authority: KeyAuthority {
        switch self {
        case .mixedInKey: .mixedInKey
        case .traktor: .traktor
        case .unknownTag: .unknownTag
        }
    }
}

public enum KeyImportAttribution: String, Codable, Sendable { case userConfirmed, documentedExport, unknown }

/// GenErik interchange format. Attribution records a declaration, not vendor authentication.
public struct KeyImportManifest: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let contentSHA256: String
        public let rawKey: String
        public let notation: KeyNotation
        public init(contentSHA256: String, rawKey: String, notation: KeyNotation) {
            self.contentSHA256 = contentSHA256
            self.rawKey = rawKey
            self.notation = notation
        }
    }
    public var schemaVersion = 1
    public let source: KeyImportSource
    public let attribution: KeyImportAttribution
    public let sourceDescription: String
    public let producerVersion: String?
    public var entries: [Entry]

    public init(
        source: KeyImportSource, attribution: KeyImportAttribution, sourceDescription: String,
        producerVersion: String? = nil, entries: [Entry]
    ) {
        self.source = source
        self.attribution = attribution
        self.sourceDescription = sourceDescription
        self.producerVersion = producerVersion
        self.entries = entries
    }
    func validate() throws {
        guard schemaVersion == 1, !entries.isEmpty, entries.count <= 10000,
            !sourceDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            sourceDescription.utf8.count <= 4096, (producerVersion?.utf8.count ?? 0) <= 256,
            source == .unknownTag || attribution != .unknown, Set(entries.map(\.contentSHA256)).count == entries.count
        else {
            throw CoreError.invalidAudio(
                "The key import has an unsupported schema, missing attribution, or duplicate tracks.")
        }
        for entry in entries {
            guard Self.isDigest(entry.contentSHA256), entry.rawKey.utf8.count <= 64 else {
                throw CoreError.invalidAudio("The key import has an invalid track identity or key.")
            }
            _ = try entry.notation.parse(entry.rawKey)
        }
    }
    static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
    static func digest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }
}

public struct KeyObservation: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let manifestSHA256: String
    public let contentSHA256: String
    public let source: KeyImportSource
    public let attribution: KeyImportAttribution
    public let sourceDescription: String
    public let producerVersion: String?
    public let rawKey: String
    public let notation: KeyNotation
    public let key: MusicalKey

    init(manifest: KeyImportManifest, entry: KeyImportManifest.Entry, digest: String) throws {
        manifestSHA256 = digest
        contentSHA256 = entry.contentSHA256
        source = manifest.source
        attribution = manifest.attribution
        sourceDescription = manifest.sourceDescription
        producerVersion = manifest.producerVersion
        rawKey = entry.rawKey
        notation = entry.notation
        key = try entry.notation.parse(entry.rawKey)
        id = try KeyImportManifest.digest([digest, entry.contentSHA256])
    }
    func validate(trackID: String) throws {
        let manifest = KeyImportManifest(
            source: source, attribution: attribution, sourceDescription: sourceDescription,
            producerVersion: producerVersion,
            entries: [.init(contentSHA256: contentSHA256, rawKey: rawKey, notation: notation)])
        try manifest.validate()
        guard contentSHA256 == trackID, KeyImportManifest.isDigest(manifestSHA256),
            id == (try KeyImportManifest.digest([manifestSHA256, contentSHA256])), key == (try notation.parse(rawKey))
        else { throw CoreError.invalidWorkspace("Key evidence does not match its track or raw value.") }
    }
}

public struct KeyGovernanceEvent: Codable, Equatable, Sendable {
    public let policyVersion: String
    public let action: String
    public let observationID: String?
    public let selectedKey: MusicalKey?
    public let selectedAuthority: KeyAuthority?
    public let recordedAt: Date
    public let reason: String?
    public let analysisKey: MusicalKey?
    public let analysisImplementation: String?
    public let analysisConfigurationID: String?
    public let analysisConfidence: Double?

    init(
        action: String, observationID: String?, decision: KeyDecision, reason: String? = nil,
        analysis: AudioAnalysis? = nil
    ) {
        policyVersion = KeyGovernancePolicy.version
        self.action = action
        self.observationID = observationID
        selectedKey = decision.key
        selectedAuthority = decision.authority
        recordedAt = Date()
        self.reason = reason
        analysisKey = analysis?.key
        analysisImplementation = analysis?.implementation
        analysisConfigurationID = analysis?.configurationID
        analysisConfidence = analysis?.keyConfidence
    }
}

public struct KeyGovernanceState: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public internal(set) var observations: [KeyObservation] = []
    public internal(set) var acceptedMixedInKeyID: String?
    public internal(set) var events: [KeyGovernanceEvent] = []
    public init() {}

    func validate(trackID: String) throws {
        let identities = Set(observations.map(\.id))
        guard schemaVersion == 1, observations.count <= 10000, events.count <= 20000,
            identities.count == observations.count,
            acceptedMixedInKeyID == nil
                || observations.contains(where: { $0.id == acceptedMixedInKeyID && $0.source == .mixedInKey }),
            events.allSatisfy({ event in
                event.recordedAt.timeIntervalSince1970.isFinite
                    && KeyGovernancePolicy.readableHistoryVersions.contains(event.policyVersion)
                    && ["import", "preparationEdit", "review", "analysisBefore", "analysis"].contains(event.action)
                    && (event.reason?.utf8.count ?? 0) <= 4096
                    && (event.analysisConfidence.map { $0.isFinite && (0...1).contains($0) } ?? true)
                    && (event.observationID.map { identities.contains($0) } ?? true)
            })
        else { throw CoreError.invalidWorkspace("The key governance history is invalid or unsupported.") }
        for observation in observations { try observation.validate(trackID: trackID) }
    }
}

public struct KeyDecision: Codable, Equatable, Sendable {
    public let policyVersion: String
    public let key: MusicalKey?
    public let authority: KeyAuthority?
    public let selectedObservationID: String?
    public let conflictingAuthorities: [KeyAuthority]
    public let needsReview: Bool
}

public enum KeyGovernancePolicy {
    public static let version = "key-authority-2"
    fileprivate static let readableHistoryVersions: Set<String> = ["key-authority-1", version]

    public static func decide(_ track: Track) -> KeyDecision {
        let evidence = track.keyGovernance?.observations ?? []
        let mixed =
            evidence.first { $0.id == track.keyGovernance?.acceptedMixedInKeyID && $0.source == .mixedInKey }
            ?? evidence.first { $0.source == .mixedInKey }
        var candidates: [(MusicalKey, KeyAuthority, String?)] = []
        if let key = track.preparation.correctedKey, track.preparation.correctedKeyAuthority != .independent {
            candidates.append((key, track.preparation.correctedKeyAuthority ?? .manual, nil))
        }
        if let mixed { candidates.append((mixed.key, .mixedInKey, mixed.id)) }
        if let key = track.traktorPreparation?.normalized.key { candidates.append((key, .traktor, nil)) }
        for observation in evidence where observation.source == .traktor {
            candidates.append((observation.key, .traktor, observation.id))
        }
        if let key = track.analysis.key { candidates.append((key, .independent, nil)) }
        if let key = track.preparation.correctedKey, track.preparation.correctedKeyAuthority == .independent {
            candidates.append((key, .independent, nil))
        }
        func priority(_ authority: KeyAuthority) -> Int {
            switch authority {
            case .manual: 0
            case .mixedInKey: 1
            case .traktor: 2
            case .independent: 3
            case .unknownTag: 4
            }
        }
        let selected = candidates.enumerated().min {
            let left = priority($0.element.1)
            let right = priority($1.element.1)
            return left == right ? $0.offset < $1.offset : left < right
        }?.element
        var conflicts: [KeyAuthority] = []
        let comparisons = candidates + evidence.map { ($0.key, $0.source.authority, Optional($0.id)) }
        for (key, authority, _) in comparisons where key != selected?.0 {
            if !conflicts.contains(authority) { conflicts.append(authority) }
        }
        return .init(
            policyVersion: version, key: selected?.0, authority: selected?.1, selectedObservationID: selected?.2,
            conflictingAuthorities: conflicts,
            needsReview: selected?.1 != .manual && (!conflicts.isEmpty || (selected == nil && !evidence.isEmpty)
                || (selected?.1 == .independent && track.analysis.keyConfidence < 0.25)))
    }
}

extension Track {
    public var keyDecision: KeyDecision { KeyGovernancePolicy.decide(self) }

    mutating func recordKeyAnalysisChange(from previous: AudioAnalysis) {
        guard
            previous.key != analysis.key || previous.configurationID != analysis.configurationID
                || previous.implementation != analysis.implementation
                || previous.keyConfidence != analysis.keyConfidence
        else { return }
        var before = self
        before.analysis = previous
        var state = keyGovernance ?? .init()
        state.events.append(
            .init(action: "analysisBefore", observationID: nil, decision: before.keyDecision, analysis: previous))
        state.events.append(.init(action: "analysis", observationID: nil, decision: keyDecision, analysis: analysis))
        keyGovernance = state
    }
}

extension Preparation {
    public mutating func copyKey(from source: Preparation) {
        correctedKey = source.correctedKey
        correctedKeyAuthority = source.correctedKeyAuthority
    }

    /// Imported values must retain their authority. Direct corrections clear this marker.
    public mutating func importKey(_ key: MusicalKey?, authority: KeyAuthority) {
        guard authority == .traktor || authority == .independent,
            correctedKey == nil || correctedKeyAuthority == authority
        else { return }
        correctedKey = key
        correctedKeyAuthority = key == nil ? nil : authority
    }
}
