import Foundation

struct ControllerFactoryProfile: RawRepresentable, Hashable, CaseIterable, Codable, Sendable {
    let rawValue: String
    static let flx4 = Self(unchecked: "DDJ-FLX4")
    static let flx2 = Self(unchecked: "DDJ-FLX2")
    static let ddj400 = Self(unchecked: "DDJ-400")
    static let flx10 = Self(unchecked: "DDJ-FLX10")
    static let rev1 = Self(unchecked: "DDJ-REV1")
    static let rev5 = Self(unchecked: "DDJ-REV5")
    static let ddj1000 = Self(unchecked: "DDJ-1000")
    private static let existing: [Self] = [.flx4, .flx2, .ddj400, .flx10, .rev1, .rev5, .ddj1000]
    private static let data = Dictionary(
        uniqueKeysWithValues: ControllerProfileCatalogue.shared.profiles.map { ($0.id, $0) })
    static let allCases: [Self] = existing + ControllerProfileCatalogue.shared.profiles.map { Self(unchecked: $0.id) }
    private static let nameIndex: [String: Set<Self>] = {
        var index: [String: Set<Self>] = [:]
        for profile in allCases {
            let names =
                profile.definition?.aliases ?? [
                    profile.rawValue, "Pioneer " + profile.rawValue,
                    "Pioneer DJ " + profile.rawValue, "AlphaTheta " + profile.rawValue,
                ]
            for name in names { index[normalise(name), default: []].insert(profile) }
        }
        return index
    }()

    private init(unchecked value: String) { rawValue = value }
    init?(rawValue: String) {
        guard Self.existing.contains(where: { $0.rawValue == rawValue }) || Self.data[rawValue] != nil else {
            return nil
        }
        self.rawValue = rawValue
    }
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let profile = Self(rawValue: value) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown controller profile."))
        }
        self = profile
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var definition: ControllerProfileData? { Self.data[rawValue] }
    var selectsAutomatically: Bool { definition?.autoSelect ?? true }

    /**
     * Exact names retain model boundaries. Shared aliases remain ambiguous.
     */
    static func matching(_ names: [String], automaticOnly: Bool = false) -> Self? {
        let matches = names.reduce(into: Set<Self>()) { result, name in
            result.formUnion(nameIndex[normalise(name), default: []])
        }
        guard matches.count == 1, let profile = matches.first,
            !automaticOnly || profile.selectsAutomatically
        else { return nil }
        return profile
    }
    private static func normalise(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    @MainActor func bindings(source: Int32) -> [ControllerBinding] {
        switch self {
        case .flx4: return ControllerMIDIConnection.ddjFLX4Bindings(source: source)
        case .flx2: return ControllerMIDIConnection.ddjFLX2Bindings(source: source)
        case .ddj400: return ControllerMIDIConnection.ddj400Bindings(source: source)
        case .flx10: return ControllerMIDIConnection.ddjFLX10Bindings(source: source)
        case .rev1: return ControllerMIDIConnection.ddjREV1Bindings(source: source)
        case .rev5: return ControllerMIDIConnection.ddjREV5Bindings(source: source)
        case .ddj1000: return ControllerMIDIConnection.ddj1000Bindings(source: source)
        default: return definition?.inputs.map { $0.binding(source: source) } ?? []
        }
    }
    @MainActor func feedback(destination: Int32) -> [ControllerFeedbackBinding] {
        switch self {
        case .flx4, .ddj400: return ControllerMIDIConnection.ddjFLX4FeedbackBindings(destination: destination)
        case .flx2: return ControllerMIDIConnection.ddjFLX2FeedbackBindings(destination: destination)
        case .flx10: return ControllerMIDIConnection.ddjFLX10FeedbackBindings(destination: destination)
        case .rev1: return ControllerMIDIConnection.ddjREV1FeedbackBindings(destination: destination)
        case .rev5: return ControllerMIDIConnection.ddjREV5FeedbackBindings(destination: destination)
        case .ddj1000: return ControllerMIDIConnection.ddj1000FeedbackBindings(destination: destination)
        default: return definition?.outputs.map { $0.binding(destination: destination) } ?? []
        }
    }
}

struct ControllerFactoryEndpoint: Equatable, Sendable {
    let id: Int32
    let device: UInt32
    let names: [String]
    var reference: UInt32? = nil
}

struct ControllerFactorySession: Equatable, Sendable {
    let device: UInt32
    let profile: ControllerFactoryProfile
    let source: Int32
    let destination: Int32?
    let sourceReference: UInt32?
    let destinationReference: UInt32?

    /**
     * Pairs one input and output on the same physical device. Ambiguous ports remain unpaired.
     */
    static func discover(
        sources: [ControllerFactoryEndpoint], destinations: [ControllerFactoryEndpoint],
        disabled: Set<ControllerFactoryProfile>
    ) -> [Self] {
        guard Set(sources.map(\.id)).count == sources.count else { return [] }
        let devices = Dictionary(grouping: sources.filter { $0.device != 0 }, by: \.device)
        return devices.keys.sorted().prefix(16).compactMap { device in
            guard let inputs = devices[device], inputs.count == 1, let input = inputs.first,
                let profile = ControllerFactoryProfile.matching(input.names, automaticOnly: true),
                !disabled.contains(profile)
            else { return nil }
            let outputs = destinations.filter { $0.device == device }
            let destination = outputs.count == 1 ? outputs.first : nil
            guard profile.definition?.startup.isEmpty != false || destination != nil else { return nil }
            if let destination,
                let outputProfile = ControllerFactoryProfile.matching(destination.names), outputProfile != profile
            {
                return nil
            }
            return .init(
                device: device, profile: profile, source: input.id, destination: destination?.id,
                sourceReference: input.reference, destinationReference: destination?.reference)
        }
    }
}
