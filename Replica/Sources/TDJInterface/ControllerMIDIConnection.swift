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
        let labels = ["play": "Play / Pause", "sync": "Sync", "keylock": "Key lock", "cue": "Headphone cue",
                      "level": "Volume", "gain": "Gain", "low": "Low EQ", "mid": "Mid EQ", "high": "High EQ",
                      "filter": "Filter", "filterToggle": "Filter on / off", "fx": "Effect amount", "fxToggle": "Effect on / off",
                      "tempo": "Tempo ±8%", "loop": "Loop on / off", "loopUp": "Larger loop", "loopDown": "Smaller loop",
                      "jumpBack": "Beat jump back", "jumpForward": "Beat jump forward", "cueReturn": "Cue return / set", "freeze": "Freeze"]
        return "\(deck.rawValue.uppercased()) · \(labels[String(rawValue.dropLast())] ?? rawValue)"
    }
    var isButton: Bool {
        switch self {
        case .levelA, .levelB, .gainA, .gainB, .lowA, .lowB, .midA, .midB, .highA, .highB,
             .filterA, .filterB, .fxA, .fxB, .crossfader, .cueMix, .master, .monitor, .tempoA, .tempoB: false
        default: true
        }
    }
    var hotcueSlot: Int? {
        guard rawValue.hasPrefix("hotcue"), let value = Int(rawValue.dropFirst(6).dropLast()) else { return nil }
        return value - 1
    }
    var supportsFeedback: Bool {
        switch self {
        case .playA, .playB, .syncA, .syncB, .keylockA, .keylockB, .cueA, .cueB,
             .levelA, .levelB, .gainA, .gainB, .lowA, .lowB, .midA, .midB, .highA, .highB,
             .filterA, .filterB, .fxA, .fxB, .fxToggleA, .fxToggleB, .crossfader, .cueMix,
             .filterToggleA, .filterToggleB, .master, .monitor, .tempoA, .tempoB, .loopA, .loopB: true
        default: false
        }
    }
}

private struct ControllerBinding: Codable {
    let source: Int32
    let channel: UInt8
    let kind: ControllerMIDIMessage.Kind
    let number: UInt8
    let action: ControllerAction
    let encoding: ControllerMIDIEncoding?
    let inverted: Bool?
    let shifted: Bool?
    var mode: ControllerMIDIEncoding { encoding ?? .absolute }
    var isShifted: Bool { shifted ?? false }
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
}

/// Core MIDI callbacks never touch the observed model or the audio renderer.
private final class ControllerMIDIInbox: @unchecked Sendable {
    struct Frame { let source: UInt32; let bytes: [UInt8] }
    private let lock = NSLock()
    private var frames: [Frame] = []
    private var overflow = false
    private var refresh = false
    func requestRefresh() { lock.lock(); refresh = true; lock.unlock() }
    func append(source: UInt32, bytes: [UInt8]) {
        lock.lock(); defer { lock.unlock() }
        if frames.count < 128 && bytes.count <= 4096 { frames.append(.init(source: source, bytes: bytes)) }
        else { overflow = true }
    }
    func take() -> ([Frame], Bool, Bool) {
        lock.lock(); defer { lock.unlock() }
        let result = (frames, overflow, refresh)
        frames.removeAll(keepingCapacity: true); overflow = false; refresh = false
        return result
    }
}

