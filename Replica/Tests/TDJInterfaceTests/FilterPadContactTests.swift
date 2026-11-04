import Foundation
import Observation
import TDJCore
import Testing

@testable import TDJInterface

private final class FilterContactChanges: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func changed() {
        lock.lock()
        count += 1
        lock.unlock()
    }
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

@Test @MainActor func filterContactSweepsKeepBookkeepingPrivateAndMarkerLive() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    let contact = FilterPadContactState()
    let bookkeeping = FilterContactChanges()
    let marker = FilterContactChanges()
    withObservationTracking {
        _ = contact.isTouching
    } onChange: {
        bookkeeping.changed()
    }
    let first = SurfaceEvent(phase: .began, points: [.init(id: 1, x: 0.2, y: 0.8)], ending: [])
    let firstX = contact.update(first)
    model.filterTouch(x: 0.2, y: 0.8, deck: .a, updateX: firstX)
    model.setMixer(.filterX, value: 0.7, deck: .a)
    model.filterTouch(x: 0.6, y: 0.4, deck: .b)
    let other = model.playbackSnapshot?.b.mixer
    withObservationTracking {
        _ = model.controlDisplay[.a].mixer.filterY
    } onChange: {
        marker.changed()
    }
    for step in 0..<1000 {
        let y = Double(step) / 1000
        let event = SurfaceEvent(phase: .moved, points: [.init(id: 1, x: 0.2, y: y)], ending: [])
        let updateX = contact.update(event)
        #expect(!updateX)
        model.filterTouch(x: 0.2, y: y, deck: .a, updateX: updateX)
    }
    #expect(contact.isTouching && bookkeeping.value == 0 && marker.value == 1)
    #expect(model.playbackSnapshot?.a.mixer.filterX == 0.7)
    #expect(abs((model.playbackSnapshot?.a.mixer.filterY ?? 0) - 0.001) < 0.000001)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == true)
    #expect(model.playbackSnapshot?.b.mixer == other)
    let release = SurfaceEvent(phase: .ended, points: [.init(id: 1, x: 0.2, y: 0.999)], ending: [1])
    #expect(!contact.update(release) && !contact.isTouching)
    model.releaseFilter(deck: .a)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == false)
    #expect(contact.update(first))
    model.filterTouch(x: 0.2, y: 0.8, deck: .a, updateX: true)
    #expect(abs((model.playbackSnapshot?.a.mixer.filterX ?? 0) + 0.6) < 0.000001)
    await model.finishForShutdown()
}

@Test @MainActor func filterContactCancellationAndResetStartANewAxisSession() {
    let contact = FilterPadContactState()
    let held = SurfaceEvent(phase: .began, points: [.init(id: 7, x: 0.3, y: 0.4)], ending: [])
    #expect(contact.update(held) && contact.isTouching)
    #expect(!contact.update(.init(phase: .moved, points: [.init(id: 7, x: 0.3, y: 0.7)], ending: [])))
    #expect(!contact.update(.init(phase: .cancelled, points: [], ending: [])) && !contact.isTouching)
    #expect(contact.update(held) && contact.isTouching)
    contact.reset()
    #expect(!contact.isTouching)
    #expect(contact.update(held) && contact.isTouching)
}
