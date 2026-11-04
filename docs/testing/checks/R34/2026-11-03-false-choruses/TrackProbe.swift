import Foundation
import CryptoKit
let args=CommandLine.arguments
let analysis=try JSONDecoder().decode(AudioAnalysis.self,from:Data(contentsOf:URL(fileURLWithPath:args[1])))
let started=Date()
let pcm=URL(fileURLWithPath:args[2])
let features=try MusicalStructureAnalyzer.analyze(pcm:pcm,analysis:analysis)
let arrangement=TrackArrangement.prepare(analysis:analysis,features:features)
let frames: [[String:Any]]=features.map { f in
    var d: [String:Any]=["start":f.start,"end":f.end,"rms":f.rms,"bass":f.bass,"rhythm":f.rhythm,"bands":f.bands,"chroma":f.chroma]
    if let vocal=f.vocal { d["vocal"]=vocal }
    return d
}
let fixture: [String:Any]=["analysis":try JSONSerialization.jsonObject(with:JSONEncoder().encode(analysis)),"frames":frames,
    "title":"99 Problems","artist":"Danger Mouse","pcmSHA256":SHA256.hash(data:try Data(contentsOf:pcm,options:.alwaysMapped)).map { String(format:"%02x",$0) }.joined()]
try JSONSerialization.data(withJSONObject:fixture,options:[.sortedKeys]).write(to:URL(fileURLWithPath:args[3]))
try JSONEncoder().encode(arrangement).write(to:URL(fileURLWithPath:args[4]))
print("Structure version \(MusicalStructureAnalyzer.version), \(features.count) feature frames, \(arrangement.sections.count) sections, \(arrangement.sections.filter { $0.role == .chorus }.count) chorus labels, \(Date().timeIntervalSince(started)) seconds")
for s in arrangement.sections { print(String(format:"%.2f–%.2f",s.start/analysis.sampleRate,s.end/analysis.sampleRate),s.label) }
