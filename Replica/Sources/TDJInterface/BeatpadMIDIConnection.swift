#if os(iOS)
    import CoreMIDI
    import Darwin
    import Foundation
    import TDJCore

    @MainActor final class BeatpadMIDIConnection {
        private let inbox = ControllerMIDIInbox()
        private var client: MIDIClientRef = 0
        private var input: MIDIPortRef = 0
        private var output: MIDIPortRef = 0
        private var source: MIDIEndpointRef = 0
        private var destination: MIDIEndpointRef = 0
        private var decoder = ControllerMIDIDecoder()
        private var sent: [UInt16: UInt8] = [:]
        private var timer: Timer?
        private static let secondsPerTick: Double = {
            var timebase = mach_timebase_info_data_t()
            mach_timebase_info(&timebase)
            return Double(timebase.numer) / Double(timebase.denom) * 1e-9
        }()

        var isConnected: Bool { source != 0 }
        var hasFeedback: Bool { destination != 0 && output != 0 }
        var onMessage: ((ControllerMIDIMessage, Double) -> Void)?
        var onReset: (() -> Void)?

        private static func device(for endpoint: MIDIEndpointRef) -> MIDIDeviceRef? {
            var entity: MIDIEntityRef = 0
            var device: MIDIDeviceRef = 0
            guard endpoint != 0, MIDIEndpointGetEntity(endpoint, &entity) == noErr, entity != 0,
                MIDIEntityGetDevice(entity, &device) == noErr, device != 0
            else { return nil }
            return device
        }

        private static func isOnline(_ object: MIDIObjectRef) -> Bool {
            var offline: Int32 = 0
            return MIDIObjectGetIntegerProperty(object, kMIDIPropertyOffline, &offline) != noErr || offline == 0
        }

        static func isBeatpad(_ endpoint: MIDIEndpointRef) -> Bool {
            guard let device = device(for: endpoint), isOnline(device), isOnline(endpoint) else { return false }
            return [device, endpoint].contains { object in
                [kMIDIPropertyModel, kMIDIPropertyName, kMIDIPropertyDisplayName].contains { key in
                    var name: Unmanaged<CFString>?
                    guard MIDIObjectGetStringProperty(object, key, &name) == noErr,
                        let name = name?.takeRetainedValue() as String?
                    else { return false }
                    return BeatpadIdentity.matches(name)
                }
            }
        }

        func start() {
            guard client == 0 else { return }
            let inbox = inbox
            guard
                MIDIClientCreateWithBlock("GenErik Beatpad" as CFString, &client, { _ in inbox.requestRefresh() })
                    == noErr,
                MIDIInputPortCreateWithBlock(
                    client, "Beatpad controls" as CFString, &input,
                    { packets, context in
                        guard let context else { return }
                        let source = UInt32(truncatingIfNeeded: UInt(bitPattern: context))
                        guard packets.pointee.numPackets <= 128 else {
                            inbox.signalOverflow()
                            return
                        }
                        let packetOffset = MemoryLayout<MIDIPacketList>.offset(of: \.packet)!
                        let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \.data)!
                        var packet = UnsafeMutablePointer(
                            mutating:
                                UnsafeRawPointer(packets).advanced(by: packetOffset).assumingMemoryBound(
                                    to: MIDIPacket.self))
                        for _ in 0..<packets.pointee.numPackets {
                            let count = Int(packet.pointee.length)
                            guard count <= 4096 else {
                                inbox.signalOverflow()
                                return
                            }
                            let bytes = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(
                                to: UInt8.self)
                            let timestamp = packet.pointee.timeStamp
                            inbox.append(
                                source: source, bytes: Array(UnsafeBufferPointer(start: bytes, count: count)),
                                timestamp: timestamp == 0 ? mach_absolute_time() : timestamp)
                            packet = MIDIPacketNext(packet)
                        }
                    }) == noErr
            else {
                stop()
                return
            }
            if MIDIOutputPortCreate(client, "Beatpad lights" as CFString, &output) != noErr { output = 0 }
            refresh()
        }

        func stop() {
            disconnect()
            if input != 0 { MIDIPortDispose(input) }
            if output != 0 { MIDIPortDispose(output) }
            if client != 0 { MIDIClientDispose(client) }
            client = 0
            input = 0
            output = 0
            _ = inbox.take()
        }

        private func disconnect() {
            timer?.invalidate()
            timer = nil
            destination = 0
            if source != 0 {
                MIDIPortDisconnectSource(input, source)
                source = 0
                reset()
            }
        }

        private func reset() {
            decoder = .init()
            sent.removeAll(keepingCapacity: true)
            onReset?()
        }

        @discardableResult private func refresh() -> Bool {
            let sources = (0..<MIDIGetNumberOfSources()).map(MIDIGetSource).filter(Self.isBeatpad)
            let next = sources.count == 1 ? sources[0] : 0
            let device = Self.device(for: next)
            let outputs = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination).filter {
                device != nil && Self.device(for: $0) == device && Self.isOnline($0)
            }
            let target = outputs.count == 1 ? outputs[0] : 0
            if source == next {
                if destination != target {
                    destination = target
                    sent.removeAll(keepingCapacity: true)
                }
                return false
            }
            disconnect()
            guard next != 0,
                MIDIPortConnectSource(input, next, UnsafeMutableRawPointer(bitPattern: UInt(next))) == noErr
            else { return true }
            source = next
            destination = target
            let timer = Timer(timeInterval: 1 / 120.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
            return true
        }

        func poll() {
            guard client != 0 else { return }
            let (frames, overflow, changed) = inbox.take()
            if changed, refresh() { return }
            if overflow {
                reset()
                return
            }
            for frame in frames where source != 0 && frame.source == source {
                guard case .bytes(let bytes) = frame.payload else { continue }
                let seconds = Double(frame.timestamp) * Self.secondsPerTick
                for message in decoder.append(bytes) { onMessage?(message, seconds) }
            }
        }

        func invalidateFeedback() { sent.removeAll(keepingCapacity: true) }

        func feedback(_ lights: [BeatpadLight]) {
            guard hasFeedback else { return }
            let changed = lights.filter { sent[$0.key] != $0.value }
            guard !changed.isEmpty else { return }
            let bytes = changed.flatMap { [0x90 | $0.channel, $0.note, $0.value] }
            var list = MIDIPacketList()
            let start = MIDIPacketListInit(&list)
            let added = bytes.withUnsafeBufferPointer {
                MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, start, 0, $0.count, $0.baseAddress!)
            }
            guard added != nil, MIDISend(output, destination, &list) == noErr else { return }
            for light in changed { sent[light.key] = light.value }
        }
    }
#endif
