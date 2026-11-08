#if os(iOS)
    import Combine
    import ExternalAccessory
    import Foundation
    import TDJCore

    /// Streams run on the main run loop. Every callback has a fixed work limit.
    @MainActor final class Z1AccessoryConnection: NSObject, StreamDelegate {
        var onReport: ((Z1InputReport) -> Void)?
        var onState: ((String, Z1CrossfaderCalibration?) -> Void)?
        private var enabled = false
        private var session: EASession?
        private var subscriptions: Set<AnyCancellable> = []
        private var decoder = Z1AccessoryProtocol.Decoder(framing: .lengthPrefixed)
        private var startup = Z1AccessoryProtocol.Startup()
        private var startupSent = false
        private var timeout: Task<Void, Never>?
        private var commands: [[UInt8]] = []
        private var writing: [UInt8] = []
        private var writeOffset = 0
        private var pendingFeedback: [UInt8]?
        private var lastFeedback: [UInt8] = []
        private var receivedInput = false

        func start() throws {
            guard !enabled else { return }
            enabled = true
            let manager = EAAccessoryManager.shared()
            manager.registerForLocalNotifications()
            NotificationCenter.default.publisher(for: .EAAccessoryDidConnect)
                .receive(on: RunLoop.main).sink { [weak self] _ in self?.connect() }.store(in: &subscriptions)
            NotificationCenter.default.publisher(for: .EAAccessoryDidDisconnect)
                .receive(on: RunLoop.main).sink { [weak self] _ in
                    guard let self, let session = self.session, session.accessory?.isConnected != true else { return }
                    self.closeSession()
                    self.onState?("Z1 disconnected. Waiting for the original Z1.", nil)
                    self.connect()
                }.store(in: &subscriptions)
            onState?("Waiting for the original Z1 accessory.", nil)
            connect()
        }

        func stop() {
            enabled = false
            subscriptions.removeAll()
            EAAccessoryManager.shared().unregisterForLocalNotifications()
            closeSession()
            onState?("Z1 disabled", nil)
        }

        private func connect() {
            guard enabled, session == nil else { return }
            guard
                let accessory = EAAccessoryManager.shared().connectedAccessories.first(where: {
                    $0.isConnected && $0.protocolStrings.contains(Z1AccessoryProtocol.identifier)
                })
            else { return }
            guard let opened = EASession(accessory: accessory, forProtocol: Z1AccessoryProtocol.identifier),
                let input = opened.inputStream, let output = opened.outputStream
            else {
                onState?("Cannot open the Z1 accessory. Close Traktor DJ, then reconnect the Z1.", nil)
                return
            }
            session = opened
            decoder = .init(framing: .init(firmwareRevision: accessory.firmwareRevision))
            onState?("Opening the Z1 native connection.", nil)
            for stream in [input as Stream, output as Stream] {
                stream.delegate = self
                stream.schedule(in: .main, forMode: .common)
                stream.open()
            }
            armTimeout()
        }

        private func closeSession() {
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
            startupSent = false
            decoder = .init(framing: .lengthPrefixed)
            commands.removeAll()
            writing.removeAll()
            writeOffset = 0
            pendingFeedback = nil
            lastFeedback.removeAll()
            receivedInput = false
        }

        private func fail(_ message: String) {
            closeSession()
            onState?(message, nil)
        }

        private func armTimeout() {
            timeout?.cancel()
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                self?.fail("The Z1 did not complete startup. Reconnect the Z1 to retry.")
            }
        }

        nonisolated func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
            MainActor.assumeIsolated { handle(aStream, event: eventCode) }
        }

        private func handle(_ stream: Stream, event: Stream.Event) {
            guard let session, stream === session.inputStream || stream === session.outputStream else { return }
            if event.contains(.errorOccurred) || event.contains(.endEncountered) {
                fail("The Z1 connection closed. Reconnect the Z1 to retry.")
                return
            }
            if !startupSent, session.inputStream?.streamStatus == .open, session.outputStream?.streamStatus == .open {
                startupSent = true
                onState?("Reading Z1 calibration.", nil)
                enqueueRequest(0xd0)
            }
            if event.contains(.hasBytesAvailable) { readInput() }
            if event.contains(.hasSpaceAvailable) { flushOutput() }
        }

        private func enqueueRequest(_ id: UInt8) {
            guard commands.count < 4 else {
                fail("Z1 output overload. Reconnect the Z1 to retry.")
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
                fail("Cannot read the Z1. Reconnect the Z1 to retry.")
                return
            }
            guard count > 0 else { return }
            do {
                let frames = try decoder.append(Array(bytes.prefix(count)))
                for frame in frames {
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
                fail("The Z1 sent an invalid report or calibration. Reconnect the Z1 to retry.")
            }
        }

        func send(_ report: [UInt8]) {
            guard receivedInput, report != lastFeedback,
                let bytes = try? Z1AccessoryProtocol.feedback(report, framing: decoder.framing)
            else { return }
            lastFeedback = report
            // Keep only the latest unsent light state. Never replace a partially written packet.
            pendingFeedback = bytes
            flushOutput()
        }

        private func flushOutput() {
            guard let output = session?.outputStream else { return }
            for _ in 0..<8 {
                guard output.hasSpaceAvailable else { return }
                if writing.isEmpty {
                    if !commands.isEmpty {
                        writing = commands.removeFirst()
                    } else if let pendingFeedback {
                        writing = pendingFeedback
                        self.pendingFeedback = nil
                    } else {
                        return
                    }
                    writeOffset = 0
                }
                let count = writing.withUnsafeBufferPointer {
                    output.write($0.baseAddress!.advanced(by: writeOffset), maxLength: writing.count - writeOffset)
                }
                if count < 0 {
                    fail("Cannot write to the Z1. Reconnect the Z1 to retry.")
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
