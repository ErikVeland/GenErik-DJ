@main struct CheckMusicLibraryNotices {
    static func main() {
        var notices = MusicLibraryNotices()
        notices.setFailure("Check BPM", for: "song-a")
        notices.setFailure("Check cues", for: "song-b")
        precondition(notices.unreadCount == 2)

        notices.markFailureRead("song-a")
        notices.markFailureRead("song-a")
        notices.markFailureRead("missing")
        precondition(notices.unreadCount == 1)
        precondition(notices.failures["song-a"] == "Check BPM")
        notices.setFailure("Check BPM", for: "song-a")
        precondition(notices.unreadCount == 1)

        notices.markAllRead()
        precondition(notices.unreadCount == 0)
        precondition(notices.failures.count == 2)
        notices.setFailure("Check beat grid", for: "song-a")
        notices.setFailure("Check tempo", for: "song-c")
        precondition(notices.unreadCount == 2)

        notices.setFailure(nil, for: "song-b")
        precondition(notices.unreadCount == 2)
        notices.setFailure("Check cues", for: "song-b")
        precondition(notices.unreadCount == 3)
        notices.clearFailures()
        precondition(notices.failures.isEmpty && notices.unreadCount == 0)

        let warning = LibraryAnalysisWarning(title: "Song A", message: "Check the beat grid.")
        notices.addLoadedAnalysisNotice(warning)
        let firstLoad = notices.loadedAnalysisNotices[0].id
        precondition(notices.unreadCount == 1 && !notices.isLoadedAnalysisNoticeRead(firstLoad))
        notices.markLoadedAnalysisNoticeRead(firstLoad)
        precondition(notices.unreadCount == 0 && notices.isLoadedAnalysisNoticeRead(firstLoad))
        notices.addLoadedAnalysisNotice(warning)
        let secondLoad = notices.loadedAnalysisNotices[1]
        precondition(secondLoad.id != firstLoad && secondLoad.warning == warning)
        notices.setFailure("Track load failed", for: "song-a")
        precondition(notices.unreadCount == 2)
        notices.clearFailures()
        precondition(notices.unreadCount == 1)
        notices.markAllRead()
        precondition(notices.unreadCount == 0 && notices.isLoadedAnalysisNoticeRead(secondLoad.id))
        precondition(notices.loadedAnalysisNotices.count == 2)

        var accessNotice = MusicLibraryAccessNotice()
        accessNotice.message = "Library access failed"
        precondition(accessNotice.unreadCount == 1)
        accessNotice.markRead()
        precondition(accessNotice.unreadCount == 0)
        precondition(accessNotice.message == "Library access failed")
        accessNotice.message = "Library access failed"
        precondition(accessNotice.unreadCount == 0)
        accessNotice.message = "Library access denied"
        precondition(accessNotice.unreadCount == 1)
        print("Music library notice checks passed.")
    }
}
