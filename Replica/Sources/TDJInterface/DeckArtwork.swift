import AVFoundation
import SwiftUI
import ImageIO
import TDJCore
#if os(iOS)
import MediaPlayer
#endif

/// Where a track's art can come from, tried in order: the prepared artwork file, the Music library
/// item, then art embedded in the audio file (ID3 APIC or MP4 covr).
struct ArtworkSource: Hashable, Sendable {
    var file: URL?
    var native: MusicLibrarySource?
    var asset: URL?
    var isEmpty: Bool { file == nil && native == nil && asset == nil }

    @MainActor static func track(_ track: Track?, item: MusicLibraryItem? = nil, media: URL) -> ArtworkSource? {
        let source=ArtworkSource(file:track?.artworkFilename.map { media.appendingPathComponent($0) },
                                 native:item?.source ?? track?.musicLibrarySources?.first,
                                 asset:item?.assetURL)
        return source.isEmpty ? nil : source
    }
}

struct DeckArtwork: View {
    let source: ArtworkSource?
    var placeholderSize: CGFloat = 22
    init(url: URL?) { source=url.map { ArtworkSource(file:$0) } }
    init(source: ArtworkSource?, placeholderSize: CGFloat = 22) { self.source=source; self.placeholderSize=placeholderSize }
    @State private var thumbnail: ArtworkThumbnail?
    var body: some View {
        Group {
            if let thumbnail, thumbnail.source == source {
                Image(decorative:thumbnail.image,scale:1).resizable().scaledToFill()
            } else {
                Image(systemName:"waveform").font(.system(size:placeholderSize))
                    .foregroundStyle(Color(red:0.40,green:0.57,blue:0.98))
            }
        }.task(id:source) {
            thumbnail=nil
            guard let source else { return }
            let loaded=await ArtworkThumbnails.shared.load(source)
            guard !Task.isCancelled else { return }
            thumbnail=loaded
        }
    }
}

struct ArtworkThumbnail: @unchecked Sendable {
    let source: ArtworkSource
    let image: CGImage
    init(source: ArtworkSource, image: CGImage) { self.source=source; self.image=image }
    init(url: URL, image: CGImage) { self.init(source:.init(file:url),image:image) }
    var url: URL? { source.file }
}

actor ArtworkThumbnails {
    /// A screen of song rows plus both decks while scrolling.
    static let shared=ArtworkThumbnails(capacity:256)
    private let worker=BackgroundFileWork(label:"org.generikdj.artwork-thumbnails")
    private let decode: @Sendable (URL) -> ArtworkThumbnail?
    private let capacity: Int
    init(capacity: Int = 32, decode: @escaping @Sendable (URL) -> ArtworkThumbnail? = ArtworkThumbnails.decodeThumbnail) {
        self.capacity=max(1,capacity); self.decode=decode
    }
    private var cache: [ArtworkSource:ArtworkThumbnail]=[:]
    private var order: [ArtworkSource]=[]
    private var pending: [ArtworkSource:Task<ArtworkThumbnail?,Never>]=[:]

    func load(_ url: URL) async -> ArtworkThumbnail? { await load(ArtworkSource(file:url)) }
    func load(_ source: ArtworkSource) async -> ArtworkThumbnail? {
        if let cached=cache[source] { return cached }
        if let task=pending[source] { return await task.value }
        let worker=self.worker, decode=self.decode
        let task=Task.detached(priority:.background) { () -> ArtworkThumbnail? in
            if let file=source.file, let decoded=await worker.run({ decode(file) }) { return .init(source:source,image:decoded.image) }
            if let native=source.native, let data=await Self.nativeArtwork(native),
               let image=await worker.run({ Self.thumbnail(data) }) { return .init(source:source,image:image) }
            if let asset=source.asset, let data=await Self.embeddedArtwork(asset),
               let image=await worker.run({ Self.thumbnail(data) }) { return .init(source:source,image:image) }
            return nil
        }
        pending[source]=task
        let result=await task.value
        pending[source]=nil
        if let result {
            cache[source]=result; order.append(source)
            if order.count>capacity { cache[order.removeFirst()]=nil }
        }
        return result
    }

    // ImageIO source creation and decoding both stay inside the enforced queue block.
    static func decodeThumbnail(_ url: URL) -> ArtworkThumbnail? {
        thumbnail(CGImageSourceCreateWithURL(url as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary))
            .map { ArtworkThumbnail(source:.init(file:url),image:$0) }
    }
    static func thumbnail(_ data: Data) -> CGImage? { thumbnail(CGImageSourceCreateWithData(data as CFData,nil)) }
    static func thumbnail(_ source: CGImageSource?) -> CGImage? {
        guard let source else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source,0,[
            kCGImageSourceCreateThumbnailFromImageAlways:true,
            kCGImageSourceCreateThumbnailWithTransform:true,
            kCGImageSourceShouldCacheImmediately:true,
            kCGImageSourceThumbnailMaxPixelSize:192
        ] as CFDictionary)
    }
    /// Embedded cover art from ID3 APIC, MP4 covr or any common artwork key.
    static func embeddedArtwork(_ url: URL) async -> Data? {
        let asset=AVURLAsset(url:url)
        guard let formats=try? await asset.load(.availableMetadataFormats) else { return nil }
        var items=(try? await asset.load(.commonMetadata)) ?? []
        for format in formats { items+=(try? await asset.loadMetadata(for:format)) ?? [] }
        let artwork=AVMetadataItem.metadataItems(from:items,filteredByIdentifier:.commonIdentifierArtwork)
            + items.filter { [AVMetadataIdentifier.id3MetadataAttachedPicture,.iTunesMetadataCoverArt].contains($0.identifier) }
        for item in artwork { if let data=try? await item.load(.dataValue), !data.isEmpty { return data } }
        return nil
    }
    static func nativeArtwork(_ source: MusicLibrarySource) async -> Data? {
#if os(iOS)
        guard source.platform == .iosMusic, let id=UInt64(source.persistentID),
              MPMediaLibrary.authorizationStatus() == .authorized else { return nil }
        let query=MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(value:NSNumber(value:id),forProperty:MPMediaItemPropertyPersistentID))
        guard let image=query.items?.first?.artwork?.image(at:CGSize(width:192,height:192)) else { return nil }
        return image.pngData()
#else
        return nil
#endif
    }
}
