import SwiftUI

@MainActor struct NotificationCenterButton: View {
    let model: ReplicaModel
    @State private var presented = false

    var body: some View {
        let unreadCount = model.unreadMusicLibraryNoticeCount
        Button {
            presented.toggle()
        } label: {
            Image(systemName: "info.circle.fill").font(.system(size: 18)).frame(width: 44, height: 44)
                .bevelPanel(cornerRadius: 5).overlay(alignment: .topLeading) {
                    if unreadCount > 0 {
                        Text("\(unreadCount)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 4).frame(minWidth: 18, minHeight: 18)
                            .background(Capsule().fill(PerformancePalette.red)).fixedSize().offset(x: -4, y: -4)
                            .accessibilityHidden(true)
                    }
                }
        }.accessibilityLabel("Notification Center").accessibilityValue("\(unreadCount) unread")
            .popover(isPresented: $presented, arrowEdge: .top) {
                LibraryNoticeList(model: model) {
                    presented = false
                    model.helpVisible = true
                }
            }
    }
}

@MainActor private struct LibraryNoticeList: View {
    let model: ReplicaModel
    let showGuide: () -> Void
    @State private var songTitles: [String: String] = [:]

    var body: some View {
        let notices = model.musicLibraryNotices
        VStack(spacing: 0) {
            HStack {
                Text("Notification Center").font(.headline)
                Spacer()
                Button("Mark all as read") {
                    model.musicLibraryNotices.markAllRead()
                    model.musicLibraryAccessNotice.markRead()
                }.disabled(model.unreadMusicLibraryNoticeCount == 0)
            }.padding(12)
            Divider()
            List {
                if let error = model.musicLibraryError {
                    LibraryNoticeRow(title: "Music library access", message: error, isRead: model.musicLibraryAccessNotice.isRead) {
                        model.musicLibraryAccessNotice.markRead()
                    }
                }
                ForEach(notices.failures.keys.sorted(), id: \.self) { id in
                    if let message = notices.failures[id] {
                        LibraryNoticeRow(
                            title: songTitles[id] ?? "Song \(id)", message: message, isRead: notices.isFailureRead(id)
                        ) { model.musicLibraryNotices.markFailureRead(id) }
                    }
                }
                if model.musicLibraryError == nil && notices.failures.isEmpty {
                    Text("No notifications").foregroundStyle(.secondary)
                }
            }.listStyle(.plain)
            Divider()
            Button(action: showGuide) { Label("Gesture guide", systemImage: "hand.tap") }.padding(12)
        }.frame(width: 340, height: 400)
            .onChange(of: model.musicLibraryCatalogVersion, initial: true) { _, _ in
                songTitles = Dictionary(
                    (model.musicLibraryCatalog?.items ?? []).lazy.map { ($0.id, $0.title) },
                    uniquingKeysWith: { first, _ in first })
            }
    }
}

private struct LibraryNoticeRow: View {
    let title: String
    let message: String
    let isRead: Bool
    let markRead: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expanded.toggle()
                if expanded { markRead() }
            } label: {
                HStack {
                    Image(systemName: isRead ? "circle" : "circle.fill").font(.system(size: 8))
                        .foregroundStyle(isRead ? Color.secondary : PerformancePalette.cyan)
                        .accessibilityHidden(true)
                    Text(title).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.caption)
                        .accessibilityHidden(true)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(isRead ? "Read" : "Unread")
            if expanded { Text(message).font(.callout).foregroundStyle(.secondary) }
        }.onChange(of: message) { _, _ in expanded = false }
    }
}
