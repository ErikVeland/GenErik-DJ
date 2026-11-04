import SwiftUI
import TDJCore

extension Color {
    init(arrangementHex: UInt32) {
        self.init(red:Double((arrangementHex >> 16)&255)/255,green:Double((arrangementHex >> 8)&255)/255,blue:Double(arrangementHex&255)/255)
    }
}

@MainActor
struct DeckSectionHeader: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        Canvas { context, size in
            guard let track = model.track(deck), let arrangement = model.arrangements[track.id] else { return }
            let frames = max(1, Double(track.analysis.frameCount))
            for section in arrangement.sections {
                let x = max(0, section.start / frames * size.width)
                let end = min(size.width, section.end / frames * size.width)
                let colour = Color(arrangementHex: section.colourHex)
                context.fill(Path(CGRect(x: x, y: 0, width: max(0, end - x), height: size.height)), with: .color(colour.opacity(0.2)))
                context.fill(Path(CGRect(x: x, y: 0, width: max(0, end - x), height: 3)), with: .color(colour))
            }
            let frame = model.playbackSnapshot?[deck].sourceFrame ?? 0
            let x = frame / frames * size.width
            context.fill(Path(CGRect(x: x, y: 0, width: 2, height: size.height)), with: .color(PerformancePalette.red))
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

@MainActor
struct ArrangementDeckStrip: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var compact = false
    var rowHeight: Double = 44
    var showsEditorButton = true
    var openEditor: () -> Void = {}
    var body: some View {
        let status=model.arrangementStatus(deck:deck)
        HStack(spacing:8) {
            Text(status?.currentSection ?? "STRUCTURE PREPARING")
                .foregroundStyle(currentColour).lineLimit(1)
            if let id=model.track(deck)?.id, model.structureAnalyzing.contains(id) {
                Text("ANALYSING STRUCTURE").lineLimit(1).foregroundStyle(.secondary)
            } else if let status, !status.nextEvent.isEmpty { Text(status.nextEvent).lineLimit(1).foregroundStyle(.secondary) }
            Spacer(minLength:0)
            if compact, let status {
                Text(status.endingText).lineLimit(1)
                    .foregroundStyle(status.warning == .red || status.warning == .urgent ? Color.red:Color.secondary)
            }
            if showsEditorButton {
            Button(action: openEditor) { Image(systemName:"diamond").frame(width:44,height:44) }
                .accessibilityLabel("Edit sections and analysis landmarks")
                .disabled(model.track(deck).flatMap { model.arrangements[$0.id] } == nil)
            }
        }
        .font(.system(size:11,weight:.semibold,design:.monospaced))
        .padding(.horizontal,8).frame(height:rowHeight).background(PerformancePalette.sunken)
        .task(id:preparationKey) { await model.prepareArrangement(deck:deck) }
    }
    private var preparationKey: String {
        guard let track=model.track(deck) else { return "" }
        return track.id + (model.preparingPlayback.contains(deck) ? "-loading":track.analysis.waveform.isEmpty ? "-waiting":"-ready")
    }
    private var currentColour: Color {
        guard let track=model.track(deck), let section=model.arrangements[track.id]?.section(at:model.playbackSnapshot?[deck].sourceFrame ?? 0) else { return .secondary }
        return Color(arrangementHex:section.colourHex)
    }
}

