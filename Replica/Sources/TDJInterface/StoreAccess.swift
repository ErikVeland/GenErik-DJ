import Foundation
import Observation
import StoreKit
import TDJCore

public enum StoreAccessFeature: String, CaseIterable, Identifiable, Sendable {
    case controllerSupport
    case recording
    case openFormat

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .controllerSupport: "Controller Support"
        case .recording: "Recording"
        case .openFormat: "Open Format"
        }
    }
}

private enum StoreAccessProductID: String, CaseIterable {
    case controllerMonthly = "org.generikdj.replica.controller.monthly"
    case controllerLifetime = "org.generikdj.replica.controller.lifetime"
    case recordingMonthly = "org.generikdj.replica.recording.monthly"
    case recordingLifetime = "org.generikdj.replica.recording.lifetime"
    case openFormatMonthly = "org.generikdj.replica.open_format.monthly"
    case openFormatLifetime = "org.generikdj.replica.open_format.lifetime"
    case allInOneLifetime = "org.generikdj.replica.all_in_one.lifetime"

    var features: Set<StoreAccessFeature> {
        switch self {
        case .controllerMonthly, .controllerLifetime: [.controllerSupport]
        case .recordingMonthly, .recordingLifetime: [.recording]
        case .openFormatMonthly, .openFormatLifetime: [.openFormat]
        case .allInOneLifetime: Set(StoreAccessFeature.allCases)
        }
    }

    var isLifetime: Bool {
        switch self {
        case .controllerLifetime, .recordingLifetime, .openFormatLifetime, .allInOneLifetime: true
        default: false
        }
    }

    var feature: StoreAccessFeature? {
        switch self {
        case .controllerMonthly, .controllerLifetime: .controllerSupport
        case .recordingMonthly, .recordingLifetime: .recording
        case .openFormatMonthly, .openFormatLifetime: .openFormat
        case .allInOneLifetime: nil
        }
    }
}

@MainActor @Observable public final class StoreAccess {
    public static let customDJNameKey = "org.generikdj.replica.custom-dj-name"
    public static let previewDuration: TimeInterval = 14 * 24 * 60 * 60
    public static let controllerLimit: TimeInterval = 20 * 60
    public static let recordingLimit: TimeInterval = 20 * 60
    public static let performanceLimit: TimeInterval = 70 * 60

    public private(set) var products: [Product] = []
    public private(set) var purchaseMessage = ""
    public private(set) var loading = false
    public private(set) var clockNow = Date()
    public let previewStartedAt: Date

    @ObservationIgnored private var activeProductIDs = Set<String>()
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    @ObservationIgnored private let performanceURL: URL
    @ObservationIgnored private var performanceStartedAt: Date?
    @ObservationIgnored private var controllerStartedAt: Date?
    @ObservationIgnored private var recordingStartedAt: Date?
    @ObservationIgnored private var hasStarted = false

    public init(root: URL, now: Date = Date()) {
        performanceURL = root.appendingPathComponent("access-performance.json")
        let previewURL = root.appendingPathComponent("access-preview-start.json")
        if let data = try? Data(contentsOf: previewURL),
            let stored = try? JSONDecoder().decode(Date.self, from: data)
        {
            previewStartedAt = stored
        } else {
            previewStartedAt = now
            if let data = try? JSONEncoder().encode(now) {
                try? data.write(to: previewURL, options: .atomic)
            }
        }
        if let data = try? Data(contentsOf: performanceURL),
            let state = try? JSONDecoder().decode(PerformanceState.self, from: data)
        {
            performanceStartedAt = state.startedAt
            controllerStartedAt = state.controllerStartedAt
            recordingStartedAt = state.recordingStartedAt
        }
    }

