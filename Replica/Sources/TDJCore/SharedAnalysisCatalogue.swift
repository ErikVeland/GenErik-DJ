import Foundation

public enum SharedAnalysisCatalogue {
    public static let batchSize = 16
    public static let maximumBytes = 64 * 1024

    public static func recordName(for analysis: AudioAnalysis) -> String {
        "deep-v1-" + AnalysisAudioIdentity(analysis).key
    }

    public static func targets(
        tracks: [Track], catalog: MusicLibraryCatalog, excluding: Set<String>, checked: Set<String>
    ) -> [String: [Track]] {
        var playlistSources = Set<String>()
        for playlist in catalog.playlists {
            playlistSources.formUnion(playlist.itemIDs)
        }
        guard !playlistSources.isEmpty else { return [:] }

        var targets: [String: [Track]] = [:]
        for track in tracks {
            guard !excluding.contains(track.id), track.analysis.deepBeatAnalysis == nil,
                CloudPreparationArchive.hasAudioIdentity(track),
                track.musicLibrarySources?.contains(where: { playlistSources.contains($0.id) }) == true
            else { continue }

            let name = recordName(for: track.analysis)
            guard !checked.contains(name), targets[name] != nil || targets.count < batchSize else { continue }
            targets[name, default: []].append(track)
        }
        return targets
    }

    public static func decode(_ data: Data, matching track: Track) -> DeepBeatAnalysis? {
        guard data.count <= maximumBytes, CloudPreparationArchive.hasAudioIdentity(track),
            let result = try? JSONDecoder().decode(DeepBeatAnalysis.self, from: data),
            result.profile == .current, (try? result.validate(matching: track.analysis)) != nil
        else { return nil }
        return result
    }
}
