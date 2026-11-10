import CoreMIDI
import Foundation
import Observation
import TDJCore

enum ControllerAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case playA, playB, syncA, syncB, keylockA, keylockB, cueA, cueB
    case shift
    case levelA, levelB, gainA, gainB, lowA, lowB, midA, midB, highA, highB
    case filterA, filterB, fxA, fxB, fxToggleA, fxToggleB, crossfader, cueMix
    case filterToggleA, filterToggleB, master, monitor, tempoA, tempoB
    case loopA, loopB, loopUpA, loopUpB, loopDownA, loopDownB, jumpBackA, jumpBackB, jumpForwardA, jumpForwardB
    case cueReturnA, cueReturnB, freezeA, freezeB
    case jogA, jogB, jogTouchA, jogTouchB, wheelJogA, wheelJogB
    case hotcue1A, hotcue2A, hotcue3A, hotcue4A, hotcue5A, hotcue6A, hotcue7A, hotcue8A
    case hotcue1B, hotcue2B, hotcue3B, hotcue4B, hotcue5B, hotcue6B, hotcue7B, hotcue8B
    var id: String { rawValue }
    var deck: DeckID { rawValue.hasSuffix("B") ? .b : .a }
    var title: String {
        if self == .shift { return "Shift layer (hold)" }
        if self == .crossfader { return "Crossfader" }
        if self == .cueMix { return "Headphone blend" }
        if self == .master { return "Master level" }
        if self == .monitor { return "Headphone level" }
        if let hotcueSlot { return "\(deck.rawValue.uppercased()) · Hotcue \(hotcueSlot + 1)" }
        let labels = [
            "play": "Play / Pause", "sync": "Sync", "keylock": "Key lock", "cue": "Headphone cue", "level": "Volume",
            "gain": "Gain", "low": "Low EQ", "mid": "Mid EQ", "high": "High EQ", "filter": "Filter",
            "filterToggle": "Filter on / off", "fx": "Effect amount", "fxToggle": "Effect on / off",
            "tempo": "Tempo ±8%", "loop": "Loop on / off", "loopUp": "Larger loop", "loopDown": "Smaller loop",
            "jumpBack": "Beat jump back", "jumpForward": "Beat jump forward", "cueReturn": "Cue return / set",
            "freeze": "Freeze", "jog": "Platter jog", "jogTouch": "Platter touch", "wheelJog": "Wheel-side jog",
        ]
        return "\(deck.rawValue.uppercased()) · \(labels[String(rawValue.dropLast())] ?? rawValue)"
    }
    var isButton: Bool {
        switch self {
        case .levelA, .levelB, .gainA, .gainB, .lowA, .lowB, .midA, .midB, .highA, .highB, .filterA, .filterB, .fxA,
            .fxB, .crossfader, .cueMix, .master, .monitor, .tempoA, .tempoB, .jogA, .jogB, .wheelJogA, .wheelJogB:
            false
        default: true
        }
    }
    var isMomentary: Bool {
        switch self {
        case .jogTouchA, .jogTouchB: true
        default: false
        }
    }
    var isJog: Bool { self == .jogA || self == .jogB || self == .wheelJogA || self == .wheelJogB }
    var hotcueSlot: Int? {
        guard rawValue.hasPrefix("hotcue"), let value = Int(rawValue.dropFirst(6).dropLast()) else { return nil }
        return value - 1
    }
    var supportsFeedback: Bool {
        switch self {
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
    let action: ControllerAction
    let encoding: ControllerMIDIEncoding?
    let inverted: Bool?
    let shifted: Bool?
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
    var id: String { "\(destination):\(action.rawValue)" }
    let destination: Int32
    let action: ControllerAction
    let kind: ControllerFeedbackKind
    let channel: UInt8
    let number: UInt8
    let offValue: UInt8
    let onValue: UInt8
    let offUsesNoteOn: Bool?

    init(
        destination: Int32, action: ControllerAction, kind: ControllerFeedbackKind, channel: UInt8, number: UInt8,
        offValue: UInt8, onValue: UInt8, offUsesNoteOn: Bool? = nil
    ) {
        self.destination = destination
        self.action = action
        self.kind = kind
        self.channel = channel
        self.number = number
        self.offValue = offValue
        self.onValue = onValue
        self.offUsesNoteOn = offUsesNoteOn
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
        return feedbackBindings.filter { $0.destination == feedbackSelected }
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
    @ObservationIgnored private var bridgeDecoders: [Int32: ControllerBridgeDecoder] = [:]
    @ObservationIgnored private var bridgeConnected = false
    @ObservationIgnored private var pendingFeedback: [UInt8]?
    @ObservationIgnored private var sentFeedback: [UInt8] = []
    @ObservationIgnored private var sentMIDIValues: [ControllerAction: [UInt8]] = [:]
    @ObservationIgnored private var activeMomentaryInputs: [ControllerAction: Set<Int32>] = [:]
    @ObservationIgnored private var lastMIDIOutputTime = 0.0
    @ObservationIgnored private var lastFeedbackTime = 0.0
    @ObservationIgnored private var needsBridgeHello = true
    @ObservationIgnored private var values: [String: Double] = [:]
    @ObservationIgnored private var valueStates: [String: ControllerMIDIValueState] = [:]
    @ObservationIgnored private var takeoverStates: [String: ControllerMIDITakeoverState] = [:]
    @ObservationIgnored private var pendingValues: [ControllerAction: Double] = [:]
    @ObservationIgnored private var shiftLayers: [Int32: ControllerShiftLayerState] = [:]
    @ObservationIgnored private var bindings: [ControllerBinding] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let inbox = ControllerMIDIInbox()
    private static let storageKey = "controllers.midiBindings.v1"
    private static let activeInputsStorageKey = "controllers.midiActiveInputs.v1"
    private static let feedbackStorageKey = "controllers.midiFeedback.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let saved = try? JSONDecoder().decode([ControllerBinding].self, from: data), saved.count <= 256
        {
            bindings = saved
        }
        if let data = UserDefaults.standard.data(forKey: Self.activeInputsStorageKey),
            let saved = try? JSONDecoder().decode([Int32].self, from: data), saved.count <= 64
        {
            activeInputIDs = Set(saved)
        }
        if let data = UserDefaults.standard.data(forKey: Self.feedbackStorageKey),
            let saved = try? JSONDecoder().decode([ControllerFeedbackBinding].self, from: data), saved.count <= 128,
            saved.allSatisfy({
                $0.channel < 16 && $0.number < 128 && $0.offValue < 128 && $0.onValue < 128
                    && $0.action.supportsFeedback && ($0.kind == .control || $0.action.isButton)
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
                        ? Array(UnsafeBufferPointer(start: bytes, count: count)) : Array(repeating: 0, count: 4097))
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
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.drain() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stop() {
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
        bridgeDecoders.removeAll()
        shiftLayers.removeAll()
        selected = nil
        enabled = false
        learning = nil
        learningShifted = false
        midiFeedbackEnabled = false
        protocolInputFailure = nil
        values.removeAll()
        valueStates.removeAll()
        takeoverStates.removeAll()
        pendingValues.removeAll()
        _ = inbox.take()
        sentMIDIValues.removeAll()
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
        return .init(id: id, reference: reference, name: name?.takeRetainedValue() as String? ?? "MIDI port")
    }
    func refreshSources() {
        sources = (0..<MIDIGetNumberOfSources()).compactMap { describe(MIDIGetSource($0)) }
        destinations = (0..<MIDIGetNumberOfDestinations()).compactMap { describe(MIDIGetDestination($0)) }
        #if os(iOS)
            sources.removeAll { BeatpadMIDIConnection.isBeatpad($0.reference) }
            destinations.removeAll { BeatpadMIDIConnection.isBeatpad($0.reference) }
        #endif
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
        for id in activeInputIDs where sourceIDs.contains(id) { connectInput(id) }
        if let feedbackSelected, !destinations.contains(where: { $0.id == feedbackSelected }) {
            self.feedbackSelected = nil
            sentFeedback = []
            sentMIDIValues.removeAll()
            midiFeedbackEnabled = false
        }
        if selected == nil {
            status =
                sources.isEmpty
                ? "No MIDI inputs found. Check the connection and MIDI mode." : "Choose the controller input to use."
        }
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
    func isInputActive(_ id: Int32) -> Bool { activeInputIDs.contains(id) }
    private func persistActiveInputs() {
        let data = try? JSONEncoder().encode(activeInputIDs.sorted())
        UserDefaults.standard.set(data, forKey: Self.activeInputsStorageKey)
    }
    private func inputPort(for id: Int32) -> MIDIPortRef {
        originalZ1Bridge && id == selected ? port : protocolPort != 0 ? protocolPort : port
    }
    private func connectInput(_ id: Int32) {
        guard enabled, activeInputIDs.contains(id), connectedEndpoints[id] == nil,
            let source = sources.first(where: { $0.id == id })
        else { return }
        let inputPort = inputPort(for: id)
        let result = MIDIPortConnectSource(
            inputPort, source.reference, UnsafeMutableRawPointer(bitPattern: Int(source.reference)))
        guard result == noErr else {
            if id == selected { status = "The controller input could not connect (\(result))." }
            return
        }
        connectedEndpoints[id] = source.reference
        connectedPorts[id] = inputPort
        sourceIDsByEndpoint[source.reference] = id
        decoders[id] = .init()
        bridgeDecoders[id] = .init()
    }
    private func disconnectInput(_ id: Int32) {
        guard let endpoint = connectedEndpoints.removeValue(forKey: id) else { return }
        if let connectedPort = connectedPorts.removeValue(forKey: id) {
            MIDIPortDisconnectSource(connectedPort, endpoint)
        }
        sourceIDsByEndpoint[endpoint] = nil
        decoders[id] = nil
        bridgeDecoders[id] = nil
        shiftLayers[id] = nil
        values = values.filter { !$0.key.hasPrefix("\(id)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(id)-") }
        takeoverStates = takeoverStates.filter { !$0.key.hasPrefix("\(id)-") }
        pendingValues.removeAll()
        releaseMomentaryActions(source: id)
    }
    private func reconnectInputs() {
        for id in Array(connectedEndpoints.keys) { disconnectInput(id) }
        for id in activeInputIDs { connectInput(id) }
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
        if !feedbackBindings.contains(where: { $0.destination == destination && $0.action == action }),
            feedbackBindings.count >= 128
        {
            return
        }
        feedbackBindings.removeAll { $0.destination == destination && $0.action == action }
        feedbackBindings.append(
            .init(
                destination: destination, action: action, kind: kind, channel: channel, number: number,
                offValue: offValue, onValue: onValue))
        feedbackBindings.sort { $0.id < $1.id }
        persistFeedbackBindings()
        sentMIDIValues[action] = nil
    }
    func applyDDJFLX4FeedbackProfile() {
        guard let destination = feedbackSelected else {
            feedbackStatus = "Choose the DDJ-FLX4 MIDI output before loading status feedback."
            return
        }
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
            "Loaded DDJ-1000 play, sync, headphone-cue and Hot Cue light mappings. Enable MIDI feedback to send them."
    }
    static func ddj1000FeedbackBindings(destination: Int32) -> [ControllerFeedbackBinding] {
        var profile: [ControllerFeedbackBinding] = []
        for (channel, padChannel, deck) in [(UInt8(0), UInt8(7), "A"), (UInt8(1), UInt8(9), "B")] {
            let play: ControllerAction = deck == "A" ? .playA : .playB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            let cue: ControllerAction = deck == "A" ? .cueA : .cueB
            profile += [
                .init(
                    destination: destination, action: play, kind: .note, channel: channel, number: 11, offValue: 0,
                    onValue: 127, offUsesNoteOn: true),
                .init(
                    destination: destination, action: sync, kind: .note, channel: channel, number: 92, offValue: 0,
                    onValue: 127, offUsesNoteOn: true),
                .init(
                    destination: destination, action: cue, kind: .note, channel: channel, number: 84, offValue: 0,
                    onValue: 127, offUsesNoteOn: true),
            ]
            let hotcues: [ControllerAction] =
                deck == "A"
                ? [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A]
                : [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B]
            profile += hotcues.enumerated().map {
                .init(
                    destination: destination, action: $0.element, kind: .note, channel: padChannel,
                    number: UInt8($0.offset), offValue: 0, onValue: 127, offUsesNoteOn: true)
            }
        }
        return profile
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
                UInt8(8),
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
        feedbackBindings.removeAll { $0.destination == destination && $0.action == action }
        if selectedFeedbackBindings.isEmpty { midiFeedbackEnabled = false }
        sentMIDIValues[action] = nil
        persistFeedbackBindings()
    }
    func feedbackBindingName(_ action: ControllerAction) -> String {
        guard let binding = selectedFeedbackBindings.first(where: { $0.action == action }) else { return "Unassigned" }
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
            .modularInput, .modularLights, .modularStatus, .s2MK1Report, .s2MK1Lights, .s4MK1Report, .s4MK1Lights, .factoryInput, .factoryLights, .factoryScreen, .factoryScreenContent: break
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
            guard let value = currentValue?(binding.action), value.isFinite else { continue }
            let bounded = min(1, max(0, value))
            let outputValue =
                binding.action.isButton
                ? (bounded > 0 ? binding.onValue : binding.offValue) : UInt8((bounded * 127).rounded())
            let status: UInt8
            switch binding.kind {
            case .control: status = 0xB0 | binding.channel
            case .note: status = (bounded > 0 || binding.offUsesNoteOn == true ? 0x90 : 0x80) | binding.channel
            }
            let message = [status, binding.number, outputValue]
            guard sentMIDIValues[binding.action] != message else { continue }
            guard sendMIDIMessage(message, destination: destination) else { return }
            sentMIDIValues[binding.action] = message
        }
    }
    private func sendMIDIMessage(_ bytes: [UInt8], destination: MIDIEndpointRef) -> Bool {
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
        bindings.removeAll { $0.source == selected }
        values.removeAll()
        valueStates.removeAll()
        pendingValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        persist()
    }
    func applyDDJFLX4Profile() {
        guard !originalZ1Bridge, let selected else {
            status = "Select a generic MIDI input before loading this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        func binding(
            _ action: ControllerAction, kind: ControllerMIDIMessage.Kind, channel: UInt8, number: UInt8,
            encoding: ControllerMIDIEncoding = .absolute
        ) -> ControllerBinding {
            .init(
                source: selected, group: 0, channel: channel, kind: kind, number: number, parameter: nil,
                noteNumber: nil, action: action, encoding: encoding, inverted: false, shifted: false)
        }
        var profile: [ControllerBinding] = []
        for (channel, deck) in [(UInt8(0), "A"), (UInt8(1), "B")] {
            let play: ControllerAction = deck == "A" ? .playA : .playB
            let cue: ControllerAction = deck == "A" ? .cueReturnA : .cueReturnB
            let headphoneCue: ControllerAction = deck == "A" ? .cueA : .cueB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            profile += [
                binding(play, kind: .note, channel: channel, number: 11),
                binding(cue, kind: .note, channel: channel, number: 12),
                binding(headphoneCue, kind: .note, channel: channel, number: 84),
                binding(sync, kind: .note, channel: channel, number: 88),
            ]
            let controls: [(ControllerAction, UInt8)] =
                deck == "A"
                ? [(.gainA, 4), (.highA, 7), (.midA, 11), (.lowA, 15), (.levelA, 19)]
                : [(.gainB, 4), (.highB, 7), (.midB, 11), (.lowB, 15), (.levelB, 19)]
            profile += controls.map {
                binding($0.0, kind: .control, channel: channel, number: $0.1, encoding: .paired14Bit)
            }
            let padChannel: UInt8 = deck == "A" ? 7 : 9
            let hotcues: [ControllerAction] =
                deck == "A"
                ? [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A]
                : [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B]
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
            ]
        }
        profile += [
            binding(.crossfader, kind: .control, channel: 6, number: 31, encoding: .paired14Bit),
            binding(.master, kind: .control, channel: 6, number: 8, encoding: .paired14Bit),
            binding(.cueMix, kind: .control, channel: 6, number: 12, encoding: .paired14Bit),
            binding(.monitor, kind: .control, channel: 6, number: 13, encoding: .paired14Bit),
            binding(.shift, kind: .note, channel: 6, number: 63),
        ]
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
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
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        persist()
        status = "Loaded the DDJ-FLX10 two-deck transport, mixer, loops, Beat Jump, Hot Cue and jog profile."
    }
    func applyDDJ1000Profile() {
        guard !originalZ1Bridge, let selected else {
            status = "Select a generic MIDI input before loading this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        let profile = Self.ddj1000Bindings(source: selected)
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
        persist()
        status = "Loaded the DDJ-1000 two-deck transport, mixer, Hot Cue, jog and Shift profile."
    }
    static func ddj1000Bindings(source: Int32) -> [ControllerBinding] {
        func binding(
            _ action: ControllerAction, kind: ControllerMIDIMessage.Kind, channel: UInt8, number: UInt8,
            encoding: ControllerMIDIEncoding = .absolute, shifted: Bool = false
        ) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number, parameter: nil, noteNumber: nil,
                action: action, encoding: encoding, inverted: false, shifted: shifted)
        }
        var profile: [ControllerBinding] = []
        for (channel, padChannel, deck) in [(UInt8(0), UInt8(7), "A"), (UInt8(1), UInt8(9), "B")] {
            let play: ControllerAction = deck == "A" ? .playA : .playB
            let cueReturn: ControllerAction = deck == "A" ? .cueReturnA : .cueReturnB
            let headphoneCue: ControllerAction = deck == "A" ? .cueA : .cueB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            let loop: ControllerAction = deck == "A" ? .loopA : .loopB
            let tempo: ControllerAction = deck == "A" ? .tempoA : .tempoB
            profile += [
                binding(play, kind: .note, channel: channel, number: 11),
                binding(cueReturn, kind: .note, channel: channel, number: 12),
                binding(headphoneCue, kind: .note, channel: channel, number: 84),
                binding(sync, kind: .note, channel: channel, number: 92),
                binding(loop, kind: .note, channel: channel, number: 80),
                binding(tempo, kind: .control, channel: channel, number: 5, encoding: .paired14Bit),
            ]
            let controls: [(ControllerAction, UInt8)] =
                deck == "A"
                ? [(.gainA, 4), (.highA, 7), (.midA, 11), (.lowA, 15), (.levelA, 19)]
                : [(.gainB, 4), (.highB, 7), (.midB, 11), (.lowB, 15), (.levelB, 19)]
            profile += controls.map {
                binding($0.0, kind: .control, channel: channel, number: $0.1, encoding: .paired14Bit)
            }
            let hotcues: [ControllerAction] =
                deck == "A"
                ? [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A]
                : [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B]
            profile += hotcues.enumerated().map {
                binding($0.element, kind: .note, channel: padChannel, number: UInt8($0.offset))
            }
            let jog: ControllerAction = deck == "A" ? .jogA : .jogB
            let jogTouch: ControllerAction = deck == "A" ? .jogTouchA : .jogTouchB
            let wheelJog: ControllerAction = deck == "A" ? .wheelJogA : .wheelJogB
            profile += [
                binding(jog, kind: .control, channel: channel, number: 33, encoding: .binaryOffset),
                binding(jogTouch, kind: .note, channel: channel, number: 54),
                binding(jogTouch, kind: .note, channel: channel, number: 103, shifted: true),
                binding(wheelJog, kind: .control, channel: channel, number: 38, encoding: .binaryOffset, shifted: true),
                binding(.shift, kind: .note, channel: channel, number: 63),
            ]
        }
        profile += [
            binding(.crossfader, kind: .control, channel: 6, number: 31, encoding: .paired14Bit),
            binding(.master, kind: .control, channel: 6, number: 8, encoding: .paired14Bit),
            binding(.cueMix, kind: .control, channel: 6, number: 12, encoding: .paired14Bit),
            binding(.monitor, kind: .control, channel: 6, number: 13, encoding: .paired14Bit),
        ]
        return profile
    }
    static func ddjFLX10Bindings(source: Int32) -> [ControllerBinding] {
        func binding(
            _ action: ControllerAction, kind: ControllerMIDIMessage.Kind, channel: UInt8, number: UInt8,
            encoding: ControllerMIDIEncoding = .absolute, shifted: Bool = false
        ) -> ControllerBinding {
            .init(
                source: source, group: 0, channel: channel, kind: kind, number: number, parameter: nil, noteNumber: nil,
                action: action, encoding: encoding, inverted: false, shifted: shifted)
        }
        var profile: [ControllerBinding] = []
        for (channel, padChannel, deck) in [(UInt8(0), UInt8(7), "A"), (UInt8(1), UInt8(9), "B")] {
            let play: ControllerAction = deck == "A" ? .playA : .playB
            let cueReturn: ControllerAction = deck == "A" ? .cueReturnA : .cueReturnB
            let headphoneCue: ControllerAction = deck == "A" ? .cueA : .cueB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            let loop: ControllerAction = deck == "A" ? .loopA : .loopB
            let loopDown: ControllerAction = deck == "A" ? .loopDownA : .loopDownB
            let loopUp: ControllerAction = deck == "A" ? .loopUpA : .loopUpB
            let jumpBack: ControllerAction = deck == "A" ? .jumpBackA : .jumpBackB
            let jumpForward: ControllerAction = deck == "A" ? .jumpForwardA : .jumpForwardB
            let tempo: ControllerAction = deck == "A" ? .tempoA : .tempoB
            profile += [
                binding(play, kind: .note, channel: channel, number: 11),
                binding(cueReturn, kind: .note, channel: channel, number: 12),
                binding(headphoneCue, kind: .note, channel: channel, number: 84),
                binding(headphoneCue, kind: .note, channel: channel, number: 57, shifted: true),
                binding(sync, kind: .note, channel: channel, number: 88),
                binding(loop, kind: .note, channel: channel, number: 20),
                binding(loopDown, kind: .note, channel: channel, number: 16),
                binding(loopDown, kind: .note, channel: channel, number: 76, shifted: true),
                binding(loopUp, kind: .note, channel: channel, number: 17),
                binding(loopUp, kind: .note, channel: channel, number: 77, shifted: true),
                binding(jumpBack, kind: .note, channel: channel, number: 94),
                binding(jumpBack, kind: .note, channel: channel, number: 97, shifted: true),
                binding(jumpForward, kind: .note, channel: channel, number: 95),
                binding(jumpForward, kind: .note, channel: channel, number: 98, shifted: true),
                binding(tempo, kind: .control, channel: channel, number: 0, encoding: .paired14Bit),
                binding(tempo, kind: .control, channel: channel, number: 5, encoding: .paired14Bit, shifted: true),
            ]
            let controls: [(ControllerAction, UInt8)] =
                deck == "A"
                ? [(.gainA, 4), (.highA, 7), (.midA, 11), (.lowA, 15), (.levelA, 19)]
                : [(.gainB, 4), (.highB, 7), (.midB, 11), (.lowB, 15), (.levelB, 19)]
            profile += controls.map {
                binding($0.0, kind: .control, channel: channel, number: $0.1, encoding: .paired14Bit)
            }
            let hotcues: [ControllerAction] =
                deck == "A"
                ? [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A]
                : [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .hotcue5B, .hotcue6B, .hotcue7B, .hotcue8B]
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
                binding(jogTouch, kind: .note, channel: channel, number: 103, shifted: true),
                binding(wheelJog, kind: .control, channel: channel, number: 33, encoding: .binaryOffset),
                binding(wheelJog, kind: .control, channel: channel, number: 38, encoding: .binaryOffset, shifted: true),
            ]
        }
        profile += [
            binding(.crossfader, kind: .control, channel: 6, number: 31, encoding: .paired14Bit),
            binding(.master, kind: .control, channel: 6, number: 8, encoding: .paired14Bit),
            binding(.cueMix, kind: .control, channel: 6, number: 12, encoding: .paired14Bit),
            binding(.monitor, kind: .control, channel: 6, number: 13, encoding: .paired14Bit),
            binding(.shift, kind: .note, channel: 0, number: 63), binding(.shift, kind: .note, channel: 1, number: 63),
        ]
        return profile
    }
    func applyDDJREV1Profile() {
        guard !originalZ1Bridge, let selected else {
            status = "Select a generic MIDI input before loading this profile."
            return
        }
        releaseMomentaryActions(source: selected)
        let profile = Self.ddjREV1Bindings(source: selected)
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
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
        bindings.removeAll { $0.source == selected }
        bindings.append(contentsOf: profile)
        values = values.filter { !$0.key.hasPrefix("\(selected)-") }
        valueStates = valueStates.filter { !$0.key.hasPrefix("\(selected)-") }
        pendingValues.removeAll()
        learning = nil
        learningShifted = false
        shiftLayers[selected] = nil
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
            let cueReturn: ControllerAction = deck == "A" ? .cueReturnA : .cueReturnB
            let headphoneCue: ControllerAction = deck == "A" ? .cueA : .cueB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            profile += [
                binding(play, kind: .note, channel: channel, number: 11),
                binding(cueReturn, kind: .note, channel: channel, number: 27),
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
            let padChannel: UInt8 = deck == "A" ? 7 : 8
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
            let cueReturn: ControllerAction = deck == "A" ? .cueReturnA : .cueReturnB
            let headphoneCue: ControllerAction = deck == "A" ? .cueA : .cueB
            let sync: ControllerAction = deck == "A" ? .syncA : .syncB
            profile += [
                binding(play, kind: .note, channel: channel, number: 11),
                binding(cueReturn, kind: .note, channel: channel, number: 12),
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
        ]
        return profile
    }
    func bindingName(_ action: ControllerAction) -> String {
        let assigned = bindings.filter { $0.source == selected && $0.action == action }
        guard !assigned.isEmpty else { return "Unassigned" }
        return assigned.sorted { !$0.isShifted && $1.isShifted }.map { binding in
            let layer = binding.isShifted ? "Shift" : "Base"
            let reversed = binding.inverted == true ? " · reversed" : ""
            let parameterLabel = binding.kind == .program ? "bank" : "parameter"
            let parameter = binding.parameter.map { " · \(parameterLabel) \($0)" } ?? ""
            let note = binding.noteNumber.map { " · note \($0)" } ?? ""
            return
                "\(layer): \(binding.kind.rawValue) \(binding.number)\(parameter)\(note) · group \(Int(binding.umpGroup) + 1), ch \(Int(binding.channel) + 1) · \(binding.mode.title)\(reversed)"
        }.joined(separator: " / ")
    }
    private func bindingStateKey(source: Int32, action: ControllerAction, shifted: Bool, group: UInt8 = 0) -> String {
        "\(source)-\(group)-\(action.rawValue)-\(shifted ? 1 : 0)"
    }
    private func bindingTakeoverKey(_ binding: ControllerBinding) -> String {
        "\(binding.source)-\(binding.umpGroup)-\(binding.channel)-\(binding.kind.rawValue)-\(binding.number)-\(binding.parameter ?? 0)-\(binding.noteNumber ?? 0)-\(binding.isShifted ? 1 : 0)"
    }
    private func persist() {
        bindingCount = bindings.count
        takeoverStates.removeAll()
        if let data = try? JSONEncoder().encode(bindings) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
    }
    private func releaseMomentaryActions(source: Int32? = nil) {
        var resetWheelJogA = source == nil
        var resetWheelJogB = source == nil
        for action in Array(activeMomentaryInputs.keys) {
            guard var inputs = activeMomentaryInputs[action] else { continue }
            let wasActive = !inputs.isEmpty
            if let source { inputs.remove(source) } else { inputs.removeAll() }
            activeMomentaryInputs[action] = inputs.isEmpty ? nil : inputs
            if wasActive && inputs.isEmpty {
                onAction?(action, 0)
                if action == .wheelJogA { resetWheelJogA = true }
                if action == .wheelJogB { resetWheelJogB = true }
            }
        }
        if resetWheelJogA { onAction?(.wheelJogA, 0.5) }
        if resetWheelJogB { onAction?(.wheelJogB, 0.5) }
    }
    private func persistFeedbackBindings() {
        if let data = try? JSONEncoder().encode(feedbackBindings) {
            UserDefaults.standard.set(data, forKey: Self.feedbackStorageKey)
        }
    }
    private func drain() {
        let (frames, overflow, refresh) = inbox.take()
        if overflow {
            stop()
            status = "Controller input overflow. Input disconnected; reconnect to continue."
            return
        }
        if refresh { refreshSources() }
        var processed = 0
        for frame in frames {
            guard let sourceID = sourceIDsByEndpoint[frame.source] else { continue }
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
                var decoder = decoders[sourceID, default: .init()]
                messages = decoder.append(bytes)
                decoders[sourceID] = decoder
            case .messages(let input): messages = input
            }
            processed += messages.count
            guard processed <= 256 else {
                stop()
                status = "Controller input overload. Input disconnected; reconnect to continue."
                return
            }
            for message in messages { receive(message, source: sourceID) }
        }
        let pending = pendingValues
        pendingValues.removeAll(keepingCapacity: true)
        for (action, value) in pending { onAction?(action, value) }
        sendFeedback()
    }
    private func receive(_ message: ControllerMIDIMessage, source sourceID: Int32) {
        let parameterLabel = message.kind == .program ? " bank" : " parameter"
        let parameter = message.parameter.map { "\(parameterLabel) \($0)" } ?? ""
        let note = message.noteNumber.map { " note \($0)" } ?? ""
        lastInput =
            "Input \(sourceID) · \(message.kind.rawValue) \(message.number)\(parameter)\(note) · channel \(Int(message.channel) + 1) · value \(message.value)"
        if let selected, selected == sourceID, activeInputIDs.contains(sourceID), let learning,
            message.kind != .note || !message.isNoteOff
        {
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
            guard learningEncoding != .paired14Bit || message.maximum <= 127 else {
                status = "MIDI 2.0 controls already use full resolution. Choose Knob / fader encoding."
                return
            }
            let number: UInt8
            if learningEncoding == .paired14Bit {
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
                    && binding.channel == message.channel && binding.parameter == message.parameter
                    && binding.noteNumber == message.noteNumber
                    && (binding.number == number
                        || (self.learningEncoding == .paired14Bit && binding.number == number + 32)
                        || (binding.mode == .paired14Bit && binding.number < 32 && binding.number + 32 == number))
            }
            let replacesShift = learning != .shift && bindings.contains(where: { $0.action == .shift && sameInput($0) })
            if bindingIsShifted && replacesShift {
                status = "That control is assigned as Shift. Clear mappings before reusing it."
                return
            }
            bindings.removeAll {
                $0.source == sourceID
                    && (($0.action == learning && $0.isShifted == bindingIsShifted)
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
            self.learning = nil
            self.learningShifted = false
            persist()
            status =
                replacesShift
                ? "Saved \(learning.title). The old Shift mapping was removed." : "Saved \(learning.title)."
            return
        }
        let matches = bindings.filter {
            $0.source == sourceID && $0.umpGroup == message.group && $0.kind == message.kind
                && $0.channel == message.channel && $0.parameter == message.parameter
                && $0.noteNumber == message.noteNumber
                && ($0.number == message.number
                    || ($0.mode == .paired14Bit && $0.number < 32 && $0.number + 32 == message.number))
        }
        for binding in matches {
            let key = bindingStateKey(
                source: binding.source, action: binding.action, shifted: binding.isShifted, group: binding.umpGroup)
            var state = valueStates[key, default: .init()]
            guard let decoded = state.decode(message, encoding: binding.mode, number: binding.number) else { continue }
            valueStates[key] = state
            var value: Double
            switch decoded {
            case .absolute(let absolute):
                value = binding.inverted == true && !binding.action.isButton ? 1 - absolute : absolute
            case .relative(let delta):
                guard !binding.action.isButton, delta != 0 else { continue }
                if binding.action.isJog {
                    let previousDelta = ((pendingValues[binding.action] ?? 0.5) - 0.5) * 8
                    let signedDelta = binding.inverted == true ? -delta : delta
                    value = 0.5 + min(4, max(-4, previousDelta + signedDelta)) / 8
                } else if let target = pendingValues[binding.action] ?? currentValue?(binding.action) {
                    guard target.isFinite else { continue }
                    value = min(1, max(0, target + (binding.inverted == true ? -delta : delta) / 127))
                } else {
                    continue
                }
            }
            if binding.action.isButton, message.kind == .note, !message.isNoteOff, value == 0 { value = 1 }
            let previous = values.updateValue(value, forKey: key)
            if binding.action == .shift {
                let inputKey =
                    "\(binding.source)-\(binding.umpGroup)-\(binding.channel)-\(binding.kind.rawValue)-\(binding.number)-\(binding.parameter ?? 0)-\(binding.noteNumber ?? 0)"
                var shiftLayer = shiftLayers[sourceID, default: .init()]
                shiftLayer.update(input: inputKey, isPressed: value > 0)
                shiftLayers[sourceID] = shiftLayer
                status = shiftLayer.isActive ? "Shift layer active." : "Base layer active."
                continue
            }
            guard binding.isShifted == (shiftLayers[sourceID]?.isActive ?? false) else { continue }
            if binding.action.isMomentary {
                guard previous != value else { continue }
                var inputs = activeMomentaryInputs[binding.action, default: []]
                let wasActive = !inputs.isEmpty
                if value > 0 { inputs.insert(sourceID) } else { inputs.remove(sourceID) }
                activeMomentaryInputs[binding.action] = inputs.isEmpty ? nil : inputs
                if value > 0 && !wasActive {
                    onAction?(binding.action, value)
                } else if value == 0 && inputs.isEmpty {
                    onAction?(binding.action, 0)
                }
                continue
            }
            if binding.action.isButton {
                if message.kind == .program {
                    onAction?(binding.action, 1)
                    continue
                }
                if previous == nil && message.kind != .note { continue }
                guard value > 0, (previous ?? 0) == 0 else { continue }
                onAction?(binding.action, value)
            } else {
                if !binding.action.isJog && !message.kind.isRelativeController
                    && (binding.mode == .absolute || binding.mode == .paired14Bit)
                {
                    let takeoverKey = bindingTakeoverKey(binding)
                    var takeover = takeoverStates[takeoverKey, default: .init()]
                    let wasPending = takeover.isPending
                    let shouldApply = takeover.shouldApply(input: value, target: currentValue?(binding.action))
                    takeoverStates[takeoverKey] = takeover
                    guard shouldApply else {
                        if !wasPending { status = "Move the control to its current value to take control." }
                        continue
                    }
                    if wasPending { status = "MIDI control took over." }
                }
                pendingValues[binding.action] = value
            }
        }
    }
}
