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

struct DeckPlaybackButton: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @AppStorage(DeckToolSettings.vinylStop) private var vinylStop = false
    private var state: DeckPlaybackSnapshot? { model.playbackSnapshot?[deck] }
    private var stopping: Bool { state?.phase.active == true && state?.braking != true }
    var body: some View {
        Button { model.pressPlay(deck:deck,vinylStop:vinylStop) } label: {
            ZStack {
                Image(systemName:stopping ? "stop.fill":"play.fill")
                    .foregroundStyle(state?.phase.active == true ? PerformancePalette.syncGreen : Color(white:0.65))
                if model.preparingTrack.contains(deck) { ProgressView().controlSize(.small) }
            }
        }
        .disabled(model.track(deck) == nil || model.preparingPlayback.contains(deck))
        .accessibilityLabel("\(stopping ? "Stop":"Play") deck \(deck.rawValue.uppercased())")
    }
}
