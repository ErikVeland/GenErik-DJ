import Foundation
import Testing
@testable import TDJCore

private func unifiedTrack(_ index:Int,sources:[MusicLibrarySource]=[],nativeOnly:Bool=false) throws -> Track {
    let analysis=AudioAnalysis(implementation:"test",configurationID:"test",contentSHA256:String(format:"%064x",index),
        sampleRate:48000,frameCount:480000,channelCount:2,waveformFramesPerBin:4800,waveform:[],
        bpm:120,beatAnchorFrame:0,tempoConfidence:1,key:.init(tonic:0,mode:.major),keyConfidence:1,chroma:[],timbre:[])
    var track=try Track(title:"File \(index)",artist:"File artist",genre:"House",mediaFilename:"\(index).caf",analysis:analysis)
    track.album="Files";track.musicLibrarySources=sources;track.nativeLibraryOnly=nativeOnly ? true:nil
    return track
}
private func unifiedItem(_ id:String,title:String?=nil,availability:MusicLibraryItem.Availability = .available) -> MusicLibraryItem {
    .init(source:.init(platform:.iosMusic,persistentID:id),title:title ?? id,artist:"Music artist",album:"Music album",
        genre:"Techno",assetURL:URL(string:"ipod-library://item/\(id)"),availability:availability)
}
private func unifiedProjection(tracks:[Track],catalog:MusicLibraryCatalog?,sort:CollectionSort?=nil,
    search:String="",category:CollectionCategory = .songs,group:String?=nil,
    playlists:CollectionPlaylists = .init(),suggestions:[String]?=nil) async throws -> LibraryBrowserProjection {
    try await LibraryBrowserProjection.build(tracks:tracks,suggestionIDs:suggestions,search:search,sort:sort,
        category:category,group:group,playlists:playlists,catalog:catalog)
}

@Test func unifiedLibraryIncludesRawNativeAndFilesWithoutDuplicatingManagedMatches() async throws {
    let a=unifiedItem("a"),b=unifiedItem("b"),raw=unifiedItem("raw")
    let prepared=try unifiedTrack(1,sources:[a.source,b.source]),file=try unifiedTrack(2)
    let result=try await unifiedProjection(tracks:[prepared,file],catalog:.init(items:[a,b,raw],playlists:[]))
    #expect(result.entries.map(\.id) == [a.id,b.id,raw.id,file.id])
    try #require(result.entries.count == 4)
    #expect(result.entries.prefix(2).allSatisfy { $0.track?.id == prepared.id && $0.canLoad })
    #expect(result.entries[2].track == nil && result.entries[2].canLoad)
    #expect(result.entries[3].nativeItem == nil && result.groups.isEmpty)
}

@Test func unifiedLibraryRetainsFilesWhenMusicIsDeniedOrEmpty() async throws {
    let file=try unifiedTrack(1)
    for catalog:MusicLibraryCatalog? in [nil,.init(items:[],playlists:[])] {
        let result=try await unifiedProjection(tracks:[file],catalog:catalog)
        #expect(result.entries.map(\.id) == [file.id] && result.entries.first?.canLoad == true)
    }
}

@Test func unifiedMusicPlaylistKeepsSourceOrderRawSongsAndDistinctAliases() async throws {
    let a=unifiedItem("a"),b=unifiedItem("b"),raw=unifiedItem("raw")
    let track=try unifiedTrack(1,sources:[a.source,b.source],nativeOnly:true)
    let catalog=MusicLibraryCatalog(items:[a,b,raw],playlists:[.init(id:"p",name:"Set",itemIDs:[b.id,raw.id,a.id,b.id])])
    let result=try await unifiedProjection(tracks:[track],catalog:catalog,category:.playlists,group:"music:p")
    #expect(result.entries.compactMap { $0.nativeItem?.id } == [b.id,raw.id,a.id,b.id])
    #expect(Set(result.entries.map(\.id)).count == 4)
    #expect(result.entries.map(\.membershipID) == [b.id,raw.id,a.id,b.id])
    let saved=try await LibraryBrowserProjection.selectedIDs(selection:Set(result.entries.map(\.membershipID)),tracks:[track],catalog:catalog)
    #expect(saved == [a.id,b.id,raw.id])
    #expect(result.groups.contains { $0.id == "music:p" && $0.name == "Set · Music" })
    let sorted=try await unifiedProjection(tracks:[track],catalog:catalog,sort:.title,category:.playlists,group:"music:p")
    #expect(sorted.entries.compactMap { $0.nativeItem?.id } == [a.id,b.id,b.id,raw.id])
}