/// Converts MIDI-1.0 UMP words into the byte stream used by the generic MIDI decoder.
private func midi1Bytes(from eventList: UnsafePointer<MIDIEventList>) -> [UInt8] {
    let packetOffset = MemoryLayout<MIDIEventList>.offset(of: \.packet)!
    let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \.words)!
    var packet = UnsafeMutablePointer(mutating:
        UnsafeRawPointer(eventList).advanced(by: packetOffset).assumingMemoryBound(to: MIDIEventPacket.self))
    var bytes: [UInt8] = []
    var totalWords = 0
    for _ in 0..<min(Int(eventList.pointee.numPackets), 128) {
        let wordCount = Int(packet.pointee.wordCount)
        guard wordCount <= 1024, totalWords <= 4096 - wordCount else { return Array(repeating: 0, count: 4097) }
        totalWords += wordCount
        let words = UnsafeRawPointer(packet).advanced(by: wordsOffset).assumingMemoryBound(to: UInt32.self)
        for index in 0..<wordCount {
            let word = words[index]
            guard word >> 28 == 0x2 else { continue }
            let status = UInt8((word >> 16) & 0xff)
            let command = status & 0xf0
            guard (0x80...0xe0).contains(command) else { continue }
            bytes.append(status)
            bytes.append(UInt8((word >> 8) & 0x7f))
            if command != 0xc0 && command != 0xd0 { bytes.append(UInt8(word & 0x7f)) }
            if bytes.count > 4096 { return Array(repeating: 0, count: 4097) }
        }
        packet = UnsafeMutableRawPointer(packet).advanced(by: wordsOffset + wordCount * MemoryLayout<UInt32>.size)
            .assumingMemoryBound(to: MIDIEventPacket.self)
    }
    if Int(eventList.pointee.numPackets) > 128 { return Array(repeating: 0, count: 4097) }
    return bytes
}

