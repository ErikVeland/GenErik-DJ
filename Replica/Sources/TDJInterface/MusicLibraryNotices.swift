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
    private var readFailureIDs: Set<String> = []

    var unreadCount: Int {
        failures.count - readFailureIDs.count
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
    }
}