@Test func unifiedCustomPlaylistResolvesLegacySHAAndNativeIDs() async throws {
    let a=unifiedItem("a"),raw=unifiedItem("raw"),file=try unifiedTrack(1)
    let prepared=try unifiedTrack(2,sources:[a.source],nativeOnly:true)
    var playlists=CollectionPlaylists();try playlists.add(trackIDs:[prepared.id,raw.id,file.id],name:"Custom")
    let group=try #require(playlists.playlists.first?.id.uuidString)
    let result=try await unifiedProjection(tracks:[file,prepared],catalog:.init(items:[a,raw],playlists:[]),
        category:.playlists,group:group,playlists:playlists)
    #expect(result.entries.map(\.id) == [prepared.id,raw.id,file.id])
    #expect(result.entries[0].nativeItem?.id == a.id && result.entries[0].track?.id == prepared.id)
}

@Test func unifiedUnavailableNativeUsesManagedCopyAndPreservesPreparedDisplay() throws {
    let missing=unifiedItem("missing",availability:.notDownloaded)
    var track=try unifiedTrack(1,sources:[missing.source]);track.preparation.correctedKey = .init(tonic:7,mode:.minor)
    track.preparation.grid=try BeatGrid(bpm:128,anchorFrame:0,sampleRate:48000)
    let entry=LibraryBrowserEntry(nativeItem:missing,track:track)
    #expect(entry.id == missing.id && entry.canLoad && entry.track?.id == track.id)
    #expect(entry.title == missing.title && entry.artist == missing.artist && entry.album == missing.album)
    #expect(entry.key == track.key && entry.bpm == 128)
    track.nativeLibraryOnly=true
    #expect(!LibraryBrowserEntry(nativeItem:missing,track:track).canLoad)
    #expect(!LibraryBrowserEntry(nativeItem:missing).canLoad)
}

@Test func unifiedCategoriesSearchAndSortIncludeUnpreparedNativeMetadata() async throws {
    let z=unifiedItem("z",title:"Écho 10"),a=unifiedItem("a",title:"Echo 2"),file=try unifiedTrack(1)
    let catalog=MusicLibraryCatalog(items:[z,a],playlists:[])
    let result=try await unifiedProjection(tracks:[file],catalog:catalog,sort:.title,search:"echo techno",category:.artists,group:"Music artist")
    #expect(result.entries.map(\.id) == [a.id,z.id])
    #expect(result.groups.map(\.id).contains("Music artist") && result.groups.map(\.id).contains("File artist"))
    for sort in CollectionSort.allCases {
        let tracks=try (1...8).map { try unifiedTrack($0) }
        let projected=try await unifiedProjection(tracks:tracks,catalog:nil,sort:sort)
        #expect(projected.entries.map(\.id) == CollectionBrowser.tracks(tracks,search:"",sort:sort).map(\.id))
    }
}

@Test func unifiedSuggestionsKeepCanonicalIdentityAndOriginalRank() async throws {
    let item=unifiedItem("a"),first=try unifiedTrack(1),second=try unifiedTrack(2,sources:[item.source],nativeOnly:true)
    let result=try await unifiedProjection(tracks:[first,second],catalog:.init(items:[item],playlists:[]),sort:.title,suggestions:[second.id,first.id])
    #expect(result.entries.map(\.id) == [second.id,first.id])
    #expect(result.entries[0].nativeItem?.id == item.id)
}

@Test func unifiedProjectionHonoursCancellation() async throws {
    let (stream,continuation)=AsyncStream<Void>.makeStream()
    let task=Task {
        for await _ in stream { break }
        return try await unifiedProjection(tracks:[],catalog:nil)
    }
    task.cancel();continuation.finish()
    await #expect(throws:CancellationError.self) { try await task.value }
}

