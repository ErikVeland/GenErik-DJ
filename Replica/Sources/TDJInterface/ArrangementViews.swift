import SwiftUI
import TDJCore

extension Color {
    init(arrangementHex: UInt32) {
        self.init(
            red: Double((arrangementHex >> 16) & 255) / 255, green: Double((arrangementHex >> 8) & 255) / 255,
            blue: Double(arrangementHex & 255) / 255)
    }
}

/// Section rectangles share the waveform time axis and retain exact boundaries.
struct ArrangementColourRegion {
    let rect: CGRect
    let colour: Color
    static func visible(
        _ sections: [ArrangementSection], left: Double, span: Double, width: Double, height: Double, origin: Double = 0
    ) -> [Self] {
        guard span > 0, width > 0 else { return [] }
        return sections.compactMap { section in
            let start = max(0, (section.start - left) / span * width)
            let end = min(width, (section.end - left) / span * width)
            guard end > start else { return nil }
            return Self(
                rect: CGRect(x: origin + start, y: 0, width: end - start, height: height),
                colour: Color(arrangementHex: section.colourHex))
        }
    }
}

@MainActor struct DeckSectionHeader: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let visibleSeconds: Double
    let waveform: CGRect
    var body: some View {
        Canvas { context, size in
            guard model.pendingNativeSelection[deck] == nil, let track = model.track(deck),
                let arrangement = model.arrangements[track.id]
            else { return }
            if let current = arrangement.section(at: model.playbackSnapshot?[deck].sourceFrame ?? 0) {
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(arrangementHex: current.colourHex).opacity(0.08)))
            }
            let span = max(1, visibleSeconds * track.analysis.sampleRate)
            let left = (model.viewport[deck] ?? 0) - span / 2
            for region in ArrangementColourRegion.visible(
                arrangement.sections, left: left, span: span, width: waveform.width, height: size.height,
                origin: waveform.minX)
            {
                context.fill(
                    Path(CGRect(x: region.rect.minX, y: 0, width: region.rect.width, height: 3)),
                    with: .color(region.colour))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

@MainActor struct ArrangementDeckStrip: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var compact = false
    var rowHeight: Double = 44
    var showsEditorButton = true
    var inHeader = false
    var openEditor: () -> Void = {}
    var body: some View {
        let timeline = model.arrangementCueTimeline(deck: deck)
        HStack(spacing: 8) {
            if let timeline {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Label(timeline.currentLabel, systemImage: timeline.currentKind.symbol)
                            .foregroundStyle(currentColour).lineLimit(1)
                        if let next = timeline.next { ArrangementCueBadge(cue: next) }
                    }.fixedSize(horizontal: true, vertical: false)
                    if let next = timeline.next {
                        ArrangementCueBadge(cue: next)
                    } else {
                        Label(timeline.currentLabel, systemImage: timeline.currentKind.symbol).lineLimit(1)
                    }
                }
            } else {
                Image(systemName: "waveform").foregroundStyle(.secondary)
                    .accessibilityLabel("Song structure is not ready")
            }
            Spacer(minLength: 0)
            if compact { ArrangementEndingCue(model: model, deck: deck) }
            if showsEditorButton {
                Button(action: openEditor) { Image(systemName: "diamond").frame(width: 44, height: 44) }
                    .accessibilityLabel("Edit sections and analysis landmarks").disabled(
                        model.track(deck).flatMap { model.arrangements[$0.id] } == nil)
            }
        }.font(.system(size: 11, weight: .semibold, design: .monospaced)).padding(.horizontal, inHeader ? 0 : 8).frame(
            height: rowHeight
        ).background(inHeader ? Color.clear : PerformancePalette.sunken).task(id: preparationKey) {
            await model.prepareArrangement(deck: deck)
        }
    }
    private var preparationKey: String {
        guard let track = model.track(deck) else { return "" }
        return track.id
            + (model.preparingPlayback.contains(deck)
                ? "-loading" : track.analysis.waveform.isEmpty ? "-waiting" : "-ready")
    }
    private var currentColour: Color {
        guard let track = model.track(deck),
            let section = model.arrangements[track.id]?.section(at: model.playbackSnapshot?[deck].sourceFrame ?? 0)
        else { return .secondary }
        return Color(arrangementHex: section.colourHex)
    }
}

