import Foundation
import CoreGraphics

@main
enum PerformancePanelChecks {
    @MainActor static func main() {
        var checks = 0, failures = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: \(message)") }
        }
        var panels = DeckPanelsState()
        panels.configure(width: 1004, portrait: false)
        panels.setPresented(.effects, true)
        expect(panels.extent(.effects) == 200, "FX opens to usable default")
        panels.begin(.effects)
        panels.update(.effects, translation: 80)
        panels.end(.effects, velocity: 0)
        expect(panels.extent(.effects) == 280, "FX retains arbitrary resized width")
        panels.setPresented(.effects, false)
        panels.setPresented(.effects, true)
        expect(panels.extent(.effects) == 280, "FX reopens to remembered width")
        panels.setPresented(.mixer, true)
        let otherWidth = panels.extent(.mixer)
        let otherFrame = panels.geometry(height: 240).mixerContent
        panels.begin(.effects)
        panels.update(.effects, translation: 10000)
        expect(panels.geometry(height: 240).mixerContent == otherFrame, "FX resizing cannot move EQ")
        panels.cancel(.effects)
        expect(panels.extent(.effects) == 280, "FX cancellation restores width")
        panels.setPresented(.effects, false)
        expect(panels.extent(.mixer) == otherWidth, "closing FX cannot resize EQ")
        panels.setPresented(.effects, true)
        panels.begin(.mixer)
        panels.update(.mixer, translation: -30)
        panels.end(.mixer, velocity: -900)
        expect(!panels.isPresented(.mixer), "EQ closes with library-style flick")
        panels.setPresented(.mixer, true)
        expect(panels.extent(.mixer) == otherWidth, "EQ remembers width after flick")
        panels.configure(width: 726, portrait: true)
        expect(panels.extent(.effects) == 200 && panels.extent(.mixer) == 200, "portrait uses separate panel memories")
        expect(!panels.isPresented(.extra), "opening pair makes room by collapsing extras")
        panels.configure(width: 1004, portrait: false)
        expect(panels.extent(.effects) == 280, "landscape restores its own FX width")
        panels.setPresented(.mixer, false)
        panels.setPresented(.extra, true)
        panels.begin(.extra)
        panels.update(.extra, translation: 40)
        panels.end(.extra, velocity: 0)
        let rememberedExtra = panels.extent(.extra)
        panels.setPresented(.extra, false)
        panels.setPresented(.extra, true)
        expect(panels.extent(.extra) == rememberedExtra, "extra controls remember resized width: \(panels.extent(.extra)) vs \(rememberedExtra)")
        panels.setPresented(.mixer, true)
        let beforeConstraint = panels.extent(.effects)
        panels.configure(width: 300, portrait: false)
        expect(panels.isPresented(.effects) && panels.isPresented(.mixer), "space constraints do not close held performance gates")
        panels.configure(width: 1004, portrait: false)
        expect(panels.extent(.effects) == beforeConstraint && panels.isPresented(.mixer), "restored space keeps remembered panel intents")

