import CoreMIDI
import Foundation
import TDJCore

@MainActor public protocol S4MK3ReportConnection: AnyObject {
    var isReceiving: Bool { get }
    var onReport: (([UInt8]) -> Void)? { get set }
    var onDisconnect: (() -> Void)? { get set }
    func start()
    func stop()
    func poll()
    func feedback(_ report: [UInt8])
}

@MainActor final class TraktorHIDBridgeConnection: S4MK3ReportConnection {
    enum Model: Equatable {
        case s4MK3, z1MK2, x1MK3, s2MK1, s4MK1
        case factory(TraktorFactoryModel)

        var deviceName: String {
            switch self {
            case .s4MK3: "GenErik S4 Mk3 Bridge"
            case .s4MK1: "GenErik S4 Mk1 Bridge"
            case .z1MK2: "GenErik Z1 Mk2 Bridge"
            case .x1MK3: "GenErik X1 Mk3 Bridge"
            case .s2MK1: "GenErik S2 Mk1 Bridge"
            case .factory(let model): model.bridgeName
            }
        }

        var statusKind: ControllerBridgeFrame.Kind { self == .s4MK3 ? .s4MK3Status : .modularStatus }
        var inputKind: ControllerBridgeFrame.Kind {
            switch self {
            case .s4MK3: .s4MK3Input
            case .s4MK1: .s4MK1Report
            case .s2MK1: .s2MK1Report
            case .z1MK2, .x1MK3: .modularInput
            case .factory: .factoryInput
            }
        }

        var lightSize: Int {
            switch self {
            case .s4MK3: 95
            case .s4MK1: 103
            case .z1MK2: 47
            case .x1MK3: 50
            case .s2MK1: 62
            case .factory: 0
            }
        }
    }

    private let model: Model

    init(_ model: Model) { self.model = model }

    private let inbox = ControllerMIDIInbox()
    private var client: MIDIClientRef = 0
    private var input: MIDIPortRef = 0
    private var output: MIDIPortRef = 0
    private var source: MIDIEndpointRef = 0
    private var destination: MIDIEndpointRef = 0
    private var decoder = ControllerBridgeDecoder()
    private var factoryInput = TraktorFactoryFragments()
    private var lastHeartbeat: ContinuousClock.Instant?
    private var lastHello: ContinuousClock.Instant?
    private var lastFeedback: [Int: [UInt8]] = [:]

    var isReceiving: Bool { lastHeartbeat != nil }
    var onReport: (([UInt8]) -> Void)?
    var onDisconnect: (() -> Void)?

