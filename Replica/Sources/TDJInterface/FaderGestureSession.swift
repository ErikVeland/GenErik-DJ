import Foundation

enum FaderAxis: Equatable { case horizontal, vertical }

@MainActor
final class FaderGestureSession {
    private var held: Double?
    private var contactInsets: [Int: Double] = [:]
    func handle(_ event: SurfaceEvent,value: @autoclosure () -> Double,range: ClosedRange<Double>,reset: Double?,axis: FaderAxis = .horizontal,
                insetFraction: Double = 0,change: (Double)->Void) {
        if event.phase == .cancelled {
            if let held { change(held) }; held=nil; contactInsets.removeAll(); return
        }
        for point in event.points where contactInsets[point.id] == nil { contactInsets[point.id] = insetFraction }
        defer {
            for id in event.ending { contactInsets[id] = nil }
            if event.phase == .ended && event.remaining.isEmpty { contactInsets.removeAll() }
        }
        if event.points.count>1 && held == nil && event.phase != .ended { held=value() }
        if event.phase == .ended {
            if event.remaining.count<=1,let held { change(held); self.held=nil; return }
            if event.remaining.isEmpty { return }
        }
        guard let point=event.remaining.last else { return }
        let position=axis == .vertical ? 1-point.y : point.x
        let inset=min(0.49,max(0,contactInsets[point.id] ?? insetFraction))
        let fraction=min(1,max(0,(position-inset)/(1-2*inset)))
        let target=range.lowerBound+fraction*(range.upperBound-range.lowerBound)
        change(reset != nil && abs(fraction-0.5)<0.035 ? reset! : target)
    }
}
