import Foundation
import TDJCore

extension ReplicaModel {
    /// Collection results first, then first-minute results, merged for the browser.
    public var browserHints: [String: BrowserPreparationHint] {
        _ = browserHintsVersion
        var merged = collectionHints
        for (id, hint) in analysisHints.entries {
            let existing = merged[id]
            merged[id] = .init(bpm: existing?.bpm ?? hint.bpm, key: existing?.key ?? hint.key,
                               isMix: existing?.isMix == true || hint.isMix)
        }
        return merged
    }

    func refreshCollectionHints() async {
        guard let catalog = musicLibraryCatalog else { return }
        collectionHints = await service.collectionHints(for: catalog)
        browserHintsVersion &+= 1
    }

    func recordAnalysisHint(_ hint: NativeAnalysisHint, for item: MusicLibraryItem) async {
        analysisHints.entries[item.id] = hint
        browserHintsVersion &+= 1
        let hints = analysisHints, url = analysisHintsURL
        await nativeMusic.files.run { try? hints.save(to: url) }
    }

    /// Appends one line to analysis.log, keeping the newest 256 KB.
    func logAnalysis(_ text: String) {
        let url = analysisLogURL, line = Date().ISO8601Format() + " " + text + "\n"
        Task { await nativeMusic.files.run {
            var data = (try? Data(contentsOf: url)) ?? Data()
            data.append(Data(line.utf8))
            if data.count > 256 * 1024 { data = data.suffix(192 * 1024) }
            try? data.write(to: url, options: .atomic)
        } }
    }

    /// Removes temporary exports an interrupted session left behind. Runs only with no loads active.
    func removeStaleNativeSources() async {
        guard !staleSourcesCleaned, nativeMusic.loadOwners.isEmpty else { return }
        staleSourcesCleaned = true
        let root = store.root
        let removed = await nativeMusic.files.run { () -> Int in
            let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
            var count = 0
            for name in names where name.hasPrefix(".native-source-") || name.hasPrefix(".music-import-") {
                if (try? FileManager.default.removeItem(at: root.appendingPathComponent(name))) != nil { count += 1 }
            }
            return count
        }
        if removed > 0 { logAnalysis("Removed \(removed) interrupted temporary exports") }
    }

    /// Mixes: analyse the opening minute for tempo, grid and key without exporting the whole file.
    func analyseMixOpening(_ item: MusicLibraryItem) async throws {
        guard item.availability == .available, let url = item.assetURL else { throw MusicLibraryError.missingAudio }
        let directory = store.root.appendingPathComponent(".native-source-" + UUID().uuidString, isDirectory: true)
        let files = nativeMusic.files
        await files.run { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        let excerpt = directory.appendingPathComponent("opening.caf")
        do {
            try await MusicLibraryAudio.decodeAsset(url: url, destination: excerpt, maximumSeconds: NativeAnalysisPlan.excerptSeconds)
            let analysis = try await AnalysisWorker.shared.analyze(url: excerpt)
            await files.run { try? FileManager.default.removeItem(at: directory) }
            await recordAnalysisHint(.init(excerpt: analysis, isMix: true), for: item)
        } catch {
            await files.run { try? FileManager.default.removeItem(at: directory) }
            throw error
        }
    }

    /// A loaded mix has no full analysis. Apply its first-minute grid and key once.
    func applyAnalysisHintIfNeeded(trackID: String) async {
        guard let track = library.tracks.first(where: { $0.id == trackID }), track.grid == nil, !track.preparation.gridIsManual,
              let hint = (track.musicLibrarySources ?? []).lazy.compactMap({ self.analysisHints.entries[$0.id] }).first,
              let bpm = hint.bpm, let anchor = hint.beatAnchorSeconds,
              let grid = try? BeatGrid(bpm: bpm, anchorFrame: anchor * track.analysis.sampleRate,
                                       sampleRate: track.analysis.sampleRate, downbeatOffset: hint.downbeatOffset ?? 0) else { return }
        var preparation = track.preparation
        preparation.grid = grid
        preparation.importKey(hint.key, authority: .independent)
        do { adoptLibrary(try await service.updatePreparation(trackID: trackID, preparation: preparation)) }
        catch { logAnalysis("Could not apply mix grid: \(error.localizedDescription)") }
    }
}