@MainActor @Observable
final class ControllerMIDIConnection {
    struct Source: Identifiable { let id: Int32; let reference: MIDIEndpointRef; let name: String }
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
    @ObservationIgnored private var endpoint = MIDIEndpointRef()
    @ObservationIgnored private var decoder = ControllerMIDIDecoder()
    @ObservationIgnored private var bridgeDecoder = ControllerBridgeDecoder()
    @ObservationIgnored private var bridgeConnected = false
    @ObservationIgnored private var pendingFeedback: [UInt8]?
    @ObservationIgnored private var sentFeedback: [UInt8] = []
    @ObservationIgnored private var sentMIDIValues: [ControllerAction: [UInt8]] = [:]
    @ObservationIgnored private var lastMIDIOutputTime = 0.0
    @ObservationIgnored private var lastFeedbackTime = 0.0
    @ObservationIgnored private var needsBridgeHello = true
    @ObservationIgnored private var values: [String: Double] = [:]
    @ObservationIgnored private var valueStates: [String: ControllerMIDIValueState] = [:]
    @ObservationIgnored private var pendingValues: [ControllerAction: Double] = [:]
    @ObservationIgnored private var shiftActive = false
    @ObservationIgnored private var bindings: [ControllerBinding] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let inbox = ControllerMIDIInbox()
    private static let storageKey = "controllers.midiBindings.v1"
    private static let feedbackStorageKey = "controllers.midiFeedback.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([ControllerBinding].self, from: data), saved.count <= 256 { bindings = saved }
        if let data = UserDefaults.standard.data(forKey: Self.feedbackStorageKey),
           let saved = try? JSONDecoder().decode([ControllerFeedbackBinding].self, from: data), saved.count <= 128,
           saved.allSatisfy({ $0.channel < 16 && $0.number < 128 && $0.offValue < 128 && $0.onValue < 128 &&
               $0.action.supportsFeedback && ($0.kind == .control || $0.action.isButton) }),
           Set(saved.map(\.id)).count == saved.count { feedbackBindings = saved }
        bindingCount = bindings.count
    }
    func start() {
        guard !enabled else { return }
        let inbox = inbox
        let clientResult = MIDIClientCreateWithBlock("GenErik DJ controllers" as CFString, &client) { _ in inbox.requestRefresh() }
        guard clientResult == noErr else { status = "MIDI input is unavailable (\(clientResult))."; return }
        let result = MIDIInputPortCreateWithBlock(client, "Controller input" as CFString, &port) { list, context in
            guard let context else { return }
            let source = UInt32(truncatingIfNeeded: UInt(bitPattern: context))
            let offset = MemoryLayout<MIDIPacketList>.offset(of: \.packet)!
            let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \.data)!
            var packet = UnsafeMutablePointer(mutating: UnsafeRawPointer(list).advanced(by: offset).assumingMemoryBound(to: MIDIPacket.self))
            for _ in 0..<list.pointee.numPackets {
                let count = Int(packet.pointee.length)
                let bytes = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)
                inbox.append(source: source, bytes: count <= 4096 ? Array(UnsafeBufferPointer(start: bytes, count: count)) : Array(repeating: 0, count: 4097))
                packet = MIDIPacketNext(packet)
            }
        }
        guard result == noErr else { stop(); status = "MIDI input could not open (\(result))."; return }
        let protocolResult = MIDIInputPortCreateWithProtocol(client, "Controller MIDI 1.0 input" as CFString,
                                                              kMIDIProtocol_1_0, &protocolPort) { list, context in
            guard let context else { return }
            let source = UInt32(truncatingIfNeeded: UInt(bitPattern: context))
            let bytes = midi1Bytes(from: list)
            if !bytes.isEmpty { inbox.append(source: source, bytes: bytes) }
        }
        if protocolResult != noErr { protocolPort = 0; protocolInputFailure = protocolResult }
        else { protocolInputFailure = nil }
        let outputResult = MIDIOutputPortCreate(client, "Controller feedback" as CFString, &outputPort)
        feedbackOutputAvailable = outputResult == noErr
        feedbackStatus = feedbackOutputAvailable ? "MIDI feedback output is available." : "MIDI feedback output could not open (\(outputResult))."
        enabled = true
        refreshSources()
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.drain() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stop() {
        timer?.invalidate(); timer = nil
        if port != 0 { MIDIPortDispose(port); port = 0 }
        if protocolPort != 0 { MIDIPortDispose(protocolPort); protocolPort = 0 }
        if outputPort != 0 { MIDIPortDispose(outputPort); outputPort = 0 }
        feedbackOutputAvailable = false
        if client != 0 { MIDIClientDispose(client); client = 0 }
        endpoint = 0; selected = nil; enabled = false; learning = nil; learningShifted = false; shiftActive = false; midiFeedbackEnabled = false
        protocolInputFailure = nil
        decoder = .init(); values.removeAll(); valueStates.removeAll(); pendingValues.removeAll(); _ = inbox.take()
        sentMIDIValues.removeAll()
        resetBridge()
        sources = []; destinations = []; feedbackSelected = nil; feedbackStatus = "Feedback output is off."; status = "Controller input is off."
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
        if let selected, !sources.contains(where: { $0.id == selected && $0.reference == endpoint }) { select(nil) }
        if let feedbackSelected, !destinations.contains(where: { $0.id == feedbackSelected }) {
            self.feedbackSelected = nil; sentFeedback = []; sentMIDIValues.removeAll()
            midiFeedbackEnabled = false
        }
        if selected == nil { status = sources.isEmpty ? "No MIDI inputs found. Check the connection and MIDI mode." : "Choose the controller input to use." }
    }
    func select(_ id: Int32?) {
        if endpoint != 0 {
            MIDIPortDisconnectSource(port, endpoint)
            if protocolPort != 0 { MIDIPortDisconnectSource(protocolPort, endpoint) }
        }
        endpoint = 0; selected = nil; learning = nil; learningShifted = false; shiftActive = false
        decoder = .init(); values.removeAll(); valueStates.removeAll(); pendingValues.removeAll(); _ = inbox.take()
        feedbackSelected = nil; midiFeedbackEnabled = false; sentMIDIValues.removeAll(); resetBridge()
        guard enabled, let source = sources.first(where: { $0.id == id }) else { return }
        let inputPort = !originalZ1Bridge && protocolPort != 0 ? protocolPort : port
        let result = MIDIPortConnectSource(inputPort, source.reference, UnsafeMutableRawPointer(bitPattern: Int(source.reference)))
        if result == noErr {
            endpoint = source.reference; selected = source.id
            let fallback = !originalZ1Bridge ? protocolInputFailure.map { " · MIDI 2 conversion unavailable (\($0))" } ?? "" : ""
            status = "Input connected: \(source.name)\(fallback)"
        }
        else { status = "The controller input could not connect (\(result))." }
    }
    func setBridgeMode(_ enabled: Bool) {
        originalZ1Bridge = enabled
        if enabled { midiFeedbackEnabled = false; sentMIDIValues.removeAll() }
        learning = nil; learningShifted = false; shiftActive = false
        decoder = .init(); values.removeAll(); valueStates.removeAll(); pendingValues.removeAll(); resetBridge()
        guard let selected, let source = sources.first(where: { $0.id == selected }), endpoint != 0 else { return }
        MIDIPortDisconnectSource(port, endpoint)
        if protocolPort != 0 { MIDIPortDisconnectSource(protocolPort, endpoint) }
        let inputPort = !originalZ1Bridge && protocolPort != 0 ? protocolPort : port
        let result = MIDIPortConnectSource(inputPort, source.reference, UnsafeMutableRawPointer(bitPattern: Int(source.reference)))
        if result == noErr {
            let fallback = !originalZ1Bridge ? protocolInputFailure.map { " · MIDI 2 conversion unavailable (\($0))" } ?? "" : ""
            status = "Input connected: \(source.name)\(fallback)"
        }
        else { endpoint = 0; self.selected = nil; status = "The controller input could not reconnect (\(result))." }
    }
    func setFeedbackDestination(_ id: Int32?) {
        feedbackSelected = id; sentFeedback = []; sentMIDIValues.removeAll()
        lastFeedbackTime = 0; lastMIDIOutputTime = 0; needsBridgeHello = true
        let destinationIsMapped = id.map { selectedID in feedbackBindings.contains { $0.destination == selectedID } } ?? false
        if !destinationIsMapped { midiFeedbackEnabled = false }
    }
    func setMIDIFeedbackEnabled(_ enabled: Bool) {
        midiFeedbackEnabled = enabled && feedbackOutputAvailable && feedbackSelected != nil && !selectedFeedbackBindings.isEmpty
        sentMIDIValues.removeAll()
    }
    func setFeedbackBinding(action: ControllerAction, kind: ControllerFeedbackKind,
                            channel: UInt8, number: UInt8, offValue: UInt8, onValue: UInt8) {
        guard let destination = feedbackSelected,
              channel < 16, number < 128, offValue < 128, onValue < 128,
              action.supportsFeedback, kind == .control || action.isButton else { return }
        if !feedbackBindings.contains(where: { $0.destination == destination && $0.action == action }), feedbackBindings.count >= 128 { return }
        feedbackBindings.removeAll { $0.destination == destination && $0.action == action }
        feedbackBindings.append(.init(destination: destination, action: action, kind: kind, channel: channel, number: number,
                                      offValue: offValue, onValue: onValue))
        feedbackBindings.sort { $0.id < $1.id }
        persistFeedbackBindings()
        sentMIDIValues[action] = nil
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
        bridgeDecoder = .init(); bridgeConnected = false; pendingFeedback = nil; sentFeedback = []
        needsBridgeHello = requestHello
        bridgeStatus = "No Z1 bridge report received."; onBridgeReset?()
    }
    func queueZ1Feedback(_ bytes: [UInt8]) {
        guard enabled, originalZ1Bridge, bridgeConnected, bytes.count == 22 else { return }
        pendingFeedback = bytes
    }
    private func receiveBridge(_ frame: ControllerBridgeFrame) {
        switch frame.kind {
        case .z1Input:
            guard let report = try? Z1InputReport(bytes: frame.payload) else { bridgeStatus = "Rejected an invalid Z1 report."; return }
            if !bridgeConnected { bridgeStatus = "Z1 input received. Select the feedback output to request calibration." }
            bridgeConnected = true; lastInput = "Original Z1 control report received."; onZ1Report?(report)
        case .z1Calibration:
            guard let calibration = try? Z1CrossfaderCalibration(featureD2: frame.payload) else {
                onBridgeReset?(); bridgeStatus = "Z1 calibration is invalid. Crossfader input stays disabled."; return
            }
            bridgeConnected = true; onZ1Calibration?(calibration); bridgeStatus = "Z1 bridge calibration received."
        case .z1Status:
            switch frame.payload[0] {
            case 0: resetBridge(requestHello: false); bridgeStatus = "The Z1 disconnected from the bridge."
            case 1: resetBridge(requestHello: false); bridgeConnected = true; bridgeStatus = "Z1 connected. Waiting for calibration."
            case 2: onBridgeReset?(); bridgeConnected = true; bridgeStatus = "Z1 controls connected. Crossfader waits for calibration."
            default: break
            }
        case .z1Output: break
        }
    }
    private func sendFeedback() {
        guard outputPort != 0,
              let destination = destinations.first(where: { $0.id == feedbackSelected }) else { return }
        if !originalZ1Bridge {
            sendMIDIFeedback(to: destination.reference)
            return
        }
        guard ProcessInfo.processInfo.systemUptime - lastFeedbackTime >= 1.0 / 30 else { return }
        if needsBridgeHello {
            if let hello = try? ControllerBridgeFrame(kind: .z1Status, payload: [3]),
               sendBridgeFrame(hello, destination: destination.reference) { needsBridgeHello = false }
            return
        }
        guard bridgeConnected, let payload = pendingFeedback, payload != sentFeedback,
              let frame = try? ControllerBridgeFrame(kind: .z1Output, payload: payload) else { return }
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
            let outputValue = binding.action.isButton
                ? (bounded > 0 ? binding.onValue : binding.offValue)
                : UInt8((bounded * 127).rounded())
            let status: UInt8
            switch binding.kind {
            case .control: status = 0xB0 | binding.channel
            case .note: status = (bounded > 0 ? 0x90 : 0x80) | binding.channel
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
        bindings.removeAll { $0.source == selected }; values.removeAll(); valueStates.removeAll(); pendingValues.removeAll()
        learning = nil; learningShifted = false; shiftActive = false; persist()
    }
    func bindingName(_ action: ControllerAction) -> String {
        let assigned = bindings.filter { $0.source == selected && $0.action == action }
        guard !assigned.isEmpty else { return "Unassigned" }
        return assigned.sorted { !$0.isShifted && $1.isShifted }.map { binding in
            let layer = binding.isShifted ? "Shift" : "Base"
            let reversed = binding.inverted == true ? " · reversed" : ""
            return "\(layer): \(binding.kind.rawValue) \(binding.number) · ch \(Int(binding.channel) + 1) · \(binding.mode.title)\(reversed)"
        }.joined(separator: " / ")
    }
    private func bindingStateKey(source: Int32, action: ControllerAction, shifted: Bool) -> String {
        "\(source)-\(action.rawValue)-\(shifted ? 1 : 0)"
    }
    private func persist() {
        bindingCount = bindings.count
        if let data = try? JSONEncoder().encode(bindings) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
    }
    private func persistFeedbackBindings() {
        if let data = try? JSONEncoder().encode(feedbackBindings) {
            UserDefaults.standard.set(data, forKey: Self.feedbackStorageKey)
        }
    }
    private func drain() {
        let (frames, overflow, refresh) = inbox.take()
        if overflow { stop(); status = "Controller input overflow. Input disconnected; reconnect to continue."; return }
        if refresh { refreshSources() }
        var processed = 0
        for frame in frames where frame.source == endpoint {
            if originalZ1Bridge {
                let reports = bridgeDecoder.append(frame.bytes)
                processed += reports.count
                guard processed <= 256 else { stop(); status = "Controller input overload. Reconnect to continue."; return }
                for report in reports { receiveBridge(report) }
                continue
            }
            let messages = decoder.append(frame.bytes)
            processed += messages.count
            guard processed <= 256 else {
                stop(); status = "Controller input overload. Input disconnected; reconnect to continue."; return
            }
            for message in messages { receive(message) }
        }
        let pending = pendingValues
        pendingValues.removeAll(keepingCapacity: true)
        for (action, value) in pending { onAction?(action, value) }
        sendFeedback()
    }
    private func receive(_ message: ControllerMIDIMessage) {
        guard let selected else { return }
        lastInput = "\(message.kind.rawValue) \(message.number) · channel \(Int(message.channel) + 1)"
        if let learning, message.kind != .note || message.value > 0 {
            if learning == .shift {
                guard learningEncoding == .absolute, message.kind == .note || message.kind == .control else {
                    status = "Shift uses a momentary note or absolute Control Change button."; return
                }
            }
            guard message.kind != .program || learning.isButton else {
                status = "Program changes map to button actions. Use a knob, fader or pressure control for an amount."; return
            }
            guard learningEncoding == .absolute || (message.kind == .control && !learning.isButton) else {
                status = "Use a CC knob/encoder for this mode, or choose Knob / fader for buttons."; return
            }
            let number: UInt8
            if learningEncoding == .paired14Bit {
                guard message.number < 64 else { status = "A paired high-resolution CC uses controllers 0–31 and their low bytes 32–63."; return }
                number = message.number >= 32 ? message.number - 32 : message.number
            } else { number = message.number }
            let bindingIsShifted = learning == .shift ? false : learningShifted
            let sameInput: (ControllerBinding) -> Bool = { binding in
                binding.source == selected && binding.kind == message.kind && binding.channel == message.channel &&
                    (binding.number == number || (learningEncoding == .paired14Bit && binding.number == number + 32) ||
                     (binding.mode == .paired14Bit && binding.number < 32 && binding.number + 32 == number))
            }
            let replacesShift = learning != .shift && bindings.contains(where: { $0.action == .shift && sameInput($0) })
            if bindingIsShifted && replacesShift {
                status = "That control is assigned as Shift. Clear mappings before reusing it."; return
            }
            bindings.removeAll {
                $0.source == selected && (($0.action == learning && $0.isShifted == bindingIsShifted) ||
                    ($0.isShifted == bindingIsShifted && sameInput($0)) || (learning == .shift && sameInput($0)))
            }
            guard bindings.count < 256 else { status = "The controller mapping is full."; self.learning = nil; return }
            bindings.append(.init(source: selected, channel: message.channel, kind: message.kind, number: number,
                                  action: learning, encoding: learningEncoding, inverted: learningInverted, shifted: bindingIsShifted))
            let key = bindingStateKey(source: selected, action: learning, shifted: bindingIsShifted)
            values[key] = message.normalized; valueStates[key] = .init()
            shiftActive = false; self.learning = nil; self.learningShifted = false
            persist()
            status = replacesShift ? "Saved \(learning.title). The old Shift mapping was removed." : "Saved \(learning.title)."
            return
        }
        let matches = bindings.filter {
            $0.source == selected && $0.kind == message.kind && $0.channel == message.channel &&
                ($0.number == message.number || ($0.mode == .paired14Bit && $0.number < 32 && $0.number + 32 == message.number))
        }
        for binding in matches {
            let key = bindingStateKey(source: binding.source, action: binding.action, shifted: binding.isShifted)
            var state = valueStates[key, default: .init()]
            guard let decoded = state.decode(message, encoding: binding.mode, number: binding.number) else { continue }
            valueStates[key] = state
            let value: Double
            switch decoded {
            case .absolute(let absolute): value = binding.inverted == true && !binding.action.isButton ? 1 - absolute : absolute
            case .relative(let delta):
                guard !binding.action.isButton, delta != 0,
                      let target = pendingValues[binding.action] ?? currentValue?(binding.action), target.isFinite else { continue }
                value = min(1, max(0, target + Double(binding.inverted == true ? -delta : delta) / 127))
            }
            let previous = values.updateValue(value, forKey: key)
            if binding.action == .shift {
                shiftActive = value > 0
                status = shiftActive ? "Shift layer active." : "Base layer active."
                continue
            }
            guard binding.isShifted == shiftActive else { continue }
            if binding.action.isButton {
                if message.kind == .program { onAction?(binding.action, 1); continue }
                if previous == nil && message.kind != .note { continue }
                guard value > 0, (previous ?? 0) == 0 else { continue }
                onAction?(binding.action, value)
            } else {
                pendingValues[binding.action] = value
            }
        }
    }
}
