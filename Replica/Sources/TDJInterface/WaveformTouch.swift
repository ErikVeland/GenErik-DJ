import SwiftUI
import TDJCore

/// Contact arbitration is shared by the waveform, grid editor and slicer.
/// Thresholds and quantisation choices are development policies, not NI measurements.
struct WaveformTouch: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let span: Double
    var onZoom: (Double) -> Void = { _ in }
    @State private var session=WaveformGestureSession()
    var body: some View {
        TouchSurface(geometryPolicy:.retainContactSpace) { session.handle($0,model:model,deck:deck,span:span,onZoom:onZoom) }
            .accessibilityLabel("Deck \(deck.rawValue) waveform")
    }
}

/// Grid zoom shares the stripe's development bounds. Original limits remain unmeasured.
enum WaveformZoom {
    static func seconds(frameSpan: Double, sampleRate: Double, duration: Double) -> Double {
        max(min(1,duration),min(duration,frameSpan/sampleRate))
    }
}

@MainActor
final class WaveformGestureSession {
    private struct GridPinch {
        let first: Int
        let second: Int
        let distance: Double
        let span: Double
        var lastDistance: Double
    }
    private var gridPinch: GridPinch?
    private var initial: [SurfacePoint] = []
    private var center: Double = 0
    private var initialGrid: BeatGrid?
    private var multi=false
    private var audition=false
    private var moved=false
    private var oldLoop: (Double,Double)?
    private var initialTiming: BeatTiming?
    private var wasLoop=false
    private var wasPlaying=false
    private var lastSlice: Double?
    private var lastAction: SuperSlicerAction?
    private var dismissLoop=false
    private var activeTrack: String?
    private var activeLoad: UUID?
    private var editingAtStart=false
    private var frozenAtStart=false
    private var familyAtStart: SuperSlicerFamily?
    private var ignoringContacts=false
    private var lastScratchX: Double?
    private var lastScratchTime: TimeInterval?
    private var scratchContact: Int?
    private var gestureSpan = TouchGestureValue()
    func handle(_ event: SurfaceEvent, model: ReplicaModel, deck: DeckID, span: Double,
                onZoom: (Double) -> Void = { _ in }) {
        let span = gestureSpan.value(for:event,current:span)
        func frame(_ x: Double) -> Double { model.boundedFrame(center+(x-0.5)*span,deck:deck) }
        func sliceRegion(_ point: SurfacePoint) -> (target: Double,start: Double,end: Double)? {
            guard let track=model.track(deck) else { return nil }
            let slice=floor(min(0.999,max(0,point.x))*8)
            var target=center-span/2+slice*span/8
            var sliceEnd=target+span/8
            if let timing=initialTiming, timing.adaptive != nil {
                let first=timing.beat(atFrame:center-span/2),last=timing.beat(atFrame:center+span/2)
                target=timing.frame(atBeat:first+slice*(last-first)/8)
                sliceEnd=timing.frame(atBeat:first+(slice+1)*(last-first)/8)
            }
            let start=max(0,target),end=min(Double(track.analysis.frameCount),sliceEnd)
            guard end-start>=1 else { return nil }
            return (target,start,end)
        }
        if ignoringContacts {
            if event.remaining.isEmpty || event.phase == .cancelled { ignoringContacts=false }
            return
        }
        if !initial.isEmpty && (activeTrack != model.loaded[deck] || activeLoad != model.loadIdentity(deck) || editingAtStart != model.editing.contains(deck)
            || frozenAtStart != model.frozen.contains(deck) || familyAtStart != model.superSlicerFamily(deck:deck)) {
            // A held contact cannot become an unrelated gesture when the deck mode changes.
            if activeTrack == model.loaded[deck] && activeLoad == model.loadIdentity(deck) {
                if audition { model.perform(.touch,deck:deck,enabled:false) }
                if editingAtStart { model.gridDraft[deck]=nil; model.viewport[deck]=center }
            }
            initial=[]; gridPinch=nil; audition=false; multi=false; lastSlice=nil; lastAction=nil
            ignoringContacts = !event.remaining.isEmpty && event.phase != .cancelled
            return
        }
        guard let first=event.remaining.last ?? event.points.last,model.track(deck) != nil,model.playbackSnapshot?[deck].phase != .queued else { return }
        if initial.isEmpty {
            activeTrack=model.loaded[deck]; activeLoad=model.loadIdentity(deck); editingAtStart=model.editing.contains(deck)
            frozenAtStart=model.frozen.contains(deck); familyAtStart=model.superSlicerFamily(deck:deck)
            initial=event.points; center=model.viewport[deck] ?? 0; initialGrid=model.grid(deck); initialTiming=model.timing(deck)
            multi=false; gridPinch=nil; audition=false; moved=false; lastSlice=nil; lastAction=nil; dismissLoop=false
            lastScratchX=first.x; lastScratchTime=ProcessInfo.processInfo.systemUptime; scratchContact=nil
            let state=model.playbackSnapshot?[deck]
            wasLoop=state?.loopEnabled == true
            wasPlaying=state?.phase == .playing
            oldLoop=wasLoop ? (state!.loopStart,state!.loopEnd) : nil
        }
        if editingAtStart,(gridPinch != nil || event.points.count>1),event.phase != .cancelled {
            // A second contact cancels phase preview before owning view-only zoom.
            model.gridDraft[deck]=nil; model.viewport[deck]=center
            if event.points.count != 2 || !span.isFinite || span<=0 {
                gridPinch=nil; initial=[]; ignoringContacts = !event.remaining.isEmpty
                return
            }
            if var pinch=gridPinch {
                guard let first=event.points.first(where: { $0.id == pinch.first }),
                      let second=event.points.first(where: { $0.id == pinch.second }),
                      first.x.isFinite,second.x.isFinite else {
                    gridPinch=nil; initial=[]; ignoringContacts = !event.remaining.isEmpty
                    return
                }
                let distance=max(0.01,abs(second.x-first.x))
                if distance != pinch.lastDistance {
                    let requested=pinch.span*pinch.distance/distance
                    if requested.isFinite,requested>0 { onZoom(requested) }
                    pinch.lastDistance=distance; gridPinch=pinch
                }
            } else {
                let first=event.points[0],second=event.points[1]
                guard first.x.isFinite,second.x.isFinite else {
                    initial=[]; ignoringContacts = !event.remaining.isEmpty
                    return
                }
                let distance=max(0.01,abs(second.x-first.x))
                gridPinch=GridPinch(first:first.id,second:second.id,distance:distance,span:span,lastDistance:distance)
            }
            if event.remaining.count<2 {
                gridPinch=nil; initial=[]; ignoringContacts = !event.remaining.isEmpty
            }
            return
        }
        if event.phase == .cancelled {
            if audition { model.perform(.touch,deck:deck,enabled:false) }
            if model.editing.contains(deck) { model.gridDraft[deck]=nil; model.viewport[deck]=center }
            if multi {
                if wasLoop,let oldLoop { model.setLoop(start:oldLoop.0,end:oldLoop.1,deck:deck) }
                else { model.perform(.loop,deck:deck,enabled:false) }
            }
            initial=[]; gridPinch=nil; return
        }
        if event.points.count>=2 && event.phase != .ended && !model.editing.contains(deck) && !model.frozen.contains(deck) {
            if !multi {
                if audition { model.perform(.touch,deck:deck,enabled:false); audition=false }
                initial=Array(event.points.prefix(2)); multi=true
                if oldLoop == nil {
                    let a=model.snappedFrame(frame(initial[0].x),deck:deck)
                    let b=model.snappedFrame(frame(initial[1].x),deck:deck)
                    let minimum=initialTiming?.span(beats:1,from:min(a,b)) ?? 1
                    oldLoop=(min(a,b),max(max(a,b),min(a,b)+minimum))
                }
            }
            if let loop=oldLoop,initial.count>=2 {
                let p=event.points[0],q=event.points[1]
                // S24 describes a two-finger downward dismissal. Distance and axis
                // tolerances remain development values until target-build comparison.
                dismissLoop=event.points.count==2 && p.y-initial[0].y>0.35 && q.y-initial[1].y>0.35
                    && abs(p.x-initial[0].x)<0.15 && abs(q.x-initial[1].x)<0.15
                if dismissLoop { return }
                let baseline=max(0.01,abs(initial[1].x-initial[0].x))
                let ratio=max(0.0625,min(16,abs(q.x-p.x)/baseline))
                let midpoint=(p.x+q.x-initial[0].x-initial[1].x)/2
                let step=initialGrid?.framesPerBeat ?? 1
                let shift=(midpoint*span/step).rounded()*step
                let length=max(step/4,(loop.1-loop.0)*pow(2,log2(ratio).rounded()))
                let start=max(0,loop.0+shift)
                if let timing=initialTiming, timing.adaptive != nil {
                    let origin=timing.beat(atFrame:loop.0)
                    let moved=timing.beat(atFrame:loop.0+midpoint*span)-origin
                    let beats=max(0.25,(timing.beat(atFrame:loop.1)-origin)*pow(2,log2(ratio).rounded()))
                    let first=max(0,timing.frame(atBeat:origin+moved.rounded()))
                    model.setLoop(start:first,end:timing.frame(atBeat:timing.beat(atFrame:first)+beats),deck:deck)
                } else { model.setLoop(start:start,end:start+length,deck:deck) }
            }
        } else if !multi {
            let dx=first.x-initial[0].x,dy=first.y-initial[0].y
            if abs(dx)>0.006 || abs(dy)>0.025 { moved=true }
            if model.editing.contains(deck) {
                if event.phase == .moved,let grid=initialGrid,abs(dx)>0.002 {
                    let drag=GridDrag(grid:grid,viewportFrame:center,framesPerPoint:span)
                    if let result=try? drag.preview(translationPoints:dx) {
                        model.gridDraft[deck]=result.grid; model.viewport[deck]=result.viewportFrame
                    }
                }
            } else if model.frozen.contains(deck) {
                if event.phase == .began || event.phase == .moved || (event.phase == .ended && !event.remaining.isEmpty) {
                    guard let contact=event.remaining.reversed().first(where:{ sliceRegion($0) != nil }),
                          let region=sliceRegion(contact) else {
                        if audition { model.perform(.touch,deck:deck,enabled:false) }
                        audition=false; lastSlice=nil; lastAction=nil
                        return
                    }
                    let action=model.superSlicerFamily(deck:deck).action(at:contact.y)
                    if action == .scratch {
                        let now=ProcessInfo.processInfo.systemUptime
                        let entering=lastAction != .scratch || scratchContact != contact.id
                        if entering && audition { model.perform(.touch,deck:deck,enabled:false) }
                        let elapsed=max(0.001,now-(lastScratchTime ?? now))
                        let movement=entering ? 0:contact.x-(lastScratchX ?? contact.x)
                        let sampleRate=model.track(deck)?.analysis.sampleRate ?? 44100
                        let rate=min(4,max(-4,movement*span/(sampleRate*elapsed)))
                        // Anchor once. Native rate updates preserve the continuous cursor.
                        model.perform(.touch,deck:deck,value:frame(contact.x),touchRate:rate)
                        lastScratchX=contact.x; lastScratchTime=now; scratchContact=contact.id
                        lastSlice=region.target; lastAction=action; audition=true
                    } else if !action.isSliceRepeat || lastSlice != region.target || lastAction != action {
                        // One compound action also restores native rate when entering the Slice region.
                        let fraction=action.provisionalSliceFraction
                        var repeatEnd=fraction == 1 ? region.end:min(region.end,region.start+max(1,(region.end-region.start)*fraction))
                        if fraction != 1, let timing=initialTiming, timing.adaptive != nil {
                            let beats=timing.beat(atFrame:region.end)-timing.beat(atFrame:region.start)
                            repeatEnd=region.start+max(1,timing.span(beats:beats*fraction,from:region.start))
                        }
                        model.perform(.touch,deck:deck,value:region.start,end:repeatEnd,
                                      quantum:model.performance.slicerQuantize ? model.performance.quantize : 0,
                                      touchRate:action.provisionalRate(at:contact.y))
                        lastSlice=region.target; lastAction=action; audition=true
                    }
                }
            } else if event.phase == .moved && abs(dx)>abs(dy)*0.3 {
                let target=model.boundedFrame(frame(first.x),deck:deck)
                model.disengageSyncForManualControl(deck:deck)
                if model.performance.waveformScratchAudio {
                    let now=ProcessInfo.processInfo.systemUptime
                    let elapsed=max(0.001,now-(lastScratchTime ?? now))
                    let track=model.track(deck)
                    let movement=first.x-(lastScratchX ?? first.x)
                    // Stationary contacts and delayed events retain the moving rate.
                    // Only actual movement changes the scratch trajectory.
                    if movement != 0 {
                        let rate=track.map { movement*span/($0.analysis.sampleRate*elapsed) } ?? 1
                        model.perform(.touch,deck:deck,value:target,touchRate:min(4,max(-4,rate)))
                        audition=true
                    }
                    lastScratchX=first.x; lastScratchTime=now
                } else if abs(dx)>0.01 && wasPlaying {
                    model.perform(.touch,deck:deck,value:target); audition=true
                } else if abs(dx)>0.01 {
                    model.jump(target,deck:deck,quantized:false)
                }
            }
        }
        if event.phase == .ended && event.remaining.isEmpty {
            if model.editing.contains(deck) {
                if moved,let grid=model.gridDraft[deck] { model.saveGrid(grid,deck:deck) }
            } else if multi && dismissLoop { model.perform(.loop,deck:deck,enabled:false) }
            else if audition { model.perform(.touch,deck:deck,enabled:false) }
            else if !model.frozen.contains(deck) && !multi && !moved { model.jump(model.snappedFrame(frame(first.x),deck:deck),deck:deck) }
            else if !multi && first.y-initial[0].y < -0.35 { model.showLibrary() }
            initial=[]; lastScratchX=nil; lastScratchTime=nil
        }
    }
}
