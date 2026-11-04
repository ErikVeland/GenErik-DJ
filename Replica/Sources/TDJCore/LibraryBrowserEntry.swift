import Foundation

public struct LibraryBrowserEntry: Sendable, Identifiable {
    public let id: String
    public let membershipID: String
    public let nativeItem: MusicLibraryItem?
    public let track: Track?
    public let title: String
    public let artist: String
    public let album: String
    public let genre: String?
    public let key: MusicalKey?
    public let bpm: Double?
    public let canLoad: Bool
    /// Longer than the mix threshold, shown with a mix icon.
    public let isMix: Bool

    private let hint: BrowserPreparationHint?
    public init(nativeItem: MusicLibraryItem, track: Track? = nil, hint: BrowserPreparationHint? = nil) {
        let id = nativeItem.id
        self.init(id: id, membershipID: id, nativeItem: nativeItem, track: track, hint: hint)
    }
    public init(track: Track, nativeItem: MusicLibraryItem? = nil, hint: BrowserPreparationHint? = nil) {
        self.init(id: track.id, membershipID: track.id, nativeItem: nativeItem, track: track, hint: hint)
    }
    public func withOccurrenceID(_ id: String) -> Self {
        Self(id: id, membershipID: membershipID, nativeItem: nativeItem, track: track, hint: hint)
    }
    private init(
        id: String, membershipID: String, nativeItem: MusicLibraryItem?, track: Track?, hint: BrowserPreparationHint?
    ) {
        self.hint = hint
        self.id = id
        self.membershipID = membershipID
        self.nativeItem = nativeItem
        self.track = track
        title = nativeItem?.title ?? track?.title ?? ""
        artist = nativeItem?.artist ?? track?.artist ?? ""
        album = nativeItem?.album ?? track?.album ?? ""
        genre = nativeItem?.genre ?? track?.genre
        // Prepared values win; collection or first-minute results fill the rest.
        key = track?.key ?? hint?.key
        bpm = track?.bpm ?? hint?.bpm
        isMix =
            hint?.isMix == true || NativeAnalysisPlan.isMix(duration: nativeItem?.duration ?? track?.analysis.duration)
        canLoad = (track != nil && track?.nativeLibraryOnly != true) || nativeItem?.isOnDevice == true
    }
}
