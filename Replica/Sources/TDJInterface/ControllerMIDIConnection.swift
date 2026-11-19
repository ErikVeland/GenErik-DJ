import CoreMIDI
import Foundation
import Observation
import TDJCore

enum ControllerAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case playA, playB, syncA, syncB, keylockA, keylockB, cueA, cueB
    case cueStateA, cueStateB, keylockStateA, keylockStateB
    case syncDisableA, syncDisableB
    case syncStateA, syncStateB
    case cueSetA, cueSetB, cueGotoA, cueGotoB
    case pitchBendDownA, pitchBendDownB, pitchBendUpA, pitchBendUpB
    case shift
    case levelA, levelB, gainA, gainB, lowA, lowB, midA, midB, highA, highB
    case filterA, filterB, fxA, fxB, fxToggleA, fxToggleB, crossfader, cueMix
    case filterToggleA, filterToggleB, master, monitor, tempoA, tempoB
    case loopA, loopB, loopUpA, loopUpB, loopDownA, loopDownB, jumpBackA, jumpBackB, jumpForwardA, jumpForwardB
    case cueReturnA, cueReturnB, cueStopA, cueStopB, cuePreviewA, cuePreviewB, freezeA, freezeB
    case jogA, jogB, jogTouchA, jogTouchB, wheelJogA, wheelJogB
    case browse, browseGroups, openGroup, loadA, loadB
    case browsePrevious, browseNext, browsePreviousGroup, browseNextGroup
    case filterKnobA, filterKnobB
    case toggleFixedLoopA, toggleFixedLoopB
    case fixedLoopA, fixedLoopB, fixedJumpA, fixedJumpB, loopInA, loopInB, loopOutA, loopOutB
    case seekA, seekB, tempoResetA, tempoResetB
    case tempoDownA, tempoDownB, tempoUpA, tempoUpB
    case reloopA, reloopB
    case loopInOrHalveA, loopInOrHalveB, loopOutOrDoubleA, loopOutOrDoubleB
    case loopDivideA, loopDivideB, loopRestoreA, loopRestoreB
    case reloopOriginalA, reloopOriginalB
    case loopSizeA, loopSizeB
    case loopEnableA, loopEnableB, loopDisableA, loopDisableB
    case loopOutOrExitA, loopOutOrExitB
    case hotcue1A, hotcue2A, hotcue3A, hotcue4A, hotcue5A, hotcue6A, hotcue7A, hotcue8A
    case hotcue1B, hotcue2B, hotcue3B, hotcue4B, hotcue5B, hotcue6B, hotcue7B, hotcue8B
    case clearHotcue1A, clearHotcue2A, clearHotcue3A, clearHotcue4A, clearHotcue5A, clearHotcue6A, clearHotcue7A, clearHotcue8A
    case clearHotcue1B, clearHotcue2B, clearHotcue3B, clearHotcue4B, clearHotcue5B, clearHotcue6B, clearHotcue7B, clearHotcue8B
    var id: String { rawValue }
    var deck: DeckID { rawValue.hasSuffix("B") ? .b : .a }
    var title: String {
        if self == .shift { return "Shift layer (hold)" }
        if self == .crossfader { return "Crossfader" }
        if self == .cueMix { return "Headphone blend" }
        if self == .master { return "Master level" }
        if self == .monitor { return "Headphone level" }
        if self == .browse { return "Browse tracks" }
        if self == .browseGroups { return "Browse groups" }
        if self == .browsePrevious { return "Previous library track" }
        if self == .browseNext { return "Next library track" }
        if self == .browsePreviousGroup { return "Previous library group" }
        if self == .browseNextGroup { return "Next library group" }
        if self == .openGroup { return "Open group" }
        if self == .loadA || self == .loadB { return "\(deck.rawValue.uppercased()) · Load selected track" }
        if self == .filterKnobA || self == .filterKnobB {
            return "\(deck.rawValue.uppercased()) · Filter knob (automatic on/off)"
        }
        if let clearHotcueSlot { return "\(deck.rawValue.uppercased()) · Clear Hotcue \(clearHotcueSlot + 1)" }
        if let hotcueSlot { return "\(deck.rawValue.uppercased()) · Hotcue \(hotcueSlot + 1)" }
        let labels = [
            "play": "Play / Pause", "sync": "Sync", "keylock": "Key lock", "cue": "Headphone cue", "level": "Volume",
            "pitchBendDown": "Pitch bend down (hold)", "pitchBendUp": "Pitch bend up (hold)",
            "keylockState": "Key lock state", "cueState": "Headphone cue state", "syncState": "Sync state", "syncDisable": "Turn Sync off", "loopEnable": "Enable loop", "loopDisable": "Disable loop", "loopOutOrExit": "Loop out / exit",
            "cueSet": "Set Cue point", "cueGoto": "Go to Cue point",
            "gain": "Gain", "low": "Low EQ", "mid": "Mid EQ", "high": "High EQ", "filter": "Filter",
            "filterToggle": "Filter on / off", "fx": "Effect amount", "fxToggle": "Effect on / off",
            "tempo": "Tempo ±8%", "loop": "Loop on / off", "loopUp": "Larger loop", "loopDown": "Smaller loop",
            "jumpBack": "Beat jump back", "jumpForward": "Beat jump forward", "cueReturn": "Cue return / set", "cueStop": "Go to Cue and stop", "cuePreview": "Cue preview (hold)",
            "freeze": "Freeze", "jog": "Platter jog", "jogTouch": "Platter touch", "wheelJog": "Wheel-side jog",
            "toggleFixedLoop": "Loop pad", "fixedLoop": "Fixed beat loop", "fixedJump": "Fixed beat jump", "loopIn": "Loop in", "loopOut": "Loop out",
            "seek": "Waveform position", "tempoReset": "Tempo reset",
            "tempoDown": "Tempo down 0.1%", "tempoUp": "Tempo up 0.1%",
            "reloop": "Reloop / exit",
            "loopInOrHalve": "Loop in / halve", "loopOutOrDouble": "Loop out / double",
            "loopDivide": "Divide loop", "loopRestore": "Restore loop length",
            "reloopOriginal": "Reloop original / exit", "loopSize": "Loop size encoder",
        ]
        return "\(deck.rawValue.uppercased()) · \(labels[String(rawValue.dropLast())] ?? rawValue)"
    }
    var isButton: Bool {
        switch self {
        case .levelA, .levelB, .gainA, .gainB, .lowA, .lowB, .midA, .midB, .highA, .highB, .filterA, .filterB, .fxA,
            .fxB, .crossfader, .cueMix, .master, .monitor, .tempoA, .tempoB, .jogA, .jogB, .wheelJogA, .wheelJogB,
            .browse, .browseGroups, .filterKnobA, .filterKnobB, .seekA, .seekB, .loopSizeA, .loopSizeB,
            .cueStateA, .cueStateB, .keylockStateA, .keylockStateB, .syncStateA, .syncStateB:
            false
        default: true
        }
    }
    var isMomentary: Bool {
        switch self {
        case .jogTouchA, .jogTouchB, .cuePreviewA, .cuePreviewB, .pitchBendDownA, .pitchBendDownB, .pitchBendUpA, .pitchBendUpB: true
        default: false
        }
    }
    var isJog: Bool { self == .jogA || self == .jogB || self == .wheelJogA || self == .wheelJogB }
    var isCueState: Bool { self == .cueStateA || self == .cueStateB }
    var isDirectState: Bool { isCueState || self == .keylockStateA || self == .keylockStateB || self == .syncStateA || self == .syncStateB }
    var isLearnable: Bool { ![.syncStateA, .syncStateB, .keylockStateA, .keylockStateB, .toggleFixedLoopA, .toggleFixedLoopB, .fixedLoopA, .fixedLoopB, .fixedJumpA, .fixedJumpB, .loopSizeA, .loopSizeB].contains(self) }
    func assigned(to deck: DeckID) -> Self {
        Self(rawValue: String(rawValue.dropLast()) + (deck.leftSide ? "A" : "B")) ?? self
    }
    var isLoopSizeEncoder: Bool { self == .loopSizeA || self == .loopSizeB }
    var isBrowserEncoder: Bool { self == .browse || self == .browseGroups }
    var browserStep: (detents: Int, groups: Bool)? {
        switch self {
        case .browsePrevious: (-1, false)
        case .browseNext: (1, false)
        case .browsePreviousGroup: (-1, true)
        case .browseNextGroup: (1, true)
        default: nil
        }
    }
    var hotcueSlot: Int? {
        guard rawValue.hasPrefix("hotcue"), let value = Int(rawValue.dropFirst(6).dropLast()) else { return nil }
        return value - 1
    }
    var clearHotcueSlot: Int? {
        guard rawValue.hasPrefix("clearHotcue"), let value = Int(rawValue.dropFirst(11).dropLast()) else { return nil }
        return value - 1
    }
    var supportsFeedback: Bool {
        switch self {
        case .pitchBendDownA, .pitchBendDownB, .pitchBendUpA, .pitchBendUpB, .cuePreviewA, .cuePreviewB: true
        case .playA, .playB, .syncA, .syncB, .keylockA, .keylockB, .cueA, .cueB, .levelA, .levelB, .gainA, .gainB,
            .lowA, .lowB, .midA, .midB, .highA, .highB, .filterA, .filterB, .fxA, .fxB, .fxToggleA, .fxToggleB,
            .crossfader, .cueMix, .filterToggleA, .filterToggleB, .master, .monitor, .tempoA, .tempoB, .loopA, .loopB,
            .hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A, .hotcue1B,
            .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B:
            true
        default: false
        }
    }
}

struct ControllerBinding: Codable {
    let source: Int32
    let group: UInt8?
    let channel: UInt8
    let kind: ControllerMIDIMessage.Kind
    let number: UInt8
    let parameter: UInt16?
    let noteNumber: UInt8?
    var action: ControllerAction
    let encoding: ControllerMIDIEncoding?
    let inverted: Bool?
    let shifted: Bool?
    var targetDeck: DeckID? = nil
    var layerIndependent: Bool? = nil
    var anyChannel: Bool? = nil
    var argument: Double? = nil
    var releaseOnly: Bool? = nil
    var requiredMode: UInt8? = nil
    var shiftChannel: UInt8? = nil
    var shiftInput: UInt8? = nil
    var holdInput: UInt8? = nil
    var lowNumber: UInt8? = nil
    var pulse: Bool? = nil
    var requiresTouch: Bool? = nil
    var directionStep: Double? = nil
    var deckBank: UInt8? = nil
    var lowControllerNumber: UInt8? { mode.isPairedCC ? lowNumber ?? (number < 32 ? number + 32 : nil) : nil }
    var target: ControllerActionTarget { .init(action, deck: targetDeck, argument: argument) }
    var mode: ControllerMIDIEncoding { encoding ?? .absolute }
    var isShifted: Bool { shifted ?? false }
    var umpGroup: UInt8 { group ?? 0 }
}

struct ControllerShiftLayerState {
    private var activeInputs: Set<String> = []
    var isActive: Bool { !activeInputs.isEmpty }
    mutating func update(input: String, isPressed: Bool) {
        if isPressed { activeInputs.insert(input) } else { activeInputs.remove(input) }
    }
    mutating func reset() { activeInputs.removeAll() }
}

struct ControllerMIDITakeoverState {
    private var previousInput: Double?
    private var isArmed = false
    private var hasTakenControl = false
    var isPending: Bool { isArmed && !hasTakenControl }

    mutating func shouldApply(input: Double, target: Double?, tolerance: Double = 0.02) -> Bool {
        guard input.isFinite, (0...1).contains(input), let target, target.isFinite, (0...1).contains(target) else {
            return true
        }
        guard !hasTakenControl else { return true }
        isArmed = true
        let close = abs(input - target) <= tolerance
        let crossed = previousInput.map { ($0 - target) * (input - target) <= 0 } ?? false
        previousInput = input
        hasTakenControl = close || crossed
        return hasTakenControl
    }
}

enum ControllerFeedbackKind: String, CaseIterable, Codable, Sendable {
    case note, control
    var title: String { self == .note ? "Note" : "Control Change" }
}

struct ControllerFeedbackBinding: Codable, Identifiable, Equatable {
    var id: String { "\(destination):\(action.rawValue):\(targetDeck?.rawValue ?? "default"):\(kind.rawValue):\(channel):\(number)" }
    let destination: Int32
    let action: ControllerAction
    let kind: ControllerFeedbackKind
    let channel: UInt8
    let number: UInt8
    let offValue: UInt8
    let onValue: UInt8
    let offUsesNoteOn: Bool?
    let offNumber: UInt8?
    let targetDeck: DeckID?
    var target: ControllerActionTarget { .init(action, deck: targetDeck) }

    init(
        destination: Int32, action: ControllerAction, kind: ControllerFeedbackKind, channel: UInt8, number: UInt8,
        offValue: UInt8, onValue: UInt8, offUsesNoteOn: Bool? = nil, targetDeck: DeckID? = nil, offNumber: UInt8? = nil
    ) {
        self.destination = destination
        self.action = action
        self.kind = kind
        self.channel = channel
        self.number = number
        self.offValue = offValue
        self.onValue = onValue
        self.offUsesNoteOn = offUsesNoteOn
        self.offNumber = offNumber
        self.targetDeck = targetDeck
    }

    /**
     * Follows the assigned player deck while preserving its physical output address.
     */
    func assigned(to deck: DeckID?) -> Self {
        guard let deck, targetDeck != nil else { return self }
        return .init(
            destination: destination, action: action.assigned(to: deck), kind: kind,
            channel: channel, number: number, offValue: offValue, onValue: onValue,
            offUsesNoteOn: offUsesNoteOn, targetDeck: deck, offNumber: offNumber)
    }

    var isValid: Bool {
        channel < 16 && number < 128 && offValue < 128 && onValue < 128
            && action.supportsFeedback && (kind == .control || action.isButton)
            && (offNumber == nil || (kind == .control && action.isButton && offNumber! < 128))
    }

    /**
     * Encodes a feedback value, including separate controller numbers for on/off triggers.
     */
    func message(value: Double) -> [UInt8]? {
        guard isValid, value.isFinite else { return nil }
        let bounded = min(1, max(0, value))
        let output = action.isButton ? (bounded > 0 ? onValue : offValue) : UInt8((bounded * 127).rounded())
        let status: UInt8 = kind == .control ? 0xB0 | channel
            : (bounded > 0 || offUsesNoteOn == true ? 0x90 : 0x80) | channel
        return [status, bounded > 0 ? number : offNumber ?? number, output]
    }
}

/// Core MIDI callbacks never touch the observed model or the audio renderer.
final class ControllerMIDIInbox: @unchecked Sendable {
    enum Payload {
        case bytes([UInt8])
        case messages([ControllerMIDIMessage])
    }
    struct Frame {
        let source: UInt32
        let payload: Payload
        var timestamp: UInt64 = 0
    }
    private let lock = NSLock()
    private var frames: [Frame] = []
    private var overflow = false
    private var refresh = false
    func requestRefresh() {
        lock.lock()
        refresh = true
        lock.unlock()
    }
    func append(source: UInt32, bytes: [UInt8], timestamp: UInt64 = 0) {
        lock.lock()
        defer { lock.unlock() }
        if frames.count < 128 && bytes.count <= 4096 {
            frames.append(.init(source: source, payload: .bytes(bytes), timestamp: timestamp))
        } else {
            overflow = true
        }
    }
    func append(source: UInt32, messages: [ControllerMIDIMessage]) {
        lock.lock()
        defer { lock.unlock() }
        if frames.count < 128 && messages.count <= 256 {
            frames.append(.init(source: source, payload: .messages(messages)))
        } else {
            overflow = true
        }
    }
    func signalOverflow() {
        lock.lock()
        overflow = true
        lock.unlock()
    }
    func take() -> ([Frame], Bool, Bool) {
        lock.lock()
        defer { lock.unlock() }
        let result = (frames, overflow, refresh)
        frames.removeAll(keepingCapacity: true)
        overflow = false
        refresh = false
        return result
    }
}