    func start() {
        guard client == 0 else { return }
        let inbox = inbox
        guard
            MIDIClientCreateWithBlock(model.deviceName as CFString, &client, { _ in inbox.requestRefresh() }) == noErr,
            MIDIInputPortCreateWithBlock(
                client, "Traktor reports" as CFString, &input,
                { list, context in
                    guard let context else { return }
                    let source = UInt32(truncatingIfNeeded: UInt(bitPattern: context))
                    let offset = MemoryLayout<MIDIPacketList>.offset(of: \.packet)!
                    let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \.data)!
                    var packet = UnsafeMutablePointer(
                        mutating: UnsafeRawPointer(list).advanced(by: offset).assumingMemoryBound(to: MIDIPacket.self))
                    guard list.pointee.numPackets <= 128 else {
                        inbox.signalOverflow()
                        return
                    }
                    for _ in 0..<list.pointee.numPackets {
                        let count = Int(packet.pointee.length)
                        guard count <= 4096 else {
                            inbox.signalOverflow()
                            return
                        }
                        let bytes = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(
                            to: UInt8.self)
                        inbox.append(source: source, bytes: Array(UnsafeBufferPointer(start: bytes, count: count)))
                        packet = MIDIPacketNext(packet)
                    }
                }) == noErr,
            MIDIOutputPortCreate(client, "Traktor feedback" as CFString, &output) == noErr
        else {
            stop()
            return
        }
        refresh()
    }

    func stop() {
        if input != 0 { MIDIPortDispose(input) }
        if output != 0 { MIDIPortDispose(output) }
        if client != 0 { MIDIClientDispose(client) }
        client = 0
        input = 0
        output = 0
        source = 0
        destination = 0
        _ = inbox.take()
        reset()
    }

    private func reset() {
        let wasReceiving = isReceiving
        lastHeartbeat = nil
        lastHello = nil
        lastFeedback.removeAll(keepingCapacity: true)
        decoder = .init()
        factoryInput = .init()
        if wasReceiving { onDisconnect?() }
    }

    static func availableFactoryModels() -> Set<TraktorFactoryModel> {
        let names = Set((0..<MIDIGetNumberOfSources()).map(MIDIGetSource).compactMap { endpoint in
            deviceNames(endpoint)?.names
        }.flatMap { $0 })
        return Set(TraktorFactoryModel.allCases.filter { names.contains($0.bridgeName) })
    }

    private static func deviceNames(_ endpoint: MIDIEndpointRef) -> (device: MIDIDeviceRef, names: [String])? {
        var entity: MIDIEntityRef = 0
        var device: MIDIDeviceRef = 0
        guard endpoint != 0, MIDIEndpointGetEntity(endpoint, &entity) == noErr, entity != 0,
            MIDIEntityGetDevice(entity, &device) == noErr, device != 0
        else { return nil }
        let names: [String] = [kMIDIPropertyName, kMIDIPropertyModel, kMIDIPropertyDisplayName].compactMap { key in
            var property: Unmanaged<CFString>?
            guard MIDIObjectGetStringProperty(device, key, &property) == noErr else { return nil }
            return property?.takeRetainedValue() as String?
        }
        return (device, names)
    }

    private func bridgeDevice(_ endpoint: MIDIEndpointRef) -> MIDIDeviceRef? {
        guard let info = Self.deviceNames(endpoint), info.names.contains(model.deviceName) else { return nil }
        return info.device
    }

    private func refresh() {
        let sources = (0..<MIDIGetNumberOfSources()).map(MIDIGetSource).filter { bridgeDevice($0) != nil }
        let next = sources.count == 1 ? sources[0] : 0
        let device = bridgeDevice(next)
        let destinations = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination).filter {
            device != nil && bridgeDevice($0) == device
        }
        let feedback = destinations.count == 1 ? destinations[0] : 0
        guard next != source || feedback != destination else { return }
        if source != 0 { MIDIPortDisconnectSource(input, source) }
        source = 0
        destination = 0
        reset()
        guard next != 0, feedback != 0,
            MIDIPortConnectSource(input, next, UnsafeMutableRawPointer(bitPattern: UInt(next))) == noErr
        else { return }
        source = next
        destination = feedback
    }

    func poll() {
        let now = ContinuousClock.now
        guard client != 0 else { return }
        let (frames, overflow, changed) = inbox.take()
        if changed { refresh() }
        if overflow { reset() }
        if !overflow {
            for frame in frames where source != 0 && frame.source == source {
                guard case .bytes(let bytes) = frame.payload else { continue }
                for report in decoder.append(bytes) {
                    switch report.kind {
                    case model.statusKind where report.payload == [1]:
                        lastHeartbeat = now
                    case model.statusKind where report.payload == [0]:
                        reset()
                    case model.inputKind where isReceiving:
                        if report.kind == .factoryInput {
                            if let raw = factoryInput.append(report.payload) { onReport?(raw) }
                            continue
                        }
                        let length = Int(report.payload[0])
                        if (1..<report.payload.count).contains(length) {
                            onReport?(Array(report.payload[1...length]))
                        }
                    default: break
                    }
                }
            }
        }
        if let lastHeartbeat, now - lastHeartbeat >= .seconds(2) { reset() }
        if destination != 0,
            lastHello == nil || (!isReceiving && lastHello.map { now - $0 >= .milliseconds(500) } == true)
        {
            lastHello = now
            _ = send(kind: model.statusKind, payload: [3])
        }
    }

    func feedback(_ report: [UInt8]) {
        guard isReceiving else { return }
        if case .factory(let factory) = model {
            guard let id = report.first, let index = factory.lightSizes.indices.first(where: {
                id == 0x80 + $0
            }), report.count == factory.lightSizes[index], lastFeedback[Int(id)] != report else { return }
            for payload in TraktorFactoryFragments.payloads(report) {
                guard send(kind: .factoryLights, payload: payload) else { return }
            }
            lastFeedback[Int(id)] = report
            return
        }
        let kind: ControllerBridgeFrame.Kind
        let key: Int
        var payload = report
        switch report.first {
        case 0x80 where report.count == model.lightSize:
            switch model {
            case .s4MK3: kind = .s4MK3Lights
            case .s4MK1: kind = .s4MK1Lights
            case .s2MK1: kind = .s2MK1Lights
            case .factory: return
            case .z1MK2, .x1MK3:
                kind = .modularLights
                payload = [UInt8(report.count)] + report + .init(repeating: 0, count: 50 - report.count)
            }
            key = 2
        case 0x32 where model == .s4MK3 && report.count == 41 && report[1] < 2:
            kind = .s4MK3Ring
            key = Int(report[1])
        default: return
        }
        guard lastFeedback[key] != report else { return }
        if send(kind: kind, payload: payload) { lastFeedback[key] = report }
    }

    func factoryScreen(_ payload: [UInt8]) {
        guard isReceiving, let screen = payload.first, screen < 2 else { return }
        let key = 256 + Int(screen)
        guard lastFeedback[key] != payload else { return }
        if send(kind: .factoryScreen, payload: payload) { lastFeedback[key] = payload }
    }

    private func send(kind: ControllerBridgeFrame.Kind, payload: [UInt8]) -> Bool {
        guard output != 0, destination != 0, let frame = try? ControllerBridgeFrame(kind: kind, payload: payload)
        else { return false }
        var list = MIDIPacketList()
        let start = MIDIPacketListInit(&list)
        _ = frame.encoded.withUnsafeBufferPointer {
            MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, start, 0, $0.count, $0.baseAddress!)
        }
        return list.numPackets == 1 && MIDISend(output, destination, &list) == noErr
    }
}
