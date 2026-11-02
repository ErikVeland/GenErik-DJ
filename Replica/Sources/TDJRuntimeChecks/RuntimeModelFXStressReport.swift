import Foundation

struct RuntimeModelFXStressReport: Codable, Sendable {
    let path: String
    let setupSubmissions: Int
    let controlSubmissions: Int
    let expectedControlSubmissions: Int
    let controlPersistenceRequests: Int
    let expectedControlPersistenceRequests: Int
    let persistedStateMatches: Bool
    let passed: Bool
    let scope: String

    init(batches: Int, setupSubmissions: Int, controlSubmissions: Int,
         controlPersistenceRequests: Int, persistedStateMatches: Bool) {
        path="ReplicaModel.setEffect"
        self.setupSubmissions=setupSubmissions;self.controlSubmissions=controlSubmissions
        expectedControlSubmissions=batches*6
        self.controlPersistenceRequests=controlPersistenceRequests
        expectedControlPersistenceRequests=(batches/100)*6
        self.persistedStateMatches=persistedStateMatches
        passed=batches>0 && setupSubmissions==6 && controlSubmissions==expectedControlSubmissions
            && controlPersistenceRequests==expectedControlPersistenceRequests && persistedStateMatches
        scope="Six model FX updates per batch. Every hundredth batch requests persistence for all six slots. Shutdown flushes the final state. Physical touch, frame presentation and original-app parity require separate checks."
    }
}
