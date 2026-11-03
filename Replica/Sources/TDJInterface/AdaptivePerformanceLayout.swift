import Foundation
import CoreGraphics

struct PerformanceDockGeometry {
    static let dockWidth = 96.0
    static let minimumHeight = 576.0
    let aButtons: [CGRect]
    let bButtons: [CGRect]
    let crossfader: CGRect
    let workArea: CGRect
    let contentHeight: Double
    let fits: Bool

    init(width: Double, height: Double) {
        let width = width.isFinite ? max(0, width) : 0
        let height = height.isFinite ? max(0, height) : 0
        let contentHeight = max(Self.minimumHeight, height)
        self.contentHeight = contentHeight
        fits = width >= Self.dockWidth + 44 && height >= Self.minimumHeight
        workArea = CGRect(x: 0, y: 0, width: max(0, width - Self.dockWidth), height: height)
        let x = workArea.width + 8
        aButtons = (0..<4).map { CGRect(x: x, y: 28 + Double($0) * 52, width: 80, height: 48) }
        bButtons = (0..<4).map { CGRect(x: x, y: contentHeight - 212 + Double($0) * 52, width: 80, height: 48) }
        crossfader = CGRect(x: x, y: contentHeight / 2 - 48, width: 80, height: 96)
    }
}

struct PerformanceWorkspaceGeometry {
    let dock: PerformanceDockGeometry
    let deckArea: CGRect
    let libraryArea: CGRect

    init(width: Double, height: Double, browserVisible: Bool, deckShare: Double) {
        dock = PerformanceDockGeometry(width: width, height: height)
        let available = dock.workArea.height
        let deckHeight = AdaptivePerformanceLayout.deckHeight(available: available,
            browserVisible: browserVisible, share: deckShare)
        deckArea = CGRect(x: 0, y: 0, width: dock.workArea.width, height: deckHeight)
        let libraryY = min(available, deckHeight + AdaptivePerformanceLayout.dividerHeight)
        libraryArea = CGRect(x: 0, y: libraryY, width: dock.workArea.width, height: max(0, available - libraryY))
    }
}

struct AdaptivePerformanceLayout {
    static let dividerHeight = 16.0
    static let minimumDeckHeight = 132.0
    static let librarySnapDistance = 80.0

    static func deckHeight(available: Double, browserVisible: Bool, share: Double) -> Double {
        let height = max(0, available)
        guard browserVisible else { return max(0, height - dividerHeight) }
        let minimum = min(minimumDeckHeight, height)
        let maximum = max(minimum, height - dividerHeight)
        return min(maximum, max(minimum, height * (share.isFinite ? share : 0)))
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
        expansion = min(1, max(0, (height - 56) / 144))
        headerHeight = 48 * expansion
        sectionHeight = 0
        footerHeight = 44 * expansion
        overviewHeight = min(height, 32 - 8 * expansion)
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
