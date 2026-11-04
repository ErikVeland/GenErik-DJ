#if os(macOS)
import AppKit
import SwiftUI
import Testing
import Vision
import TDJCore
@testable import TDJInterface

@Test(arguments: [DeckID.a, .b], ["normal", "effects", "freeze"]) @MainActor
func sectionColoursFollowTheWaveformAndLeaveItsTopClear(deck: DeckID, presentation: String) async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let key = DeckToolSettings.sectionWaveformColours
    let previous = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.removeObject(forKey: key)
    defer {
        if let previous { UserDefaults.standard.set(previous, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }
    let store = try WorkspaceStore(root: root)
    let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let original = try await AnalysisWorker.shared.waveformOnly(url: source)
    let bin = try JSONDecoder().decode(WaveformBin.self, from: Data(#"{"minimum":-0.8,"maximum":0.8,"rms":0.4}"#.utf8))
    let analysis = original.replacingWaveform(Array(repeating: bin, count: original.waveform.count))
    let track = try Track(title: "Section colour check", artist: "Fixture", mediaFilename: "clock.wav", analysis: analysis)
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.adoptLibrary(library)
    model.loaded[deck] = track.id
    let rate = analysis.sampleRate
    model.arrangements[track.id] = TrackArrangement(sections: [
        .init(start: 0, end: 6 * rate, role: .intro),
        .init(start: 6 * rate, end: 10 * rate, role: .chorus),
        .init(start: 10 * rate, end: Double(analysis.frameCount), role: .bridge)
    ], landmarks: [], musicalEnd: Double(analysis.frameCount), rhythmicEnd: nil)
    let panels = DeckPanelPresentation()
    panels.configure(width: 1004, portrait: false, handleExtent: 12)
    panels.setTrackAvailable(true)
    let layout = AdaptiveDeckGeometry(height: 216, compactControls: true)
    if presentation == "effects" { panels.toggleEffects() }
    if presentation == "freeze" { model.frozen.insert(deck) }
    let geometry = panels.geometry(width: 1004, height: layout.waveformHeight)
    let frozenWidth = presentation == "freeze" ? 44.0 : 0
    let waveformOrigin = geometry.waveform.minX + frozenWidth
    let waveformWidth = geometry.waveform.width - frozenWidth
    let samples = (0..<Int(analysis.frameCount) * 2).map { sample in
        Float(0.3 * sin(Double(sample / 2) * 0.03) + 0.2 * sin(Double(sample / 2) * 0.4))
    }
    let band = try samples.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: rate) }
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DECK_RENDER_OUTPUT"] ?? root.path)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for center in [6.0, 10.0] {
        model.viewport[deck] = center * rate
        for useBands in [false, true] {
            let view = DeckView(model: model, deck: deck, panels: panels)
                .frame(width: 1004, height: 224).environment(\.colorScheme, .dark)
                .environment(\.snapshotWaveformIndexes, [WaveformIndexKey(analysis): WaveformRangeIndex(analysis.waveform)])
                .environment(\.snapshotBandWaveforms, useBands ? [track.id: band] : [:])
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
            try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(deck.rawValue)-\(presentation)-\(Int(center))-\(useBands ? "bands" : "bins").png"))
            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .accurate
            text.minimumTextHeight = 0.005
            try VNImageRequestHandler(cgImage: try #require(bitmap.cgImage), options: [:]).perform([text])
            let sectionLabel = text.results?.first { $0.topCandidates(1).first?.string.uppercased().contains("INTRO") == true }
            #expect(sectionLabel != nil && sectionLabel!.boundingBox.minY > 0.78, "Current section guidance belongs in the header.")
            let overviewLeft = try #require(bitmap.colorAt(x: 10, y: 197)?.usingColorSpace(.deviceRGB))
            #expect(overviewLeft.greenComponent > 0.4 && overviewLeft.greenComponent > overviewLeft.redComponent * 1.3, "The overview extends behind the current-time readout.")
            for (seconds, role) in [(5.57, ArrangementRole.intro), (6.43, .chorus), (9.57, .chorus), (10.43, .bridge)] where abs(seconds - center) < 1.1 {
                let x = Int(4 + waveformOrigin + (seconds - center + 1.1) / 2.2 * waveformWidth)
                func matches(_ pixel: NSColor) -> Bool {
                    switch role {
                    case .intro: return pixel.greenComponent > pixel.redComponent * 1.3
                    case .chorus: return pixel.redComponent > pixel.blueComponent * 1.5
                    default: return pixel.blueComponent > pixel.greenComponent * 1.2
                    }
                }
                let body = try #require(bitmap.colorAt(x: x, y: Int(4 + layout.headerHeight + layout.waveformHeight / 2 + 3))?.usingColorSpace(.deviceRGB))
                #expect(matches(body), "The waveform uses the section colour at \(seconds) seconds.")
                let header = try #require(bitmap.colorAt(x: x, y: 5)?.usingColorSpace(.deviceRGB))
                if x < 810 {
                    #expect(matches(header), "The visible header colour shares the waveform time axis at \(seconds) seconds.")
                }
                let top = try #require(bitmap.colorAt(x: x, y: 50)?.usingColorSpace(.deviceRGB))
                #expect(max(top.redComponent, top.greenComponent, top.blueComponent) < (presentation == "freeze" ? 0.12 : 0.08), "The section strip leaves the detailed waveform clear.")
            }
        }
    }
    await model.finishForShutdown()
}
#endif
