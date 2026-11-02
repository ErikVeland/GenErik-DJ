import Foundation

/// Preserves the development wheel curve while separating contact ownership from angle state.
@MainActor
final class TempoWheelGestureSession {
    private var owner: Int?
    private var previousAngle: Double?
    private var requestedBPM: Double?
    private var tapOrigin: SurfacePoint?
    private var tapBeganAt = 0.0
    private var lastTap: (point: SurfacePoint, time: Double)?
    private var waitingForRelease = false
    func handle(_ event: SurfaceEvent,width: Double,height: Double,bpm: Double,
                at time: Double = ProcessInfo.processInfo.systemUptime,
                resetTempo: (() -> Void)? = nil,change: (Double)->Void) {
        if event.phase == .cancelled {
            reset(); lastTap = nil; waitingForRelease = false; return
        }
        if waitingForRelease {
            if event.remaining.isEmpty { waitingForRelease = false }
            return
        }
        if owner == nil {
            guard event.phase == .began, let point = event.remaining.first else { return }
            owner=point.id
            requestedBPM=bpm
            tapOrigin = point
            tapBeganAt = time
        }
        guard let point = event.points.first(where: { $0.id == owner }) else {
            reset(); lastTap = nil; return
        }
        if event.points.count != 1 || time - tapBeganAt > 0.25
            || tapOrigin.map({ distance($0, point, width: width, height: height) > 8 }) == true {
            tapOrigin = nil
            lastTap = nil
        }
        if event.ending.contains(point.id) {
            let tapped = tapOrigin != nil && time >= tapBeganAt && time - tapBeganAt <= 0.25
            reset()
            waitingForRelease = !event.remaining.isEmpty
            if tapped {
                if let previous = lastTap, time >= previous.time, time - previous.time <= 0.35,
                   distance(previous.point, point, width: width, height: height) <= 24 {
                    lastTap = nil
                    resetTempo?()
                } else { lastTap = (point, time) }
            }
            return
        }
        let x=(point.x-0.5)*width,y=(point.y-0.5)*height
        guard hypot(x,y)>20 else { previousAngle=nil; return }
        let angle=atan2(y,x)
        if let previousAngle {
            var delta=angle-previousAngle
            if delta > .pi { delta-=2 * .pi }
            if delta < -.pi { delta+=2 * .pi }
            let value=max(30,min(300,(requestedBPM ?? bpm)+delta*180 / .pi*0.1))
            if value != requestedBPM { requestedBPM=value; change(value) }
        }
        previousAngle=angle
    }
    private func distance(_ a: SurfacePoint, _ b: SurfacePoint, width: Double, height: Double) -> Double {
        hypot((a.x - b.x) * width, (a.y - b.y) * height)
    }
    private func reset() { owner=nil; previousAngle=nil; requestedBPM=nil; tapOrigin=nil }
}
