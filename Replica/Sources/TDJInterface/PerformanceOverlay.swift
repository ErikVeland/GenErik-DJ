import SwiftUI
import TDJCore

struct PerformanceOverlay: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let span: Double
    var body: some View {
        Canvas { context,size in
            let left=(model.viewport[deck] ?? 0)-span/2
            if let state=model.playbackSnapshot?[deck],state.loopEnabled {
                let start=(state.loopStart-left)/max(1,span)*size.width
                let end=(state.loopEnd-left)/max(1,span)*size.width
                let region=CGRect(x:start,y:0,width:max(1,end-start),height:size.height)
                context.fill(Path(region),with:.color(.green.opacity(0.13)))
                context.stroke(Path(region),with:.color(.green.opacity(0.8)),lineWidth:1)
            }
            if let track=model.track(deck),let cues=model.performance.cues[track.id] {
                for slot in cues.keys.sorted() {
                    guard let cue=cues[slot] else { continue }
                    let x=(cue.frame-left)/max(1,span)*size.width
                    guard x>=0,x<=size.width else { continue }
                    let colour: Color = cue.category == .grid ? .white : cue.category == .loop ? .green : .cyan
                    var line=Path()
                    line.move(to:.init(x:x,y:0)); line.addLine(to:.init(x:x,y:size.height))
                    context.stroke(line,with:.color(colour.opacity(0.65)),lineWidth:1)
                    let label=CGRect(x:min(max(0,x),max(0,size.width-18)),y:max(0,size.height-18),width:18,height:18)
                    context.fill(Path(label),with:.color(colour.opacity(0.8)))
                    if (0..<8).contains(slot),let symbol=context.resolveSymbol(id:slot) {
                        context.draw(symbol,at:.init(x:label.midX,y:label.midY))
                    } else {
                        context.draw(Text("\(slot+1)").font(.caption.bold()).foregroundStyle(.black),at:.init(x:label.midX,y:label.midY))
                    }
                }
            }
            if model.frozen.contains(deck) {
                if !model.editing.contains(deck) {
                    context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(.green.opacity(0.04)))
                    for row in 0..<3 {
                        if row>0 {
                            var boundary=Path()
                            let y=Double(row)*size.height/3
                            boundary.move(to:.init(x:0,y:y)); boundary.addLine(to:.init(x:size.width,y:y))
                            context.stroke(boundary,with:.color(.green.opacity(0.6)),lineWidth:1)
                        }
                        if let symbol=context.resolveSymbol(id:16+row) {
                            context.draw(symbol,
                                         at:.init(x:size.width/2,y:(Double(row)+0.5)*size.height/3))
                        }
                    }
                }
                for slice in 0..<8 {
                    let rect=CGRect(x:Double(slice)*size.width/8,y:0,width:size.width/8,height:size.height)
                    context.stroke(Path(rect),with:.color(.cyan.opacity(0.6)),lineWidth:1)
                    if let symbol=context.resolveSymbol(id:8+slice) {
                        context.draw(symbol,at:.init(x:rect.midX,y:12))
                    }
                }
            }
        } symbols: {
            ForEach(0..<8,id:\.self) { slot in
                Text("\(slot+1)").font(.caption.bold()).foregroundStyle(.black).tag(slot)
            }
            ForEach(8..<16,id:\.self) { symbolID in
                let slice=symbolID-8
                Text("\(slice+1)").font(.caption).foregroundStyle(.cyan).tag(symbolID)
            }
            ForEach(16..<19,id:\.self) { symbolID in
                let row=symbolID-16
                if let label=model.superSlicerFamily(deck:deck).label(row:row) {
                    Text(label).font(.system(size:11,weight:.semibold)).foregroundStyle(.green).tag(symbolID)
                }
            }
        }.clipped().allowsHitTesting(false)
    }
}
