import AVFoundation
import Foundation

let input=URL(fileURLWithPath:CommandLine.arguments[1])
let reference=URL(fileURLWithPath:CommandLine.arguments[2])
let context=try JSONDecoder().decode(MusicalStructureContext.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[3])))
let model=URL(fileURLWithPath:CommandLine.arguments[4])
let output=URL(fileURLWithPath:CommandLine.arguments[5])
let values=try JSONSerialization.jsonObject(with:Data(contentsOf:reference)) as! [String:Any]
var analysisValues=(values["analysis"] as? [String:Any]) ?? values
for name in ["waveform","chroma","timbre"] where analysisValues[name] == nil { analysisValues[name]=[] }
let analysisData=try JSONSerialization.data(withJSONObject:analysisValues)
let analysis=try JSONDecoder().decode(AudioAnalysis.self,from:analysisData)
func savedFeatures() -> [MusicalStructureFrame] {
    (values["frames"] as! [[String:Any]]).map { f in
        MusicalStructureFrame(start:f["start"] as! Double,end:f["end"] as! Double,rms:f["rms"] as! Double,
            bass:f["bass"] as! Double,rhythm:f["rhythm"] as! Double,bands:f["bands"] as! [Double],chroma:f["chroma"] as! [Double],
            vocal:f["vocal"] as? Double,rapping:f["rapping"] as? Double,singing:f["singing"] as? Double)
    }
}
if CommandLine.arguments.contains("--plan") {
    let plan=VocalRecognitionWindow.plan(features:savedFeatures(),sampleRate:analysis.sampleRate,frameCount:analysis.frameCount)
    try JSONEncoder().encode(plan).write(to:output)
    exit(0)
}
if CommandLine.arguments.contains("--replay") {
    let features=savedFeatures()
    let phrases=try JSONDecoder().decode([VocalPhrase].self,from:JSONSerialization.data(withJSONObject:values["phrases"]!))
    let arrangement=TrackArrangement.prepare(analysis:analysis,features:features,context:context,vocalPhrases:phrases)
    var replay=values
    replay["arrangement"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(arrangement))
    replay["valid"]=arrangement.isValid(fileEnd:Double(analysis.frameCount))
    replay["structureVersion"]=MusicalStructureAnalyzer.version
    try JSONSerialization.data(withJSONObject:replay,options:[.sortedKeys]).write(to:output,options:.atomic)
    exit(0)
}
let pcm=output.deletingPathExtension().appendingPathExtension("pcm")
if input.pathExtension == "pcm" {
    try FileManager.default.copyItem(at:input,to:pcm)
} else {
    let audio=try AVAudioFile(forReading:input,commonFormat:.pcmFormatFloat32,interleaved:false)
    guard audio.processingFormat.sampleRate == analysis.sampleRate, audio.length == analysis.frameCount,
          let buffer=AVAudioPCMBuffer(pcmFormat:audio.processingFormat,frameCapacity:8192) else {
        throw CoreError.invalidAudio("The source and analysis timelines differ.")
    }
    FileManager.default.createFile(atPath:pcm.path,contents:nil)
    let handle=try FileHandle(forWritingTo:pcm)
    var decoded: Int64=0
    while decoded < audio.length {
        try audio.read(into:buffer,frameCount:AVAudioFrameCount(min(8192,audio.length-decoded)))
        guard buffer.frameLength > 0, let channels=buffer.floatChannelData else { break }
        var stereo=[Float](repeating:0,count:Int(buffer.frameLength)*2)
        for frame in 0..<Int(buffer.frameLength) {
            stereo[frame*2]=channels[0][frame]
            stereo[frame*2+1]=channels[Int(audio.processingFormat.channelCount) > 1 ? 1:0][frame]
        }
        try stereo.withUnsafeBytes { try handle.write(contentsOf:$0) }
        decoded += Int64(buffer.frameLength)
    }
    try handle.close()
    guard decoded == analysis.frameCount else { throw CoreError.invalidAudio("The decoded source is incomplete.") }
}
defer { try? FileManager.default.removeItem(at:pcm) }
if CommandLine.arguments.contains("--resample") {
    let samples=try VocalPhraseRecognizer.monoSamples(pcm:pcm,analysis:analysis,cancellation:.init())
    try samples.withUnsafeBytes { try Data($0).write(to:output) }
    print("\(samples.count) mono samples")
    exit(0)
}
let started=Date()
let reuse=CommandLine.arguments.contains("--refine")
let features=try reuse ? savedFeatures():MusicalStructureAnalyzer.analyze(pcm:pcm,analysis:analysis)
let cancellation=VocalInferenceCancellation()
if CommandLine.arguments.contains("--cancel") {
    DispatchQueue.global().asyncAfter(deadline:.now()+1) { cancellation.cancel() }
}
let prepared: VocalPhrasePreparation
do {
    let initial=try reuse
        ? JSONDecoder().decode([VocalPhrase].self,from:JSONSerialization.data(withJSONObject:values["phrases"]!))
        : VocalPhraseRecognizer.phrases(pcm:pcm,analysis:analysis,model:model,cancellation:cancellation)
    prepared=try VocalPhraseRecognizer.refine(pcm:pcm,analysis:analysis,features:features,context:context,
        initial:initial,model:model,cancellation:cancellation)
} catch is CancellationError {
    print("Cancelled offline inference after \(Date().timeIntervalSince(started)) seconds, including feature extraction")
    exit(0)
}
let phrases=prepared.phrases, arrangement=prepared.arrangement
let frames: [[String:Any]]=features.map { f in
    var value: [String:Any]=["start":f.start,"end":f.end,"rms":f.rms,"bass":f.bass,"rhythm":f.rhythm,"bands":f.bands,"chroma":f.chroma]
    value["vocal"]=f.vocal; value["rapping"]=f.rapping; value["singing"]=f.singing
    return value
}
let result: [String:Any]=["structureVersion":MusicalStructureAnalyzer.version,"analysis":try JSONSerialization.jsonObject(with:JSONEncoder().encode(analysis)),
    "arrangement":try JSONSerialization.jsonObject(with:JSONEncoder().encode(arrangement)),
    "phrases":try JSONSerialization.jsonObject(with:JSONEncoder().encode(phrases)),"frames":frames,
    "elapsedSeconds":Date().timeIntervalSince(started),"valid":arrangement.isValid(fileEnd:Double(analysis.frameCount)),
    "initialPassReused":reuse,"usedFocusedResult":prepared.usedFocusedResult,
    "attemptedWindows":try JSONSerialization.jsonObject(with:JSONEncoder().encode(prepared.attemptedWindows))]
try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]).write(to:output,options:.atomic)
for section in arrangement.sections {
    print(String(format:"%6.2f–%6.2f %@",section.start/analysis.sampleRate,section.end/analysis.sampleRate,section.label))
}
