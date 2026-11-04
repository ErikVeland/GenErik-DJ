import Foundation

/// Play history from deck loads: the newest session first, older sessions in month folders.
public struct HistorySession: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let started: Date
    /// Track IDs in load order, without repeats.
    public let trackIDs: [String]
}
public struct HistoryMonth: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let sessions: [HistorySession]
}
public enum HistorySessions {
    public static func sessions(from events: [PerformanceEvent]) -> [HistorySession] {
        var grouped: [UUID: (Date, [String])] = [:]
        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) where event.kind == .load {
            guard let track = event.toTrackID else { continue }
            var entry = grouped[event.sessionID] ?? (event.timestamp, [])
            if !entry.1.contains(track) { entry.1.append(track) }
            grouped[event.sessionID] = entry
        }
        return grouped.map { HistorySession(id: $0.key, started: $0.value.0, trackIDs: $0.value.1) }.sorted {
            $0.started > $1.started
        }
    }
    /// The newest session stays on top; the rest group by calendar month, newest month first.
    public static func layout(_ sessions: [HistorySession], calendar: Calendar = .current) -> (
        latest: HistorySession?, months: [HistoryMonth]
    ) {
        guard let latest = sessions.first else { return (nil, []) }
        var months: [String: [HistorySession]] = [:]
        var titles: [String: String] = [:]
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"
        for session in sessions.dropFirst() {
            let parts = calendar.dateComponents([.year, .month], from: session.started)
            let key = String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
            months[key, default: []].append(session)
            titles[key] = formatter.string(from: session.started)
        }
        return (
            latest,
            months.keys.sorted(by: >).map { HistoryMonth(id: $0, title: titles[$0] ?? $0, sessions: months[$0]!) }
        )
    }
}

/// Recording tracklists are "hh:mm:ss - Artist - Title" lines beside each AIFF.
public enum RecordingTracklist {
    public struct Line: Sendable, Equatable {
        public let seconds: Int
        public let artist: String
        public let title: String
        public init(seconds: Int, artist: String, title: String) {
            self.seconds = seconds
            self.artist = artist
            self.title = title
        }
    }
    public static func parse(_ text: String) -> [Line] {
        text.split(whereSeparator: \.isNewline).compactMap { raw in
            let parts = raw.components(separatedBy: " - ")
            guard parts.count >= 3 else { return nil }
            let time = parts[0].split(separator: ":").compactMap { Int($0) }
            guard time.count == 3 else { return nil }
            return Line(
                seconds: time[0] * 3600 + time[1] * 60 + time[2], artist: parts[1],
                title: parts.dropFirst(2).joined(separator: " - "))
        }
    }
}
