import Foundation
import TDJCore
import TDJInterface

@MainActor final class RuntimePreparationLibrary: LocalMusicLibraryProviding {
    let item: MusicLibraryItem
    init(source: URL, duration: Double) {
        item = .init(source:.init(platform:.iosMusic,persistentID:"4660"),title:"Synthetic import source",
                     artist:"Diagnostic",duration:duration,assetURL:source,availability:.available)
    }
    func catalog() async throws -> MusicLibraryCatalog { .init(items:[item],playlists:[]) }
    func prepare(_ requested: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        guard requested == item, let url=item.assetURL else { throw TransportError.invalid }
        return .init(url:url,metadata:.init(item:item))
    }
}

struct RuntimePreparationImportReport: Encodable, Sendable {
    let entriesPerCollection: Int
    var completedImports=0
    var failures=0
    var referencesBound=0
    var activePreparationUnchanged=true
    var fullAnalysisRetained=true
    var passed: Bool {
        completedImports>0 && failures==0 && referencesBound==completedImports
            && activePreparationUnchanged && fullAnalysisRetained
    }
    enum CodingKeys: String, CodingKey {
        case entriesPerCollection,completedImports,failures,referencesBound,activePreparationUnchanged,fullAnalysisRetained,passed,scope
    }
    func encode(to encoder: Encoder) throws {
        var values=encoder.container(keyedBy:CodingKeys.self)
        try values.encode(entriesPerCollection,forKey:.entriesPerCollection)
        try values.encode(completedImports,forKey:.completedImports)
        try values.encode(failures,forKey:.failures)
        try values.encode(referencesBound,forKey:.referencesBound)
        try values.encode(activePreparationUnchanged,forKey:.activePreparationUnchanged)
        try values.encode(fullAnalysisRetained,forKey:.fullAnalysisRetained)
        try values.encode(passed,forKey:.passed)
        try values.encode(scope,forKey:.scope)
    }
    static func qualifies(enabled: Bool, report: Self?) -> Bool {
        guard let report else { return !enabled }
        return enabled && report.passed
    }
    let scope="Synthetic collection import through ReplicaModel during playback. Original files and native Music framework access are excluded. Physical acceptance requires the unchanged audio/control gates."
}

struct RuntimePreparationCollection: Sendable {
    let url: URL
    let sha256: String
}

enum RuntimePreparationImportStress {
    static let collectionEntries=10_000
    static func collection(duration: Double, entries: Int = collectionEntries, variant: Int = 0) throws -> Data {
        guard duration.isFinite, duration>0, (1...collectionEntries).contains(entries) else { throw TransportError.invalid }
        var xml="<NML VERSION=\"17\"><HEAD PROGRAM=\"Traktor DJ\"/><COLLECTION ENTRIES=\"\(entries)\">"
        for index in 0..<entries {
            try Task.checkCancellation()
            let identity=String(format:"%016llX",UInt64(4660+index))
            xml += "<ENTRY UUID=\"synthetic-\(variant)-\(index)\"><ITUNES PERSISTENT_ID=\"\(identity)\" PLAYTIME=\"\(duration*1000)\"/><TEMPO BPM=\"123\"/><MUSICAL_KEY VALUE=\"21\"/><CUE_V2 TYPE=\"4\" START=\"1000\" HOTCUE=\"-1\"/></ENTRY>"
        }
        return Data((xml+"</COLLECTION></NML>").utf8)
    }

    static func prepareCollections(directory: URL, duration: Double, entries: Int = collectionEntries) throws -> [RuntimePreparationCollection] {
        try (0..<2).map { variant in
            let url=directory.appendingPathComponent("synthetic-preparation-\(variant).nml")
            try collection(duration:duration,entries:entries,variant:variant).write(to:url,options:.atomic)
            return .init(url:url,sha256:try AudioAnalyzer.sha256(url:url))
        }
    }

