import Foundation
import TDJCore

struct ControllerProfileData: Decodable, Sendable {
    enum InputProtocol: String, Codable, Sendable {
        case smk25II, cdj101, ddjSR2, keyLabMKI, kontrolOne, midiFighterSpectra, p1Nano, sc5000M, denonPrimePlayer,
            denonPrime4, nanoKontrol2Native, nanoPad2Native, nanoKontrolScene, xdjAN, launchControlDAW,
            launchControlTemplate, launchControlXLTemplate, mc1000, legacyUSBPlayer, legacySinglePlayer, orbit,
            mpd218Chroma, mpd2Bitwig, apc64
        var setupInputMode: ControllerSetupInputDecoder.Mode? {
            self == .launchControlXLTemplate
                ? .launchControlXLTemplate
                : self == .launchControlTemplate
                    ? .launchControlTemplate
                    : self == .launchControlDAW
                        ? .launchControlDAW : self == .apc64 ? .apc64 : self == .xdjAN ? .xdjAN : korgInputMode.map { .korg($0) }
        }
        var preservesRawMappings: Bool {
            self == .nanoKontrolScene || self == .xdjAN || self == .launchControlTemplate
                || self == .launchControlXLTemplate
        }
        var korgNativeModel: ControllerKorgNativeDecoder.Model? {
            switch self {
            case .nanoKontrol2Native: .nanoKontrol2
            case .nanoPad2Native: .nanoPad2
            default: nil
            }
        }
        var korgInputMode: ControllerKorgInputDecoder.Mode? {
            self == .nanoKontrolScene ? .originalNanoKontrol : korgNativeModel.map { .native($0) }
        }
    }
    enum AudioOutput: String, Decodable, Sendable {
        case masterAndHeadphones
    }

    struct Input: Sendable {
        let action: ControllerAction
        let kind: ControllerMIDIMessage.Kind
        let channel: UInt8
        let number: UInt8
        let encoding: ControllerMIDIEncoding
        let inverted: Bool
        let targetDeck: DeckID?
        let anyChannel: Bool?
        let argument: Double?
        let releaseOnly: Bool?
        let requiredMode: UInt8?
        let shifted: Bool?
        let shiftInput: UInt8?
        let holdInput: UInt8?
        let shiftChannel: UInt8?
        let lowNumber: UInt8?
        let pulse: Bool?
        let requiresTouch: Bool?
        let directionStep: Double?
        let deckBank: UInt8?

