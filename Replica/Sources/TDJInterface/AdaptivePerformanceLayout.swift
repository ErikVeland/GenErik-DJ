import CoreGraphics
import Foundation

struct PanelHandleMetrics {
    let expanded: Bool
    var extent: Double { expanded ? 44 : 12 }
}

struct PerformanceDockGeometry {
    static let dockWidth = 96.0
    // Eight 44-point buttons and an 88-point crossfader.
    static let minimumHeight = 440.0
    var aButtons: [CGRect] {
        let row = (crossfader.minY - verticalInset) / 4
        return (0..<4).map {
            let top = verticalInset + Double($0) * row
            let bottom = verticalInset + Double($0 + 1) * row
            return CGRect(x: workArea.width + 8, y: top, width: 80, height: bottom - top)
        }
    }
    var bButtons: [CGRect] {
        let row = (contentHeight - verticalInset - crossfader.maxY) / 4
        return (0..<4).map {
            let top = crossfader.maxY + Double($0) * row
            let bottom = crossfader.maxY + Double($0 + 1) * row
            return CGRect(x: workArea.width + 8, y: top, width: 80, height: bottom - top)
        }
    }
    let crossfader: CGRect
    let workArea: CGRect
    let contentHeight: Double
    let fits: Bool
    let verticalInset: Double

    init(width: Double, height: Double, deckBoundary: Double? = nil, verticalInset: Double = 0) {
        let width = width.isFinite ? max(0, width) : 0
        let height = height.isFinite ? max(0, height) : 0
        let verticalInset = verticalInset.isFinite ? max(0, verticalInset) : 0
        self.verticalInset = verticalInset
        let minimumHeight = Self.minimumHeight + 2 * verticalInset
        let contentHeight = max(minimumHeight, height)
        self.contentHeight = contentHeight
        fits = width >= Self.dockWidth + 44 && height >= minimumHeight
        workArea = CGRect(x: 0, y: 0, width: max(0, width - Self.dockWidth), height: height)
        let proposed = deckBoundary.flatMap { $0.isFinite ? $0 : nil } ?? contentHeight / 2
        let minimumSide = minimumHeight / 2
        let center = min(contentHeight - minimumSide, max(minimumSide, proposed))
        let half = min(
            (contentHeight - 2 * verticalInset) * 0.1, min(center, contentHeight - center) - verticalInset - 4 * 44)
        crossfader = CGRect(x: workArea.width + 8, y: center - half, width: 80, height: 2 * half)
    }
}

struct PerformanceWorkspaceGeometry {
    let dock: PerformanceDockGeometry
    let deckArea: CGRect
    let libraryArea: CGRect

    init(width: Double, height: Double, libraryExtent: Double, handleExtent: Double = 44) {
        let available = height.isFinite ? max(0, height) : 0
        let maximum = AdaptivePerformanceLayout.maximumLibraryExtent(available: available, handleExtent: handleExtent)
        let extent = libraryExtent.isFinite ? min(maximum, max(0, libraryExtent)) : 0
        let handle = min(handleExtent, available)
        let deckHeight = max(0, available - handle - extent)
        dock = PerformanceDockGeometry(width: width, height: deckHeight)
        deckArea = CGRect(x: 0, y: 0, width: dock.workArea.width, height: deckHeight)
        libraryArea = CGRect(x: 0, y: deckHeight + handle, width: width.isFinite ? max(0, width) : 0, height: extent)
    }

    init(width: Double, height: Double, browserVisible: Bool, deckShare: Double) {
        let available = height.isFinite ? max(0, height) : 0
        let deckHeight = AdaptivePerformanceLayout.deckHeight(
            available: available, browserVisible: browserVisible, share: deckShare)
        dock = PerformanceDockGeometry(width: width, height: deckHeight)
        deckArea = CGRect(x: 0, y: 0, width: dock.workArea.width, height: deckHeight)
        let libraryY = min(available, deckHeight + AdaptivePerformanceLayout.dividerHeight)
        libraryArea = CGRect(x: 0, y: libraryY, width: width.isFinite ? max(0, width) : 0, height: max(0, available - libraryY))
    }
}

struct AdaptivePerformanceLayout {
    static let dividerHeight = 16.0
    static let libraryHandleHeight = 44.0
    // Two padded 44-point targets and the separate 44-point deck divider.
    static let minimumDeckHeight = 148.0
    static let minimumCompactDeckHeight = 240.0
    static let librarySnapDistance = 80.0

    static func maximumLibraryExtent(available: Double, handleExtent: Double = 44) -> Double {
        guard available.isFinite else { return 0 }
        let handle = handleExtent.isFinite ? max(0, handleExtent) : 44
        return max(0, available - handle)
    }

    static func deckHeight(available: Double, browserVisible: Bool, share: Double) -> Double {
        let height = max(0, available)
        guard browserVisible else { return max(0, height - dividerHeight) }
        let minimum = min(minimumDeckHeight, height)
        let maximum = max(minimum, height - dividerHeight)
        return min(maximum, max(minimum, height * (share.isFinite ? share : 0)))
    }

    static func crossfaderHeight(available: Double) -> Double { max(0, available) * 0.3 }
    static func railClearance(available: Double) -> Double { crossfaderHeight(available: available) / 2 }

    static func panelWidth(available: Double) -> Double { min(196, max(144, available * 0.22)) }
}

struct AdaptiveDeckGeometry {
    let expansion: Double
    let headerHeight: Double
    let sectionHeight: Double
    let footerHeight: Double
    let overviewHeight: Double
    let hotcueHeight: Double
    let controlsHeight: Double
    let waveformHeight: Double
    let transportWidth: Double

    init(
        height: Double, hotcues: Bool = false, compactControls: Bool = false, editing: Bool = false,
        inlineControls: Bool = false, previewStripHeight: Double = 24
    ) {
        let height = max(0, height)
        expansion = min(1, max(0, (height - 56) / 144))
        let preferredHotcueHeight = hotcues ? 56 * expansion : 0
        let minimumWaveformHeight = 44.0
        let reservedControlsHeight = inlineControls ? 48.0 : 0
        let footerLimit = max(24, height - 44 - minimumWaveformHeight - preferredHotcueHeight - reservedControlsHeight)
        footerHeight = min(editing ? 44 : min(previewStripHeight, footerLimit), height * 0.35)
        headerHeight = min(44, max(0, height - footerHeight))
        sectionHeight = 0
        overviewHeight = 0
        let available = max(0, height - headerHeight - footerHeight)
        controlsHeight = min(reservedControlsHeight, available)
        hotcueHeight = min(max(0, available - controlsHeight), preferredHotcueHeight)
        waveformHeight = max(0, available - hotcueHeight - controlsHeight)
        transportWidth = 128 - 64 * expansion
    }
}

struct PerformanceToolsPanelState {
    var isVisible = true

    mutating func finishSwipe(horizontal: Double, vertical: Double, velocity: Double = 0) {
        guard horizontal.isFinite, vertical.isFinite, velocity.isFinite, abs(horizontal) > abs(vertical),
            abs(horizontal) >= 40 || (abs(horizontal) >= 16 && abs(velocity) >= 600)
        else { return }
        isVisible = horizontal < 0
    }
}
