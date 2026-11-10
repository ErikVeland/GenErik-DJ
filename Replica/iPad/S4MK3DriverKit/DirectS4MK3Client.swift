import TDJInterface

@MainActor final class DirectS4MK3Client: S4MK3ReportConnection {
    private struct Update: Sendable {
        var connected = false
        var reset = false
        var reports: [[UInt8]] = []
        var sent: [Int: [UInt8]] = [:]
    }

    private actor Worker {
        private var connection: UInt32 = 0

        func close() {
            s4_mk3_driver_close(connection)
            connection = 0
        }

        func exchange(outgoing: [Int: [UInt8]]) -> Update {
            if connection == 0 { connection = s4_mk3_driver_open() }
            guard connection != 0 else { return .init() }
            var bytes = [UInt8](repeating: 0, count: 1540)
            let count = bytes.withUnsafeMutableBufferPointer {
                s4_mk3_driver_read(connection, $0.baseAddress, UInt32($0.count))
            }
            guard count == bytes.count, bytes[0] == 1, bytes[1] & 0xfe == 0, bytes[2] <= 16, bytes[3] == 0 else {
                close()
                return .init()
            }
            var update = Update(connected: true, reset: bytes[1] == 1)
            for slot in 0..<Int(bytes[2]) {
                let offset = 4 + slot * 96
                let length = Int(bytes[offset])
                guard (1...95).contains(length) else {
                    close()
                    return .init()
                }
                update.reports.append(Array(bytes[(offset + 1)...(offset + length)]))
            }
            // Baseline frames must reach the mapper before any feedback from a prior connection.
            if update.reset { return update }
            for (key, report) in outgoing.sorted(by: { $0.key < $1.key }) {
                let result = report.withUnsafeBufferPointer {
                    s4_mk3_driver_write(connection, $0.baseAddress, UInt32($0.count))
                }
                if result < 0 {
                    close()
                    return .init()
                }
                if result == 0 { update.sent[key] = report }
            }
            return update
        }
    }

    var isReceiving = false
    var onReport: (([UInt8]) -> Void)?
    var onDisconnect: (() -> Void)?
    private var worker = Worker()
    private var running = false
    private var exchange: Task<Void, Never>?
    private var nextProbe: ContinuousClock.Instant?
    private var pending: [Int: [UInt8]] = [:]
    private var sent: [Int: [UInt8]] = [:]
    private var writing: [Int: [UInt8]] = [:]

    func start() { running = true }

    func stop() {
        running = false
        exchange?.cancel()
        exchange = nil
        let closing = worker
        worker = Worker()
        Task { await closing.close() }
        reset()
    }

    private func reset() {
        let hadConnection = isReceiving
        isReceiving = false
        nextProbe = nil
        pending.removeAll(keepingCapacity: true)
        sent.removeAll(keepingCapacity: true)
        writing.removeAll(keepingCapacity: true)
        if hadConnection { onDisconnect?() }
    }

    func poll() {
        let now = ContinuousClock.now
        guard running, exchange == nil, nextProbe.map({ now >= $0 }) ?? true else { return }
        let worker = worker
        let outgoing = pending
        writing = outgoing
        exchange = Task { [weak self] in
            let update = await worker.exchange(outgoing: outgoing)
            guard let self, !Task.isCancelled else { return }
            exchange = nil
            writing.removeAll(keepingCapacity: true)
            guard update.connected else {
                reset()
                nextProbe = .now + .seconds(1)
                return
            }
            if update.reset { reset() }
            isReceiving = true
            for (key, report) in update.sent {
                sent[key] = report
                if pending[key] == report { pending[key] = nil }
            }
            for report in update.reports { onReport?(report) }
        }
    }

    func feedback(_ report: [UInt8]) {
        guard isReceiving else { return }
        let key: Int
        switch report.first {
        case 0x80 where report.count == 95: key = 0
        case 0x32 where report.count == 41 && report[1] < 2: key = 1 + Int(report[1])
        default: return
        }
        if pending[key] == report { return }
        // An outstanding write can still change the hardware after this call.
        pending[key] = sent[key] == report && writing[key] == nil ? nil : report
    }
}
