import Foundation

struct AdaptivePerformanceLayout {
    static let dividerHeight = 16.0
    static let minimumDeckHeight = 132.0
    static let librarySnapDistance = 80.0

    static func deckHeight(available: Double, browserVisible: Bool, share: Double) -> Double {
        let height = max(0, available)
        guard browserVisible else { return max(0, height - dividerHeight) }
        let minimum = min(minimumDeckHeight, height)
        let maximum = max(minimum, height - dividerHeight)
        return min(maximum, max(minimum, height * (share.isFinite ? share : 0.28)))
    }

    static func crossfaderHeight(available: Double) -> Double { max(0, available) * 0.3 }
    static func railClearance(available: Double) -> Double { crossfaderHeight(available: available) / 2 }

    static func panelWidth(available: Double) -> Double {
        min(196, max(144, available * 0.22))
    }
}

struct AdaptiveDeckGeometry {
    let expansion: Double
    let headerHeight: Double
    let sectionHeight: Double
    let footerHeight: Double
    let overviewHeight: Double
    let hotcueHeight: Double
    let waveformHeight: Double
    let transportWidth: Double

    init(height: Double, hotcues: Bool = false) {
        let height = max(0, height)
        expansion = min(1, max(0, (height - 56) / 180))
        headerHeight = 64 * expansion
        sectionHeight = 24 * expansion
        footerHeight = 24 * expansion
        overviewHeight = min(height, 56 - 12 * expansion)
        hotcueHeight = hotcues ? 56 * expansion : 0
        waveformHeight = max(0, height - headerHeight - sectionHeight - footerHeight - overviewHeight - hotcueHeight)
        transportWidth = 128 - 64 * expansion
    }
}

struct PerformanceToolsPanelState {
    var isVisible = true

    mutating func finishSwipe(horizontal: Double, vertical: Double, velocity: Double = 0) {
        guard horizontal.isFinite, vertical.isFinite, velocity.isFinite,
              abs(horizontal) > abs(vertical),
              abs(horizontal) >= 40 || (abs(horizontal) >= 16 && abs(velocity) >= 600) else { return }
        isVisible = horizontal < 0
    }
}
