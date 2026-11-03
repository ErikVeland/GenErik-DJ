import Foundation

struct AdaptivePerformanceLayout {
    static let dividerHeight = 16.0
    static let minimumDeckHeight = 132.0
    static let minimumLibraryHeight = 220.0

    static func deckHeight(available: Double, browserVisible: Bool, share: Double) -> Double {
        let height = max(0, available)
        guard browserVisible else { return height }
        let minimum = min(minimumDeckHeight, height)
        let maximum = max(minimum, height - minimumLibraryHeight - dividerHeight)
        return min(maximum, max(minimum, height * (share.isFinite ? share : 0.28)))
    }

    static func panelWidth(available: Double) -> Double {
        min(196, max(144, available * 0.22))
    }
}