    public var previewEndsAt: Date { previewStartedAt.addingTimeInterval(Self.previewDuration) }
    public var previewIsActive: Bool { Date() < previewEndsAt }
    public var personalisationIsUnlocked: Bool {
        previewIsActive || activeProductIDs.contains { StoreAccessProductID(rawValue: $0)?.isLifetime == true }
    }
    public var performanceElapsed: TimeInterval {
        guard let performanceStartedAt else { return 0 }
        return max(0, clockNow.timeIntervalSince(performanceStartedAt))
    }
    public var controllerElapsed: TimeInterval {
        guard let controllerStartedAt else { return 0 }
        return max(0, clockNow.timeIntervalSince(controllerStartedAt))
    }
    public var recordingElapsed: TimeInterval {
        guard let recordingStartedAt else { return 0 }
        return max(0, clockNow.timeIntervalSince(recordingStartedAt))
    }
    public var performanceRemaining: TimeInterval {
        max(0, Self.performanceLimit - performanceElapsed)
    }
    public var controllerRemaining: TimeInterval {
        max(0, Self.controllerLimit - controllerElapsed)
    }
    public var recordingRemaining: TimeInterval {
        max(0, Self.recordingLimit - recordingElapsed)
    }
    public var performanceLimitReached: Bool {
        !isUnlocked(.openFormat) && performanceElapsed >= Self.performanceLimit
    }
    public var controllerLimitReached: Bool {
        !isUnlocked(.controllerSupport) && controllerStartedAt != nil && controllerElapsed >= Self.controllerLimit
    }
    public var recordingLimitReached: Bool {
        !isUnlocked(.recording) && recordingStartedAt != nil && recordingElapsed >= Self.recordingLimit
    }
    public var hasActivePerformance: Bool { performanceStartedAt != nil }

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true
        clockNow = Date()
        startPerformanceClock()
        updatesTask = Task { [weak self] in
            await self?.refreshProducts()
            await self?.refreshEntitlements()
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                guard let self else { return }
                await self.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    public func beginPerformance(controllerInput: Bool = false, now: Date = Date()) {
        clockNow = now
        if performanceStartedAt == nil { performanceStartedAt = now }
        if controllerInput && controllerStartedAt == nil { controllerStartedAt = now }
        persistPerformance()
        startPerformanceClock()
    }

    public func beginControllerUse(now: Date = Date()) {
        guard performanceStartedAt != nil, controllerStartedAt == nil else { return }
        clockNow = now
        controllerStartedAt = now
        persistPerformance()
    }

    public func beginRecording(now: Date = Date()) {
        guard recordingStartedAt == nil else { return }
        clockNow = now
        if performanceStartedAt == nil { performanceStartedAt = now }
        recordingStartedAt = now
        persistPerformance()
        startPerformanceClock()
    }

    public func endPerformance() {
        performanceStartedAt = nil
        controllerStartedAt = nil
        recordingStartedAt = nil
        try? FileManager.default.removeItem(at: performanceURL)
    }

    public func isUnlocked(_ feature: StoreAccessFeature, now: Date = Date()) -> Bool {
        if now < previewEndsAt { return true }
        return hasPurchase(for: feature)
    }

    public func hasPurchase(for feature: StoreAccessFeature) -> Bool {
        return activeProductIDs.contains { productID in
            StoreAccessProductID(rawValue: productID)?.features.contains(feature) == true
        }
    }

    public func products(for feature: StoreAccessFeature) -> [Product] {
        products.filter { StoreAccessProductID(rawValue: $0.id)?.feature == feature }
            .sorted { $0.id < $1.id }
    }

    public var allInOneProduct: Product? {
        products.first { $0.id == StoreAccessProductID.allInOneLifetime.rawValue }
    }

    public func purchase(_ product: Product) async {
        purchaseMessage = ""
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    purchaseMessage = "The App Store could not verify this purchase."
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                purchaseMessage = "The App Store is waiting for purchase approval."
            case .userCancelled:
                break
            @unknown default:
                purchaseMessage = "The App Store did not complete this purchase."
            }
        } catch {
            purchaseMessage = "Purchase failed. Check your App Store account and try again."
        }
    }

    public func restorePurchases() async {
        purchaseMessage = ""
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseMessage = "Purchases could not be restored. Try again when the App Store is available."
        }
    }

    private func refreshProducts() async {
        loading = true
        defer { loading = false }
        do {
            products = try await Product.products(for: StoreAccessProductID.allCases.map(\.rawValue))
        } catch {
            purchaseMessage = "Purchase options are not available. Try again when the App Store is available."
        }
    }

    private func refreshEntitlements() async {
        var verified = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                transaction.revocationDate == nil,
                StoreAccessProductID(rawValue: transaction.productID) != nil
            else { continue }
            verified.insert(transaction.productID)
        }
        activeProductIDs = verified
    }

    private func startPerformanceClock() {
        guard clockTask == nil else { return }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                let isActive = self?.performanceStartedAt != nil || self?.recordingStartedAt != nil
                let interval: TimeInterval = isActive ? 1 : 60
                try? await Task.sleep(for: .seconds(interval))
                guard let self, !Task.isCancelled else { return }
                clockNow = Date()
            }
        }
    }

    private func persistPerformance() {
        let state = PerformanceState(
            startedAt: performanceStartedAt, controllerStartedAt: controllerStartedAt,
            recordingStartedAt: recordingStartedAt)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: performanceURL, options: .atomic)
    }

    private struct PerformanceState: Codable {
        let startedAt: Date?
        let controllerStartedAt: Date?
        let recordingStartedAt: Date?
    }
}
