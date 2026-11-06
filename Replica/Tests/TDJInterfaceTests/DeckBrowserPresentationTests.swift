#if os(macOS)
    import AppKit
    import SwiftUI
    import Testing
    import Vision
    import TDJCore
    @testable import TDJInterface

    @MainActor private func presentationFixture() async throws -> (ReplicaModel, URL, Track) {
        var base = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { base.deleteLastPathComponent() }
        let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try WorkspaceStore(root: root)
        let analysis = try await AnalysisWorker.shared.waveformOnly(url: source)
        let track = try Track(
            title: "Presentation fixture", artist: "Fixture", mediaFilename: "clock.wav", analysis: analysis)
        try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent("clock.wav"))
        var library = LibrarySnapshot()
        library.tracks = [track]
        try store.save(library)
        let model = try ReplicaModel(
            root: root, playback: PlaybackController(offline: true), automaticTraktorSources: [])
        model.loaded[.a] = track.id
        model.loaded[.b] = track.id
        model.nativeMusic.closed = true
        try await model.prepareLoadedWaveforms()
        return (model, root, track)
    }

    @Test @MainActor func deckFlagIsTheOnlyWayToShowSavedHotcues() async throws {
        let (model, root, track) = try await presentationFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacyKey = "deckTools.hotcuePads"
        let previous = UserDefaults.standard.object(forKey: legacyKey)
        defer { UserDefaults.standard.set(previous, forKey: legacyKey) }
        UserDefaults.standard.set(true, forKey: legacyKey)
        let frame = track.analysis.sampleRate
        let cue = PerformanceCue(frame: frame, sectionName: "Cue fixture", sectionColour: 0xFF00FF)
        model.performance.cues[track.id] = [0: cue]
        model.viewport[.a] = frame
        model.viewport[.b] = frame
        let panels = DeckPanelPresentation()
        panels.configure(width: 1004, portrait: false, handleExtent: 12)
        panels.setTrackAvailable(true)

        func cuePixels(_ deck: DeckID) throws -> Int {
            let renderer = ImageRenderer(
                content: DeckView(model: model, deck: deck, panels: panels).frame(width: 1004, height: 344)
                    .environment(\.colorScheme, .dark))
            let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
            var count = 0
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                    if let colour = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                        colour.redComponent > 0.5, colour.greenComponent < 0.15, colour.blueComponent > 0.5
                    {
                        count += 1
                    }
                }
            }
            return count
        }

        #expect(try cuePixels(.a) == 0)
        model.toggleHotcuePads(deck: .a)
        #expect(try cuePixels(.a) > 0)
        #expect(try cuePixels(.b) == 0)
        model.toggleHotcuePads(deck: .a)
        #expect(try cuePixels(.a) == 0)
        #expect(model.performance.cues[track.id]?[0] == cue)
        await model.finishForShutdown()
    }

    @Test(arguments: [CGSize(width: 1112, height: 774), CGSize(width: 834, height: 1052)]) @MainActor
    func minimisedBrowserKeepsBothDecksAndOptionalControlsVisible(size: CGSize) async throws {
        let (model, root, _) = try await presentationFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let keys = [
            DeckToolSettings.cueButton, DeckToolSettings.headphoneButton, DeckToolSettings.tempoFader,
        ]
        let previous = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value {
                    UserDefaults.standard.set(value, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
        for key in keys { UserDefaults.standard.set(true, forKey: key) }
        model.toggleHotcuePads(deck: .a)
        model.toggleHotcuePads(deck: .b)
        model.browserVisible = true
        let host = NSHostingView(rootView: ReplicaView(model: model).frame(width: size.width, height: size.height))
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(800))
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.minimumTextHeight = 0.005
        try VNImageRequestHandler(cgImage: try #require(bitmap.cgImage), options: [:]).perform([request])
        let labels = request.results?.compactMap { $0.topCandidates(1).first?.string.uppercased() } ?? []
        #expect(model.browserVisible)
        #expect(labels.filter { $0.contains("ACTIONS") }.count == 2)
        #expect(labels.filter { $0.contains("PRESENTATION FIXTURE") }.count >= 2)
        #expect(labels.filter { $0.contains("0:00") }.count >= 2)
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DECK_RENDER_OUTPUT"] ?? root.path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try bitmap.representation(using: .png, properties: [:])!.write(
            to: folder.appendingPathComponent("browser-\(Int(size.width)).png"))
        window.contentView = nil
        await model.finishForShutdown()
    }

    @Test @MainActor func sectionWaveformColoursHaveAnExplicitFrequencyAlternativeAndKeepTheHeader() async throws {
        let (model, root, track) = try await presentationFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let key = DeckToolSettings.sectionWaveformColours
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let frames = Double(track.analysis.frameCount)
        model.arrangements[track.id] = TrackArrangement(
            sections: [
                ArrangementSection(start: 0, end: frames / 2, role: .verse),
                ArrangementSection(start: frames / 2, end: frames, role: .chorus),
            ], landmarks: [], musicalEnd: frames, rhythmicEnd: frames)
        model.viewport[.a] = frames / 2
        let analysis = try #require(model.track(.a)?.analysis)
        let indexes = [WaveformIndexKey(analysis): WaveformRangeIndex(analysis.waveform)]
        let panels = DeckPanelPresentation()
        panels.configure(width: 1004, portrait: false, handleExtent: 12)
        panels.setTrackAvailable(true)
        var counts: [Int] = []
        for mode in ["default", "frequency", "sections"] {
            if mode == "default" {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(mode == "sections", forKey: key)
            }
            let renderer = ImageRenderer(
                content: DeckView(model: model, deck: .a, panels: panels).frame(width: 1004, height: 344).environment(
                    \.colorScheme, .dark
                ).environment(\.snapshotWaveformIndexes, indexes))
            let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
            var orange = 0
            for y in stride(from: 70, to: 240, by: 3) {
                for x in stride(from: 520, to: 930, by: 3) {
                    if let colour = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), colour.redComponent > 0.3,
                        colour.greenComponent > 0.2, colour.redComponent > colour.greenComponent * 1.1,
                        colour.greenComponent > colour.blueComponent * 1.1
                    {
                        orange += 1
                    }
                }
            }
            counts.append(orange)
            let header = try #require(bitmap.colorAt(x: 750, y: 5)?.usingColorSpace(.deviceRGB))
            #expect(header.redComponent > header.greenComponent && header.greenComponent > header.blueComponent)
            let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DECK_RENDER_OUTPUT"] ?? root.path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try bitmap.representation(using: .png, properties: [:])!.write(
                to: folder.appendingPathComponent("waveform-\(mode).png"))
        }
        #expect(counts[0] > 10 && counts[1] == 0)
        #expect(counts[2] > 10)
        await model.finishForShutdown()
    }
#endif