@MainActor
struct ArrangementWaveformOverlay: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let track: Track
    let center: Double
    let span: Double
    var overview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Canvas { context,size in
            guard let arrangement=model.arrangements[track.id] else { return }
            let left=center-span/2
            func x(_ frame: Double) -> Double { (frame-left)/max(1,span)*size.width }
            for section in arrangement.sections where section.end > left && section.start < left+span {
                let start=max(0,x(section.start)), end=min(size.width,x(section.end))
                let colour=Color(arrangementHex:section.colourHex)
                context.fill(Path(CGRect(x:start,y:0,width:max(0,end-start),height:overview ? size.height:16)),with:.color(colour.opacity(overview ? 0.28:0.2)))
                context.fill(Path(CGRect(x:start,y:0,width:max(0,end-start),height:3)),with:.color(colour))
                let currentSection = arrangement.section(at: model.playbackSnapshot?[deck].sourceFrame ?? 0)
                if !overview, section.id != currentSection?.id, end-start > 60 {
                    context.draw(Text(section.label).font(.system(size:overview ? 8:10,weight:.bold)).foregroundColor(colour),
                        at:CGPoint(x:start+4,y:overview ? 5:4),anchor:.topLeading)
                }
                if start > 0 {
                    var line=Path(); line.move(to:.init(x:start,y:0)); line.addLine(to:.init(x:start,y:size.height))
                    context.stroke(line,with:.color(colour.opacity(0.5)),lineWidth:1)
                }
            }
            var lastX = -100.0
            for landmark in arrangement.landmarks.sorted(by: { $0.frame < $1.frame }) where landmark.state != .dismissed {
                let px=x(landmark.frame)
                guard px >= 5, px < size.width-5, px-lastX > (overview ? 38:70) else { continue }
                lastX=px
                if let finish=landmark.end {
                    context.fill(Path(CGRect(x:px,y:size.height-9,width:max(1,min(size.width,x(finish))-px),height:8)),with:.color(Color.white.opacity(0.18)))
                }
                var diamond=Path(); diamond.move(to:.init(x:px,y:size.height-10))
                diamond.addLine(to:.init(x:px+4,y:size.height-6)); diamond.addLine(to:.init(x:px,y:size.height-2))
                diamond.addLine(to:.init(x:px-4,y:size.height-6)); diamond.closeSubpath()
                context.stroke(diamond,with:.color(.white.opacity(0.85)),lineWidth:1)
            }
            if let status=model.arrangementStatus(deck:deck), status.warning == .red || status.warning == .urgent {
                let pulse=status.pulseValue(reduceMotion:reduceMotion,audible:model.arrangementAudible(deck:deck))
                let opacity=(status.warning == .urgent ? 0.20:0.12)+pulse*0.08
                context.fill(Path(CGRect(x:0,y:size.height-4,width:size.width,height:4)),with:.color(Color.red.opacity(opacity)))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

@MainActor
struct ArrangementRemainingTime: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @AppStorage("arrangement.prepareBars") private var prepareBars = 32
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if let status=model.arrangementStatus(deck:deck,prepareBars:prepareBars) {
            HStack(spacing:12) {
                Text(status.endingText).fontWeight(.semibold)
                Text("Music \(clock(status.musicSeconds)) · File \(clock(status.fileSeconds))").foregroundStyle(.secondary)
            }
            .font(.system(size:10,design:.monospaced)).lineLimit(1)
            .foregroundStyle(colour(status.warning))
            .padding(.horizontal,5).padding(.vertical,3)
            .background(colour(status.warning).opacity(status.warning == .none ? 0:0.08+status.pulseValue(reduceMotion:reduceMotion,audible:model.arrangementAudible(deck:deck))*0.06))
            .accessibilityElement(children:.combine)
        }
    }
    private func colour(_ warning: ArrangementWarning) -> Color {
        switch warning {
        case .red,.urgent,.ended: .red
        case .amber: .orange
        default: .secondary
        }
    }
    private func clock(_ seconds: Double) -> String {
        let value=Int(ceil(seconds)); return String(format:"%d:%02d",value/60,value%60)
    }
}

