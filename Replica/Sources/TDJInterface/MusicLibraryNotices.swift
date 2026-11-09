import Foundation

struct LibraryAnalysisWarning: Equatable {
    let title: String
    let message: String
}

struct LoadedAnalysisNotice: Identifiable {
    let id = UUID()
    let warning: LibraryAnalysisWarning
}

struct MusicLibraryAccessNotice {
    var message: String? {
        didSet {
            if message != oldValue { isRead = false }
        }
    }
    private(set) var isRead = false
    var unreadCount: Int { message != nil && !isRead ? 1 : 0 }

    mutating func markRead() {
        isRead = message != nil
    }
}

struct MusicLibraryNotices {
    private(set) var failures: [String: String] = [:]
    private(set) var loadedAnalysisNotices: [LoadedAnalysisNotice] = []
    private var readFailureIDs: Set<String> = []
    private var unreadLoadedAnalysisIDs: Set<UUID> = []

    var unreadCount: Int {
        failures.count - readFailureIDs.count + unreadLoadedAnalysisIDs.count
    }

    mutating func addLoadedAnalysisNotice(_ warning: LibraryAnalysisWarning) {
        let notice = LoadedAnalysisNotice(warning: warning)
        loadedAnalysisNotices.append(notice)
        unreadLoadedAnalysisIDs.insert(notice.id)
    }

    func isLoadedAnalysisNoticeRead(_ id: UUID) -> Bool {
        !unreadLoadedAnalysisIDs.contains(id)
    }

    mutating func markLoadedAnalysisNoticeRead(_ id: UUID) {
        unreadLoadedAnalysisIDs.remove(id)
    }

    mutating func setFailure(_ message: String?, for id: String) {
        guard failures[id] != message else { return }
        failures[id] = message
        readFailureIDs.remove(id)
    }

    mutating func clearFailures() {
        failures.removeAll()
        readFailureIDs.removeAll()
    }

    func isFailureRead(_ id: String) -> Bool {
        readFailureIDs.contains(id)
    }

    mutating func markFailureRead(_ id: String) {
        guard failures[id] != nil else { return }
        readFailureIDs.insert(id)
    }

    mutating func markAllRead() {
        readFailureIDs = Set(failures.keys)
        unreadLoadedAnalysisIDs.removeAll()
    }
}