        func binding(source: Int32) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number,
                parameter: nil, noteNumber: nil, action: action, encoding: encoding,
                inverted: inverted, shifted: shifted ?? false, targetDeck: targetDeck, layerIndependent: shifted == nil,
                anyChannel: anyChannel, argument: argument, releaseOnly: releaseOnly, requiredMode: requiredMode,
                shiftChannel: shiftChannel, shiftInput: shiftInput, holdInput: holdInput, lowNumber: lowNumber,
                pulse: pulse,
                requiresTouch: requiresTouch, directionStep: directionStep, deckBank: deckBank)
        }
    }

    struct InputMode: Decodable, Sendable {
        struct Selector: Decodable, Hashable, Sendable {
            let channel: UInt8
            let number: UInt8
        }

        let channel: UInt8
        let initial: UInt8?
        let numbers: [UInt8]
        let onValue: UInt8?
        let offValue: UInt8?
        let invalidatingSelectors: [Selector]?

        var isValid: Bool {
            channel < 16 && !numbers.isEmpty && numbers.count <= 16
                && numbers.allSatisfy { $0 < 128 } && Set(numbers).count == numbers.count
                && (initial.map { numbers.contains($0) } ?? true)
                && (invalidatingSelectors.map {
                    $0.count <= 16 && $0.allSatisfy { $0.channel < 16 && $0.number < 128 }
                        && Set($0).count == $0.count
                } ?? true)
                && ((onValue == nil && offValue == nil)
                    || (onValue.map { $0 < 128 } == true && offValue.map { $0 < 128 } == true))
        }
    }

    struct BankChange: Decodable, Sendable {
        let kind: ControllerMIDIMessage.Kind?
        let channel: UInt8
        let anyChannel: Bool?
        let number: UInt8
        let onValue: UInt8?
        let anyPositive: Bool?
        let decks: [DeckID]
        let releaseShiftChannels: [UInt8]?
        let deckBank: UInt8?
        let releaseNumber: UInt8?

        var isValid: Bool {
            (kind == nil || kind == .note || kind == .control)
                && channel < 16 && number < 128
                && (anyPositive == true
                    ? (kind == nil || kind == .note) && onValue == nil
                    : (onValue.map { $0 < 128 && (kind == .control || $0 > 0) } ?? (kind == .control)))
                && (kind != .control || releaseShiftChannels == nil)
                && !decks.isEmpty && decks.count <= 4 && Set(decks).count == decks.count
                && (releaseNumber.map { deckBank != nil && $0 < 128 && $0 != number } ?? true)
                && (releaseShiftChannels.map {
                    $0.count <= 16 && $0.allSatisfy { $0 < 16 } && Set($0).count == $0.count
                } ?? true)
                && (deckBank.map { bank in
                    bank < 2 && (kind == nil || kind == .note) && onValue == 127
                        && releaseShiftChannels == nil && decks == (bank == 0 ? [.a, .c] : [.b, .d])
                } ?? true)
        }
    }

    struct Output: Decodable, Sendable {
        let action: ControllerAction
        let kind: ControllerFeedbackKind
        let channel: UInt8
        let number: UInt8
        let onValue: UInt8
        let offValue: UInt8
        let offUsesNoteOn: Bool
        let offNumber: UInt8?
        let targetDeck: DeckID?

        func binding(destination: Int32) -> ControllerFeedbackBinding {
            .init(
                destination: destination, action: action, kind: kind, channel: channel, number: number,
                offValue: offValue, onValue: onValue, offUsesNoteOn: offUsesNoteOn, targetDeck: targetDeck,
                offNumber: offNumber)
        }
    }

    let id: String
    let aliases: [String]
    let excludedAliases: [String]?
    let inputs: [Input]
    let outputs: [Output]
    let startup: [[UInt8]]
    let startupDelaysMilliseconds: [UInt16]?
    let shutdown: [[UInt8]]
    let startupAbort: [[UInt8]]?
    let unbankedGlobalInputs: Bool?
    let autoSelect: Bool
    let scope: String
    let source: String
    let role: String?
    let inputModes: [InputMode]?
    let bankChanges: [BankChange]?
    let audioOutput: AudioOutput?
    let portAliases: [String]?
    let inputProtocol: InputProtocol?

    var isValid: Bool {
        let pairedGlobals = hasPairedUnbankedGlobals
        let manualMixer = hasManualUnbankedMixer
        let manualTwoDeckCore = hasManualUnbankedTwoDeckCore
        return (unbankedGlobalInputs != true || pairedGlobals)
            && (role == nil || role == "player" || role == "accessory") && !id.isEmpty && id.count <= 128
            && !aliases.isEmpty
            && aliases.count <= 24
            && aliases.allSatisfy { !$0.isEmpty && $0.count <= 128 }
            && (portAliases.map { !$0.isEmpty && $0.count <= 16 && $0.allSatisfy { !$0.isEmpty && $0.count <= 128 } }
                ?? true)
            && (excludedAliases?.count ?? 0) <= 24
            && (excludedAliases ?? []).allSatisfy { !$0.isEmpty && $0.count <= 128 }
            && validInputModes && validBankChanges && validDeckBanks && validStartupTiming
            && (audioOutput == nil || autoSelect)
            && inputs.allSatisfy { input in
                guard let channel = input.shiftChannel else { return true }
                return channel < 16 && inputs.contains { $0.action == .shift && $0.shiftChannel == channel }
            }
            && inputs.allSatisfy { input in
                guard input.requiresTouch == true else { return true }
                let touch: ControllerAction = input.action.deck == .a ? .jogTouchA : .jogTouchB
                return inputs.contains { $0.action == touch && $0.targetDeck == input.targetDeck }
            }
            && !inputs.isEmpty && inputs.count <= 512 && outputs.count <= 128
            && inputs.allSatisfy {
                $0.channel < 16 && $0.number < 128
                    && ($0.encoding.isPairedCC
                        ? $0.kind == .control && ($0.lowNumber.map { $0 < 128 } ?? ($0.number < 32))
                            && $0.lowNumber != $0.number
                        : $0.lowNumber == nil)
                    && ($0.anyChannel != true || role == "player" || pairedGlobals || manualMixer || manualTwoDeckCore)
                    && ($0.requiresTouch != true || ($0.action.isJog && $0.encoding.isRelative))
                    && ($0.encoding != .unsignedCount || ($0.kind == .control && $0.action.isJog && $0.requiresTouch == true))
                    && (!$0.encoding.isContactGate
                        || ($0.kind == .note && [.jogTouchA, .jogTouchB].contains($0.action)))
                    && ($0.encoding != .lc6000Jog || $0.action.isJog)
                    && ($0.encoding != .ndx500Jog || ($0.kind == .control && $0.action.isJog))
                    && ($0.encoding != .ndx500Browse || ($0.kind == .control && $0.action == .browse))
                    && ($0.encoding != .g2vBrowse || ($0.kind == .control && $0.action == .browse))
                    && ($0.encoding != .smcMixerEncoder
                        || ($0.kind == .control && [.gainA, .gainB, .master, .monitor, .cueMix].contains($0.action)))
                    && ($0.encoding != .iconVelocity
                        || ($0.kind == .control && [.gainA, .gainB, .filterKnobA, .filterKnobB].contains($0.action)))
                    && ($0.encoding != .p1NanoEncoder
                        || (inputProtocol == .p1Nano && $0.kind == .control && (16...20).contains($0.number)
                            && [.gainA, .gainB, .highA, .highB, .midA, .midB, .lowA, .lowB, .filterKnobA, .filterKnobB]
                                .contains($0.action)))
                    && ($0.encoding != .noteStep || ($0.kind == .note && $0.action.isJog))
                    && ($0.encoding != .rot64Fast || ($0.kind == .control && [.master, .monitor].contains($0.action)))
                    && ($0.encoding != .readyTempo || [.tempoA, .tempoB].contains($0.action))
                    && ($0.encoding != .airTempo || [.tempoA, .tempoB].contains($0.action))
                    && (![.compactTempo, .fineTempo512].contains($0.encoding)
                        || ($0.kind == .control && [.tempoA, .tempoB].contains($0.action)))
                    && ($0.releaseOnly != true
                        || (($0.kind == .note || ($0.kind == .control && $0.encoding == .absolute))
                            && $0.action.isButton && $0.action != .shift))
                    && ($0.pulse != true
                        || ($0.kind == .note && $0.encoding == .absolute && $0.action.isButton
                            && !$0.action.isMomentary && $0.action != .shift && $0.releaseOnly != true))
                    && ($0.shiftInput == nil
                        || ($0.shiftInput! < 16 && $0.action == .shift
                            && ($0.kind == .note || ($0.kind == .control && $0.shiftChannel == nil))))
                    && ($0.holdInput == nil || ($0.holdInput! < 128 && $0.action.isMomentary))
                    && ($0.encoding != .centredPitch || ($0.kind == .pitch && $0.number == 0))
                    && (![.mixstreamJog, .cyclic14BitJog, .vci100MK2Tempo, .lc6000Jog, .readyTempo, .airTempo].contains(
                        $0.encoding)
                        || $0.lowNumber != nil)
                    && validDirectionStep($0)
                    && Self.validArgument($0)
                    && (![
                        .centreDetent, .binaryStep, .binaryDirection, .signedStep, .dj2go2Jog, .mc7000Jog, .denonJog,
                        .zeroForward,
                        .numarkPlatinumJog,
                        .cdjPlatterSpeed, .cdjRingSpeed,
                        .cdj350PlatterSpeed, .cdjTempo, .needlePosition,
                    ].contains($0.encoding)
                        || $0.kind == .control)
            }
            && outputs.allSatisfy {
                $0.binding(destination: 0).isValid
            }
            && validStartupAbort
            && (startup + shutdown + (startupAbort ?? [])).count <= 64
            && (startup + shutdown + (startupAbort ?? [])).allSatisfy(Self.validSetupMessage)
    }

    /**
     * Limits normalised direction steps to reviewed encoder actions and protocol addresses.
     */
    private func validDirectionStep(_ input: Input) -> Bool {
        guard let step = input.directionStep else { return true }
        return step.isFinite && step > 0 && step <= 0.1 && input.kind == .control
            && input.encoding == .twosComplement
            && ([.tempoA, .tempoB, .cueMix].contains(input.action)
                || (inputProtocol == .kontrolOne && (52...55).contains(input.number)
                    && [.gainA, .gainB, .highA, .highB, .midA, .midB, .lowA, .lowB].contains(input.action)))
    }

    private var validBankChanges: Bool {
        let changes = bankChanges ?? []
        return changes.count <= 32
            && (role != "player" || changes.allSatisfy { $0.decks == [.a] && $0.deckBank == nil })
            && changes.allSatisfy {
                $0.isValid && ($0.anyChannel != true || (role == "player" && $0.channel == 0 && ($0.kind ?? .note) == .note))
            }
            && changes.allSatisfy { change in
                (change.releaseShiftChannels ?? []).allSatisfy { channel in
                    inputs.contains { $0.action == .shift && $0.shiftChannel == channel }
                }
            }
            && changes.enumerated().allSatisfy { index, change in
                changes.prefix(index).allSatisfy { previous in
                    let sameAddress = (change.kind ?? .note) == (previous.kind ?? .note)
                        && (change.channel == previous.channel || change.anyChannel == true || previous.anyChannel == true)
                        && change.number == previous.number
                    let aliasCollision = (change.kind ?? .note) == .note && (previous.kind ?? .note) == .note
                        && (change.channel == previous.channel || change.anyChannel == true || previous.anyChannel == true)
                        && (change.releaseNumber == previous.number || previous.releaseNumber == change.number
                            || (change.releaseNumber != nil && change.releaseNumber == previous.releaseNumber))
                    return !aliasCollision && (!sameAddress || (change.kind == .control && change.onValue != nil
                        && previous.onValue != nil && change.onValue != previous.onValue)
                    )
                }
            }
    }

    /**
     * Limits automatic bank routing to paired load-only profiles with static feedback.
     */
    private var validDeckBanks: Bool {
        let selectors = (bankChanges ?? []).filter { $0.deckBank != nil }
        guard !selectors.isEmpty || inputs.contains(where: { $0.deckBank != nil }) else { return true }
        return ((!autoSelect && outputs.isEmpty) || hasAutomaticLoadBanks) && inputProtocol == nil && role == nil
            && (!autoSelect || selectors.allSatisfy { $0.releaseNumber == nil })
            && Set(selectors.compactMap(\.deckBank)).count == selectors.count
            && selectors.allSatisfy { selector in inputs.contains { $0.deckBank == selector.deckBank } }
            && inputs.allSatisfy { input in
                guard let bank = input.deckBank else { return true }
                return bank < 2 && input.targetDeck == (bank == 0 ? .a : .b)
                    && input.action.rawValue.hasSuffix(bank == 0 ? "A" : "B")
                    && input.anyChannel != true
                    && selectors.contains { $0.deckBank == bank }
            }
            && selectors.allSatisfy { selector in
                !inputs.contains {
                    $0.kind == .note && $0.channel == selector.channel
                        && ($0.number == selector.number || $0.number == selector.releaseNumber)
                }
            }
    }

    private var validInputModes: Bool {
        let modes = inputModes ?? []
        let selectors = Set(modes.flatMap { mode in
            mode.numbers.map { InputMode.Selector(channel: mode.channel, number: $0) }
        })
        let invalidators = modes.flatMap { $0.invalidatingSelectors ?? [] }
        return modes.count <= 16 && modes.allSatisfy { $0.isValid }
            && Set(modes.map(\.channel)).count == modes.count
            && Set(invalidators).count == invalidators.count && selectors.isDisjoint(with: invalidators)
            && inputs.allSatisfy { input in
                guard let required = input.requiredMode else { return true }
                return input.kind == .note && input.action.isButton && !input.action.isMomentary
                    && input.anyChannel != true
                    && modes.contains { $0.channel == input.channel && $0.numbers.contains(required) }
            }
    }

    private var hasAutomaticLoadBanks: Bool {
        autoSelect && inputs.contains { $0.deckBank != nil }
            && inputs.allSatisfy { $0.deckBank == nil || $0.action == .loadA || $0.action == .loadB }
            && !startup.isEmpty && !shutdown.isEmpty
            && outputs.allSatisfy { $0.action != .loadA && $0.action != .loadB }
    }

    /**
     * Accepts manufacturer Bn controls and two PFL notes in a manual mixer contract.
     */
    private var hasManualUnbankedMixer: Bool {
        let actions: Set<ControllerAction> = [
            .gainA, .gainB, .highA, .highB, .midA, .midB, .lowA, .lowB, .levelA, .levelB,
            .crossfader, .master, .monitor, .cueMix,
        ]
        let buttons = inputs.filter { $0.kind == .note }
        return !autoSelect && role == "accessory" && !inputs.isEmpty && inputs.count <= 32
            && inputs.contains { $0.kind == .control } && buttons.count <= 2
            && Set(buttons.map(\.action)).count == buttons.count
            && outputs.isEmpty && startup.isEmpty && shutdown.isEmpty && startupAbort == nil
            && startupDelaysMilliseconds == nil && audioOutput == nil && inputProtocol == nil
            && inputModes == nil && bankChanges == nil
            && Set(inputs.map(\.number)).count == inputs.count
            && inputs.allSatisfy {
                let matchesKind = ($0.kind == .control && actions.contains($0.action))
                    || ($0.kind == .note && (($0.action == .cueA && $0.targetDeck == .a)
                        || ($0.action == .cueB && $0.targetDeck == .b)))
                return $0.anyChannel == true && $0.channel == 0 && matchesKind && $0.encoding == .absolute
                    && !$0.inverted && $0.shifted == nil
                    && $0.requiredMode == nil && $0.shiftChannel == nil && $0.shiftInput == nil && $0.holdInput == nil
                    && $0.releaseOnly == nil && $0.lowNumber == nil && $0.pulse == nil && $0.requiresTouch == nil
                    && $0.directionStep == nil && $0.argument == nil && $0.deckBank == nil
            }
    }

    /**
     * Accepts a manual two-deck core only when every wire and action is unique.
     */
    private var hasManualUnbankedTwoDeckCore: Bool {
        guard !autoSelect, role == nil, (7...33).contains(inputs.count),
            outputs.isEmpty, startup.isEmpty, shutdown.isEmpty, startupAbort == nil,
            startupDelaysMilliseconds == nil, audioOutput == nil, inputProtocol == nil,
            inputModes == nil, bankChanges == nil, portAliases == nil, unbankedGlobalInputs == nil,
            inputs.allSatisfy({ $0.anyChannel == true && $0.channel == 0 }),
            Set(inputs.map(\.number)).count == inputs.count,
            Set(inputs.map(\.action)).count == inputs.count
        else { return false }
        let buttons: Set<ControllerAction> = [
            .playA, .playB, .cuePreviewA, .cuePreviewB, .syncA, .syncB, .keylockA, .keylockB,
            .loadA, .loadB, .cueA, .cueB, .pitchBendDownA, .pitchBendDownB, .pitchBendUpA, .pitchBendUpB,
            .loopUpA, .loopUpB, .loopDownA, .loopDownB,
            .cueStopA, .cueStopB, .reloopA, .reloopB,
        ]
        let controls: Set<ControllerAction> = [
            .gainA, .gainB, .highA, .highB, .midA, .midB, .lowA, .lowB, .levelA, .levelB,
            .crossfader, .cueMix, .monitor,
        ]
        let required: Set<ControllerAction> = [
            .playA, .playB, .cuePreviewA, .cuePreviewB, .levelA, .levelB,
        ]
        return required.isSubset(of: Set(inputs.map(\.action))) && inputs.allSatisfy {
            let matchesKind = ($0.kind == .note && buttons.contains($0.action))
                || ($0.kind == .control && controls.contains($0.action))
            let isGlobal = [.crossfader, .cueMix, .monitor].contains($0.action)
            let matchesDeck = isGlobal ? $0.targetDeck == nil : $0.targetDeck == $0.action.deck
            return matchesKind && matchesDeck && $0.encoding == .absolute
                && (!$0.inverted || $0.action == .crossfader) && $0.shifted == nil
                && $0.requiredMode == nil && $0.shiftChannel == nil && $0.shiftInput == nil && $0.holdInput == nil
                && $0.releaseOnly == nil && $0.lowNumber == nil && $0.pulse == nil && $0.requiresTouch == nil
                && $0.directionStep == nil && $0.argument == nil && $0.deckBank == nil
        }
    }

    /**
     * Allows reviewed global channels only after paired setup and complete Shift cleanup.
     */
    private var hasPairedUnbankedGlobals: Bool {
        guard unbankedGlobalInputs == true, autoSelect, role == "accessory", inputProtocol == nil,
            !startup.isEmpty, !shutdown.isEmpty, startupAbort?.isEmpty == false, inputs.count <= 512,
            let changes = bankChanges, changes.count == 16
        else { return false }
        let globals = inputs.filter { $0.anyChannel == true }
        let shifts = inputs.filter { $0.action == .shift }
        guard !globals.isEmpty, shifts.count == 1, let shift = shifts.first,
            shift.anyChannel == true, shift.kind == .note, shift.encoding == .absolute
        else { return false }
        return globals.allSatisfy {
            $0.channel == 0 && ($0.kind == .note || $0.kind == .control)
                && $0.deckBank == nil && $0.shiftChannel == nil
        }
            && Set(changes.map(\.channel)) == Set(UInt8(0)..<16)
            && changes.allSatisfy {
                ($0.kind == nil || $0.kind == .note) && $0.number == shift.number && $0.onValue == 127
                    && Set($0.decks) == Set(DeckID.allCases)
                    && $0.releaseShiftChannels == nil && $0.deckBank == nil
            }
    }

    private var validStartupAbort: Bool {
        guard let startupAbort else { return true }
        return autoSelect && (inputProtocol == nil || ((inputProtocol == .launchControlDAW || inputProtocol == .apc64) && role == "accessory"))
            && !startup.isEmpty && !shutdown.isEmpty
            && !startupAbort.isEmpty && startupAbort.count <= 4
    }

    var requiresPairedSetup: Bool {
        hasDelayedStartup || inputProtocol?.setupInputMode != nil || hasAutomaticLoadBanks || startupAbort != nil
    }

    var hasDelayedStartup: Bool { startupDelaysMilliseconds?.contains { $0 > 0 } == true }

    var startupSteps: [ControllerMIDISetupStep] {
        zip(startup, startupDelaysMilliseconds ?? []).map {
            .init(message: $0.0, delayMilliseconds: $0.1)
        }
    }

    private var validStartupTiming: Bool {
        guard let delays = startupDelaysMilliseconds else { return true }
        return delays.count == startup.count && ControllerMIDISetupSequence(steps: startupSteps, startingAt: 0) != nil
    }

    static func validSetupMessage(_ bytes: [UInt8]) -> Bool { ControllerMIDISetupStep.validMessage(bytes) }

    private static func validArgument(_ input: Input) -> Bool {
        switch input.action {
        case .jogA, .jogB, .wheelJogA, .wheelJogB:
            return input.argument.map { input.encoding.isRelative && ControllerCountJogMotion.validResolution($0) }
                ?? true
        case .loopSizeA, .loopSizeB:
            return input.kind == .control && [.twosComplement, .binaryOffset, .binaryStep, .binaryDirection, .zeroForward, .signedStep].contains(input.encoding)
                && input.argument == nil
        case .loopA, .loopB:
            return input.argument.map { PerformancePreparation.loopSizes.contains($0) } ?? true
        case .toggleFixedLoopA, .toggleFixedLoopB, .fixedLoopA, .fixedLoopB:
            return input.argument.map { PerformancePreparation.loopSizes.contains($0) } ?? false
        case .fixedJumpA, .fixedJumpB:
            return input.argument.map { $0.isFinite && $0 != 0 && abs($0) <= 64 } ?? false
        default: return input.argument == nil
        }
    }
}

struct ControllerProfileCatalogue: Decodable, Sendable {
    let schemaVersion: Int
    let profiles: [ControllerProfileData]

    private static let loaded: Result<Self, Error> = Result {
        guard let url = Bundle.module.url(forResource: "factory-controller-profiles.compact", withExtension: "json")
        else { throw TransportError.invalid }
        return try decode(Data(contentsOf: url))
    }
    static let shared: Self = (try? loaded.get()) ?? .init(schemaVersion: 1, profiles: [])
    static var loadFailure: String? {
        if case .failure = loaded { return "The bundled controller catalogue could not load." }
        return nil
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 4 * 1024 * 1024 else { throw TransportError.invalid }
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard result.schemaVersion == 1, result.profiles.count <= 512,
            Set(result.profiles.map(\.id)).count == result.profiles.count,
            result.profiles.allSatisfy(\.isValid)
        else { throw TransportError.invalid }
        return result
    }
}