@MainActor
struct ArrangementEditor: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let identity: SectionEditIdentity
    let isPresented: Bool
    var close: () -> Void
    @FocusState private var focusedField: EditorField?
    private enum EditorField: Hashable {
        case sectionName(Int), boundary(Int), landmarkName(Int), landmarkTime(Int, Bool), reason(Int)
    }
    private var validLoad: Bool { identity.matches(trackID: model.track(deck)?.id, loadID: model.loadIdentity(deck)) }
    @State private var draft: TrackArrangement?
    @AppStorage("arrangement.prepareBars") private var prepareBars = 32
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: close).frame(minWidth:44,minHeight:44)
                Spacer(minLength: 8)
                Text("Deck \(deck.rawValue.uppercased()) sections").font(.headline).lineLimit(1)
                Spacer(minLength: 8)
                Button("Save") {
                    guard validLoad, let draft else { close(); return }
                    if model.updateArrangement(draft,deck:deck) { close() }
                }.frame(minWidth:44,minHeight:44).disabled(!validLoad || draft == nil)
            }.padding(.horizontal,12).background(PerformancePalette.frame)
            Form {
                Picker("Ending preparation cue",selection:$prepareBars) {
                    ForEach([32,48,64,96],id:\.self) { Text("\($0) bars").tag($0) }
                }
                Text("Hollow diamonds are analysis landmarks. Edit them here. Waveform gestures keep their existing actions.")
                    .font(.caption).foregroundStyle(.secondary)
                if let value=draft {
                    Section("Sections") {
                        ForEach(value.sections.indices,id:\.self) { index in
                            DisclosureGroup(value.sections[index].label) {
                                Text(value.sections[index].locked ? "Assignment: Manual" : "Assignment: Automatic")
                                    .font(.caption).foregroundStyle(.secondary)
                                TextField("Name",text:sectionBinding(index,\.name)).focused($focusedField,equals:.sectionName(index))
                                Picker("Musical role",selection:roleBinding(index)) {
                                    ForEach(ArrangementRole.allCases,id:\.self) { Text($0.label).tag($0) }
                                }
                                Picker("Arrangement behaviour",selection:sectionBinding(index,\.behaviour)) {
                                    ForEach(ArrangementBehaviour.allCases,id:\.self) { Text($0 == .sustaining ? "SUSTAINING":$0.label).tag($0) }
                                }
                                if index > 0 {
                                    HStack { Text("Start (seconds)"); TextField("Start",value:boundaryBinding(index),format:.number).frame(width:100).focused($focusedField,equals:.boundary(index)) }
                                }
                                Text("Edits lock this section against reanalysis.").font(.caption).foregroundStyle(.secondary)
                            }.foregroundStyle(Color(arrangementHex:value.sections[index].colourHex))
                        }
                        Button("Split section at preview position") { splitSection() }
                    }
                    Section("Analysis landmarks") {
                        ForEach(value.landmarks.indices,id:\.self) { index in
                            DisclosureGroup("◇ " + value.landmarks[index].name + (value.landmarks[index].state == .dismissed ? " · DISMISSED":"")) {
                                TextField("Name",text:landmarkBinding(index,\.name)).focused($focusedField,equals:.landmarkName(index))
                                Picker("Kind",selection:landmarkBinding(index,\.kind)) {
                                    ForEach(ArrangementLandmarkKind.allCases,id:\.self) { Text($0.label).tag($0) }
                                }
                                HStack { Text("Position (seconds)"); TextField("Position",value:landmarkTime(index),format:.number).frame(width:100).focused($focusedField,equals:.landmarkTime(index,false)) }
                                TextField("Mixing reason",text:landmarkBinding(index,\.reason)).focused($focusedField,equals:.reason(index))
                                Toggle("Region",isOn:Binding(get: { draft?.landmarks[index].end != nil },set: { enabled in
                                    draft?.landmarks[index].end=enabled ? min(fileEnd,(draft?.landmarks[index].frame ?? 0)+8*sampleRate):nil
                                    draft?.landmarks[index].locked=true
                                }))
                                if value.landmarks[index].end != nil {
                                    HStack { Text("Finish by (seconds)"); TextField("Region end",value:landmarkTime(index,end:true),format:.number).frame(width:100).focused($focusedField,equals:.landmarkTime(index,true)) }
                                }
                                HStack {
                                    Button("Accept") { draft?.landmarks[index].state = .accepted; draft?.landmarks[index].locked=true }
                                    Button("Dismiss") { draft?.landmarks[index].state = .dismissed; draft?.landmarks[index].locked=true }
                                    Button("Promote to hot cue") { if validLoad, let mark=draft?.landmarks[index] { model.promoteLandmark(mark,deck:deck) } }
                                }
                                Text(value.landmarks[index].reason).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button("Add landmark at preview position") {
                            draft?.landmarks.append(.init(frame:position,name:"New landmark",state:.accepted,locked:true))
                        }
                    }
                }
                Text(model.status).font(.caption).foregroundStyle(.secondary)
            }
            .formStyle(.grouped).disabled(!validLoad)
        }
        .onAppear { if draft == nil, validLoad { draft = model.arrangements[identity.trackID] } }
        .onChange(of: isPresented) { _, visible in if !visible { focusedField = nil } }
        .onChange(of: model.loaded[deck]) { _, _ in if !validLoad { close() } }
        .onChange(of: model.loadIdentity(deck)) { _, _ in if !validLoad { close() } }
    }
    private var sampleRate: Double { model.track(deck)?.analysis.sampleRate ?? 44100 }
    private var fileEnd: Double { Double(model.track(deck)?.analysis.frameCount ?? 0) }
    private var position: Double { min(fileEnd,max(0,model.viewport[deck] ?? model.playbackSnapshot?[deck].sourceFrame ?? 0)) }
    private func sectionBinding<T>(_ index: Int,_ key: WritableKeyPath<ArrangementSection,T>) -> Binding<T> {
        Binding(get: { draft!.sections[index][keyPath:key] },set: { draft?.sections[index][keyPath:key]=$0; draft?.sections[index].locked=true })
    }
    private func landmarkBinding<T>(_ index: Int,_ key: WritableKeyPath<ArrangementLandmark,T>) -> Binding<T> {
        Binding(get: { draft!.landmarks[index][keyPath:key] },set: { draft?.landmarks[index][keyPath:key]=$0; draft?.landmarks[index].locked=true })
    }
    private func roleBinding(_ index: Int) -> Binding<ArrangementRole> {
        Binding(get: { draft!.sections[index].role },set: { role in
            guard let old=draft?.sections[index] else { return }
            if old.name.isEmpty || old.name.hasPrefix("SECTION ") || old.name == old.role.label {
                draft?.sections[index].name=role.label
            }
            draft?.sections[index].role=role; draft?.sections[index].labelConfidence=1
            draft?.sections[index].locked=true
        })
    }
    private func boundaryBinding(_ index: Int) -> Binding<Double> {
        Binding(get: { draft!.sections[index].start/sampleRate },set: { seconds in
            let frame=seconds*sampleRate
            guard let value=draft, frame.isFinite, frame > value.sections[index-1].start, frame < value.sections[index].end else { return }
            draft?.sections[index].start=frame; draft?.sections[index-1].end=frame
            draft?.sections[index].locked=true; draft?.sections[index-1].locked=true
        })
    }
    private func landmarkTime(_ index: Int,end: Bool = false) -> Binding<Double> {
        Binding(get: { (end ? draft!.landmarks[index].end ?? 0 : draft!.landmarks[index].frame)/sampleRate },set: { seconds in
            let frame=seconds*sampleRate
            guard frame.isFinite, frame >= 0, frame <= fileEnd else { return }
            if end { draft?.landmarks[index].end=frame } else { draft?.landmarks[index].frame=frame }
            draft?.landmarks[index].locked=true
        })
    }
    private func splitSection() {
        guard let value=draft, let i=value.sections.firstIndex(where: { position > $0.start && position < $0.end }) else { return }
        var next=value.sections[i]; next.id=UUID(); next.start=position; next.name="New section"; next.locked=true
        draft?.sections[i].end=position; draft?.sections[i].locked=true; draft?.sections.insert(next,at:i+1)
    }
}
