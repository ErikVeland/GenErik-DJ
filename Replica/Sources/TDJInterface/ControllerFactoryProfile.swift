import Foundation

enum ControllerFactoryProfile: String, CaseIterable, Codable, Sendable {
    case flx4 = "DDJ-FLX4"
    case flx2 = "DDJ-FLX2"
    case ddj400 = "DDJ-400"
    case flx10 = "DDJ-FLX10"
    case rev1 = "DDJ-REV1"
    case rev5 = "DDJ-REV5"
    case ddj1000 = "DDJ-1000"

    /**
     * Matches exact model names and known manufacturer prefixes without matching other Mk variants.
     */
    static func matching(_ names: [String]) -> Self? {
        let matches = allCases.filter { profile in
            let model = normalise(profile.rawValue)
            let aliases = [model, "pioneer" + model, "pioneerdj" + model, "alphatheta" + model]
            return names.contains { aliases.contains(normalise($0)) }
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func normalise(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    @MainActor func bindings(source: Int32) -> [ControllerBinding] {
        switch self {
        case .flx4: ControllerMIDIConnection.ddjFLX4Bindings(source: source)
        case .flx2: ControllerMIDIConnection.ddjFLX2Bindings(source: source)
        case .ddj400: ControllerMIDIConnection.ddj400Bindings(source: source)
        case .flx10: ControllerMIDIConnection.ddjFLX10Bindings(source: source)
        case .rev1: ControllerMIDIConnection.ddjREV1Bindings(source: source)
        case .rev5: ControllerMIDIConnection.ddjREV5Bindings(source: source)
        case .ddj1000: ControllerMIDIConnection.ddj1000Bindings(source: source)
        }
    }

    @MainActor func feedback(destination: Int32) -> [ControllerFeedbackBinding] {
        switch self {
        case .flx4: ControllerMIDIConnection.ddjFLX4FeedbackBindings(destination: destination)
        case .flx2: ControllerMIDIConnection.ddjFLX2FeedbackBindings(destination: destination)
        case .ddj400: ControllerMIDIConnection.ddjFLX4FeedbackBindings(destination: destination)
        case .flx10: ControllerMIDIConnection.ddjFLX10FeedbackBindings(destination: destination)
        case .rev1: ControllerMIDIConnection.ddjREV1FeedbackBindings(destination: destination)
        case .rev5: ControllerMIDIConnection.ddjREV5FeedbackBindings(destination: destination)
        case .ddj1000: ControllerMIDIConnection.ddj1000FeedbackBindings(destination: destination)
        }
    }
}

struct ControllerFactoryEndpoint: Equatable, Sendable {
    let id: Int32
    let device: UInt32
    let names: [String]
}

struct ControllerFactorySession: Equatable, Sendable {
    let device: UInt32
    let profile: ControllerFactoryProfile
    let source: Int32
    let destination: Int32?

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
                let profile = ControllerFactoryProfile.matching(input.names), !disabled.contains(profile)
            else { return nil }
            let outputs = destinations.filter { $0.device == device }
            let destination = outputs.count == 1 ? outputs.first : nil
            if let destination,
                let outputProfile = ControllerFactoryProfile.matching(destination.names), outputProfile != profile
            {
                return nil
            }
            return .init(device: device, profile: profile, source: input.id, destination: destination?.id)
        }
    }
}
