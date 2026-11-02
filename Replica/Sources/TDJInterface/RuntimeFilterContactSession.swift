import Foundation
import TDJCore

/// Diagnostic sweeps use the same contact state and model commands as the filter pane.
@MainActor
package final class RuntimeFilterContactSession {
    private let a=FilterPadContactState(),b=FilterPadContactState()
    private var last:[DeckID:SurfacePoint]=[:]
    package private(set) var cancellationFailures=0
    package init() {}
    package func apply(model:ReplicaModel,deck:DeckID,x:Double,y:Double) -> Bool {
        guard x.isFinite,y.isFinite,(0...1).contains(x),(0...1).contains(y) else { return false }
        let contact=deck == .a ? a:b
        let point=SurfacePoint(id:1,x:x,y:y)
        let updateX=contact.update(.init(phase:contact.isTouching ? .moved:.began,points:[point],ending:[]))
        guard model.filterTouch(x:x,y:y,deck:deck,updateX:updateX) else { return false }
        last[deck]=point
        return true
    }
    @discardableResult
    package func cancelAll(model:ReplicaModel) -> Int {
        var count=0
        for deck in DeckID.allCases {
            let contact=deck == .a ? a:b
            guard contact.isTouching else { continue }
            _=contact.update(.init(phase:.cancelled,points:[],ending:[]))
            if !model.releaseFilter(deck:deck,cancelled:true) { cancellationFailures+=1 }
            count+=1
        }
        return count
    }
    package func filtersAreDisabled(model:ReplicaModel) -> Bool {
        guard let snapshot=model.playback.core.snapshot() else { return false }
        return !snapshot.a.mixer.filterEnabled && !snapshot.b.mixer.filterEnabled
    }
    /// Check the last accepted resonance values after shutdown flushes the preferences.
    package func preferencesMatchSavedState(model:ReplicaModel) async -> Bool {
        guard let a=last[.a],let b=last[.b] else { return false }
        let expectedA=1-a.y,expectedB=1-b.y
        let url=model.store.root.appendingPathComponent("mixer-preferences.json")
        return await Task.detached(priority:.utility) {
            do {
                guard FileManager.default.fileExists(atPath:url.path) else { return false }
                let value=try MixerPreferences.load(from:url)
                return value.filterResonanceA==expectedA && value.filterResonanceB==expectedB
            } catch { return false }
        }.value
    }
}
