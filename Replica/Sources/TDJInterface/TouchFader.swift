import SwiftUI

enum FaderAxis: Equatable { case horizontal, vertical }

struct TouchFader: View {
    let value: Double
    let range: ClosedRange<Double>
    let reset: Double?
    var axis: FaderAxis = .horizontal
    let readValue: () -> Double
    let change: (Double) -> Void
    @State private var gesture=FaderGestureSession()
    var body: some View {
        GeometryReader { geometry in
            let fraction=min(1,max(0,(value-range.lowerBound)/(range.upperBound-range.lowerBound)))
            ZStack {
                if axis == .horizontal {
                    Capsule().fill(.white.opacity(0.15)).frame(height:4)
                    if reset != nil { Rectangle().fill(.white.opacity(0.4)).frame(width:1,height:16) }
                    Circle().fill(.white).frame(width:12,height:12)
                        .position(x:6+max(0,geometry.size.width-12)*fraction,y:geometry.size.height/2)
                } else {
                    Path { path in
                        for tick in 0...8 {
                            let y=6+max(0,geometry.size.height-12)*Double(tick)/8
                            path.move(to:.init(x:6,y:y)); path.addLine(to:.init(x:max(6,geometry.size.width-6),y:y))
                        }
                    }.stroke(.white.opacity(0.08),lineWidth:1)
                    if reset != nil { Rectangle().fill(.white.opacity(0.3)).frame(height:1) }
                    RoundedRectangle(cornerRadius:1).fill(PerformancePalette.cyan)
                        .frame(width:max(8,geometry.size.width-8),height:12)
                        .overlay { Rectangle().fill(.black.opacity(0.25)).padding(.horizontal,4).padding(.vertical,4) }
                        .overlay { RoundedRectangle(cornerRadius:1).stroke(PerformancePalette.cyan,lineWidth:1) }
                        .position(x:geometry.size.width/2,y:6+max(0,geometry.size.height-12)*(1-fraction))
                }
                TouchSurface { event in
                    let length=axis == .vertical ? geometry.size.height : geometry.size.width
                    handleTouch(event,length:Double(length),using:gesture)
                }
            }.frame(maxHeight:.infinity)
        }.frame(height:axis == .horizontal ? 24 : nil)
            .onDisappear { gesture.handle(.init(phase:.cancelled,points:[],ending:[]),value:readValue(),range:range,reset:reset,axis:axis,change:change) }
    }
    func handleTouch(_ event:SurfaceEvent,length:Double,using session:FaderGestureSession) {
        session.handle(event,value:readValue(),range:range,reset:reset,axis:axis,
                       insetFraction:min(0.49,6/max(1,length)),change:change)
    }
}

@MainActor
final class FaderGestureSession {
    private var held: Double?
    func handle(_ event: SurfaceEvent,value: @autoclosure () -> Double,range: ClosedRange<Double>,reset: Double?,axis: FaderAxis = .horizontal,
                insetFraction: Double = 0,change: (Double)->Void) {
        if event.phase == .cancelled {
            if let held { change(held) }; held=nil; return
        }
        if event.points.count>1 && held == nil && event.phase != .ended { held=value() }
        if event.phase == .ended {
            if event.remaining.count<=1,let held { change(held); self.held=nil; return }
            if event.remaining.isEmpty { return }
        }
        guard let point=event.remaining.last else { return }
        let position=axis == .vertical ? 1-point.y : point.x
        let inset=min(0.49,max(0,insetFraction))
        let fraction=min(1,max(0,(position-inset)/(1-2*inset)))
        let target=range.lowerBound+fraction*(range.upperBound-range.lowerBound)
        change(reset != nil && abs(fraction-0.5)<0.035 ? reset! : target)
    }
}