@Test func unifiedRowWindowBoundsLargeLibraryIdentityWorkAndRetainsScrollExtent() {
    for offset in [0.0,58000,6_669_000,Double.greatestFiniteMagnitude] {
        let window=LibraryBrowserRowWindow(count:115000,offset:offset,viewportHeight:900)
        #expect(window.range.count <= 128 && window.range.lowerBound >= 0 && window.range.upperBound <= 115000)
        #expect(window.topHeight+Double(window.range.count)*58+window.bottomHeight == 115000*58)
    }
    let first=LibraryBrowserRowWindow(count:115000,offset:0,viewportHeight:900)
    #expect(first.range.lowerBound == 0 && first.range.upperBound >= 16)
    let middle=LibraryBrowserRowWindow(count:115000,offset:58000,viewportHeight:900)
    #expect(middle.range.contains(1000) && middle.range.contains(1015))
    let end=LibraryBrowserRowWindow(count:115000,offset:Double.greatestFiniteMagnitude,viewportHeight:900)
    #expect(end.range.upperBound == 115000)
}

@Test func unifiedRowWindowHandlesEmptyAndTransientGeometry() {
    #expect(LibraryBrowserRowWindow(count:0,offset:0,viewportHeight:900).range.isEmpty)
    for offset in [-100,Double.nan,-Double.infinity] {
        let window=LibraryBrowserRowWindow(count:20,offset:offset,viewportHeight:Double.nan)
        #expect(window.range.lowerBound == 0 && window.range.upperBound <= 20)
    }
}

@Test func unifiedPlaylistSaveResolvesHiddenSelectionAndDropsVanishedMembers() async throws {
    let a=unifiedItem("a"),b=unifiedItem("b"),first=try unifiedTrack(1),second=try unifiedTrack(2)
    let result=try await LibraryBrowserProjection.selectedIDs(selection:[b.id,second.id,"vanished",a.id],
        tracks:[first,second],catalog:.init(items:[a,b],playlists:[]))
    #expect(result == [second.id,a.id,b.id])
    let denied=try await LibraryBrowserProjection.selectedIDs(selection:[second.id,a.id],tracks:[first,second],catalog:nil)
    #expect(denied == [second.id])
}

@Test func unifiedProjectionKeepsLargeCatalogueRowsBoundedAfterSearch() async throws {
    let items=(0..<115000).map { unifiedItem(String($0),title:"Song \($0)") }
    let result=try await unifiedProjection(tracks:[],catalog:.init(items:items,playlists:[]))
    #expect(result.entries.count == 115000)
    let window=LibraryBrowserRowWindow(count:result.entries.count,offset:58000,viewportHeight:900)
    let visible=Array(result.entries[window.range])
    #expect(visible.count <= 128 && visible.contains { $0.id == "iosMusic:1000" })
    let filtered=try await unifiedProjection(tracks:[],catalog:.init(items:items,playlists:[]),search:"Song 114999")
    #expect(filtered.entries.map(\.id) == ["iosMusic:114999"])
}

@Test func unifiedDistinctArtistGroupsRetainSelectionAndPlaylistTargets() async throws {
    let items=(0..<115000).map { index in
        MusicLibraryItem(source:.init(platform:.iosMusic,persistentID:String(index)),title:"Song",artist:"Artist \(index)",
            assetURL:URL(string:"ipod-library://item/\(index)"),availability:.available)
    }
    var playlists=CollectionPlaylists();try playlists.add(trackIDs:[items[0].id],name:"Saved")
    let result=try await unifiedProjection(tracks:[],catalog:.init(items:items,playlists:[]),category:.artists,group:"Artist 114999",playlists:playlists)
    #expect(result.groups.count == 115000 && result.selectedGroup?.id == "Artist 114999")
    let choices=try await LibraryGroupProjection.build(source:result.groupSource,search:"Artist 114999",selectedID:"Artist 114999")
    #expect(choices.count == 1 && choices.selectedGroup?.id == "Artist 114999")
    let targets=try await LibraryGroupProjection.build(source:result.playlistTargets,search:"Saved")
    #expect(targets.count == 1 && targets.visibleGroups(in:0..<1).first?.id == playlists.playlists.first?.id.uuidString)
}