/// Copies bounded UMP channel voice messages before handing them to the observed model.
private func controllerMessages(from eventList: UnsafePointer<MIDIEventList>) -> [ControllerMIDIMessage]? {
    let packetOffset = MemoryLayout<MIDIEventList>.offset(of: \.packet)!
    let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \.words)!
    var packet = UnsafeMutablePointer(
        mutating: UnsafeRawPointer(eventList).advanced(by: packetOffset).assumingMemoryBound(to: MIDIEventPacket.self))
    var messages: [ControllerMIDIMessage] = []
    var totalWords = 0
    let packetCount = Int(eventList.pointee.numPackets)
    guard packetCount <= 128 else { return nil }
    for _ in 0..<packetCount {
        let wordCount = Int(packet.pointee.wordCount)
        guard wordCount <= 1024, totalWords <= 4096 - wordCount else { return nil }
        totalWords += wordCount
        let words = UnsafeRawPointer(packet).advanced(by: wordsOffset).assumingMemoryBound(to: UInt32.self)
        let packetWords = Array(UnsafeBufferPointer(start: words, count: wordCount))
        guard let decoded = ControllerMIDIUMPDecoder.decode(packetWords), messages.count <= 256 - decoded.count else {
            return nil
        }
        messages.append(contentsOf: decoded)
        packet = UnsafeMutableRawPointer(packet).advanced(by: wordsOffset + wordCount * MemoryLayout<UInt32>.size)
            .assumingMemoryBound(to: MIDIEventPacket.self)
    }
    return messages
}

@MainActor @Observable final class ControllerMIDIConnection {
    struct Source: Identifiable {
        let id: Int32
        let reference: MIDIEndpointRef
        let name: String
        var identity: ControllerFactoryEndpoint? = nil
    }
    var enabled = false
    var sources: [Source] = []
    var destinations: [Source] = []
    var selected: Int32?
    var feedbackSelected: Int32?
    var midiFeedbackEnabled = false
    var feedbackBindings: [ControllerFeedbackBinding] = []
    var feedbackOutputAvailable = false
    var selectedFeedbackBindings: [ControllerFeedbackBinding] {
        guard let feedbackSelected else { return [] }
        let custom = feedbackBindings.filter { $0.destination == feedbackSelected }
        return custom.isEmpty ? factoryFeedback[feedbackSelected, default: []] : custom
    }
    var isSelectedFeedbackEnabled: Bool {
        guard let feedbackSelected else { return false }
        if factorySessions.contains(where: { $0.destination == feedbackSelected }) {
            return factoryFeedbackIsEnabled(feedbackSelected)
        }
        return midiFeedbackEnabled
    }
    var originalZ1Bridge = false
    var isZ1BridgeConnected: Bool { originalZ1Bridge && bridgeConnected }
    var activeInputIDs: Set<Int32> = []
    var bridgeStatus = "No Z1 bridge report received."
    var feedbackStatus = "Feedback output is off."
    var status = "Controller input is off."
    var lastInput = "No input received."
    var learning: ControllerAction?
    var learningShifted = false
    var learningEncoding = ControllerMIDIEncoding.absolute
    var learningInverted = false
    var bindingCount = 0
    @ObservationIgnored var onAction: ((ControllerAction, Double) -> Void)?
    @ObservationIgnored var currentValue: ((ControllerAction) -> Double?)?
    @ObservationIgnored var onTargetAction: ((ControllerActionTarget, Double) -> Void)?
    @ObservationIgnored var onJogAction: ((ControllerActionTarget, ControllerMIDIValue) -> Void)?
    @ObservationIgnored var currentTargetValue: ((ControllerActionTarget) -> Double?)?
    @ObservationIgnored var onZ1Report: ((Z1InputReport) -> Void)?
    @ObservationIgnored var onZ1Calibration: ((Z1CrossfaderCalibration) -> Void)?
    @ObservationIgnored var onBridgeReset: (() -> Void)?
    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var protocolPort = MIDIPortRef()
    @ObservationIgnored private var protocolInputFailure: OSStatus?
    @ObservationIgnored private var outputPort = MIDIPortRef()
    @ObservationIgnored private var connectedEndpoints: [Int32: MIDIEndpointRef] = [:]
    @ObservationIgnored private var connectedPorts: [Int32: MIDIPortRef] = [:]
    @ObservationIgnored private var sourceIDsByEndpoint: [UInt32: Int32] = [:]
    @ObservationIgnored private var decoders: [Int32: ControllerMIDIDecoder] = [:]
    @ObservationIgnored private var smk25Decoders: [Int32: ControllerSMK25Decoder] = [:]
    @ObservationIgnored private var cdj101Decoders: [Int32: ControllerCDJ101Decoder] = [:]
    @ObservationIgnored private var sr2Decoders: [Int32: ControllerSR2Decoder] = [:]
    @ObservationIgnored private var kontrolOneDecoders: [Int32: ControllerKontrolOneDecoder] = [:]
    @ObservationIgnored private var setupInputDecoders: [Int32: ControllerSetupInputDecoder] = [:]
    @ObservationIgnored private var nativeFactoryProtocols: [Int32: ControllerProfileData.InputProtocol] = [:]
    @ObservationIgnored private var sc5000MDecoders: [Int32: ControllerSC5000MDecoder] = [:]
    @ObservationIgnored private var prime4Decoders: [Int32: ControllerPrime4Decoder] = [:]
    @ObservationIgnored private var spectraDecoders: [Int32: ControllerSpectraDecoder] = [:]
    @ObservationIgnored private var p1NanoDecoders: [Int32: ControllerP1NanoDecoder] = [:]
    @ObservationIgnored private var legacyUSBPlayerDecoders: [Int32: ControllerLegacyUSBPlayerDecoder] = [:]
    @ObservationIgnored private var legacySinglePlayerDecoders: [Int32: ControllerLegacySinglePlayerDecoder] = [:]
    @ObservationIgnored private var orbitDecoders: [Int32: ControllerOrbitDecoder] = [:]
    @ObservationIgnored private var mpd218Decoders: [Int32: ControllerMPD218Decoder] = [:]
    @ObservationIgnored private var mpd2BitwigDecoders: [Int32: ControllerMPD2BitwigDecoder] = [:]
    @ObservationIgnored private var mc1000Decoders: [Int32: ControllerMC1000Decoder] = [:]
    @ObservationIgnored private var keyLabDecoders: [Int32: ControllerKeyLabDecoder] = [:]
    @ObservationIgnored private var manualFactoryProfiles: [Int32: ControllerFactoryProfile] = [:]
    @ObservationIgnored private var manualInputProtocols: [Int32: ControllerProfileData.InputProtocol] = [:]
    @ObservationIgnored private var bridgeDecoders: [Int32: ControllerBridgeDecoder] = [:]
    @ObservationIgnored private var bridgeConnected = false
    @ObservationIgnored private var pendingFeedback: [UInt8]?
    @ObservationIgnored private var sentFeedback: [UInt8] = []
    @ObservationIgnored private var sentMIDIValues: [String: [UInt8]] = [:]
    private struct MomentaryInput: Hashable {
        let source: Int32
        let group: UInt8
        let input: UInt8?
    }
    @ObservationIgnored private var activeMomentaryInputs: [ControllerActionTarget: Set<MomentaryInput>] = [:]
    @ObservationIgnored private var lastMIDIOutputTime = 0.0
    @ObservationIgnored private var lastFeedbackTime = 0.0
    @ObservationIgnored private var needsBridgeHello = true
    @ObservationIgnored private var values: [String: Double] = [:]
    @ObservationIgnored private var valueStates: [String: ControllerMIDIValueState] = [:]
    @ObservationIgnored private var takeoverStates: [String: ControllerMIDITakeoverState] = [:]
    @ObservationIgnored private var pendingValues: [ControllerActionTarget: Double] = [:]
    @ObservationIgnored private var pendingInputOwners: [ControllerActionTarget: Int32] = [:]
    @ObservationIgnored private var pendingJogSources: [ControllerActionTarget: [Int32: Double]] = [:]
    @ObservationIgnored private var pendingJogValues: [ControllerActionTarget: ControllerMIDIValue] = [:]
    @ObservationIgnored private var channelShiftLayers: [Int32: [UInt8: ControllerShiftLayerState]] = [:]
    @ObservationIgnored private var shiftLayers: [Int32: ControllerShiftLayerState] = [:]
    @ObservationIgnored private var bindings: [ControllerBinding] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var pollingInterval = 0.0
    @ObservationIgnored private let inbox = ControllerMIDIInbox()
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let factoryPacketSender: (([UInt8], Int32) -> Bool)?
    private struct PendingFactorySetup {
        let session: ControllerFactorySession
        var sequence: ControllerMIDISetupSequence
    }
    @ObservationIgnored private let factorySetupClock: () -> UInt64
    @ObservationIgnored private var pendingFactorySetups: [Int32: PendingFactorySetup] = [:]
    @ObservationIgnored private var timedFactoryInputs: Set<Int32> = []
    @ObservationIgnored private var timedFactoryOutputs: Set<Int32> = []
    @ObservationIgnored private var factoryInputReadyTimes: [Int32: UInt64] = [:]
    @ObservationIgnored private let factoryInputConnector: ((Int32) -> Bool)?
    @ObservationIgnored private let deckAvailability: (() -> [DeckID])?
    @ObservationIgnored private var factorySessions: [ControllerFactorySession] = []
    @ObservationIgnored private var factoryPadModes: [Int32: ControllerPadModeState] = [:]
    @ObservationIgnored private var deckBanks: [Int32: ControllerDeckBankState] = [:]
    @ObservationIgnored private var factoryBindings: [Int32: [ControllerBinding]] = [:]
    @ObservationIgnored private var factoryFeedback: [Int32: [ControllerFeedbackBinding]] = [:]
    @ObservationIgnored private var sentFactoryValues: [Int32: [String: [UInt8]]] = [:]
    @ObservationIgnored private var lastFactoryOutputTime = 0.0
    @ObservationIgnored private var factorySetupFailure: String?
    @ObservationIgnored private var disabledFactoryProfiles: Set<ControllerFactoryProfile> = []
    @ObservationIgnored private var disabledPlayerSources: Set<Int32> = []
    @ObservationIgnored private var disabledFactoryFeedback: Set<ControllerFactoryProfile> = []
    @ObservationIgnored private var customFactoryInputs: [String: [ControllerBinding]] = [:]
    @ObservationIgnored private var customFactoryFeedback: [String: [ControllerFeedbackBinding]] = [:]
    @ObservationIgnored private var savedPlayerDecks: [Int32: DeckID] = [:]
    private static let storageKey = "controllers.midiBindings.v1"
    private static let activeInputsStorageKey = "controllers.midiActiveInputs.v1"
    private static let manualProfilesStorageKey = "controllers.factory.manualProfiles.v1"
    private static let inputProtocolsStorageKey = "controllers.midiInputProtocols.v1"
    private static let feedbackStorageKey = "controllers.midiFeedback.v1"