@MainActor struct ArrangementWaveformOverlay: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let track: Track
    let center: Double
    let span: Double
    var overview = false
    var editorDraft: TrackArrangement? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if editorDraft == nil, !model.editing.contains(deck) {
            PerformanceArrangementOverlay(
                model: model, deck: deck, track: track, center: center, span: span, overview: overview)
        } else {
            editorOverlay
        }
    }
    private var editorOverlay: some View {
        Canvas { context, size in
            guard let arrangement = editorDraft ?? model.arrangements[track.id] else { return }
            let left = center - span / 2
            func x(_ frame: Double) -> Double { (frame - left) / max(1, span) * size.width }
            for section in arrangement.sections where section.end > left && section.start < left + span {
                let start = max(0, x(section.start))
                let end = min(size.width, x(section.end))
                let colour = Color(arrangementHex: section.colourHex)
                if overview {
                    context.fill(
                        Path(CGRect(x: start, y: 0, width: max(0, end - start), height: size.height)),
                        with: .color(colour.opacity(0.12)))
                    context.fill(
                        Path(CGRect(x: start, y: 0, width: max(0, end - start), height: 3)), with: .color(colour))
                }
                if start > 0 {
                    var line = Path()
                    line.move(to: .init(x: start, y: 0))
                    line.addLine(to: .init(x: start, y: size.height))
                    context.stroke(line, with: .color(colour.opacity(0.5)), lineWidth: 1)
                }
            }
            var lastX = -100.0
            for landmark in arrangement.landmarks.sorted(by: { $0.frame < $1.frame }) where landmark.state != .dismissed
            {
                let px = x(landmark.frame)
                guard px >= 5, px < size.width - 5, px - lastX > (overview ? 38 : 70) else { continue }
                lastX = px
                if let finish = landmark.end {
                    context.fill(
                        Path(
                            CGRect(x: px, y: size.height - 9, width: max(1, min(size.width, x(finish)) - px), height: 8)
                        ), with: .color(Color.white.opacity(0.18)))
                }
                var diamond = Path()
                diamond.move(to: .init(x: px, y: size.height - 10))
                diamond.addLine(to: .init(x: px + 4, y: size.height - 6))
                diamond.addLine(to: .init(x: px, y: size.height - 2))
                diamond.addLine(to: .init(x: px - 4, y: size.height - 6))
                diamond.closeSubpath()
                context.stroke(diamond, with: .color(.white.opacity(0.85)), lineWidth: 1)
            }
            if editorDraft == nil, let status = model.arrangementStatus(deck: deck),
                status.warning == .red || status.warning == .urgent
            {
                let pulse = status.pulseValue(reduceMotion: reduceMotion, audible: model.arrangementAudible(deck: deck))
                let opacity = (status.warning == .urgent ? 0.20 : 0.12) + pulse * 0.08
                context.fill(
                    Path(CGRect(x: 0, y: size.height - 4, width: size.width, height: 4)),
                    with: .color(Color.red.opacity(opacity)))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

@MainActor struct ArrangementRemainingTime: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @AppStorage("arrangement.prepareBars") private var prepareBars = 32
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if let status = model.arrangementStatus(deck: deck, prepareBars: prepareBars) {
            HStack(spacing: 12) {
                Text(status.endingText).fontWeight(.semibold)
                Text("Music \(clock(status.musicSeconds)) · File \(clock(status.fileSeconds))").foregroundStyle(
                    .secondary)
            }.font(.system(size: 10, design: .monospaced)).lineLimit(1).foregroundStyle(colour(status.warning)).padding(
                .horizontal, 5
            ).padding(.vertical, 3).background(
                colour(status.warning).opacity(
                    status.warning == .none
                        ? 0
                        : 0.08 + status.pulseValue(
                            reduceMotion: reduceMotion, audible: model.arrangementAudible(deck: deck)) * 0.06)
            ).accessibilityElement(children: .combine)
        }
    }
    private func colour(_ warning: ArrangementWarning) -> Color {
        switch warning {
        case .red, .urgent, .ended: .red
        case .amber: .orange
        default: .secondary
        }
    }
    private func clock(_ seconds: Double) -> String {
        let value = Int(ceil(seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

@MainActor struct ArrangementEditor: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let identity: SectionEditIdentity
    let isPresented: Bool
    var usesColumns = false
    var close: () -> Void
    @FocusState private var focusedField: EditorField?
    private enum EditorField: Hashable {
        case sectionName(Int)
        case boundary(Int)
        case landmarkName(Int)
        case landmarkTime(Int, Bool)
        case reason(Int)
    }
    private var validLoad: Bool {
        model.pendingNativeSelection[deck] == nil
            && identity.matches(trackID: model.track(deck)?.id, loadID: model.loadIdentity(deck))
    }
    @State private var draft: TrackArrangement?
    @State private var editCursor: Double?
    @AppStorage("arrangement.prepareBars") private var prepareBars = 32
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: close).frame(minWidth: 44, minHeight: 44)
                Spacer(minLength: 8)
                Text("Deck \(deck.rawValue.uppercased()) sections").font(.headline).lineLimit(1)
                Spacer(minLength: 8)
                Button("Save") {
                    guard validLoad, let draft else {
                        close()
                        return
                    }
                    if model.updateArrangement(draft, deck: deck) { close() }
                }.frame(minWidth: 44, minHeight: 44).disabled(!validLoad || draft == nil)
            }.padding(.horizontal, 12).background(PerformancePalette.frame)
            if usesColumns {
                if validLoad, let track = model.track(deck), let draft {
                    ArrangementEditorWaveform(
                        model: model, deck: deck, track: track, draft: draft,
                        cursor: Binding(get: { position }, set: { editCursor = $0 }))
                    placementControls
                }
                GeometryReader { space in
                    if space.size.width >= 740 {
                        HStack(spacing: 0) {
                            Form {
                                options
                                sections
                            }
                            Divider()
                            Form {
                                landmarks
                                statusText
                            }
                        }.formStyle(.grouped).disabled(!validLoad)
                    } else {
                        combinedForm
                    }
                }
            } else {
                combinedForm
            }
        }.onAppear {
            if draft == nil, validLoad { draft = model.arrangements[identity.trackID] }
            if usesColumns, editCursor == nil { editCursor = position }
        }.onChange(
            of: isPresented
        ) { _, visible in if !visible { focusedField = nil } }.onChange(of: model.loaded[deck]) { _, _ in
            if !validLoad { close() }
        }.onChange(of: model.loadIdentity(deck)) { _, _ in if !validLoad { close() } }
            .onChange(of: model.pendingNativeSelection[deck]?.id) { _, _ in if !validLoad { close() } }
    }
    private var combinedForm: some View {
        Form {
            options
            sections
            landmarks
            statusText
        }.formStyle(.grouped).disabled(!validLoad)
    }

    @ViewBuilder private var options: some View {
        Picker("Ending preparation cue", selection: $prepareBars) {
            ForEach([32, 48, 64, 96], id: \.self) { Text("\($0) bars").tag($0) }
        }
    }

    @ViewBuilder private var sections: some View {
        if let value = draft {
            Section("Sections") {
                ForEach(value.sections.indices, id: \.self) { index in
                    DisclosureGroup(value.sections[index].label) {
                        Text(value.sections[index].locked ? "Assignment: Manual" : "Assignment: Automatic")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("Name", text: sectionBinding(index, \.name)).focused(
                            $focusedField, equals: .sectionName(index))
                        Picker("Musical role", selection: roleBinding(index)) {
                            ForEach(ArrangementRole.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        Picker("Arrangement behaviour", selection: sectionBinding(index, \.behaviour)) {
                            ForEach(ArrangementBehaviour.allCases, id: \.self) {
                                Text($0 == .sustaining ? "SUSTAINING" : $0.label).tag($0)
                            }
                        }
                        if index > 0 {
                            HStack {
                                Text("Start (seconds)")
                                TextField("Start", value: boundaryBinding(index), format: .number).frame(
                                    width: 100
                                ).focused($focusedField, equals: .boundary(index))
                            }
                        }
                        Text("Edits lock this section against reanalysis.").font(.caption).foregroundStyle(
                            .secondary)
                    }.foregroundStyle(Color(arrangementHex: value.sections[index].colourHex))
                }
                if !usesColumns { Button("Split section at preview position", action: splitSection) }
            }
        }
    }

    @ViewBuilder private var landmarks: some View {
        if let value = draft {
            Section("Analysis landmarks") {
                ForEach(value.landmarks.indices, id: \.self) { index in
                    DisclosureGroup(
                        "◇ " + value.landmarks[index].name
                            + (value.landmarks[index].state == .dismissed ? " · DISMISSED" : "")
                    ) {
                        TextField("Name", text: landmarkBinding(index, \.name)).focused(
                            $focusedField, equals: .landmarkName(index))
                        Picker("Kind", selection: landmarkBinding(index, \.kind)) {
                            ForEach(ArrangementLandmarkKind.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        HStack {
                            Text("Position (seconds)")
                            TextField("Position", value: landmarkTime(index), format: .number).frame(width: 100)
                                .focused($focusedField, equals: .landmarkTime(index, false))
                        }
                        TextField("Mixing reason", text: landmarkBinding(index, \.reason)).focused(
                            $focusedField, equals: .reason(index))
                        Toggle(
                            "Region",
                            isOn: Binding(
                                get: { draft?.landmarks[index].end != nil },
                                set: { enabled in
                                    draft?.landmarks[index].end =
                                        enabled
                                        ? min(fileEnd, (draft?.landmarks[index].frame ?? 0) + 8 * sampleRate)
                                        : nil
                                    draft?.landmarks[index].locked = true
                                }))
                        if value.landmarks[index].end != nil {
                            HStack {
                                Text("Finish by (seconds)")
                                TextField("Region end", value: landmarkTime(index, end: true), format: .number)
                                    .frame(width: 100).focused(
                                        $focusedField, equals: .landmarkTime(index, true))
                            }
                        }
                        HStack {
                            Button("Accept") {
                                draft?.landmarks[index].state = .accepted
                                draft?.landmarks[index].locked = true
                            }
                            Button("Dismiss") {
                                draft?.landmarks[index].state = .dismissed
                                draft?.landmarks[index].locked = true
                            }
                            Button("Promote to hot cue") {
                                if validLoad, let mark = draft?.landmarks[index] {
                                    model.promoteLandmark(mark, deck: deck)
                                }
                            }
                        }
                        Text(value.landmarks[index].reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !usesColumns { Button("Add landmark at preview position", action: addLandmark) }
            }
        }
    }

    private var placementControls: some View {
        HStack(spacing: 12) {
            Text("Cursor \(position / sampleRate, format: .number.precision(.fractionLength(2))) s").monospacedDigit()
            Spacer(minLength: 0)
            Button("Split Section", action: splitSection)
                .disabled(draft?.sections.contains { $0.start < position && position < $0.end } != true)
            Button("Add Landmark", action: addLandmark)
        }.buttonStyle(.bordered).padding(.horizontal, 12).frame(minHeight: 44)
    }

    private var statusText: some View {
        Text(model.status).font(.caption).foregroundStyle(.secondary)
    }
    private var sampleRate: Double { model.track(deck)?.analysis.sampleRate ?? 44100 }
    private var fileEnd: Double { Double(model.track(deck)?.analysis.frameCount ?? 0) }
    private var position: Double {
        min(fileEnd, max(0, editCursor ?? model.viewport[deck] ?? model.playbackSnapshot?[deck].sourceFrame ?? 0))
    }
    private func sectionBinding<T>(_ index: Int, _ key: WritableKeyPath<ArrangementSection, T>) -> Binding<T> {
        Binding(
            get: { draft!.sections[index][keyPath: key] },
            set: {
                draft?.sections[index][keyPath: key] = $0
                draft?.sections[index].locked = true
            })
    }
    private func landmarkBinding<T>(_ index: Int, _ key: WritableKeyPath<ArrangementLandmark, T>) -> Binding<T> {
        Binding(
            get: { draft!.landmarks[index][keyPath: key] },
            set: {
                draft?.landmarks[index][keyPath: key] = $0
                draft?.landmarks[index].locked = true
            })
    }
    private func roleBinding(_ index: Int) -> Binding<ArrangementRole> {
        Binding(
            get: { draft!.sections[index].role },
            set: { role in
                guard let old = draft?.sections[index] else { return }
                if old.name.isEmpty || old.name.hasPrefix("SECTION ") || old.name == old.role.label {
                    draft?.sections[index].name = role.label
                }
                draft?.sections[index].role = role
                draft?.sections[index].labelConfidence = 1
                draft?.sections[index].locked = true
            })
    }
    private func boundaryBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { draft!.sections[index].start / sampleRate },
            set: { seconds in
                let frame = seconds * sampleRate
                guard let value = draft, frame.isFinite, frame > value.sections[index - 1].start,
                    frame < value.sections[index].end
                else { return }
                draft?.sections[index].start = frame
                draft?.sections[index - 1].end = frame
                draft?.sections[index].locked = true
                draft?.sections[index - 1].locked = true
            })
    }
    private func landmarkTime(_ index: Int, end: Bool = false) -> Binding<Double> {
        Binding(
            get: { (end ? draft!.landmarks[index].end ?? 0 : draft!.landmarks[index].frame) / sampleRate },
            set: { seconds in
                let frame = seconds * sampleRate
                guard frame.isFinite, frame >= 0, frame <= fileEnd else { return }
                if end { draft?.landmarks[index].end = frame } else { draft?.landmarks[index].frame = frame }
                draft?.landmarks[index].locked = true
            })
    }
    private func addLandmark() {
        draft?.landmarks.append(.init(frame: position, name: "New landmark", state: .accepted, locked: true))
    }

    private func splitSection() {
        guard let value = draft, let i = value.sections.firstIndex(where: { position > $0.start && position < $0.end })
        else { return }
        var next = value.sections[i]
        next.id = UUID()
        next.start = position
        next.name = "New section"
        next.locked = true
        draft?.sections[i].end = position
        draft?.sections[i].locked = true
        draft?.sections.insert(next, at: i + 1)
    }
}


@MainActor private struct ArrangementEditorWaveform: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let track: Track
    let draft: TrackArrangement
    @Binding var cursor: Double
    @State private var detailCenter: Double?

    var body: some View {
        let end = Double(track.analysis.frameCount)
        let duration = track.analysis.duration
        let seconds = min(duration, model.waveformZoomSeconds(deck: deck))
        let center = detailCenter ?? cursor
        VStack(spacing: 2) {
            waveform(center: center, seconds: seconds, overview: false) { frame in
                if detailCenter == nil { detailCenter = center }
                cursor = frame
            }.frame(height: 84)
            waveform(center: end / 2, seconds: duration, overview: true) { frame in
                detailCenter = frame
                cursor = frame
            }.frame(height: 44)
        }.padding(.horizontal, 8).padding(.top, 4)
    }

    private func waveform(
        center: Double, seconds: Double, overview: Bool, select: @escaping (Double) -> Void
    ) -> some View {
        let span = max(1, seconds * track.analysis.sampleRate)
        let left = center - span / 2
        return GeometryReader { space in
            let width = max(1, space.size.width)
            let markerX = (cursor - left) / span * width
            WaveformView(
                track: track, grid: overview ? nil : model.grid(deck), centerFrame: center,
                visibleSeconds: seconds, adaptiveMap: overview ? nil : track.adaptiveMap, sections: draft.sections
            ).equatable().overlay {
                ArrangementWaveformOverlay(
                    model: model, deck: deck, track: track, center: center, span: span, overview: overview,
                    editorDraft: draft)
            }.overlay(alignment: .leading) {
                Rectangle().fill(PerformancePalette.cyan).frame(width: 2)
                    .offset(x: max(0, min(width - 2, markerX)))
                    .allowsHitTesting(false)
            }.background(PerformancePalette.stage).clipped().contentShape(Rectangle()).gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    let fraction = min(1, max(0, value.location.x / width))
                    select(boundedFrame(left + fraction * span))
                }
            ).accessibilityLabel(overview ? "Track overview" : "Waveform detail")
                .accessibilityValue(Text("\(cursor / track.analysis.sampleRate, format: .number.precision(.fractionLength(2))) s"))
                .accessibilityAdjustableAction { direction in
                    let step = span / (overview ? 20 : 32)
                    switch direction {
                    case .increment: select(boundedFrame(min(left + span, cursor + step)))
                    case .decrement: select(boundedFrame(max(left, cursor - step)))
                    @unknown default: break
                    }
                }
        }
    }

    private func boundedFrame(_ frame: Double) -> Double {
        min(max(0, Double(track.analysis.frameCount) - 1), max(0, frame))
    }
}
