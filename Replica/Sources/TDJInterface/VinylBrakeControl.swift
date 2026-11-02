import Foundation
import SwiftUI
import TDJCore

enum VinylBrakeSettings {
    static func duration(in defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey:DeckToolSettings.vinylStopDuration) != nil else { return 1 }
        let value=defaults.double(forKey:DeckToolSettings.vinylStopDuration)
        return value.isFinite ? min(5,max(0.2,value)) : 1
    }
}

/// Contact release leaves the sample-clock slowdown running.
@MainActor
final class VinylBrakeGestureSession {
    private var owner: Int?
    private var origin=0.0
    private var lastStrength=1.0
    func handle(_ event: SurfaceEvent, height: Double, begin: ()->Void, shape: (Double)->Void) {
        if event.phase == .cancelled { owner=nil;return }
        if owner == nil {
            guard event.phase == .began,let point=event.remaining.first else { return }
            owner=point.id;origin=point.y;lastStrength=1;begin()
        }
        guard let point=event.points.first(where: { $0.id == owner }) else { return }
        if event.ending.contains(point.id) { owner=nil;return }
        let travel=(point.y-origin)*height
        let strength=min(4,max(0.25,pow(2,travel/50)))
        if abs(strength-lastStrength)>0.005 { lastStrength=strength;shape(strength) }
    }
}

extension ReplicaModel {
    public func beginBrake(deck: DeckID, duration: Double = 1) {
        guard !preparingPlayback.contains(deck) else { return }
        do { try playback.brake(.begin,value:duration,deck:deck);refreshPlayback() }
        catch { status=error.localizedDescription }
    }
    public func shapeBrake(deck: DeckID, strength: Double) {
        do { try playback.brake(.strength,value:strength,deck:deck);refreshPlayback() }
        catch { status=error.localizedDescription }
    }
    public func resumeBrake(deck: DeckID) {
        do { try playback.brake(.resume,deck:deck);refreshPlayback() }
        catch { status=error.localizedDescription }
    }
}

struct DeckBrakeControl: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var compact = false
    @State private var gesture=VinylBrakeGestureSession()
    private var state: DeckPlaybackSnapshot? { model.playbackSnapshot?[deck] }
    private var available: Bool { state?.phase == .playing && !model.preparingPlayback.contains(deck) }
    var body: some View {
        VStack(spacing:4) {
            if state?.braking == true && !compact {
                Text("BRAKING · \(Int((state?.brakeRate ?? 0)*100))%")
                    .font(.system(size:10,weight:.semibold).monospacedDigit())
                Button { model.resumeBrake(deck:deck) } label: {
                    Label("Play",systemImage:"play.fill").font(.system(size:13,weight:.semibold))
                        .frame(maxWidth:.infinity,minHeight:44)
                }.accessibilityLabel("Resume deck \(deck.rawValue.uppercased()) at saved speed")
                Text("↑ Gentle · Firm ↓").font(.system(size:10))
            }
            HStack(spacing:4) {
            ZStack {
                VStack(spacing:2) {
                    Text("Brake").font(.system(size:15,weight:.bold))
                    if compact && state?.braking == true {
                        Text("BRAKING · \(Int((state?.brakeRate ?? 0)*100))%")
                            .font(.system(size:9,weight:.semibold).monospacedDigit())
                        Text("↑ Gentle · Firm ↓").font(.system(size:8))
                    }
                }
                    .foregroundStyle(state?.braking == true ? PerformancePalette.red : PerformancePalette.text)
                TouchSurface(capturesDrag:true) { event in
                    gesture.handle(event,height:50,
                        begin:{model.beginBrake(deck:deck,duration:VinylBrakeSettings.duration())},
                        shape:{model.shapeBrake(deck:deck,strength:$0)})
                }.allowsHitTesting(available)
            }.frame(minWidth:96,minHeight:50,maxHeight:50)
                .bevelPanel(cornerRadius:3,sunken:state?.braking == true)
                .opacity(available ? 1:0.45)
                .accessibilityElement(children:.ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Brake deck \(deck.rawValue.uppercased())")
                .accessibilityHint("Touch to slow down. Drag down to brake harder. Release to finish the stop.")
                .accessibilityValue(state?.braking == true ? "Braking" : "Ready")
                .accessibilityAction { if available { model.beginBrake(deck:deck,duration:VinylBrakeSettings.duration()) } }
            if compact && state?.braking == true {
                Button { model.resumeBrake(deck:deck) } label: {
                    Image(systemName:"play.fill").frame(width:44,height:50)
                }.buttonStyle(BevelButtonStyle())
                    .accessibilityLabel("Resume deck \(deck.rawValue.uppercased()) at saved speed")
            }
            }
        }.onDisappear {
            gesture.handle(.init(phase:.cancelled,points:[],ending:[]),height:50,begin:{},shape:{_ in})
        }
    }
}