    init(
        preferences: UserDefaults = .standard, factoryPacketSender: (([UInt8], Int32) -> Bool)? = nil,
        deckAvailability: (() -> [DeckID])? = nil, factoryInputConnector: ((Int32) -> Bool)? = nil,
        factorySetupClock: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }
    ) {
        self.preferences = preferences
        self.factoryPacketSender = factoryPacketSender
        self.factoryInputConnector = factoryInputConnector
        self.factorySetupClock = factorySetupClock
        self.deckAvailability = deckAvailability
        if let data = preferences.data(forKey: "controllers.factory.disabledPlayers"),
            let saved = try? JSONDecoder().decode(Set<Int32>.self, from: data)
        {
            disabledPlayerSources = saved
        }
        if let data = preferences.data(forKey: "controllers.factory.playerDecks"),
            let saved = try? JSONDecoder().decode([Int32: DeckID].self, from: data)
        {
            savedPlayerDecks = saved
        }
        disabledFactoryProfiles = Set(
            (preferences.stringArray(forKey: "controllers.factory.disabled") ?? [])
                .compactMap(ControllerFactoryProfile.init(rawValue:)))
        disabledFactoryFeedback = Set(
            (preferences.stringArray(forKey: "controllers.factory.feedbackDisabled") ?? [])
                .compactMap(ControllerFactoryProfile.init(rawValue:)))
        if let data = preferences.data(forKey: "controllers.factory.customInputs"),
            let saved = try? JSONDecoder().decode([String: [ControllerBinding]].self, from: data)
        { customFactoryInputs = saved }
        if let data = preferences.data(forKey: "controllers.factory.customFeedback"),
            let saved = try? JSONDecoder().decode([String: [ControllerFeedbackBinding]].self, from: data)
        { customFactoryFeedback = saved }
        if let data = preferences.data(forKey: Self.storageKey),
            let saved = try? JSONDecoder().decode([ControllerBinding].self, from: data), saved.count <= 256
        {
            bindings = saved
        }
        if let data = preferences.data(forKey: Self.manualProfilesStorageKey), data.count <= 16_384,
            let saved = try? JSONDecoder().decode([Int32: ControllerFactoryProfile].self, from: data), saved.count <= 64 {
            manualFactoryProfiles = saved.filter { source, _ in bindings.contains { $0.source == source } }
            for (source, profile) in manualFactoryProfiles {
                factoryPadModes[source] = profile.definition?.inputModes.map { .init(modes: $0) }
            }
        }
        if let data = preferences.data(forKey: Self.inputProtocolsStorageKey), data.count <= 4096,
            let saved = try? JSONDecoder().decode([Int32: ControllerProfileData.InputProtocol].self, from: data),
            saved.count <= 64
        {
            manualInputProtocols = saved.filter { source, _ in bindings.contains { $0.source == source } }
        }
        if let data = preferences.data(forKey: Self.activeInputsStorageKey),
            let saved = try? JSONDecoder().decode([Int32].self, from: data), saved.count <= 64
        {
            activeInputIDs = Set(saved)
        }
        if let data = preferences.data(forKey: Self.feedbackStorageKey),
            let saved = try? JSONDecoder().decode([ControllerFeedbackBinding].self, from: data), saved.count <= 128,
            saved.allSatisfy({
                $0.isValid
            }), Set(saved.map(\.id)).count == saved.count
        {
            feedbackBindings = saved
        }
        bindingCount = bindings.count
    }
    func start() {
        guard !enabled else { return }
        let inbox = inbox
        let clientResult = MIDIClientCreateWithBlock("GenErik DJ controllers" as CFString, &client) { _ in
            inbox.requestRefresh()
        }
        guard clientResult == noErr else {
            status = "MIDI input is unavailable (\(clientResult))."
            return
        }
        let result = MIDIInputPortCreateWithBlock(client, "Controller input" as CFString, &port) { list, context in
            guard let context else { return }
            let source = UInt32(truncatingIfNeeded: UInt(bitPattern: context))
            let offset = MemoryLayout<MIDIPacketList>.offset(of: \.packet)!
            let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \.data)!
            var packet = UnsafeMutablePointer(
                mutating: UnsafeRawPointer(list).advanced(by: offset).assumingMemoryBound(to: MIDIPacket.self))
            for _ in 0..<list.pointee.numPackets {
                let count = Int(packet.pointee.length)
                let bytes = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)
                inbox.append(
                    source: source,
                    bytes: count <= 4096
                        ? Array(UnsafeBufferPointer(start: bytes, count: count)) : Array(repeating: 0, count: 4097),
                    timestamp: DispatchTime.now().uptimeNanoseconds)
                packet = MIDIPacketNext(packet)
            }
        }
        guard result == noErr else {
            stop()
            status = "MIDI input could not open (\(result))."
            return
        }
        let protocolResult = MIDIInputPortCreateWithProtocol(
            client, "Controller MIDI 2.0 input" as CFString, ._2_0, &protocolPort
        ) { list, context in
            guard let context else { return }
            let source = UInt32(truncatingIfNeeded: UInt(bitPattern: context))
            guard let messages = controllerMessages(from: list) else {
                inbox.signalOverflow()
                return
            }
            if !messages.isEmpty { inbox.append(source: source, messages: messages) }
        }
        if protocolResult != noErr {
            protocolPort = 0
            protocolInputFailure = protocolResult
        } else {
            protocolInputFailure = nil
        }
        let outputResult = MIDIOutputPortCreate(client, "Controller feedback" as CFString, &outputPort)
        feedbackOutputAvailable = outputResult == noErr
        feedbackStatus =
            feedbackOutputAvailable
            ? "MIDI feedback output is available." : "MIDI feedback output could not open (\(outputResult))."
        lastInput = "No input received."
        enabled = true
        refreshSources()
        updatePollingInterval()
    }

    private func updatePollingInterval() {
        guard enabled else { return }
        let interval = connectedEndpoints.isEmpty ? 0.25 : 1.0 / 120
        guard timer == nil || pollingInterval != interval else { return }
        timer?.invalidate()
        pollingInterval = interval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.drain() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stop() {
        pendingFactorySetups.removeAll()
        factoryInputReadyTimes.removeAll()
        for session in factorySessions { sendFactorySetup(session, starting: false) }
        releaseMomentaryActions()
        timer?.invalidate()
        timer = nil
        if port != 0 {
            MIDIPortDispose(port)
            port = 0
        }
        if protocolPort != 0 {
            MIDIPortDispose(protocolPort)
            protocolPort = 0
        }
        if outputPort != 0 {
            MIDIPortDispose(outputPort)
            outputPort = 0
        }
        feedbackOutputAvailable = false
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
        connectedEndpoints.removeAll()
        connectedPorts.removeAll()
        sourceIDsByEndpoint.removeAll()
        decoders.removeAll()
        smk25Decoders.removeAll()
        cdj101Decoders.removeAll()
        sr2Decoders.removeAll()
        keyLabDecoders.removeAll()
        p1NanoDecoders.removeAll()
        legacyUSBPlayerDecoders.removeAll()
        legacySinglePlayerDecoders.removeAll()
        orbitDecoders.removeAll()
        mpd218Decoders.removeAll()
        mpd2BitwigDecoders.removeAll()
        mc1000Decoders.removeAll()
        setupInputDecoders.removeAll()
        sc5000MDecoders.removeAll()
        prime4Decoders.removeAll()
        spectraDecoders.removeAll()
        kontrolOneDecoders.removeAll()
        bridgeDecoders.removeAll()
        shiftLayers.removeAll()
        channelShiftLayers.removeAll()
        selected = nil
        enabled = false
        learning = nil
        learningShifted = false
        midiFeedbackEnabled = false
        protocolInputFailure = nil
        values.removeAll()
        valueStates.removeAll()
        takeoverStates.removeAll()
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        _ = inbox.take()
        sentMIDIValues.removeAll()
        factorySessions.removeAll()
        factoryBindings.removeAll()
        factoryPadModes.removeAll()
        deckBanks.removeAll()
        factoryFeedback.removeAll()
        sentFactoryValues.removeAll()
        resetBridge()
        sources = []
        destinations = []
        feedbackSelected = nil
        feedbackStatus = "Feedback output is off."
        status = "Controller input is off."
    }
    private func describe(_ reference: MIDIEndpointRef) -> Source? {
        guard reference != 0 else { return nil }
        var id: Int32 = 0
        guard MIDIObjectGetIntegerProperty(reference, kMIDIPropertyUniqueID, &id) == noErr else { return nil }
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(reference, kMIDIPropertyDisplayName, &name)
        let displayName = name?.takeRetainedValue() as String? ?? "MIDI port"
        var entity: MIDIEntityRef = 0
        var device: MIDIDeviceRef = 0
        var identity: ControllerFactoryEndpoint?
        if MIDIEndpointGetEntity(reference, &entity) == noErr, entity != 0,
            MIDIEntityGetDevice(entity, &device) == noErr, device != 0
        {
            var offline: Int32 = 0
            if MIDIObjectGetIntegerProperty(device, kMIDIPropertyOffline, &offline) == noErr, offline != 0 {
                return nil
            }
            let names: [String] = [device, reference].flatMap { object in
                [kMIDIPropertyModel, kMIDIPropertyName, kMIDIPropertyDisplayName].compactMap { property in
                    var value: Unmanaged<CFString>?
                    guard MIDIObjectGetStringProperty(object, property, &value) == noErr else { return nil }
                    return value?.takeRetainedValue() as String?
                }
            }
            let portNames: [String] = [kMIDIPropertyName, kMIDIPropertyDisplayName].compactMap { property in
                var value: Unmanaged<CFString>?
                guard MIDIObjectGetStringProperty(reference, property, &value) == noErr else { return nil }
                return value?.takeRetainedValue() as String?
            }
            identity = .init(id: id, device: device, names: names, reference: reference, portNames: portNames)
        }
        return .init(id: id, reference: reference, name: displayName, identity: identity)
    }
    func refreshSources() {
        let previousDestinations = Dictionary(uniqueKeysWithValues: destinations.map { ($0.id, $0.reference) })
        sources = (0..<MIDIGetNumberOfSources()).compactMap { describe(MIDIGetSource($0)) }
        destinations = (0..<MIDIGetNumberOfDestinations()).compactMap { describe(MIDIGetDestination($0)) }
        for destination in destinations where previousDestinations[destination.id] != destination.reference {
            sentFactoryValues[destination.id] = nil
            if destination.id == feedbackSelected { sentMIDIValues.removeAll() }
        }
        #if os(iOS)
            sources.removeAll { BeatpadMIDIConnection.isBeatpad($0.reference) }
            destinations.removeAll { BeatpadMIDIConnection.isBeatpad($0.reference) }
        #endif
        reconcileFactoryProfiles()
        let sourceIDs = Set(sources.map(\.id))
        for id in Array(connectedEndpoints.keys) where !sourceIDs.contains(id) { disconnectInput(id) }
        for source in sources
        where connectedEndpoints[source.id] != nil && connectedEndpoints[source.id] != source.reference {
            disconnectInput(source.id)
        }
        if let selected, !sourceIDs.contains(selected) {
            self.selected = nil
            learning = nil
            learningShifted = false
            if originalZ1Bridge {
                resetBridge()
                reconnectInputs()
            }
        }
        for id in sourceIDs where isInputActive(id)
            || factorySessions.contains(where: { $0.source == id && $0.profile.definition?.requiresPairedSetup == true })
        { connectInput(id) }
        if let feedbackSelected, !destinations.contains(where: { $0.id == feedbackSelected }) {
            self.feedbackSelected = nil
            sentFeedback = []
            sentMIDIValues.removeAll()
            midiFeedbackEnabled = false
        }
        if selected == nil {
            if !factorySessions.isEmpty {
                status = factorySessions.allSatisfy { connectedEndpoints[$0.source] != nil }
                    ? "Factory controller profiles loaded automatically."
                    : "Factory profiles loaded. Check the controller connection."
            } else {
                status = sources.isEmpty
                    ? "No MIDI inputs found. Check the connection and MIDI mode." : "Choose the controller input to use."
            }
        }
        if let failure = ControllerProfileCatalogue.loadFailure { status = failure }
        if let factorySetupFailure { status = factorySetupFailure }
        updatePollingInterval()
    }

    /**
     * Removes queued input from the controller that lost software ownership.
     */
    private func discardPendingInput(source: Int32) {
        let targets = Set(pendingInputOwners.compactMap { $0.value == source ? $0.key : nil })
            .union(pendingJogSources.compactMap { $0.value[source] != nil ? $0.key : nil })
        for target in targets {
            if var contributions = pendingJogSources[target] {
                contributions[source] = nil
                if let owner = contributions.keys.min() {
                    let total = contributions.values.reduce(0,+)
                    pendingJogSources[target] = contributions
                    pendingInputOwners[target] = owner
                    pendingJogValues[target] = .relative(total)
                    pendingValues[target] = 0.5 + min(4,max(-4,total)) / 8
                    continue
                }
            }
            pendingInputOwners[target] = nil
            pendingJogSources[target] = nil
            pendingJogValues[target] = nil
            pendingValues[target] = nil
        }
    }

    private func setupInputModeChanged(_ ready: Bool, source: Int32) {
        if !ready { discardPendingInput(source: source) }
        releaseMomentaryActions(source: source, resetJogs: false)
        shiftLayers[source] = nil
        channelShiftLayers[source] = nil
        resetInputValueStates(inputBindings(source: source))
        if inputProtocol(for: source) == .apc64 {
            status = ready ? "Controller ready." : "Select Session mode on APC64 to continue."
        } else if inputProtocol(for: source) == .launchControlTemplate || inputProtocol(for: source) == .launchControlXLTemplate {
            status = ready ? "Controller template ready." : "Reading the controller template. Select a User template if setup does not finish."
        } else if inputProtocol(for: source) == .nanoKontrolScene {
            status = ready ? "Controller scene ready." : "Reading the controller scene. Reconnect if setup does not finish."
        } else {
            status = ready ? "Controller ready." : "Controller left its MIDI mode. Reconnect to continue."
        }
        if let destination = factorySessions.first(where: { $0.source == source })?.destination {
            sentFactoryValues[destination] = nil
        }
    }

    private func keepsRawSetupMappings(_ source: Int32, protocol input: ControllerProfileData.InputProtocol) -> Bool {
        input.preservesRawMappings && bindings.contains { $0.source == source } && manualInputProtocols[source] != input
    }

    func reconcileFactoryProfiles(reassigning: Set<Int32> = []) {
        factorySetupFailure = nil
        let presentSources = Set(sources.map(\.id))
        for (source, profile) in manualFactoryProfiles {
            guard presentSources.contains(source), let modes = profile.definition?.inputModes else {
                factoryPadModes[source] = nil
                continue
            }
            if factoryPadModes[source] == nil { factoryPadModes[source] = .init(modes: modes) }
        }
        timedFactoryInputs = Set(sources.compactMap { source in
            guard let identity = source.identity,
                let profile = ControllerFactoryProfile.matching(identity.names, automaticOnly: true),
                profile.definition?.hasDelayedStartup == true
            else { return nil }
            return source.id
        })
        nativeFactoryProtocols = Dictionary(uniqueKeysWithValues: sources.compactMap { source in
            guard let identity = source.identity,
                let input = ControllerFactoryProfile.matching(identity.names, automaticOnly: true)?.definition?.inputProtocol,
                input.setupInputMode != nil
            else { return nil }
            guard !keepsRawSetupMappings(source.id, protocol: input) else { return nil }
            return (source.id, input)
        })
        let timedDevices = Set(sources.compactMap { source -> UInt32? in
            guard timedFactoryInputs.contains(source.id) || nativeFactoryProtocols[source.id] != nil,
                let device = source.identity?.device, device != 0 else { return nil }
            return device
        })
        timedFactoryOutputs = Set(destinations.compactMap { destination in
            guard let identity = destination.identity else { return nil }
            let profile = ControllerFactoryProfile.matching(identity.names, automaticOnly: true)
            return timedDevices.contains(identity.device)
                || (profile?.definition?.requiresPairedSetup == true && profile?.definition?.inputProtocol?.preservesRawMappings != true)
                ? destination.id : nil
        })
        let discovered = ControllerFactorySession.discover(
            sources: sources.compactMap(\.identity), destinations: destinations.compactMap(\.identity),
            disabled: disabledFactoryProfiles
        ).filter { session in
            (!session.profile.isPlayer || !disabledPlayerSources.contains(session.source))
                && (session.profile.definition?.inputProtocol.map { !keepsRawSetupMappings(session.source, protocol: $0) } ?? true)
        }
        let current = Dictionary(
            uniqueKeysWithValues: factorySessions.compactMap { session -> (Int32, DeckID)? in
                guard let deck = session.playerDeck, !reassigning.contains(session.source) else { return nil }
                return (session.source, deck)
            })
        let allocated = ControllerPlayerAssignment.allocate(
            sources: discovered.filter { $0.profile.isPlayer }.map(\.source), current: current,
            saved: savedPlayerDecks, available: availablePlayerDecks)
        let candidates = discovered.compactMap { session -> ControllerFactorySession? in
            guard session.profile.isPlayer else { return session }
            guard let deck = allocated[session.source] else { return nil }
            var assigned = session
            assigned.playerDeck = deck
            return assigned
        }
        for old in factorySessions where !candidates.contains(old) {
            sendFactorySetup(old, starting: false)
            disconnectInput(old.source)
            if let destination = old.destination { sentFactoryValues[destination] = nil }
        }
        let starting = candidates.filter { !factorySessions.contains($0) }
        let sessions = candidates
        guard sessions != factorySessions else {
            advanceFactorySetups()
            return
        }
        var padModes = factoryPadModes.filter { manualFactoryProfiles[$0.key] != nil && presentSources.contains($0.key) }
        for session in sessions {
            guard let modes = session.profile.definition?.inputModes else { continue }
            padModes[session.source] = factorySessions.contains(session)
                ? factoryPadModes[session.source] ?? .init(modes: modes) : .init(modes: modes)
        }
        factoryPadModes = padModes
        factorySessions = sessions
        for (id, deck) in allocated { savedPlayerDecks[id] = deck }
        let oldAssignments = savedPlayerDecks.filter { allocated[$0.key] == nil }.sorted { $0.key < $1.key }
        savedPlayerDecks = allocated
        for (id, deck) in oldAssignments.prefix(max(0, 64 - allocated.count)) { savedPlayerDecks[id] = deck }
        preferences.set(try? JSONEncoder().encode(savedPlayerDecks), forKey: "controllers.factory.playerDecks")
        var rebound = false
        for index in bindings.indices {
            guard bindings[index].targetDeck != nil,
                let deck = sessions.first(where: { $0.source == bindings[index].source })?.playerDeck
            else { continue }
            let action = bindings[index].action.assigned(to: deck)
            if bindings[index].targetDeck != deck || bindings[index].action != action {
                bindings[index].targetDeck = deck
                bindings[index].action = action
                rebound = true
            }
        }
        if rebound { preferences.set(try? JSONEncoder().encode(bindings), forKey: Self.storageKey) }
        let previousFeedback = feedbackBindings
        for index in feedbackBindings.indices {
            guard let deck = sessions.first(where: { $0.destination == feedbackBindings[index].destination })?.playerDeck else { continue }
            feedbackBindings[index] = feedbackBindings[index].assigned(to: deck)
        }
        if feedbackBindings != previousFeedback {
            preferences.set(try? JSONEncoder().encode(feedbackBindings), forKey: Self.feedbackStorageKey)
        }
        rememberFactoryOverrides()
        factoryBindings = Dictionary(
            uniqueKeysWithValues: sessions.map { session in
                let profile =
                    customFactoryInputs[factoryInputKey(session)]?.map { binding in
                        ControllerBinding(
                            source: session.source, group: binding.group, channel: binding.channel,
                            kind: binding.kind, number: binding.number, parameter: binding.parameter,
                            noteNumber: binding.noteNumber,
                            action: session.playerDeck.map {
                                binding.targetDeck != nil ? binding.action.assigned(to: $0) : binding.action
                            } ?? binding.action,
                            encoding: binding.encoding,
                            inverted: binding.inverted, shifted: binding.shifted,
                            targetDeck: session.playerDeck != nil && binding.targetDeck != nil
                                ? session.playerDeck : binding.targetDeck,
                            layerIndependent: binding.layerIndependent, anyChannel: binding.anyChannel,
                            argument: binding.argument, releaseOnly: binding.releaseOnly,
                            requiredMode: binding.requiredMode, shiftChannel: binding.shiftChannel,
                            shiftInput: binding.shiftInput, holdInput: binding.holdInput, lowNumber: binding.lowNumber, pulse: binding.pulse,
                            requiresTouch: binding.requiresTouch, directionStep: binding.directionStep, deckBank: binding.deckBank)
                    } ?? session.profile.bindings(source: session.source, playerDeck: session.playerDeck)
                return (session.source, profile)
            })
        factoryFeedback = Dictionary(
            uniqueKeysWithValues: sessions.compactMap { session in
                guard let destination = session.destination else {
                    return nil
                }
                let profile =
                    customFactoryFeedback[session.profile.rawValue]?.map { binding in
                        ControllerFeedbackBinding(
                            destination: destination, action: binding.action, kind: binding.kind,
                            channel: binding.channel, number: binding.number, offValue: binding.offValue,
                            onValue: binding.onValue, offUsesNoteOn: binding.offUsesNoteOn,
                            targetDeck: binding.targetDeck, offNumber: binding.offNumber)
                    }.map { $0.assigned(to: session.playerDeck) } ?? session.profile.feedback(destination: destination, playerDeck: session.playerDeck)
                return (destination, profile)
            })
        for session in sessions {
            let connected = factoryInputConnector?(session.source)
                ?? (!enabled || connectInput(session.source, startingFactorySetup: false))
            if !connected { factorySetupFailure = "The controller input could not connect. Check the connection." }
            let needsSetup = starting.contains(session)
                || (session.profile.definition?.hasDelayedStartup == true
                    && factoryInputReadyTimes[session.source] == nil && pendingFactorySetups[session.source] == nil)
            guard connected && (!needsSetup || beginFactorySetup(session)) else {
                disconnectInput(session.source)
                factoryBindings[session.source] = nil
                factoryPadModes[session.source] = nil
                factorySessions.removeAll { $0 == session }
                if let destination = session.destination { factoryFeedback[destination] = nil }
                continue
            }
        }
    }

    /**
     * Sends bounded mode messages only to the paired physical output.
     */
    @discardableResult private func sendFactorySetup(_ session: ControllerFactorySession, starting: Bool) -> Bool {
        if let model = session.profile.definition?.inputProtocol?.setupInputMode {
            if starting {
                setupInputDecoders[session.source] = .init(mode: model)
                status = "Waiting for controller setup."
            } else if let message = setupInputDecoders[session.source]?.exitRequest {
                return sendFactoryMessage(message, session: session, starting: false)
            }
        }
        let messages = starting ? session.profile.definition?.startup : session.profile.definition?.shutdown
        guard let messages, !messages.isEmpty else { return true }
        for message in messages {
            guard sendFactoryMessage(message, session: session, starting: starting) else {
                if starting || session.profile.definition?.inputProtocol == .apc64 { abortFactoryStartup(session) }
                return false
            }
        }
        return true
    }

    /**
     * Attempts the reviewed exit after partial setup or APC64 shutdown failure.
     */
    private func abortFactoryStartup(_ session: ControllerFactorySession) {
        for message in session.profile.definition?.startupAbort ?? [] {
            _ = sendFactoryMessage(message, session: session, starting: false)
        }
    }

    private func sendFactoryMessage(_ message: [UInt8], session: ControllerFactorySession, starting: Bool) -> Bool {
        guard let id = session.destination, let destination = destinations.first(where: { $0.id == id }) else { return false }
        let sent = factoryPacketSender?(message, id)
            ?? (outputPort != 0 && sendMIDIMessage(message, destination: destination.reference, duringSetup: true))
        if !sent {
            let operation = starting ? "start" : "stop"
            let failure = "The controller MIDI mode could not \(operation). Check the output connection."
            factorySetupFailure = failure
            status = failure
        }
        return sent
    }

    private func beginFactorySetup(_ session: ControllerFactorySession) -> Bool {
        guard let definition = session.profile.definition, definition.hasDelayedStartup else {
            return sendFactorySetup(session, starting: true)
        }
        if pendingFactorySetups[session.source]?.session == session || factoryInputReadyTimes[session.source] != nil {
            return true
        }
        guard pendingFactorySetups.count < 16,
            let sequence = ControllerMIDISetupSequence(steps: definition.startupSteps, startingAt: factorySetupClock())
        else {
            failFactorySetup(session)
            return false
        }
        releaseMomentaryActions(source: session.source)
        decoders[session.source] = nil
        if let destination = session.destination { sentFactoryValues[destination] = nil }
        pendingFactorySetups[session.source] = .init(session: session, sequence: sequence)
        status = "Preparing controller."
        advanceFactorySetups()
        return pendingFactorySetups[session.source] != nil || factoryInputReadyTimes[session.source] != nil
    }

    /**
     * Advances bounded startup work on the input polling loop, using actual send completion times.
     */
    func advanceFactorySetups() {
        var budget = 64
        for source in pendingFactorySetups.keys.sorted() {
            guard var pending = pendingFactorySetups[source] else { continue }
            guard factorySessions.contains(pending.session) else {
                pendingFactorySetups[source] = nil
                continue
            }
            var failed = false
            while budget > 0, let message = pending.sequence.nextMessage(at: factorySetupClock()) {
                budget -= 1
                guard sendFactoryMessage(message, session: pending.session, starting: true),
                    pending.sequence.didSend(at: factorySetupClock())
                else {
                    failFactorySetup(pending.session)
                    failed = true
                    break
                }
            }
            if failed { continue }
            if pending.sequence.isComplete(at: factorySetupClock()) {
                decoders[source] = nil
                shiftLayers[source] = nil
                channelShiftLayers[source] = nil
                resetInputValueStates(inputBindings(source: source))
                factoryInputReadyTimes[source] = pending.sequence.readyAfter
                pendingFactorySetups[source] = nil
                if factorySetupFailure == nil { status = "Controller ready." }
            } else {
                pendingFactorySetups[source] = pending
            }
        }
    }

    private func failFactorySetup(_ session: ControllerFactorySession) {
        abortFactoryStartup(session)
        if session.profile.definition?.inputProtocol?.setupInputMode != nil {
            _ = sendFactorySetup(session, starting: false)
        }
        disconnectInput(session.source)
        factoryBindings[session.source] = nil
        factoryPadModes[session.source] = nil
        factorySessions.removeAll { $0 == session }
        if let destination = session.destination {
            factoryFeedback[destination] = nil
            sentFactoryValues[destination] = nil
        }
        if factorySetupFailure == nil {
            factorySetupFailure = "Controller setup failed. Check its MIDI connections."
        }
        status = factorySetupFailure ?? "Controller setup failed."
    }

    var availablePlayerDecks: [DeckID] {
        if let deckAvailability { return deckAvailability() }
        return FourDeckTrial.isAvailable && preferences.bool(forKey: FourDeckTrial.preferenceKey)
            ? DeckID.allCases : DeckID.primary
    }

    func playerDeck(source: Int32) -> DeckID? { factorySessions.first { $0.source == source }?.playerDeck }

    func setPlayerDeck(_ deck: DeckID, source: Int32) {
        guard availablePlayerDecks.contains(deck), let old = playerDeck(source: source), old != deck else { return }
        var changed: Set<Int32> = [source]
        if let other = factorySessions.first(where: { $0.playerDeck == deck }) {
            savedPlayerDecks[other.source] = old
            changed.insert(other.source)
        }
        savedPlayerDecks[source] = deck
        reconcileFactoryProfiles(reassigning: changed)
    }

    func factoryProfileName(source: Int32) -> String? {
        guard !bindings.contains(where: { $0.source == source }) else { return nil }
        guard let session = factorySessions.first(where: { $0.source == source }),
            customFactoryInputs[factoryInputKey(session)] == nil
        else { return nil }
        return session.profile.rawValue + (session.playerDeck.map { " · Deck " + $0.rawValue.uppercased() } ?? "")
    }

    private func inputBindings(source: Int32) -> [ControllerBinding] {
        let custom = bindings.filter { $0.source == source }
        let raw = custom.isEmpty ? factoryBindings[source, default: []] : custom
        guard let banks = deckBanks[source] else { return raw }
        return raw.map { binding in
            guard let bank = binding.deckBank else { return binding }
            var result = binding
            result.targetDeck = banks.deck(for: bank)
            result.action = binding.action.assigned(to: banks.deck(for: bank))
            return result
        }
    }

    /**
     * Keeps ordinary feedback out of incomplete or failed paired mode setup.
     */
    func factoryOutputIsReady(_ id: Int32) -> Bool {
        guard timedFactoryOutputs.contains(id) else { return true }
        guard let session = factorySessions.first(where: { $0.destination == id }) else { return false }
        if session.profile.definition?.inputProtocol?.setupInputMode != nil {
            return setupInputDecoders[session.source]?.isReady == true
        }
        return factoryInputReadyTimes[session.source] != nil
    }

    private func factoryFeedbackIsEnabled(_ destination: Int32) -> Bool {
        guard factoryFeedback[destination] != nil,
            let session = factorySessions.first(where: { $0.destination == destination }) else { return false }
        return !disabledFactoryFeedback.contains(session.profile) && factoryOutputIsReady(destination)
    }

    func applyFactoryProfile(_ profile: ControllerFactoryProfile) {
        guard !originalZ1Bridge, let selected else { return }
        let adoptsSceneProfile = profile.definition?.inputProtocol?.preservesRawMappings == true
            && !factorySessions.contains(where: { $0.source == selected && $0.profile == profile })
        let availableScenePair = adoptsSceneProfile && ControllerFactorySession.discover(
            sources: sources.compactMap(\.identity), destinations: destinations.compactMap(\.identity), disabled: []
        ).contains { $0.source == selected && $0.profile == profile && $0.destination != nil }
        guard profile.definition?.requiresPairedSetup != true
            || factorySessions.contains(where: { $0.source == selected && $0.profile == profile })
            || availableScenePair
        else {
            status = "Controller setup needs a paired MIDI input and output."
            return
        }
        let replacement = profile.bindings(source: selected, playerDeck: playerDeck(source: selected))
        guard bindings.filter({ $0.source != selected }).count + replacement.count <= 256 else {
            status = "The controller mapping is full. Remove a mapping before applying this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        manualFactoryProfiles[selected] = profile
        factoryPadModes[selected] = profile.definition?.inputModes.map { .init(modes: $0) }
        setManualInputProtocol(profile.definition?.inputProtocol, source: selected)
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: replacement)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        channelShiftLayers[selected] = nil
        persist()
        if adoptsSceneProfile {
            setFactoryDisabled(false, profile: profile, source: selected)
            reconcileFactoryProfiles()
            return
        }
        if profile.definition?.inputProtocol?.setupInputMode != nil,
            let session = factorySessions.first(where: { $0.source == selected && $0.profile == profile }) {
            if !sendFactorySetup(session, starting: true) { failFactorySetup(session) }
            return
        }
        status = "Loaded the \(profile.rawValue) factory profile."
    }

    func applyFactoryFeedbackProfile(_ profile: ControllerFactoryProfile) {
        guard let destination = feedbackSelected else { return }
        feedbackBindings.removeAll { $0.destination == destination }
        feedbackBindings.append(contentsOf: profile.feedback(destination: destination, playerDeck: factorySessions.first(where: { $0.destination == destination })?.playerDeck))
        sentMIDIValues.removeAll()
        midiFeedbackEnabled = false
        persistFeedbackBindings()
        setMIDIFeedbackEnabled(false)
        feedbackStatus = "Loaded the \(profile.rawValue) light mappings. Enable MIDI feedback to send them."
    }

    func setEnabled(_ enabled: Bool) {
        preferences.set(enabled, forKey: "controllers.midi.enabled")
        if enabled { start() } else { stop() }
    }

    var shouldStartAutomatically: Bool {
        preferences.object(forKey: "controllers.midi.enabled") as? Bool != false
    }
    func select(_ id: Int32?) {
        learning = nil
        learningShifted = false
        let previous = selected
        guard let id, sources.contains(where: { $0.id == id }) else {
            selected = nil
            if originalZ1Bridge, previous != nil {
                resetBridge()
                reconnectInputs()
            }
            return
        }
        selected = id
        if activeInputIDs.insert(id).inserted { persistActiveInputs() }
        if originalZ1Bridge, previous != id {
            resetBridge()
            reconnectInputs()
        }
        connectInput(id)
        if connectedEndpoints[id] != nil, let source = sources.first(where: { $0.id == id }) {
            let fallback =
                !originalZ1Bridge ? protocolInputFailure.map { " · MIDI 2 conversion unavailable (\($0))" } ?? "" : ""
            status = "Input connected: \(source.name)\(fallback)"
        }
    }
    func setInputActive(_ id: Int32, active: Bool) {
        guard sources.contains(where: { $0.id == id }) else { return }
        if let identity = sources.first(where: { $0.id == id })?.identity,
            let profile = ControllerFactoryProfile.matching(identity.names)
        {
            setFactoryDisabled(!active, profile: profile, source: id)
            reconcileFactoryProfiles()
        }
        if active {
            activeInputIDs.insert(id)
            connectInput(id)
        } else {
            activeInputIDs.remove(id)
            disconnectInput(id)
        }
        persistActiveInputs()
        if id == selected, !active {
            learning = nil
            learningShifted = false
        }
    }
    func isInputActive(_ id: Int32) -> Bool {
        guard !timedFactoryInputs.contains(id) || factoryInputReadyTimes[id] != nil,
            nativeFactoryProtocols[id] == nil || setupInputDecoders[id]?.isReady == true else { return false }
        return activeInputIDs.contains(id) || factoryBindings[id] != nil
    }
    private func setFactoryDisabled(_ disabled: Bool, profile: ControllerFactoryProfile, source: Int32) {
        if profile.isPlayer {
            if disabled {
                disabledPlayerSources.insert(source)
            } else {
                disabledPlayerSources.remove(source)
                disabledFactoryProfiles.remove(profile)
            }
            preferences.set(
                try? JSONEncoder().encode(disabledPlayerSources.sorted()), forKey: "controllers.factory.disabledPlayers"
            )
        } else if disabled {
            disabledFactoryProfiles.insert(profile)
        } else {
            disabledFactoryProfiles.remove(profile)
        }
        preferences.set(disabledFactoryProfiles.map(\.rawValue).sorted(), forKey: "controllers.factory.disabled")
    }
    private func persistActiveInputs() {
        let data = try? JSONEncoder().encode(activeInputIDs.sorted())
        preferences.set(data, forKey: Self.activeInputsStorageKey)
    }
    private func inputProtocol(for source: Int32) -> ControllerProfileData.InputProtocol? {
        if let session = factorySessions.first(where: { $0.source == source }) {
            return session.profile.definition?.inputProtocol
        }
        if let input = nativeFactoryProtocols[source] { return input }
        return manualInputProtocols[source]
    }

    /**
     * Resets manual protocol state and reconnects only when the required input port changes.
     */
    private func setManualInputProtocol(_ input: ControllerProfileData.InputProtocol?, source: Int32) {
        deckBanks[source] = nil
        let wasConnected = connectedEndpoints[source] != nil
        manualInputProtocols[source] = input
        decoders[source] = nil
        smk25Decoders[source] = nil
        cdj101Decoders[source] = nil
        sr2Decoders[source] = nil
        keyLabDecoders[source] = nil
        p1NanoDecoders[source] = nil
        legacyUSBPlayerDecoders[source] = nil
        legacySinglePlayerDecoders[source] = nil
        orbitDecoders[source] = nil
        mpd218Decoders[source] = nil
        mpd2BitwigDecoders[source] = nil
        mc1000Decoders[source] = nil
        setupInputDecoders[source] = nil
        sc5000MDecoders[source] = nil
        prime4Decoders[source] = nil
        spectraDecoders[source] = nil
        kontrolOneDecoders[source] = nil
        if wasConnected, connectedPorts[source] != inputPort(for: source) {
            disconnectInput(source)
            connectInput(source)
        }
    }

    private func inputPort(for id: Int32) -> MIDIPortRef {
        if factoryBindings[id] != nil || inputProtocol(for: id) != nil || (originalZ1Bridge && id == selected) { return port }
        return protocolPort != 0 ? protocolPort : port
    }
    @discardableResult private func connectInput(_ id: Int32, startingFactorySetup: Bool = true) -> Bool {
        if connectedEndpoints[id] != nil { return true }
        let timedSession = factorySessions.first { $0.source == id && $0.profile.definition?.requiresPairedSetup == true }
        guard enabled, isInputActive(id) || timedSession != nil,
            let source = sources.first(where: { $0.id == id })
        else { return false }
        let inputPort = inputPort(for: id)
        let result = MIDIPortConnectSource(
            inputPort, source.reference, UnsafeMutableRawPointer(bitPattern: Int(source.reference)))
        guard result == noErr else {
            if id == selected { status = "The controller input could not connect (\(result))." }
            return false
        }
        connectedEndpoints[id] = source.reference
        connectedPorts[id] = inputPort
        sourceIDsByEndpoint[source.reference] = id
        decoders[id] = .init()
        smk25Decoders[id] = nil
        cdj101Decoders[id] = nil
        sr2Decoders[id] = nil
        keyLabDecoders[id] = nil
        p1NanoDecoders[id] = nil
        legacyUSBPlayerDecoders[id] = nil
        legacySinglePlayerDecoders[id] = nil
        orbitDecoders[id] = nil
        mpd218Decoders[id] = nil
        mpd2BitwigDecoders[id] = nil
        mc1000Decoders[id] = nil
        setupInputDecoders[id] = nil
        sc5000MDecoders[id] = nil
        prime4Decoders[id] = nil
        spectraDecoders[id] = nil
        kontrolOneDecoders[id] = nil
        bridgeDecoders[id] = .init()
        updatePollingInterval()
        if startingFactorySetup, let timedSession, factoryInputReadyTimes[id] == nil,
            setupInputDecoders[id]?.isReady != true {
            return beginFactorySetup(timedSession)
        }
        return true
    }
    private func disconnectInput(_ id: Int32) {
        pendingFactorySetups[id] = nil
        factoryInputReadyTimes[id] = nil
        let endpoint = connectedEndpoints.removeValue(forKey: id)
        if let endpoint {
            if let connectedPort = connectedPorts.removeValue(forKey: id) {
                MIDIPortDisconnectSource(connectedPort, endpoint)
            }
            sourceIDsByEndpoint[endpoint] = nil
        }
        decoders[id] = nil
        smk25Decoders[id] = nil
        cdj101Decoders[id] = nil
        sr2Decoders[id] = nil
        keyLabDecoders[id] = nil
        p1NanoDecoders[id] = nil
        legacyUSBPlayerDecoders[id] = nil
        legacySinglePlayerDecoders[id] = nil
        orbitDecoders[id] = nil
        mpd218Decoders[id] = nil
        mpd2BitwigDecoders[id] = nil
        mc1000Decoders[id] = nil
        setupInputDecoders[id] = nil
        sc5000MDecoders[id] = nil
        prime4Decoders[id] = nil
        spectraDecoders[id] = nil
        kontrolOneDecoders[id] = nil
        bridgeDecoders[id] = nil
        shiftLayers[id] = nil
        channelShiftLayers[id] = nil
        values = values.filter { !$0.key.hasPrefix("\(id)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(id)-") }
        takeoverStates = takeoverStates.filter { !$0.key.hasPrefix("\(id)-") }
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        releaseMomentaryActions(source: id, resetJogs: endpoint != nil || playerDeck(source: id) != nil)
        deckBanks[id] = nil
        updatePollingInterval()
    }
    private func reconnectInputs() {
        for id in Array(connectedEndpoints.keys) { disconnectInput(id) }
        for source in sources where isInputActive(source.id)
            || factorySessions.contains(where: { $0.source == source.id && $0.profile.definition?.requiresPairedSetup == true })
        { connectInput(source.id) }
    }
    func setBridgeMode(_ enabled: Bool) {
        originalZ1Bridge = enabled
        if enabled {
            midiFeedbackEnabled = false
            sentMIDIValues.removeAll()
        }
        learning = nil
        learningShifted = false
        resetBridge()
        reconnectInputs()
    }
    func setFeedbackDestination(_ id: Int32?) {
        feedbackSelected = id
        sentFeedback = []
        sentMIDIValues.removeAll()
        lastFeedbackTime = 0
        lastMIDIOutputTime = 0
        needsBridgeHello = true
        let destinationIsMapped =
            id.map { selectedID in feedbackBindings.contains { $0.destination == selectedID } } ?? false
        if !destinationIsMapped { midiFeedbackEnabled = false }
    }
    func setMIDIFeedbackEnabled(_ enabled: Bool) {
        if let destination = feedbackSelected,
            let session = factorySessions.first(where: { $0.destination == destination })
        {
            if enabled { disabledFactoryFeedback.remove(session.profile) }
            else { disabledFactoryFeedback.insert(session.profile) }
            preferences.set(disabledFactoryFeedback.map(\.rawValue).sorted(), forKey: "controllers.factory.feedbackDisabled")
            let profile = customFactoryFeedback[session.profile.rawValue]?.map { binding in
                ControllerFeedbackBinding(destination: destination, action: binding.action, kind: binding.kind,
                    channel: binding.channel, number: binding.number, offValue: binding.offValue,
                    onValue: binding.onValue, offUsesNoteOn: binding.offUsesNoteOn, targetDeck: binding.targetDeck, offNumber: binding.offNumber)
            }.map { $0.assigned(to: session.playerDeck) } ?? session.profile.feedback(destination: destination, playerDeck: session.playerDeck)
            factoryFeedback[destination] = profile
            sentFactoryValues[destination] = nil
        }
        midiFeedbackEnabled =
            enabled && feedbackOutputAvailable && feedbackSelected != nil && !selectedFeedbackBindings.isEmpty
        sentMIDIValues.removeAll()
    }
    func setFeedbackBinding(
        action: ControllerAction, kind: ControllerFeedbackKind, channel: UInt8, number: UInt8, offValue: UInt8,
        onValue: UInt8
    ) {
        guard let destination = feedbackSelected, channel < 16, number < 128, offValue < 128, onValue < 128,
            action.supportsFeedback, kind == .control || action.isButton
        else { return }
        let wasEnabled = isSelectedFeedbackEnabled
        if !feedbackBindings.contains(where: { $0.destination == destination }),
            let factory = factoryFeedback[destination]
        {
            guard feedbackBindings.count + factory.count <= 128 else {
                feedbackStatus = "The controller feedback mapping is full."
                return
            }
            feedbackBindings.append(contentsOf: factory)
        }
        if !feedbackBindings.contains(where: { $0.destination == destination && $0.action == action && ($0.targetDeck == nil || $0.targetDeck == action.deck) }),
            feedbackBindings.count >= 128
        {
            return
        }
        feedbackBindings.removeAll { $0.destination == destination && $0.action == action && ($0.targetDeck == nil || $0.targetDeck == action.deck) }
        feedbackBindings.append(
            .init(
                destination: destination, action: action, kind: kind, channel: channel, number: number,
                offValue: offValue, onValue: onValue))
        feedbackBindings.sort { $0.id < $1.id }
        persistFeedbackBindings()
        setMIDIFeedbackEnabled(wasEnabled)
        sentMIDIValues.removeAll()
    }
    func applyDDJFLX4FeedbackProfile() {
        guard let destination = feedbackSelected else {
            feedbackStatus = "Choose the DDJ-FLX4 MIDI output before loading status feedback."
            return
        }
        let completeProfile = Self.ddjFLX4FeedbackBindings(destination: destination)
        let actions = completeProfile.map(\.action)
        feedbackBindings.removeAll { $0.destination == destination && actions.contains($0.action) }
        feedbackBindings.append(contentsOf: completeProfile)
        feedbackBindings.sort { $0.id < $1.id }
        sentMIDIValues.removeAll()
        midiFeedbackEnabled = false
        persistFeedbackBindings()
        feedbackStatus =
            "Loaded DDJ-FLX4 play, sync, headphone-cue and Hot Cue light mappings. Enable MIDI feedback to send them."
    }
    func applyDDJREV1FeedbackProfile() {
        guard let destination = feedbackSelected else {
            feedbackStatus = "Choose a DDJ-REV1 MIDI output before loading status feedback."
            return
        }
        let completeProfile = Self.ddjREV1FeedbackBindings(destination: destination)
        let actions = completeProfile.map(\.action)
        feedbackBindings.removeAll { $0.destination == destination && actions.contains($0.action) }
        feedbackBindings.append(contentsOf: completeProfile)
        feedbackBindings.sort { $0.id < $1.id }
        sentMIDIValues.removeAll()
        midiFeedbackEnabled = false
        persistFeedbackBindings()
        feedbackStatus =
            "Loaded DDJ-REV1 play, sync, headphone-cue and Hot Cue light mappings. Enable MIDI feedback to send them."
    }
    func applyDDJREV5FeedbackProfile() {
        guard let destination = feedbackSelected else {
            feedbackStatus = "Choose a DDJ-REV5 MIDI output before loading status feedback."
            return
        }
        let completeProfile = Self.ddjREV5FeedbackBindings(destination: destination)
        let actions = completeProfile.map(\.action)
        feedbackBindings.removeAll { $0.destination == destination && actions.contains($0.action) }
        feedbackBindings.append(contentsOf: completeProfile)
        feedbackBindings.sort { $0.id < $1.id }
        sentMIDIValues.removeAll()
        midiFeedbackEnabled = false
        persistFeedbackBindings()
        feedbackStatus =
            "Loaded DDJ-REV5 play, sync, headphone-cue and Hot Cue light mappings. Enable MIDI feedback to send them."
    }
    func applyDDJFLX10FeedbackProfile() {
        guard let destination = feedbackSelected else {
            feedbackStatus = "Choose a DDJ-FLX10 MIDI output before loading status feedback."
            return
        }
        let completeProfile = Self.ddjFLX10FeedbackBindings(destination: destination)
        let actions = completeProfile.map(\.action)
        feedbackBindings.removeAll { $0.destination == destination && actions.contains($0.action) }
        feedbackBindings.append(contentsOf: completeProfile)
        feedbackBindings.sort { $0.id < $1.id }
        sentMIDIValues.removeAll()
        midiFeedbackEnabled = false
        persistFeedbackBindings()
        feedbackStatus =
            "Loaded DDJ-FLX10 play, sync, headphone-cue and Hot Cue light mappings. Enable MIDI feedback to send them."
    }
    func applyDDJ1000FeedbackProfile() {
        guard let destination = feedbackSelected else {
            feedbackStatus = "Choose a DDJ-1000 MIDI output before loading status feedback."
            return
        }
        let completeProfile = Self.ddj1000FeedbackBindings(destination: destination)
        let actions = completeProfile.map(\.action)
        feedbackBindings.removeAll { $0.destination == destination && actions.contains($0.action) }
        feedbackBindings.append(contentsOf: completeProfile)
        feedbackBindings.sort { $0.id < $1.id }
        sentMIDIValues.removeAll()
        midiFeedbackEnabled = false
        persistFeedbackBindings()
        feedbackStatus =
            "Loaded DDJ-1000 core light mappings. Enable MIDI feedback to send them."
    }
    static func ddj1000FeedbackBindings(destination: Int32) -> [ControllerFeedbackBinding] {
        ControllerFactoryProfile.ddj1000.feedback(destination: destination)
    }
    static func ddjREV5FeedbackBindings(destination: Int32) -> [ControllerFeedbackBinding] {
        let profile: [ControllerFeedbackBinding] = [
            .init(
                destination: destination, action: .playA, kind: .note, channel: 0, number: 11, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .syncA, kind: .note, channel: 0, number: 9, offValue: 0, onValue: 127,
                offUsesNoteOn: true),
            .init(
                destination: destination, action: .cueA, kind: .note, channel: 0, number: 7, offValue: 0, onValue: 127,
                offUsesNoteOn: true),
            .init(
                destination: destination, action: .playB, kind: .note, channel: 1, number: 11, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .syncB, kind: .note, channel: 1, number: 9, offValue: 0, onValue: 127,
                offUsesNoteOn: true),
            .init(
                destination: destination, action: .cueB, kind: .note, channel: 1, number: 7, offValue: 0, onValue: 127,
                offUsesNoteOn: true),
        ]
        var completeProfile = profile
        for (padChannel, padActions) in [
            (
                UInt8(7),
                [
                    ControllerAction.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A,
                    .hotcue8A,
                ]
            ),
            (
                UInt8(9),
                [
                    ControllerAction.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B,
                    .hotcue8B,
                ]
            ),
        ] {
            for (number, action) in padActions.enumerated() {
                completeProfile.append(
                    .init(
                        destination: destination, action: action, kind: .note, channel: padChannel,
                        number: UInt8(number), offValue: 0, onValue: 127, offUsesNoteOn: true))
            }
        }
        return completeProfile
    }
    static func ddjFLX10FeedbackBindings(destination: Int32) -> [ControllerFeedbackBinding] {
        ControllerFactoryProfile.flx10.feedback(destination: destination)
    }
    static func ddjREV1FeedbackBindings(destination: Int32) -> [ControllerFeedbackBinding] {
        let profile: [ControllerFeedbackBinding] = [
            .init(
                destination: destination, action: .playA, kind: .note, channel: 0, number: 11, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .syncA, kind: .note, channel: 0, number: 88, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .cueA, kind: .note, channel: 0, number: 84, offValue: 0, onValue: 127,
                offUsesNoteOn: true),
            .init(
                destination: destination, action: .playB, kind: .note, channel: 1, number: 11, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .syncB, kind: .note, channel: 1, number: 88, offValue: 0,
                onValue: 127, offUsesNoteOn: true),
            .init(
                destination: destination, action: .cueB, kind: .note, channel: 1, number: 84, offValue: 0, onValue: 127,
                offUsesNoteOn: true),
        ]
        var completeProfile = profile
        for (padChannel, padActions) in [
            (
                UInt8(7),
                [
                    ControllerAction.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A,
                    .hotcue8A,
                ]
            ),
            (
                UInt8(9),
                [
                    ControllerAction.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B,
                    .hotcue8B,
                ]
            ),
        ] {
            for (number, action) in padActions.enumerated() {
                completeProfile.append(
                    .init(
                        destination: destination, action: action, kind: .note, channel: padChannel,
                        number: UInt8(number), offValue: 0, onValue: 127, offUsesNoteOn: true))
            }
        }
        return completeProfile
    }
    func removeFeedbackBinding(_ action: ControllerAction) {
        guard let destination = feedbackSelected else { return }
        feedbackBindings.removeAll { $0.destination == destination && $0.action == action && ($0.targetDeck == nil || $0.targetDeck == action.deck) }
        if selectedFeedbackBindings.isEmpty { midiFeedbackEnabled = false }
        sentMIDIValues.removeAll()
        persistFeedbackBindings()
    }
    func feedbackBindingName(_ action: ControllerAction) -> String {
        guard let binding = selectedFeedbackBindings.first(where: { $0.action == action && ($0.targetDeck == nil || $0.targetDeck == action.deck) }) else { return "Unassigned" }
        return "\(binding.kind.title) \(binding.number) · channel \(Int(binding.channel) + 1)"
    }
    private func resetBridge(requestHello: Bool = true) {
        bridgeDecoders.removeAll()
        bridgeConnected = false
        pendingFeedback = nil
        sentFeedback = []
        needsBridgeHello = requestHello
        bridgeStatus = "No Z1 bridge report received."
        onBridgeReset?()
    }
    func queueZ1Feedback(_ bytes: [UInt8]) {
        guard enabled, originalZ1Bridge, bridgeConnected, bytes.count == 22 else { return }
        pendingFeedback = bytes
    }
    private func receiveBridge(_ frame: ControllerBridgeFrame) {
        switch frame.kind {
        case .z1Input:
            guard let report = try? Z1InputReport(bytes: frame.payload) else {
                bridgeStatus = "Rejected an invalid Z1 report."
                return
            }
            if !bridgeConnected {
                bridgeStatus = "Z1 input received. Select the feedback output to request calibration."
            }
            bridgeConnected = true
            lastInput = "Original Z1 control report received."
            onZ1Report?(report)
        case .z1Calibration:
            guard let calibration = try? Z1CrossfaderCalibration(featureD2: frame.payload) else {
                onBridgeReset?()
                bridgeStatus = "Z1 calibration is invalid. Crossfader input stays disabled."
                return
            }
            bridgeConnected = true
            onZ1Calibration?(calibration)
            bridgeStatus = "Z1 bridge calibration received."
        case .z1Status:
            switch frame.payload[0] {
            case 0:
                resetBridge(requestHello: false)
                bridgeStatus = "The Z1 disconnected from the bridge."
            case 1:
                resetBridge(requestHello: false)
                bridgeConnected = true
                bridgeStatus = "Z1 connected. Waiting for calibration."
            case 2:
                onBridgeReset?()
                bridgeConnected = true
                bridgeStatus = "Z1 controls connected. Crossfader waits for calibration."
            default: break
            }
        case .z1Output, .s4MK3Input, .s4MK3Lights, .s4MK3Ring, .s4MK3Status,
            .modularInput, .modularLights, .modularStatus, .s2MK1Report, .s2MK1Lights, .s4MK1Report, .s4MK1Lights, .factoryInput, .factoryLights, .factoryScreen, .factoryScreenContent, .x1PatternScreen: break
        }
    }
    private func sendFeedback() {
        guard outputPort != 0, let destination = destinations.first(where: { $0.id == feedbackSelected }) else {
            return
        }
        if !originalZ1Bridge {
            sendMIDIFeedback(to: destination.reference)
            return
        }
        guard ProcessInfo.processInfo.systemUptime - lastFeedbackTime >= 1.0 / 30 else { return }
        if needsBridgeHello {
            if let hello = try? ControllerBridgeFrame(kind: .z1Status, payload: [3]),
                sendBridgeFrame(hello, destination: destination.reference)
            {
                needsBridgeHello = false
            }
            return
        }
        guard bridgeConnected, let payload = pendingFeedback, payload != sentFeedback,
            let frame = try? ControllerBridgeFrame(kind: .z1Output, payload: payload)
        else { return }
        if sendBridgeFrame(frame, destination: destination.reference) { sentFeedback = payload }
    }
    private func sendBridgeFrame(_ frame: ControllerBridgeFrame, destination: MIDIEndpointRef) -> Bool {
        let bytes = frame.encoded
        var list = MIDIPacketList()
        let start = MIDIPacketListInit(&list)
        _ = bytes.withUnsafeBufferPointer {
            MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, start, 0, bytes.count, $0.baseAddress!)
        }
        guard list.numPackets == 1 else { return false }
        let result = MIDISend(outputPort, destination, &list)
        lastFeedbackTime = ProcessInfo.processInfo.systemUptime
        if result != noErr { bridgeStatus = "Z1 feedback could not send (\(result))." }
        return result == noErr
    }
    private func sendMIDIFeedback(to destination: MIDIEndpointRef) {
        let now = ProcessInfo.processInfo.systemUptime
        guard midiFeedbackEnabled, now - lastMIDIOutputTime >= 1.0 / 30 else { return }
        lastMIDIOutputTime = now
        for binding in selectedFeedbackBindings {
            guard let value = lookupValue(binding.target), let message = binding.message(value: value) else { continue }
            guard sentMIDIValues[binding.id] != message else { continue }
            guard sendMIDIMessage(message, destination: destination) else { return }
            sentMIDIValues[binding.id] = message
        }
    }

    private func sendFactoryFeedback() {
        let now = ProcessInfo.processInfo.systemUptime
        guard outputPort != 0, now - lastFactoryOutputTime >= 1.0 / 30 else { return }
        lastFactoryOutputTime = now
        for (id, profile) in factoryFeedback {
            guard factoryFeedbackIsEnabled(id),
                !(id == feedbackSelected && midiFeedbackEnabled),
                let destination = destinations.first(where: { $0.id == id })
            else { continue }
            for binding in profile {
                guard let value = lookupValue(binding.target), let message = binding.message(value: value) else { continue }
                guard sentFactoryValues[id]?[binding.id] != message else { continue }
                guard sendMIDIMessage(message, destination: destination.reference) else { break }
                sentFactoryValues[id, default: [:]][binding.id] = message
            }
        }
    }
    private func sendMIDIMessage(_ bytes: [UInt8], destination: MIDIEndpointRef, duringSetup: Bool = false) -> Bool {
        guard ControllerProfileData.validSetupMessage(bytes) else { return false }
        if !duringSetup, let output = destinations.first(where: { $0.reference == destination }), !factoryOutputIsReady(output.id) {
            return false
        }
        var list = MIDIPacketList()
        let start = MIDIPacketListInit(&list)
        _ = bytes.withUnsafeBufferPointer {
            MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, start, 0, bytes.count, $0.baseAddress!)
        }
        guard list.numPackets == 1 else { return false }
        let result = MIDISend(outputPort, destination, &list)
        if result != noErr { feedbackStatus = "MIDI feedback could not send (\(result))." }
        return result == noErr
    }
    func clearBindings() {
        guard let selected else { return }
        releaseMomentaryActions(source: selected)
        if let session = factorySessions.first(where: { $0.source == selected }) {
            customFactoryInputs[factoryInputKey(session)] = nil
            preferences.set(try? JSONEncoder().encode(customFactoryInputs), forKey: "controllers.factory.customInputs")
            setFactoryDisabled(true, profile: session.profile, source: selected)
            reconcileFactoryProfiles()
        }
        setManualInputProtocol(nil, source: selected)
        bindings.removeAll { $0.source == selected }
        values.removeAll()
        valueStates.removeAll()
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        channelShiftLayers[selected] = nil
        persist()
    }
    func applyDDJFLX4Profile() {
        guard !originalZ1Bridge, let selected else {
            status = "Select a generic MIDI input before loading this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        let profile = Self.ddjFLX4Bindings(source: selected)
        setManualInputProtocol(nil, source: selected)
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        channelShiftLayers[selected] = nil
        persist()
        status =
            "Loaded the DDJ-FLX4 transport, mixer, Hot Cue, platter and wheel-side jog profile. Other lights are not mapped."
    }
    func applyDDJFLX10Profile() {
        guard !originalZ1Bridge, let selected else {
            status = "Select a generic MIDI input before loading this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        let profile = Self.ddjFLX10Bindings(source: selected)
        setManualInputProtocol(nil, source: selected)
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        channelShiftLayers[selected] = nil
        persist()
        status = "Loaded the DDJ-FLX10 core profile. Four decks require the app setting."
    }
    func applyDDJ1000Profile() {
        guard !originalZ1Bridge, let selected else {
            status = "Select a generic MIDI input before loading this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        let profile = Self.ddj1000Bindings(source: selected)
        setManualInputProtocol(nil, source: selected)
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        channelShiftLayers[selected] = nil
        persist()
        status = "Loaded the DDJ-1000 core profile. Four decks require the app setting."
    }
    static func ddj1000Bindings(source: Int32) -> [ControllerBinding] {
        ControllerFactoryProfile.ddj1000.bindings(source: source)
    }
    static func ddjFLX10Bindings(source: Int32) -> [ControllerBinding] {
        ControllerFactoryProfile.flx10.bindings(source: source)
    }
    func applyDDJREV1Profile() {
        guard !originalZ1Bridge, let selected else {
            status = "Select a generic MIDI input before loading this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        let profile = Self.ddjREV1Bindings(source: selected)
        setManualInputProtocol(nil, source: selected)
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        channelShiftLayers[selected] = nil
        persist()
        status =
            "Loaded the DDJ-REV1 transport, mixer, Hot Cue, loop and jog profile. Set the performance pads to Hot Cue mode."
    }
    func applyDDJREV5Profile() {
        guard !originalZ1Bridge, let selected else {
            status = "Select a generic MIDI input before loading this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        let profile = Self.ddjREV5Bindings(source: selected)
        setManualInputProtocol(nil, source: selected)
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingInputOwners.removeAll()
        pendingJogSources.removeAll()
        pendingValues.removeAll()
        pendingJogValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        channelShiftLayers[selected] = nil
        persist()
        status =
            "Loaded the DDJ-REV5 two-deck transport, mixer, Hot Cue, jog and Shift profile. Set both pad banks to Hot Cue mode."
    }
    static func ddjREV5Bindings(source: Int32) -> [ControllerBinding] {
        func binding(
            _ action: ControllerAction, kind: ControllerMIDIMessage.Kind, channel: UInt8, number: UInt8,
            encoding: ControllerMIDIEncoding = .absolute, shifted: Bool = false
        ) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number, parameter: nil, noteNumber: nil,
                action: action, encoding: encoding, inverted: false, shifted: shifted)
        }
        var profile: [ControllerBinding] = []
        for (channel, deck) in [(UInt8(0), "A"), (UInt8(1), "B")] {
            let play: ControllerAction = deck == "A" ? .playA : .playB
            let cuePreview: ControllerAction = deck == "A" ? .cuePreviewA : .cuePreviewB
            let headphoneCue: ControllerAction = deck == "A" ? .cueA : .cueB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            profile += [
                binding(play, kind: .note, channel: channel, number: 11),
                binding(cuePreview, kind: .note, channel: channel, number: 27),
                binding(headphoneCue, kind: .note, channel: channel, number: 7),
                binding(sync, kind: .note, channel: channel, number: 9),
                binding(deck == "A" ? .keylockA : .keylockB, kind: .note, channel: channel, number: 24, shifted: true),
                binding(deck == "A" ? .loopA : .loopB, kind: .note, channel: channel, number: 4),
                binding(deck == "A" ? .loopDownA : .loopDownB, kind: .note, channel: channel, number: 1),
                binding(
                    deck == "A" ? .loopDownA : .loopDownB, kind: .note, channel: channel, number: 16, shifted: true),
                binding(deck == "A" ? .loopUpA : .loopUpB, kind: .note, channel: channel, number: 3),
                binding(deck == "A" ? .loopUpA : .loopUpB, kind: .note, channel: channel, number: 18, shifted: true),
            ]
            let controls: [(ControllerAction, UInt8)] =
                deck == "A"
                ? [(.gainA, 4), (.highA, 7), (.midA, 11), (.lowA, 15), (.levelA, 19), (.tempoA, 5)]
                : [(.gainB, 4), (.highB, 7), (.midB, 11), (.lowB, 15), (.levelB, 19), (.tempoB, 5)]
            profile += controls.map {
                binding($0.0, kind: .control, channel: channel, number: $0.1, encoding: .paired14Bit)
            }
            let hotcues: [ControllerAction] =
                deck == "A"
                ? [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A]
                : [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B]
            let padChannel: UInt8 = deck == "A" ? 7 : 9
            profile += hotcues.enumerated().map {
                binding($0.element, kind: .note, channel: padChannel, number: UInt8($0.offset))
            }
            let jog: ControllerAction = deck == "A" ? .jogA : .jogB
            let jogTouch: ControllerAction = deck == "A" ? .jogTouchA : .jogTouchB
            let wheelJog: ControllerAction = deck == "A" ? .wheelJogA : .wheelJogB
            profile += [
                binding(jog, kind: .control, channel: channel, number: 34, encoding: .binaryOffset),
                binding(jog, kind: .control, channel: channel, number: 35, encoding: .binaryOffset),
                binding(jogTouch, kind: .note, channel: channel, number: 28),
                binding(wheelJog, kind: .control, channel: channel, number: 33, encoding: .binaryOffset),
                binding(wheelJog, kind: .control, channel: channel, number: 38, encoding: .binaryOffset, shifted: true),
            ]
        }
        profile += [
            binding(.crossfader, kind: .control, channel: 6, number: 31, encoding: .paired14Bit),
            binding(.master, kind: .control, channel: 6, number: 8, encoding: .paired14Bit),
            binding(.cueMix, kind: .control, channel: 6, number: 12, encoding: .paired14Bit),
            binding(.monitor, kind: .control, channel: 6, number: 13, encoding: .paired14Bit),
            binding(.shift, kind: .note, channel: 6, number: 63),
        ]
        return profile
    }
    static func ddjREV1Bindings(source: Int32) -> [ControllerBinding] {
        func binding(
            _ action: ControllerAction, kind: ControllerMIDIMessage.Kind, channel: UInt8, number: UInt8,
            encoding: ControllerMIDIEncoding = .absolute
        ) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number, parameter: nil, noteNumber: nil,
                action: action, encoding: encoding, inverted: false, shifted: false)
        }
        var profile: [ControllerBinding] = []
        for (channel, deck) in [(UInt8(0), "A"), (UInt8(1), "B")] {
            let play: ControllerAction = deck == "A" ? .playA : .playB
            let cuePreview: ControllerAction = deck == "A" ? .cuePreviewA : .cuePreviewB
            let headphoneCue: ControllerAction = deck == "A" ? .cueA : .cueB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            profile += [
                binding(play, kind: .note, channel: channel, number: 11),
                binding(cuePreview, kind: .note, channel: channel, number: 12),
                binding(headphoneCue, kind: .note, channel: channel, number: 84),
                binding(sync, kind: .note, channel: channel, number: 88),
                binding(deck == "A" ? .loopA : .loopB, kind: .note, channel: channel, number: 20),
                binding(deck == "A" ? .loopDownA : .loopDownB, kind: .note, channel: channel, number: 18),
                binding(deck == "A" ? .loopUpA : .loopUpB, kind: .note, channel: channel, number: 19),
            ]
            let controls: [(ControllerAction, UInt8)] =
                deck == "A"
                ? [(.gainA, 4), (.highA, 7), (.midA, 11), (.lowA, 15), (.levelA, 19), (.tempoA, 0)]
                : [(.gainB, 4), (.highB, 7), (.midB, 11), (.lowB, 15), (.levelB, 19), (.tempoB, 0)]
            profile += controls.map {
                binding($0.0, kind: .control, channel: channel, number: $0.1, encoding: .paired14Bit)
            }
            let hotcues: [ControllerAction] =
                deck == "A"
                ? [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A]
                : [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B]
            let padChannel: UInt8 = deck == "A" ? 7 : 9
            profile += hotcues.enumerated().map {
                binding($0.element, kind: .note, channel: padChannel, number: UInt8($0.offset))
            }
            let jog: ControllerAction = deck == "A" ? .jogA : .jogB
            let jogTouch: ControllerAction = deck == "A" ? .jogTouchA : .jogTouchB
            let wheelJog: ControllerAction = deck == "A" ? .wheelJogA : .wheelJogB
            profile += [
                binding(jog, kind: .control, channel: channel, number: 34, encoding: .binaryOffset),
                binding(jog, kind: .control, channel: channel, number: 35, encoding: .binaryOffset),
                binding(jogTouch, kind: .note, channel: channel, number: 54),
                binding(wheelJog, kind: .control, channel: channel, number: 33, encoding: .binaryOffset),
                binding(wheelJog, kind: .control, channel: channel, number: 38, encoding: .binaryOffset),
            ]
        }
        profile += [
            binding(.crossfader, kind: .control, channel: 6, number: 31, encoding: .paired14Bit),
            binding(.master, kind: .control, channel: 6, number: 8, encoding: .paired14Bit),
            binding(.cueMix, kind: .control, channel: 6, number: 12, encoding: .paired14Bit),
            binding(.monitor, kind: .control, channel: 6, number: 13, encoding: .paired14Bit),
            binding(.shift, kind: .note, channel: 6, number: 63),
        ]
        return profile
    }
    func bindingName(_ action: ControllerAction) -> String {
        let assigned = selected.map { inputBindings(source: $0).filter { $0.action == action } } ?? []
        guard !assigned.isEmpty else { return "Unassigned" }
        return assigned.sorted { !$0.isShifted && $1.isShifted }.map { binding in
            let layer = (binding.targetDeck.map { "Deck " + $0.rawValue.uppercased() + " · " } ?? "") + (binding.isShifted ? "Shift" : "Base")
            let reversed = binding.inverted == true ? " · reversed" : ""
            let parameterLabel = binding.kind == .program ? "bank" : "parameter"
            let parameter = binding.parameter.map { " · \(parameterLabel) \($0)" } ?? ""
            let note = binding.noteNumber.map { " · note \($0)" } ?? ""
            return
                "\(layer): \(binding.kind.rawValue) \(binding.number)\(parameter)\(note) · group \(Int(binding.umpGroup) + 1), ch \(Int(binding.channel) + 1) · \(binding.mode.title)\(reversed)"
        }.joined(separator: " / ")
    }
    private func bindingStateKey(source: Int32, action: ControllerAction, shifted: Bool, group: UInt8 = 0, deck: DeckID? = nil) -> String {
        "\(source)-\(group)-\(action.rawValue)-\(shifted ? 1 : 0)-\(deck?.rawValue ?? "default")"
    }
    private func bindingValueKey(_ binding: ControllerBinding) -> String {
        bindingStateKey(source: binding.source, action: binding.action, shifted: binding.isShifted,
            group: binding.umpGroup, deck: binding.targetDeck) + "-" + bindingTakeoverKey(binding)
    }
    private func bindingTakeoverKey(_ binding: ControllerBinding) -> String {
        "\(binding.source)-\(binding.umpGroup)-\(binding.channel)-\(binding.kind.rawValue)-\(binding.number)-\(binding.parameter ?? 0)-\(binding.noteNumber ?? 0)-\(binding.isShifted ? 1 : 0)" + (binding.lowNumber.map { "-\($0)" } ?? "")
    }
    private func persist() {
        bindingCount = bindings.count
        takeoverStates.removeAll()
        if let data = try? JSONEncoder().encode(bindings) { preferences.set(data, forKey: Self.storageKey) }
        manualFactoryProfiles = manualFactoryProfiles.filter { source, _ in bindings.contains { $0.source == source } }
        if let data = try? JSONEncoder().encode(manualFactoryProfiles) {
            preferences.set(data, forKey: Self.manualProfilesStorageKey)
        }
        manualInputProtocols = manualInputProtocols.filter { source, _ in bindings.contains { $0.source == source } }
        if let data = try? JSONEncoder().encode(manualInputProtocols) {
            preferences.set(data, forKey: Self.inputProtocolsStorageKey)
        }
        rememberFactoryOverrides()
    }
    private func releaseMomentaryActions(source: Int32? = nil, resetJogs: Bool = true, decks: Set<DeckID>? = nil) {
        for target in Array(activeMomentaryInputs.keys) {
            if let decks, !decks.contains(target.deck ?? target.action.deck) { continue }
            guard var inputs = activeMomentaryInputs[target] else { continue }
            let wasActive = !inputs.isEmpty
            if let source { inputs = inputs.filter { $0.source != source } } else { inputs.removeAll() }
            activeMomentaryInputs[target] = inputs.isEmpty ? nil : inputs
            if wasActive && inputs.isEmpty { sendAction(target, value: 0) }
        }
        guard resetJogs else { return }
        let mapped = source.map { inputBindings(source: $0).filter { $0.action.isJog }.map(\.target) } ?? []
        let targets: Set<ControllerActionTarget> = source == nil
            ? Set(DeckID.allCases.map { .init($0.leftSide ? .wheelJogA : .wheelJogB, deck: $0) })
            : Set(mapped.map { target in
                let deck = target.deck ?? target.action.deck
                return .init(deck.leftSide ? .wheelJogA : .wheelJogB, deck: deck)
            })
        for target in targets where decks?.contains(target.deck ?? target.action.deck) ?? true {
            sendAction(target, value: 0.5)
        }
    }
    private func persistFeedbackBindings() {
        if let data = try? JSONEncoder().encode(feedbackBindings) {
            preferences.set(data, forKey: Self.feedbackStorageKey)
        }
        rememberFactoryOverrides()
    }

    private func rememberFactoryOverrides() {
        for session in factorySessions {
            let input = bindings.filter { $0.source == session.source }
            if !input.isEmpty { customFactoryInputs[factoryInputKey(session)] = input }
            if let destination = session.destination {
                let output = feedbackBindings.filter { $0.destination == destination }
                if !output.isEmpty { customFactoryFeedback[session.profile.rawValue] = output }
            }
        }
        preferences.set(try? JSONEncoder().encode(customFactoryInputs), forKey: "controllers.factory.customInputs")
        preferences.set(try? JSONEncoder().encode(customFactoryFeedback), forKey: "controllers.factory.customFeedback")
    }

    private func factoryInputKey(_ session: ControllerFactorySession) -> String {
        session.profile.rawValue + (session.profile.isPlayer ? "#\(session.source)" : "")
    }

    /**
     * Applies a bounded byte frame through the active factory protocol or the ordinary MIDI decoder.
     */
    @discardableResult func receiveBytes(
        _ bytes: [UInt8], source: Int32, limit: Int = 256, timestamp: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) -> Int? {
        let nativeSetup = inputProtocol(for: source)?.setupInputMode != nil
            && factorySessions.contains { $0.source == source && $0.profile.definition?.inputProtocol?.setupInputMode != nil }
        guard isInputActive(source) || nativeSetup else { return 0 }
        if let ready = factoryInputReadyTimes[source], timestamp < ready { return 0 }
        guard bytes.count <= 4096, (0...256).contains(limit) else {
            stop()
            status = "Controller input overload. Reconnect to continue."
            return nil
        }
        if inputProtocol(for: source) == .smk25II {
            var decoder = smk25Decoders[source, default: .init()]
            let events = decoder.append(bytes)
            smk25Decoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .deckChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source, decks: Set(DeckID.primary))
                    resetInputValueStates(inputBindings(source: source).filter { $0.targetDeck != nil })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .ddjSR2 {
            var decoder = sr2Decoders[source, default: .init()]
            let events = decoder.append(bytes)
            sr2Decoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .bankChanged(let left):
                    let decks: Set<DeckID> = left ? [.a, .c] : [.b, .d]
                    flushPendingActions()
                    releaseMomentaryActions(source: source, decks: decks)
                    resetInputValueStates(inputBindings(source: source).filter {
                        $0.targetDeck.map { decks.contains($0) } == true
                    })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .mpd2Bitwig {
            var decoder = mpd2BitwigDecoders[source, default: .init()]
            let events = decoder.append(bytes)
            mpd2BitwigDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .padBankChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source)
                    resetInputValueStates(inputBindings(source: source).filter { $0.kind == .note })
                case .controlBankChanged(let channel):
                    flushPendingActions()
                    resetInputValueStates(inputBindings(source: source).filter {
                        $0.kind == .control && ($0.action.isButton || $0.channel == channel)
                    })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .mpd218Chroma {
            var decoder = mpd218Decoders[source, default: .init()]
            let events = decoder.append(bytes)
            mpd218Decoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .bankChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source)
                    resetInputValueStates(inputBindings(source: source).filter { $0.kind == .note })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .orbit {
            var decoder = orbitDecoders[source, default: .init()]
            let events = decoder.append(bytes)
            orbitDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .bankChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source)
                    resetInputValueStates(inputBindings(source: source))
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .legacySinglePlayer {
            var decoder = legacySinglePlayerDecoders[source, default: .init()]
            let events = decoder.append(bytes)
            legacySinglePlayerDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .controlsChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source, decks: [.a, .b])
                    resetInputValueStates(inputBindings(source: source))
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .legacyUSBPlayer {
            var decoder = legacyUSBPlayerDecoders[source, default: .init()]
            let events = decoder.append(bytes)
            legacyUSBPlayerDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .controlsChanged(let channel):
                    flushPendingActions()
                    if channel != 1 {
                        releaseMomentaryActions(source: source, resetJogs: false, decks: channel == 0 ? [.a] : [.b])
                    }
                    resetInputValueStates(inputBindings(source: source).filter { $0.channel == channel })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .mc1000 {
            var decoder = mc1000Decoders[source, default: .init()]
            let events = decoder.append(bytes)
            mc1000Decoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .controlsChanged(let left):
                    let decks: Set<DeckID> = left ? [.a, .c] : [.b, .d]
                    flushPendingActions()
                    releaseMomentaryActions(source: source, resetJogs: false, decks: decks)
                    resetInputValueStates(inputBindings(source: source).filter {
                        $0.targetDeck.map { decks.contains($0) } == true
                    })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .p1Nano {
            var decoder = p1NanoDecoders[source, default: .init()]
            let events = decoder.append(bytes)
            p1NanoDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .controlsChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source)
                    resetInputValueStates(inputBindings(source: source))
                }
            }
            return events.count
        }
        if let model = inputProtocol(for: source)?.setupInputMode {
            var decoder = setupInputDecoders[source, default: .init(mode: model)]
            let events = decoder.append(bytes)
            setupInputDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .request(let message):
                    guard let session = factorySessions.first(where: { $0.source == source }),
                        sendFactoryMessage(message, session: session, starting: true) else {
                        if let session = factorySessions.first(where: { $0.source == source }) { failFactorySetup(session) }
                        return nil
                    }
                case .sceneChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source, resetJogs: false)
                    resetInputValueStates(inputBindings(source: source).filter { $0.action != .shift })
                case .modeChanged(let ready): setupInputModeChanged(ready, source: source)
                case .message(let message): receive(message, source: source)
                }
            }
            if let request = setupInputDecoders[source]?.pendingRequest {
                guard let session = factorySessions.first(where: { $0.source == source }),
                    sendFactoryMessage(request, session: session, starting: true) else {
                    if let session = factorySessions.first(where: { $0.source == source }) { failFactorySetup(session) }
                    return nil
                }
                if setupInputDecoders[source]?.didSendPendingRequest(request) == true {
                    setupInputModeChanged(true, source: source)
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .denonPrime4 {
            var decoder = prime4Decoders[source, default: .init()]
            let events = decoder.append(bytes)
            prime4Decoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .controlsChanged(let left):
                    let decks: Set<DeckID> = left ? [.a, .c] : [.b, .d]
                    flushPendingActions()
                    releaseMomentaryActions(source: source, resetJogs: false, decks: decks)
                    resetInputValueStates(inputBindings(source: source).filter {
                        $0.action != .shift && $0.targetDeck.map { decks.contains($0) } == true
                    })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .sc5000M || inputProtocol(for: source) == .denonPrimePlayer {
            var decoder = sc5000MDecoders[source, default: .init()]
            let events = decoder.append(bytes)
            sc5000MDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .deckChanged, .padModeChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source, resetJogs: false)
                    resetInputValueStates(inputBindings(source: source).filter { $0.action != .shift })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .midiFighterSpectra {
            var decoder = spectraDecoders[source, default: .init()]
            let events = decoder.append(bytes)
            spectraDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .deckChanged, .bankChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source, resetJogs: false)
                    resetInputValueStates(inputBindings(source: source).filter {
                        event == .bankChanged || $0.channel < 4
                    })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .kontrolOne {
            var decoder = kontrolOneDecoders[source, default: .init()]
            let events = decoder.append(bytes)
            kontrolOneDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .deckChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source)
                    resetInputValueStates(inputBindings(source: source).filter { $0.action != .shift })
                }
            }
            return events.count
        }
        if inputProtocol(for: source) == .keyLabMKI {
            var decoder = keyLabDecoders[source, default: .init()]
            let events = decoder.append(bytes, timestamp: timestamp)
            keyLabDecoders[source] = decoder
            guard events.count <= limit else {
                stop()
                status = "Controller input overload. Reconnect to continue."
                return nil
            }
            for event in events {
                switch event {
                case .message(let message): receive(message, source: source)
                case .deckChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source)
                    resetInputValueStates(inputBindings(source: source).filter { $0.channel < 4 })
                case .padLayerChanged:
                    flushPendingActions()
                    releaseMomentaryActions(source: source, resetJogs: false)
                    resetInputValueStates(inputBindings(source: source).filter {
                        $0.kind == .note && (64...71).contains($0.number)
                    })
                }
            }
            return events.count
        }
        let messages: [ControllerMIDIMessage]
        if inputProtocol(for: source) == .cdj101 {
            var decoder = cdj101Decoders[source, default: .init()]
            messages = decoder.append(bytes, timestamp: timestamp)
            cdj101Decoders[source] = decoder
        } else {
            var decoder = decoders[source, default: .init()]
            messages = decoder.append(bytes)
            decoders[source] = decoder
        }
        guard messages.count <= limit else {
            stop()
            status = "Controller input overload. Reconnect to continue."
            return nil
        }
        for message in messages { receive(message, source: source) }
        return messages.count
    }

    private func drain() {
        let (frames, overflow, refresh) = inbox.take()
        if overflow {
            stop()
            status = "Controller input overflow. Input disconnected; reconnect to continue."
            return
        }
        if refresh { refreshSources() }
        advanceFactorySetups()
        var processed = 0
        for frame in frames {
            guard let sourceID = sourceIDsByEndpoint[frame.source] else { continue }
            if let ready = factoryInputReadyTimes[sourceID], frame.timestamp < ready { continue }
            if originalZ1Bridge, sourceID == selected {
                guard case .bytes(let bytes) = frame.payload else { continue }
                var decoder = bridgeDecoders[sourceID, default: .init()]
                let reports = decoder.append(bytes)
                bridgeDecoders[sourceID] = decoder
                processed += reports.count
                guard processed <= 256 else {
                    stop()
                    status = "Controller input overload. Reconnect to continue."
                    return
                }
                for report in reports { receiveBridge(report) }
                continue
            }
            let messages: [ControllerMIDIMessage]
            switch frame.payload {
            case .bytes(let bytes):
                guard let count = receiveBytes(bytes, source: sourceID, limit: 256 - processed, timestamp: frame.timestamp) else { return }
                processed += count
                continue
            case .messages(let input):
                guard inputProtocol(for: sourceID) == nil else { continue }
                messages = input
            }
            processed += messages.count
            guard processed <= 256 else {
                stop()
                status = "Controller input overload. Input disconnected; reconnect to continue."
                return
            }
            for message in messages { receive(message, source: sourceID) }
        }
        flushPendingActions()
        sendFeedback()
        sendFactoryFeedback()
    }

    /**
     * Applies the latest coalesced controls within the current deck capacity.
     */
    func flushPendingActions() {
        let pending = pendingValues
        let jogs = pendingJogValues
        pendingInputOwners.removeAll(keepingCapacity: true)
        pendingJogSources.removeAll(keepingCapacity: true)
        pendingValues.removeAll(keepingCapacity: true)
        pendingJogValues.removeAll(keepingCapacity: true)
        for (target, value) in pending { sendAction(target, value: value, jog: jogs[target]) }
    }
    func receive(_ message: ControllerMIDIMessage, source sourceID: Int32) {
        let parameterLabel = message.kind == .program ? " bank" : " parameter"
        let parameter = message.parameter.map { "\(parameterLabel) \($0)" } ?? ""
        let note = message.noteNumber.map { " note \($0)" } ?? ""
        lastInput =
            "Input \(sourceID) · \(message.kind.rawValue) \(message.number)\(parameter)\(note) · channel \(Int(message.channel) + 1) · value \(message.value)"
        if let selected, selected == sourceID, activeInputIDs.contains(sourceID), let learning,
            message.kind != .note || !message.isNoteOff
        {
            guard learningEncoding.supportsLearning else {
                status = "Use the factory profile for this encoding."
                return
            }
            if learning == .shift {
                guard learningEncoding == .absolute, message.kind == .note || message.kind == .control else {
                    status = "Shift uses a momentary note or absolute Control Change button."
                    return
                }
            }
            guard message.kind != .program || learning.isButton else {
                status = "Program changes map to button actions. Use a knob, fader or pressure control for an amount."
                return
            }
            guard
                message.kind.isRelativeController
                    ? learningEncoding == .absolute && !learning.isButton
                    : learningEncoding == .absolute || (message.kind == .control && !learning.isButton)
            else {
                status = "Use a CC knob/encoder for this mode, or choose Knob / fader for buttons."
                return
            }
            guard !learningEncoding.isPairedCC || message.maximum <= 127 else {
                status = "MIDI 2.0 controls already use full resolution. Choose Knob / fader encoding."
                return
            }
            let number: UInt8
            if learningEncoding.isPairedCC {
                guard message.number < 64 else {
                    status = "A paired high-resolution CC uses controllers 0–31 and their low bytes 32–63."
                    return
                }
                number = message.number >= 32 ? message.number - 32 : message.number
            } else {
                number = message.number
            }
            let bindingIsShifted = learning == .shift ? false : learningShifted
            let sameInput: (ControllerBinding) -> Bool = { binding in
                binding.source == sourceID && binding.umpGroup == message.group && binding.kind == message.kind
                    && (binding.anyChannel == true || binding.channel == message.channel)
                    && binding.parameter == message.parameter
                    && binding.noteNumber == message.noteNumber
                    && (binding.number == number
                        || (self.learningEncoding.isPairedCC && binding.number == number + 32)
                        || (binding.lowControllerNumber == number))
            }
            let replacesShift = learning != .shift && inputBindings(source: sourceID).contains(where: {
                $0.action == .shift && sameInput($0)
            })
            if bindingIsShifted && replacesShift {
                status = "That control is assigned as Shift. Clear mappings before reusing it."
                return
            }
            if !bindings.contains(where: { $0.source == sourceID }), let factory = factoryBindings[sourceID] {
                guard bindings.count + factory.count < 256 else {
                    status = "The controller mapping is full."
                    self.learning = nil
                    return
                }
                bindings.append(contentsOf: factory)
            }
            bindings.removeAll {
                $0.source == sourceID
                    && (($0.action == learning && ($0.targetDeck == nil || $0.targetDeck == learning.deck) && $0.isShifted == bindingIsShifted)
                        || ($0.isShifted == bindingIsShifted && sameInput($0)) || (learning == .shift && sameInput($0)))
            }
            guard bindings.count < 256 else {
                status = "The controller mapping is full."
                self.learning = nil
                return
            }
            bindings.append(
                .init(
                    source: sourceID, group: message.group, channel: message.channel, kind: message.kind,
                    number: number, parameter: message.parameter, noteNumber: message.noteNumber, action: learning,
                    encoding: learningEncoding, inverted: learningInverted, shifted: bindingIsShifted))
            let key = bindingStateKey(
                source: sourceID, action: learning, shifted: bindingIsShifted, group: message.group)
            values[key] = message.normalized
            valueStates[key] = .init()
            shiftLayers[sourceID] = nil
            channelShiftLayers[sourceID] = nil
            self.learning = nil
            self.learningShifted = false
            persist()
            status =
                replacesShift
                ? "Saved \(learning.title). The old Shift mapping was removed." : "Saved \(learning.title)."
            return
        }
        receiveFactoryPadMode(message, source: sourceID)
        receiveFactoryBankChange(message, source: sourceID)
        let matches = inputBindings(source: sourceID).filter {
            $0.source == sourceID && $0.umpGroup == message.group && $0.kind == message.kind
                && ($0.releaseOnly != true || message.isNoteOff
                    || (message.kind == .control && message.maximum == 127 && message.value == 0))
                && (message.isNoteOff || $0.requiredMode == nil || factoryPadModes[sourceID]?.allows($0) == true)
                && ($0.anyChannel == true || $0.channel == message.channel) && $0.parameter == message.parameter
                && $0.noteNumber == message.noteNumber
                && ($0.number == message.number
                    || ($0.lowControllerNumber == message.number))
        }
        for binding in matches {
            let key = bindingValueKey(binding)
            var state = valueStates[key, default: .init()]
            let decoded = state.decode(message, encoding: binding.mode, number: binding.number, lowNumber: binding.lowNumber)
            valueStates[key] = state
            guard let decoded else { continue }
            if binding.requiresTouch == true {
                let touch = ControllerActionTarget(
                    binding.action.deck == .a ? .jogTouchA : .jogTouchB, deck: binding.targetDeck)
                guard activeMomentaryInputs[touch]?.contains(where: { $0.source == sourceID && $0.group == message.group }) == true else { continue }
            }
            var value: Double
            switch decoded {
            case .absolute(let absolute):
                value = binding.inverted == true && !binding.action.isButton ? 1 - absolute : absolute
            case .relative(let delta):
                guard !binding.action.isButton, delta != 0 else { continue }
                if binding.action.isLoopSizeEncoder {
                    value = 0.5 + min(63, max(-63, binding.inverted == true ? -delta : delta)) / 126
                } else if binding.action.isJog {
                    let previousDelta = ((pendingValues[binding.target] ?? 0.5) - 0.5) * 8
                    let signedDelta = binding.inverted == true ? -delta : delta
                    value = 0.5 + min(4, max(-4, previousDelta + signedDelta)) / 8
                } else if binding.action.isBrowserEncoder {
                    let previousDelta = ((pendingValues[binding.target] ?? 0.5) - 0.5) * 126
                    let signedDelta = binding.inverted == true ? -delta : delta
                    var accumulated = previousDelta + signedDelta
                    while abs(accumulated) > 63 {
                        let chunk = min(63, max(-63, accumulated))
                        sendAction(binding.target, value: 0.5 + chunk / 126)
                        accumulated -= chunk
                    }
                    value = 0.5 + accumulated / 126
                } else if let target = pendingValues[binding.target] ?? lookupValue(binding.target) {
                    guard target.isFinite else { continue }
                    let signedDelta = binding.inverted == true ? -delta : delta
                    let increment: Double
                    if let step = binding.directionStep {
                        guard step.isFinite, step > 0, step <= 0.1 else { continue }
                        increment = signedDelta > 0 ? step : -step
                    } else {
                        increment = signedDelta / 127
                    }
                    value = min(1, max(0, target + increment))
                } else {
                    continue
                }
            }
            if binding.action.isButton, !binding.mode.isContactGate, message.kind == .note, !message.isNoteOff, value == 0 { value = 1 }
            if let deck = binding.targetDeck, !availablePlayerDecks.contains(deck),
                !(binding.action.isButton && value == 0)
            { continue }
            let previous = values.updateValue(value, forKey: key)
            if binding.action == .shift {
                let layered = inputBindings(source: sourceID).filter { !$0.action.isButton && $0.layerIndependent != true }
                    .map { ($0, isShiftActive($0)) }
                flushPendingActions()
                let inputKey = shiftInputKey(binding)
                var shiftLayer = binding.shiftChannel.map { channelShiftLayers[sourceID]?[$0] ?? .init() }
                    ?? shiftLayers[sourceID, default: .init()]
                shiftLayer.update(input: inputKey, isPressed: value > 0)
                if let channel = binding.shiftChannel { channelShiftLayers[sourceID, default: [:]][channel] = shiftLayer }
                else { shiftLayers[sourceID] = shiftLayer }
                resetInputValueStates(layered.filter { isShiftActive($0.0) != $0.1 }.map { $0.0 })
                status = shiftLayer.isActive ? "Shift layer active." : "Base layer active."
                continue
            }
            guard binding.layerIndependent == true || binding.isShifted == isShiftActive(binding)
                || ((binding.action.isMomentary || binding.releaseOnly == true) && value == 0) else { continue }
            if binding.action.isLoopSizeEncoder {
                sendAction(binding.target, value: value)
                continue
            }
            if binding.action.isDirectState {
                sendAction(binding.target, value: value)
                continue
            }
            if binding.action.isMomentary {
                var inputs = activeMomentaryInputs[binding.target, default: []]
                let wasActive = !inputs.isEmpty
                let owner = MomentaryInput(source: sourceID, group: message.group, input: binding.holdInput)
                if value > 0 {
                    inputs.insert(owner)
                } else {
                    inputs.remove(owner)
                }
                activeMomentaryInputs[binding.target] = inputs.isEmpty ? nil : inputs
                if value > 0 && !wasActive {
                    sendAction(binding.target, value: value)
                } else if value == 0 && wasActive && inputs.isEmpty {
                    sendAction(binding.target, value: 0)
                }
                continue
            }
            if binding.action.isButton {
                if binding.releaseOnly == true {
                    resetInputValueStates(inputBindings(source: sourceID).filter { $0.target == binding.target })
                    continue
                }
                if message.kind == .program {
                    emitButton(binding.target, value: 1)
                    continue
                }
                if binding.pulse == true {
                    if value > 0 { emitButton(binding.target, value: value) }
                    continue
                }
                if previous == nil && message.kind != .note && binding.layerIndependent != true { continue }
                guard value > 0, (previous ?? 0) == 0 else { continue }
                emitButton(binding.target, value: value)
            } else {
                if !binding.action.isJog && !binding.action.isBrowserEncoder && binding.mode != .needlePosition
                    && binding.action != .seekA && binding.action != .seekB
                    && !message.kind.isRelativeController
                    && (binding.mode == .absolute || binding.mode == .paired14Bit || binding.mode == .cdjTempo
                        || binding.mode == .centreDetent || binding.mode == .centredPitch || binding.mode == .vci300Tempo || binding.mode == .vci100MK2Tempo || binding.mode == .readyTempo || binding.mode == .airTempo)
                {
                    let takeoverKey = bindingTakeoverKey(binding)
                    var takeover = takeoverStates[takeoverKey, default: .init()]
                    let wasPending = takeover.isPending
                    let shouldApply = takeover.shouldApply(input: value, target: lookupValue(binding.target))
                    takeoverStates[takeoverKey] = takeover
                    guard shouldApply else {
                        if !wasPending { status = "Move the control to its current value to take control." }
                        continue
                    }
                    if wasPending { status = "MIDI control took over." }
                }
                if binding.action.isJog {
                    switch decoded {
                    case .relative(let delta):
                        let previous: Double
                        if case .relative(let counts) = pendingJogValues[binding.target] { previous = counts }
                        else { previous = 0 }
                        let signedDelta = binding.inverted == true ? -delta : delta
                        let total = previous + signedDelta
                        pendingJogSources[binding.target, default: [:]][sourceID, default: 0] += signedDelta
                        pendingJogValues[binding.target] = .relative(total)
                    case .absolute:
                        pendingJogSources[binding.target] = nil
                        pendingJogValues[binding.target] = .absolute(value)
                    }
                }
                pendingInputOwners[binding.target] = sourceID
                pendingValues[binding.target] = value
            }
        }
    }

    private func isShiftActive(_ binding: ControllerBinding) -> Bool {
        if let channel = binding.shiftChannel { return channelShiftLayers[binding.source]?[channel]?.isActive ?? false }
        return shiftLayers[binding.source]?.isActive ?? false
    }

    private func shiftInputKey(_ binding: ControllerBinding) -> String {
        binding.shiftInput.map { "\(binding.source)-\(binding.umpGroup)-shift-\($0)" }
            ?? "\(binding.source)-\(binding.umpGroup)-\(binding.channel)-\(binding.kind.rawValue)-\(binding.number)-\(binding.parameter ?? 0)-\(binding.noteNumber ?? 0)"
    }

    private func receiveFactoryPadMode(_ message: ControllerMIDIMessage, source: Int32) {
        guard let mode = factoryPadModes[source]?.receive(message),
            let onValue = mode.onValue, let offValue = mode.offValue,
            let session = factorySessions.first(where: { $0.source == source }),
            let id = session.destination, let destination = destinations.first(where: { $0.id == id }) else { return }
        for number in mode.numbers {
            let active = factoryPadModes[source]?.isSelected(number, channel: mode.channel) == true
            let packet = [0x90 | mode.channel, number, active ? onValue : offValue]
            let sent = factoryPacketSender?(packet, id)
                ?? (outputPort != 0 && sendMIDIMessage(packet, destination: destination.reference))
            if !sent {
                feedbackStatus = "Controller pad lights could not update."
                break
            }
        }
    }

    /**
     * Resets contacts and pickup on a reported side. Explicit USB release reports also clear its Shift inputs.
     */
    private func receiveFactoryBankChange(_ message: ControllerMIDIMessage, source: Int32) {
        guard message.group == 0, message.maximum <= 127,
            let profile = manualFactoryProfiles[source] ?? factorySessions.first(where: { $0.source == source })?.profile,
            let change = profile.definition?.bankChanges?.first(where: {
                ($0.kind ?? .note) == message.kind && ($0.anyChannel == true || $0.channel == message.channel)
                    && ($0.number == message.number || (message.isNoteOff && $0.releaseNumber == message.number))
                    && (message.isNoteOff ? ($0.releaseShiftChannels != nil || $0.deckBank != nil)
                        : $0.anyPositive == true ? message.value > 0
                        : $0.onValue.map { Int($0) == message.value } ?? true)
            })
        else { return }
        let previousBindings = change.deckBank != nil ? inputBindings(source: source) : []
        var nextBankState: ControllerDeckBankState?
        if change.deckBank != nil {
            var state = deckBanks[source, default: .init()]
            let changed = state.receive(message, selector: change)
            guard changed else {
                deckBanks[source] = state
                return
            }
            nextBankState = state
        }
        let decks = Set(profile.isPlayer ? [playerDeck(source: source) ?? .a] : change.decks)
        flushPendingActions()
        releaseMomentaryActions(source: source, decks: decks)
        if let nextBankState { deckBanks[source] = nextBankState }
        let bindings = inputBindings(source: source)
        let layered = bindings.map { ($0, isShiftActive($0)) }
        if message.isNoteOff, let channels = change.releaseShiftChannels {
            for binding in bindings where binding.action == .shift
                && channels.contains(binding.shiftChannel ?? binding.channel)
            {
                let key = shiftInputKey(binding)
                if let channel = binding.shiftChannel {
                    channelShiftLayers[source]?[channel]?.update(input: key, isPressed: false)
                } else {
                    shiftLayers[source]?.update(input: key, isPressed: false)
                }
            }
        }
        let scoped = bindings.filter { binding in
            if let bank = change.deckBank { return binding.deckBank == bank }
            if let deck = binding.targetDeck { return decks.contains(deck) }
            return (binding.action.rawValue.hasSuffix("A") || binding.action.rawValue.hasSuffix("B"))
                && decks.contains(binding.action.deck)
        }
        let previousBank = change.deckBank.map { bank in previousBindings.filter { $0.deckBank == bank } } ?? []
        resetInputValueStates(scoped + previousBank + layered.filter { isShiftActive($0.0) != $0.1 }.map { $0.0 })
    }

    private func resetInputValueStates(_ scoped: [ControllerBinding]) {
        guard !scoped.isEmpty else { return }
        let valueKeys = Set(scoped.map { bindingValueKey($0) })
        let takeoverKeys = Set(scoped.map { bindingTakeoverKey($0) })
        values = values.filter { !valueKeys.contains($0.key) }
        valueStates = valueStates.filter { !valueKeys.contains($0.key) }
        takeoverStates = takeoverStates.filter { !takeoverKeys.contains($0.key) }
    }

    private func lookupValue(_ target: ControllerActionTarget) -> Double? {
        if let currentTargetValue { return currentTargetValue(target) }
        return currentValue?(target.action)
    }

    private func sendAction(_ target: ControllerActionTarget, value: Double, jog: ControllerMIDIValue? = nil) {
        if let deck = target.deck, !availablePlayerDecks.contains(deck),
            !(target.action.isMomentary && value == 0), !(target.action.isJog && value == 0.5)
        { return }
        if [.jogTouchA, .jogTouchB, .loadA, .loadB].contains(target.action) {
            let deck = target.deck ?? target.action.deck
            let jogs = pendingValues.keys.filter { $0.action.isJog && ($0.deck ?? $0.action.deck) == deck }
            for key in jogs {
                pendingInputOwners[key] = nil
                pendingJogSources[key] = nil
                if let pending = pendingValues.removeValue(forKey: key) {
                    sendAction(key, value: pending, jog: pendingJogValues.removeValue(forKey: key))
                }
            }
        }
        if target.action.isJog, let jog, let onJogAction { onJogAction(target, jog) }
        else if let onTargetAction { onTargetAction(target, value) }
        else { onAction?(target.action, value) }
    }

    private func emitButton(_ target: ControllerActionTarget, value: Double) {
        if target.action == .loadA || target.action == .loadB || target.action == .openGroup {
            for encoder in [ControllerAction.browse, .browseGroups] {
                let key = ControllerActionTarget(encoder)
                pendingInputOwners[key] = nil
                pendingJogSources[key] = nil
                if let pending = pendingValues.removeValue(forKey: key) { sendAction(key, value: pending) }
            }
        }
        sendAction(target, value: value)
    }
}
