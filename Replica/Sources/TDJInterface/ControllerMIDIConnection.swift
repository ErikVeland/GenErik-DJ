import CoreMIDI
import Foundation
import Observation
import TDJCore

enum ControllerAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case playA, playB, syncA, syncB, keylockA, keylockB, cueA, cueB
    case levelA, levelB, gainA, gainB, lowA, lowB, midA, midB, highA, highB
    case filterA, filterB, fxA, fxB, fxToggleA, fxToggleB, crossfader, cueMix
    var id: String { rawValue }
    var deck: DeckID { rawValue.hasSuffix("B") ? .b : .a }
    var title: String {
        if self == .crossfader { return "Crossfader" }
        if self == .cueMix { return "Headphone blend" }
        let labels = ["play": "Play / Pause", "sync": "Sync", "keylock": "Key lock", "cue": "Headphone cue",
                      "level": "Volume", "gain": "Gain", "low": "Low EQ", "mid": "Mid EQ", "high": "High EQ",
                      "filter": "Filter", "fx": "Effect amount", "fxToggle": "Effect on / off"]
        return "\(deck.rawValue.uppercased()) · \(labels[String(rawValue.dropLast())] ?? rawValue)"
    }
    var isButton: Bool {
        switch self {
        case .playA, .playB, .syncA, .syncB, .keylockA, .keylockB, .cueA, .cueB, .fxToggleA, .fxToggleB: true
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

@MainActor @Observable
final class ControllerMIDIConnection {
    struct Source: Identifiable { let id: Int32; let reference: MIDIEndpointRef; let name: String }
    var enabled = false
    var sources: [Source] = []
    var selected: Int32?
    var status = "Controller input is off."
    var lastInput = "No input received."
    var learning: ControllerAction?
    var bindingCount = 0
    @ObservationIgnored var onAction: ((ControllerAction, Double) -> Void)?
    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var endpoint = MIDIEndpointRef()
    @ObservationIgnored private var decoder = ControllerMIDIDecoder()
    @ObservationIgnored private var values: [String: Double] = [:]
    @ObservationIgnored private var bindings: [ControllerBinding] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let inbox = ControllerMIDIInbox()
    private static let storageKey = "controllers.midiBindings.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([ControllerBinding].self, from: data), saved.count <= 256 { bindings = saved }
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
            var packet = UnsafeRawPointer(list).advanced(by: offset).assumingMemoryBound(to: MIDIPacket.self)
            for _ in 0..<list.pointee.numPackets {
                let count = Int(packet.pointee.length)
                let bytes = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)
                inbox.append(source: source, bytes: count <= 4096 ? Array(UnsafeBufferPointer(start: bytes, count: count)) : Array(repeating: 0, count: 4097))
                packet = UnsafePointer(MIDIPacketNext(packet))
            }
        }
        guard result == noErr else { stop(); status = "MIDI input could not open (\(result))."; return }
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
        if client != 0 { MIDIClientDispose(client); client = 0 }
        endpoint = 0; selected = nil; enabled = false; learning = nil
        decoder = .init(); values.removeAll(); _ = inbox.take()
        sources = []; status = "Controller input is off."
    }
    func refreshSources() {
        sources = (0..<MIDIGetNumberOfSources()).compactMap { index in
            let reference = MIDIGetSource(index)
            guard reference != 0 else { return nil }
            var id: Int32 = 0
            guard MIDIObjectGetIntegerProperty(reference, kMIDIPropertyUniqueID, &id) == noErr else { return nil }
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(reference, kMIDIPropertyDisplayName, &name)
            return .init(id: id, reference: reference, name: name?.takeRetainedValue() as String? ?? "MIDI input")
        }
        if let selected, !sources.contains(where: { $0.id == selected && $0.reference == endpoint }) { select(nil) }
        if selected == nil { status = sources.isEmpty ? "No MIDI inputs found. Check the connection and MIDI mode." : "Choose the controller input to use." }
    }
    func select(_ id: Int32?) {
        if endpoint != 0 { MIDIPortDisconnectSource(port, endpoint) }
        endpoint = 0; selected = nil; learning = nil; decoder = .init(); values.removeAll(); _ = inbox.take()
        guard enabled, let source = sources.first(where: { $0.id == id }) else { return }
        let result = MIDIPortConnectSource(port, source.reference, UnsafeMutableRawPointer(bitPattern: Int(source.reference)))
        if result == noErr { endpoint = source.reference; selected = source.id; status = "Input connected: \(source.name)" }
        else { status = "The controller input could not connect (\(result))." }
    }
    func clearBindings() {
        bindings.removeAll(); values.removeAll(); learning = nil; persist()
    }
    func bindingName(_ action: ControllerAction) -> String {
        guard let binding = bindings.first(where: { $0.source == selected && $0.action == action }) else { return "Unassigned" }
        return "\(binding.kind.rawValue) \(binding.number) · channel \(Int(binding.channel) + 1)"
    }
    private func persist() {
        bindingCount = bindings.count
        if let data = try? JSONEncoder().encode(bindings) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
    }
    private func drain() {
        let (frames, overflow, refresh) = inbox.take()
        if overflow { stop(); status = "Controller input overflow. Input disconnected; reconnect to continue."; return }
        if refresh { refreshSources() }
        for frame in frames where frame.source == endpoint {
            for message in decoder.append(frame.bytes) { receive(message) }
        }
    }
    private func receive(_ message: ControllerMIDIMessage) {
        guard let selected else { return }
        lastInput = "\(message.kind.rawValue) \(message.number) · channel \(Int(message.channel) + 1)"
        let key = "\(message.kind.rawValue)-\(message.channel)-\(message.number)"
        if let learning, message.kind != .note || message.value > 0 {
            bindings.removeAll { $0.source == selected && ($0.action == learning || ($0.kind == message.kind && $0.channel == message.channel && $0.number == message.number)) }
            guard bindings.count < 256 else { status = "The controller mapping is full."; self.learning = nil; return }
            bindings.append(.init(source: selected, channel: message.channel, kind: message.kind, number: message.number, action: learning))
            values[key] = message.normalized
            self.learning = nil; persist(); status = "Saved \(learning.title)."; return
        }
        guard let binding = bindings.first(where: { $0.source == selected && $0.kind == message.kind && $0.channel == message.channel && $0.number == message.number }) else { return }
        let previous = values.updateValue(message.normalized, forKey: key)
        if binding.action.isButton {
            if previous == nil && message.kind != .note { return }
            guard message.normalized > 0, (previous ?? 0) == 0 else { return }
        }
        onAction?(binding.action, message.normalized)
    }
}