@Test func unifiedMetadataRefreshReusesGroupSourceWithoutLosingSelection() async throws {
    let item=unifiedItem("a"),track=try unifiedTrack(1,sources:[item.source])
    let catalog=MusicLibraryCatalog(items:[item],playlists:[])
    let first=try await unifiedProjection(tracks:[track],catalog:catalog,category:.artists,group:item.artist)
    var updated=track;updated.preparation.correctedKey = .init(tonic:7,mode:.minor)
    let result=try await LibraryBrowserProjection.build(tracks:[updated],suggestionIDs:nil,search:"",sort:nil,
        category:.artists,group:item.artist,playlists:.init(),catalog:catalog,previous:first)
    #expect(result.groupSource.id == first.groupSource.id && result.playlistTargets.id == first.playlistTargets.id)
    #expect(result.selectedGroup?.id == item.artist && result.entries.first?.key == updated.key)
}

@Test func unifiedNativeCustomMembershipRemainsLoadableWithoutMusicCatalogue() async throws {
    let b=unifiedItem("b"),track=try unifiedTrack(20,sources:[b.source])
    var playlists=CollectionPlaylists();try playlists.add(trackIDs:[b.id],name:"Offline set")
    let group=try #require(playlists.playlists.first?.id.uuidString)
    let result=try await unifiedProjection(tracks:[track],catalog:nil,category:.playlists,group:group,playlists:playlists)
    #expect(result.entries.count == 1)
    let row=try #require(result.entries.first)
    #expect(row.id == b.id && row.membershipID == track.id && row.track?.id == track.id && row.canLoad)
    #expect(row.nativeItem == nil && row.title == track.title)
    let members=try await LibraryBrowserProjection.selectedIDs(selection:[row.membershipID],tracks:[track],catalog:nil)
    #expect(members == [track.id])
    #expect(playlists.playlists.first?.trackIDs == [b.id])
}

@Test func unifiedStoredCloudOnlyMemberIsHiddenAndPreparationIsRetained() async throws {
    let b=unifiedItem("b")
    var track=try unifiedTrack(21,sources:[b.source],nativeOnly:true)
    track.preparation.correctedKey = .init(tonic:7,mode:.minor)
    let savedPreparation=track.preparation
    var playlists=CollectionPlaylists();try playlists.add(trackIDs:[b.id],name:"Cloud set")
    let group=try #require(playlists.playlists.first?.id.uuidString)
    let result=try await unifiedProjection(tracks:[track],catalog:.init(items:[],playlists:[]),category:.playlists,group:group,playlists:playlists)
    #expect(result.entries.isEmpty && result.groups.map(\.id) == [group])
    let members=try await LibraryBrowserProjection.selectedIDs(selection:[b.id,track.id],tracks:[track],catalog:nil)
    #expect(members.isEmpty)
    #expect(playlists.playlists.first?.trackIDs == [b.id])
    #expect(track.nativeLibraryOnly == true && track.preparation == savedPreparation)
}

@Test func unifiedCatalogueMetadataWinsOverStoredNativeFallback() async throws {
    let b=unifiedItem("b",title:"Current native title"),track=try unifiedTrack(22,sources:[b.source])
    var playlists=CollectionPlaylists();try playlists.add(trackIDs:[b.id],name:"Current")
    let group=try #require(playlists.playlists.first?.id.uuidString)
    let result=try await unifiedProjection(tracks:[track],catalog:.init(items:[b],playlists:[]),category:.playlists,group:group,playlists:playlists)
    let row=try #require(result.entries.first)
    #expect(row.nativeItem == b && row.title == b.title && row.membershipID == b.id && row.canLoad)
}

@Test func unifiedStoredMembershipFallbackKeepsCanonicalAndCatalogueOrdering() async throws {
    let a=unifiedItem("a"),b=unifiedItem("b"),track=try unifiedTrack(23,sources:[b.source])
    let catalog=MusicLibraryCatalog(items:[a],playlists:[])
    let members=try await LibraryBrowserProjection.selectedIDs(selection:[track.id,a.id,b.id,"unknown"],tracks:[track],catalog:catalog)
    #expect(members == [track.id,a.id])
    let all=try await unifiedProjection(tracks:[track],catalog:catalog)
    #expect(all.entries.map(\.id) == [a.id,track.id])
}
