import SwiftUI
import TDJCore

struct LibraryGroupChooser: View {
    let title: String
    let source: LibraryGroupSource
    let selectedGroup: CollectionGroup?
    let loading: Bool
    @Binding var selection: String?
    @State private var presented = false
    @State private var pendingName: CollectionGroup?
    private var name: String {
        guard let selection else { return "All" }
        if let selectedGroup, selectedGroup.id == selection { return selectedGroup.name }
        if let pendingName, pendingName.id == selection { return pendingName.name }
        return "Unavailable group"
    }
    var body: some View {
        Button {
            presented = true
        } label: {
            HStack(spacing: 6) {
                Text(name).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
        }.frame(maxWidth: 220).accessibilityLabel(title).accessibilityValue(name).onChange(of: source.id) { _, _ in
            pendingName = nil
        }.onChange(of: selection) { _, value in if pendingName?.id != value { pendingName = nil } }.popover(
            isPresented: $presented
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Button("Done") { presented = false }
                }
                LibraryGroupList(
                    title: title, source: source, selectedID: selection, includesAll: true, loading: loading
                ) { group in
                    pendingName = group
                    selection = group?.id
                    presented = false
                }
            }.padding(16).frame(width: 360, height: 440).presentationCompactAdaptation(.popover)
        }
    }
}

struct LibraryGroupList: View {
    let title: String
    let source: LibraryGroupSource
    let selectedID: String?
    let includesAll: Bool
    let loading: Bool
    /// Song counts shown beside groups, such as playlist sizes.
    var counts: [String: Int] = [:]
    let choose: (CollectionGroup?) -> Void
    @State private var search = ""
    @State private var result: LibraryGroupProjection?
    @State private var searching = true
    @State private var error: String?
    @State private var failedRequest: LibraryGroupRequest?
    @State private var displayedRequest: LibraryGroupRequest?
    @State private var resetToken = UUID()
    private struct TaskKey: Hashable {
        let request: LibraryGroupRequest
        let loading: Bool
    }
    private var request: LibraryGroupRequest {
        .init(sourceID: source.id, search: search, selectedID: selectedID, context: title)
    }
    private var taskKey: TaskKey { .init(request: request, loading: loading) }
    var body: some View {
        VStack(spacing: 8) {
            TextField("Search \(title.lowercased())", text: $search).textFieldStyle(.roundedBorder).accessibilityLabel(
                "Search \(title.lowercased())")
            if includesAll {
                Button {
                    choose(nil)
                } label: {
                    HStack {
                        Text("All")
                        Spacer()
                        if selectedID == nil { Image(systemName: "checkmark") }
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).frame(height: 32)
            }
            let currentError = failedRequest == request ? error : nil
            let rowsReady = !loading && currentError == nil && request.canPresentResult(from: displayedRequest)
            if let result, result.count > 0 {
                // Lazy rows render on scroll without relying on scroll-offset preferences.
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Color.clear.frame(height: 0).id("groupTop").accessibilityHidden(true)
                            ForEach(LibraryBrowserRows(count: result.count).indices, id: \.self) { index in
                                if let group = result.visibleGroups(in: index..<(index + 1)).first {
                                    Button {
                                        guard !loading, request.canPresentResult(from: displayedRequest) else { return }
                                        choose(group)
                                    } label: {
                                        HStack {
                                            Text(group.name).lineLimit(2)
                                            Spacer()
                                            if let count = counts[group.id] {
                                                Text("\(count)").monospacedDigit().foregroundStyle(.secondary)
                                            }
                                            if selectedID == group.id { Image(systemName: "checkmark") }
                                        }.padding(.horizontal, 8).frame(height: 57).contentShape(Rectangle())
                                    }.buttonStyle(.plain).padding(.bottom, 1).accessibilityLabel(group.name)
                                        .accessibilityAddTraits(selectedID == group.id ? .isSelected : [])
                                }
                            }
                        }
                    }.onChange(of: resetToken) { _, _ in reader.scrollTo("groupTop", anchor: .top) }
                }.opacity(rowsReady ? 1 : 0).disabled(!rowsReady).allowsHitTesting(rowsReady).accessibilityHidden(
                    !rowsReady
                ).overlay { if !rowsReady { Text(currentError ?? "Searching…").foregroundStyle(.secondary) } }
            } else if let currentError {
                Spacer()
                Text(currentError).foregroundStyle(.secondary)
                Spacer()
            } else if loading || !rowsReady || searching {
                Spacer()
                Text("Searching…").foregroundStyle(.secondary)
                Spacer()
            } else {
                Spacer()
                Text(search.isEmpty ? "No groups available." : "No matching groups.").foregroundStyle(.secondary)
                Spacer()
            }
        }.task(id: taskKey) {
            let current = taskKey
            guard !current.loading else { return }
            searching = true
            error = nil
            failedRequest = nil
            do {
                let value = try await LibraryGroupProjection.build(
                    source: source, search: current.request.search, selectedID: current.request.selectedID)
                guard !Task.isCancelled, current == taskKey else { return }
                if current.request.resetsScroll(comparedTo: displayedRequest) { resetToken = UUID() }
                displayedRequest = current.request
                result = value
                searching = false
            } catch is CancellationError {} catch {
                guard !Task.isCancelled, current == taskKey else { return }
                searching = false
                failedRequest = current.request
                self.error = error.localizedDescription
            }
        }
    }
}