        for width in [1004.0, 726, 660, 480] {
            for fx in [0.0, 20, 200, 350, 1000] {
                for eq in [0.0, 20, 200, 350, 1000] {
                    let layout = DeckPanelsGeometry(width: width, height: 240, effects: fx, mixer: eq, extra: 160)
                    let parts = [layout.effectsContent, layout.effectsHandle, layout.waveform, layout.mixerHandle, layout.mixerContent]
                    expect(parts.allSatisfy { $0.minX >= 0 && $0.maxX <= layout.waveformWidth + 0.001 && $0.width >= 0 }, "panels stay inside their row")
                    for i in parts.indices {
                        for other in parts.dropFirst(i + 1) {
                            expect(parts[i].isEmpty || other.isEmpty || !parts[i].intersects(other), "visible content and grab lanes cannot overlap")
                        }
                    }
                    expect(layout.effectsHandle.width == 44 && layout.mixerHandle.width == 44, "side panels retain dedicated reveal lanes")
                    expect(layout.waveform.width >= 44, "waveform keeps a compact expansion surface")
                    expect(layout.mainWidth + layout.extraWidth + 44 + 8 <= max(0, width - 8), "extra controls reserve their own grab lane")
                }
            }
        }
        let viewport = TouchSurfaceViewport(size: CGSize(width: 1112, height: 834), orientation: 3, interruption: UUID())
        let before = DeckPanelsGeometry(width: 1004, height: 240, effects: 280, mixer: 200, extra: 0)
        let after = DeckPanelsGeometry(width: 1004, height: 240, effects: 200, mixer: 280, extra: 160)
        var contact = TouchContactGeometry(policy: .retainContactSpace)
        _ = contact.begin(id: 1, frame: before.effectsContent, viewport: viewport)
        let point = CGPoint(x: 140, y: 120)
        expect(contact.point(id: 1, location: point, frame: after.effectsContent) == SurfacePoint(id: 1, x: 0.5, y: 0.5), "held FX mapping survives pair and extras resizing")
        var otherDeck = DeckPanelsState()
        otherDeck.configure(width: 1004, portrait: false)
        expect(!otherDeck.isPresented(.effects), "panel sizes and visibility belong to one deck")
        expect(TouchPanelEdge.leading.translation(horizontal: 30, vertical: 90) == 30, "FX opens toward right")
        expect(TouchPanelEdge.trailing.translation(horizontal: -30, vertical: 90) == 30, "EQ and extras open toward left")
        expect(TouchPanelEdge.bottom.translation(horizontal: 30, vertical: -90) == 90, "library keeps upward opening")
        let presentation = DeckPanelPresentation()
        presentation.setTrackAvailable(true)
        presentation.configure(width: 1004, portrait: false)
        presentation.toggleEffects()
        var cancellations = 0
        let registration = presentation.effectsInput.register { cancellations += 1 }
        presentation.begin(.effects)
        presentation.update(.effects, translation: 50)
        presentation.end(.effects, velocity: 0)
        expect(presentation.effectsInput.isEnabled && cancellations == 0, "resizing FX does not cancel its held contacts")
        presentation.toggleMixer()
        presentation.begin(.extra)
        presentation.update(.extra, translation: 25)
        presentation.end(.extra, velocity: 0)
        expect(presentation.effectsInput.isEnabled && presentation.mixerInput.isEnabled && cancellations == 0, "EQ and extras resizing retain FX input gate")
        presentation.begin(.effects)
        presentation.update(.effects, translation: -1000)
        expect(presentation.effectsInput.isEnabled, "zero-width drag preview does not cancel held sound")
        presentation.cancel(.effects)
        expect(cancellations == 0 && presentation.effectsVisible, "cancelled resize restores pane without cancelling sound")
        presentation.toggleEffects()
        expect(!presentation.effectsInput.isEnabled && cancellations == 1 && presentation.mixerInput.isEnabled, "explicit hide cancels only the intended pane once")
        presentation.effectsInput.unregister(registration)
        var direct = DeckPanelsState()
        direct.configure(width: 726, portrait: true)
        direct.setPresented(.effects, true)
        let grabStart = direct.geometry(height: 240).mixerHandle.minX
        direct.begin(.mixer)
        expect(direct.geometry(height: 240).mixerHandle.minX == grabStart, "making room keeps EQ grab under the finger")
        direct.update(.mixer, translation: 50)
        expect(direct.geometry(height: 240).mixerHandle.minX == grabStart - 50, "EQ grab follows finger after extras collapse")
        direct.cancel(.mixer)
        expect(direct.isPresented(.extra) && !direct.isPresented(.mixer), "cancelled opening restores extras")
        direct.begin(.mixer)
        direct.update(.mixer, translation: -20)
        direct.end(.mixer, velocity: -900)
        expect(!direct.isPresented(.mixer) && direct.isPresented(.extra), "closing flick uses finger travel and restores extras")
        let requests = presentation.spaceRequestID
        presentation.begin(.effects)
        expect(presentation.spaceRequestID == requests, "beginning a drag does not move the library")
        presentation.update(.effects, translation: 210)
        presentation.end(.effects, velocity: 0)
        expect(presentation.spaceRequestID != requests && presentation.spaceRequestKind == .effects, "committed opening requests performance height")
        presentation.toggleEffects()
        let accessibleRequest = presentation.spaceRequestID
        presentation.adjust(.effects, by: 44)
        expect(presentation.spaceRequestID != accessibleRequest, "accessible opening requests usable performance height")
        let fxCommand = presentation.presentationID(for: .effects)
        presentation.toggleMixer()
        expect(presentation.presentationID(for: .effects) == fxCommand, "EQ commands cannot cancel an FX resize")
        print("\(checks) performance panel checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