    @MainActor static func generations(model: ReplicaModel) -> [DeckID:UInt64] {
        guard let state=model.playback.core.snapshot(), DeckID.allCases.allSatisfy({
            state[$0].generation>0 && model.playback.generations[$0]==state[$0].generation
        }) else { return [:] }
        return Dictionary(uniqueKeysWithValues:DeckID.allCases.map { ($0,state[$0].generation) })
    }

    @MainActor static func observe(model: ReplicaModel, track: Track, expectedGrids: [DeckID:BeatGrid],
                                   expectedGenerations: [DeckID:UInt64], report: inout RuntimePreparationImportReport) {
        let stored=model.library.tracks.first(where:{ $0.id==track.id })
        report.fullAnalysisRetained = report.fullAnalysisRetained && stored?.analysis==track.analysis
            && stored?.analysis.musicalAnalysisDeferred != true
        let decks=Set(DeckID.allCases)
        guard Set(expectedGrids.keys)==decks, Set(expectedGenerations.keys)==decks,
              expectedGenerations.values.allSatisfy({ $0>0 }), let state=model.playback.core.snapshot() else {
            report.activePreparationUnchanged=false
            return
        }
        for deck in DeckID.allCases {
            report.activePreparationUnchanged = report.activePreparationUnchanged
                && model.loaded[deck]==track.id && model.track(deck)?.grid==expectedGrids[deck]
                && state[deck].grid==expectedGrids[deck] && state[deck].generation==expectedGenerations[deck]
                && model.playback.generations[deck]==expectedGenerations[deck]
                && state[deck].phase.active
        }
    }

    @MainActor static func importOnce(model: ReplicaModel, collection: RuntimePreparationCollection, track: Track,
                                      expectedGrids: [DeckID:BeatGrid], expectedGenerations: [DeckID:UInt64]? = nil,
                                      report: inout RuntimePreparationImportReport) async {
        let expectedGenerations=expectedGenerations ?? generations(model:model)
        defer { observe(model:model,track:track,expectedGrids:expectedGrids,expectedGenerations:expectedGenerations,report:&report) }
        guard model.library.tracks.first(where:{ $0.id==track.id })?.traktorPreparation?.collection.sourceSHA256 != collection.sha256
        else { report.failures+=1;return }
        await model.importTraktorPreparation(collection.url)
        if Task.isCancelled { return }
        guard model.traktorPreparationRecords==report.entriesPerCollection,
              let stored=model.library.tracks.first(where:{ $0.id==track.id }),
              let reference=stored.traktorPreparation,
              reference.collection.sourceSHA256==collection.sha256,
              reference.matchedSource.persistentID=="4660",
              reference.normalized.grid?.bpm==123 else { report.failures+=1;return }
        report.completedImports+=1
        report.referencesBound+=1
    }

    @MainActor static func run(model: ReplicaModel, collections: [RuntimePreparationCollection], track: Track,
                               expectedGrids: [DeckID:BeatGrid], expectedGenerations: [DeckID:UInt64]? = nil) async -> RuntimePreparationImportReport {
        var report=RuntimePreparationImportReport(entriesPerCollection:collectionEntries)
        let expectedGenerations=expectedGenerations ?? generations(model:model)
        guard collections.count==2, collections[0].sha256 != collections[1].sha256,
              Set(expectedGrids.keys)==Set(DeckID.allCases), Set(expectedGenerations.keys)==Set(DeckID.allCases),
              expectedGenerations.values.allSatisfy({ $0>0 }) else {
            report.failures=1
            observe(model:model,track:track,expectedGrids:expectedGrids,expectedGenerations:expectedGenerations,report:&report)
            return report
        }
        while !Task.isCancelled {
            let collection=collections[report.completedImports%collections.count]
            await importOnce(model:model,collection:collection,track:track,expectedGrids:expectedGrids,expectedGenerations:expectedGenerations,report:&report)
            if report.failures>0 || !report.activePreparationUnchanged || !report.fullAnalysisRetained { break }
            await Task.yield()
        }
        observe(model:model,track:track,expectedGrids:expectedGrids,expectedGenerations:expectedGenerations,report:&report)
        return report
    }
}
