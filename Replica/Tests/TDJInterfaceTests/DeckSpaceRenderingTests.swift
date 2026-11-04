#if os(macOS)
import Vision
import AppKit
import SwiftUI
import Testing
import TDJCore
@testable import TDJInterface

@Test @MainActor func deckControlsRenderInsideTheirAllocatedSpace() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let analysis = try await AnalysisWorker.shared.waveformOnly(url: source)
    let track = try Track(title: "Control visibility", artist: "Fixture", mediaFilename: "clock.wav", analysis: analysis)
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.loaded[.a] = track.id
    let panels = DeckPanelPresentation()
    panels.configure(width: 1004, portrait: false, handleExtent: 12)
    panels.setTrackAvailable(true)
    #expect(panels.extraVisible)
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DECK_RENDER_OUTPUT"]
        ?? root.appendingPathComponent("renders").path)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for height in [180.0, 344] {
        let view = DeckView(model: model, deck: .a, panels: panels)
            .frame(width: 1004, height: height).environment(\.colorScheme, .dark)
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1004, height: height),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.frame = CGRect(x: 0, y: 0, width: 1004, height: height)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        if !panels.extraVisible { panels.toggleControls() }
        try await Task.sleep(for: .milliseconds(300))
        host.layoutSubtreeIfNeeded()
        let hosted = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: hosted)
        try hosted.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("hosted-\(Int(height)).png"))
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: hosted.cgImage!, options: [:]).perform([request])
        let labels = request.results?.compactMap { $0.topCandidates(1).first?.string.uppercased() } ?? []
        #expect(labels.contains { $0.contains("FLUX") })
        #expect(labels.contains { $0.contains("FREEZE") })
        #expect(labels.contains { $0.contains("CUES") })
        if height == 344 {
            let bottom = try #require(hosted.colorAt(x: hosted.pixelsWide - 60, y: hosted.pixelsHigh - 40)?.usingColorSpace(.deviceRGB))
            #expect(bottom.redComponent > 0.15)
        }
        window.contentView = nil
        panels.toggleControls()
        let renderer = ImageRenderer(content: view)
        let image = try #require(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("deck-\(Int(height)).png"))
    }
    let empty = ImageRenderer(content: DeckView(model: model, deck: .b, panels: DeckPanelPresentation())
        .frame(width: 1004, height: 344).environment(\.colorScheme, .dark))
    let bitmap = NSBitmapImageRep(cgImage: try #require(empty.cgImage))
    try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("empty.png"))
    let background = try #require(bitmap.colorAt(x: 100, y: 162)?.usingColorSpace(.deviceRGB))
    #expect(background.redComponent == 0 && background.greenComponent == 0 && background.blueComponent == 0)
    let geometry = PerformanceDockGeometry(width: 1112, height: 720)
    let dock = NSHostingView(rootView: PerformanceDock(model: model, panelsA: panels,
        panelsB: DeckPanelPresentation(), geometry: geometry).frame(width: 96, height: 720)
        .environment(\.colorScheme, .dark))
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 96, height: 720),
        styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = dock
    dock.frame = CGRect(x: 0, y: 0, width: 96, height: 720)
    dock.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    let dockImage = try #require(dock.bitmapImageRepForCachingDisplay(in: dock.bounds))
    dock.cacheDisplay(in: dock.bounds, to: dockImage)
    try dockImage.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("dock.png"))
    window.contentView = nil
    await model.finishForShutdown()
}

#endif
