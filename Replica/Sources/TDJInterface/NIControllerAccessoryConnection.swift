#if os(iOS)
    import Combine
    import ExternalAccessory
    import Foundation
    import TDJCore

    /// Streams run on the main run loop. Every callback has a fixed work limit.
    @MainActor final class NIControllerAccessoryConnection: NSObject, StreamDelegate {
        enum Model {
            case z1, s2MK3, s3

            var name: String {
                switch self {
                case .z1: "Z1"
                case .s2MK3: "S2 Mk3"
                case .s3: "S3"
                }
            }

            var identifier: String {
                switch self {
                case .z1: Z1AccessoryProtocol.identifier
                case .s2MK3: S2MK3AccessoryProtocol.identifier
                case .s3: S3AccessoryProtocol.identifier
                }
            }

            var inputStartup: NIControllerReportStartup? {
                switch self {
                case .z1: nil
                case .s2MK3: S2MK3AccessoryProtocol.startup()
                case .s3: S3AccessoryProtocol.startup()
                }
            }

            func feedback(_ report: [UInt8], framing: Z1AccessoryProtocol.Framing) throws -> [UInt8] {
                switch self {
                case .z1: try Z1AccessoryProtocol.feedback(report, framing: framing)
                case .s2MK3: try S2MK3AccessoryProtocol.feedback(report)
                case .s3: try S3AccessoryProtocol.feedback(report)
                }
            }
        }

        private static var notificationUsers = 0
        private let model: Model
        private var name: String { model.name }
        init(model: Model) {
            self.model = model
            inputStartup = model.inputStartup
        }

        var onFrame: ((Z1AccessoryProtocol.Frame) -> Void)?
        var onDisconnect: (() -> Void)?
        var isReceiving: Bool { receivedInput }
        var onReport: ((Z1InputReport) -> Void)?
        var onState: ((String, Z1CrossfaderCalibration?) -> Void)?
        private var enabled = false
        private var session: EASession?
        private var subscriptions: Set<AnyCancellable> = []
        private var decoder = Z1AccessoryProtocol.Decoder(framing: .lengthPrefixed)
        private var startup = Z1AccessoryProtocol.Startup()
        private var inputStartup: NIControllerReportStartup?
        private var startupSent = false
        private var timeout: Task<Void, Never>?
        private var commands: [[UInt8]] = []
        private var writing: [UInt8] = []
        private var writeOffset = 0
        private var pendingFeedback: [(id: UInt8, bytes: [UInt8])] = []
        private var lastFeedback: [UInt8: [UInt8]] = [:]
        private var receivedInput = false

        func start() throws {
            guard !enabled else { return }
            enabled = true
            if Self.notificationUsers == 0 { EAAccessoryManager.shared().registerForLocalNotifications() }
            Self.notificationUsers += 1
            NotificationCenter.default.publisher(for: .EAAccessoryDidConnect)
                .receive(on: RunLoop.main).sink { [weak self] _ in self?.connect() }.store(in: &subscriptions)
            NotificationCenter.default.publisher(for: .EAAccessoryDidDisconnect)
                .receive(on: RunLoop.main).sink { [weak self] _ in
                    guard let self, let session = self.session, session.accessory?.isConnected != true else { return }
                    self.closeSession()
                    self.onState?("\(self.name) disconnected.", nil)
                    self.connect()
                }.store(in: &subscriptions)
            onState?("Waiting for \(name).", nil)
            connect()
        }

        func stop() {
            guard enabled else { return }
            enabled = false
            subscriptions.removeAll()
            Self.notificationUsers -= 1
            if Self.notificationUsers == 0 { EAAccessoryManager.shared().unregisterForLocalNotifications() }
            closeSession()
            onState?("\(name) disabled", nil)
        }

        private func connect() {
            guard enabled, session == nil else { return }
            guard
                let accessory = EAAccessoryManager.shared().connectedAccessories.first(where: {
                    $0.isConnected && $0.protocolStrings.contains(model.identifier)
                })
            else { return }
            guard let opened = EASession(accessory: accessory, forProtocol: model.identifier),
                let input = opened.inputStream, let output = opened.outputStream
            else {
                onState?("Cannot open \(name). Close Traktor DJ. Then reconnect the controller.", nil)
                return
            }
            session = opened
            decoder = .init(
                framing: model == .z1 ? .init(firmwareRevision: accessory.firmwareRevision) : .lengthPrefixed)
            onState?("Opening the \(name) native connection.", nil)
            for stream in [input as Stream, output as Stream] {
                stream.delegate = self
                stream.schedule(in: .main, forMode: .common)
                stream.open()
            }
            armTimeout()
        }

        private func closeSession() {
            let wasConnected = session != nil
            timeout?.cancel()
            timeout = nil
            if let session {
                for stream in [session.inputStream as Stream?, session.outputStream as Stream?].compactMap({ $0 }) {
                    stream.delegate = nil
                    stream.close()
                    stream.remove(from: .main, forMode: .common)
                }
            }
            session = nil
            startup = .init()
            inputStartup = model.inputStartup
            startupSent = false
            decoder = .init(framing: .lengthPrefixed)
            commands.removeAll()
            writing.removeAll()
            writeOffset = 0
            pendingFeedback.removeAll()
            lastFeedback.removeAll()
            receivedInput = false
            if wasConnected { onDisconnect?() }
        }

        private func fail(_ message: String) {
            closeSession()
            onState?(message, nil)
        }

        private func armTimeout() {
            timeout?.cancel()
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard let self else { return }
                fail("\(name) startup failed. Reconnect the controller.")
            }
        }

        nonisolated func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
            let identity = ObjectIdentifier(aStream)
            MainActor.assumeIsolated { handle(identity, event: eventCode) }
        }

        private func handle(_ identity: ObjectIdentifier, event: Stream.Event) {
            guard let session,
                identity == session.inputStream.map(ObjectIdentifier.init)
                    || identity == session.outputStream.map(ObjectIdentifier.init)
            else { return }
            if event.contains(.errorOccurred) || event.contains(.endEncountered) {
                fail("The \(name) connection closed. Reconnect the controller.")
                return
            }
            if !startupSent, session.inputStream?.streamStatus == .open, session.outputStream?.streamStatus == .open {
                startupSent = true
                if model == .z1 { onState?("Reading Z1 calibration.", nil) }
                enqueueRequest(model == .z1 ? 0xd0 : 1)
            }
            if event.contains(.hasBytesAvailable) { readInput() }
            if event.contains(.hasSpaceAvailable) { flushOutput() }
        }

        private func enqueueRequest(_ id: UInt8) {
            guard commands.count < 4 else {
                fail("\(name) output overload. Reconnect the controller.")
                return
            }
            commands.append(Z1AccessoryProtocol.request(id, framing: decoder.framing))
            flushOutput()
        }

        private func readInput() {
            guard let input = session?.inputStream else { return }
            var bytes = [UInt8](repeating: 0, count: 1024)
            // One bounded read per callback preserves time for audio and touch controls.
            let count = input.read(&bytes, maxLength: bytes.count)
            guard count >= 0 else {
                fail("Cannot read \(name). Reconnect the controller.")
                return
            }
            guard count > 0 else { return }
            do {
                let frames = try decoder.append(Array(bytes.prefix(count)))
                for frame in frames {
                    if var input = inputStartup {
                        let next = try input.consume(frame)
                        inputStartup = input
                        if let next {
                            onFrame?(frame)
                            enqueueRequest(next)
                            continue
                        }
                        guard input.ready, frame.reportID == 1 || frame.reportID == 2 else { continue }
                        if !receivedInput {
                            receivedInput = true
                            timeout?.cancel()
                            timeout = nil
                            onState?("\(name) native controls connected.", nil)
                        }
                        onFrame?(frame)
                        continue
                    }
                    if let next = try startup.consume(frame) {
                        if startup.ready {
                            onState?("Z1 calibrated. Waiting for control input.", startup.calibration)
                        }
                        armTimeout()
                        enqueueRequest(next)
                    }
                    if let report = try startup.input(frame) {
                        if !receivedInput {
                            receivedInput = true
                            timeout?.cancel()
                            timeout = nil
                            onState?("Z1 native controls connected.", startup.calibration)
                        }
                        onReport?(report)
                    }
                }
            } catch {
                fail("\(name) sent an invalid report. Reconnect the controller.")
            }
        }

        func send(_ report: [UInt8]) {
            guard receivedInput, let id = report.first, report != lastFeedback[id],
                let bytes = try? model.feedback(report, framing: decoder.framing)
            else { return }
            lastFeedback[id] = report
            // Retain one unsent packet per report. Finish partial writes before sending newer values.
            if let index = pendingFeedback.firstIndex(where: { $0.id == id }) {
                pendingFeedback[index].bytes = bytes
            } else {
                pendingFeedback.append((id, bytes))
            }
            flushOutput()
        }

        private func flushOutput() {
            guard let output = session?.outputStream else { return }
            for _ in 0..<8 {
                guard output.hasSpaceAvailable else { return }
                if writing.isEmpty {
                    if !commands.isEmpty {
                        writing = commands.removeFirst()
                    } else if !pendingFeedback.isEmpty {
                        writing = pendingFeedback.removeFirst().bytes
                    } else {
                        return
                    }
                    writeOffset = 0
                }
                let count = writing.withUnsafeBufferPointer {
                    output.write($0.baseAddress!.advanced(by: writeOffset), maxLength: writing.count - writeOffset)
                }
                if count < 0 {
                    fail("Cannot write to \(name). Reconnect the controller.")
                    return
                }
                if count == 0 { return }
                writeOffset += count
                if writeOffset == writing.count {
                    writing.removeAll(keepingCapacity: true)
                    writeOffset = 0
                }
            }
        }
    }
#endif
