import AVFoundation
import Foundation

let input=URL(fileURLWithPath:CommandLine.arguments[1])
let output=URL(fileURLWithPath:CommandLine.arguments[2])
let pcm=URL(fileURLWithPath:CommandLine.arguments[3])
let context=try CommandLine.arguments.count > 4
    ? JSONDecoder().decode(MusicalStructureContext.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[4])))
    : MusicalStructureContext()
func phase(_ message: String) { FileHandle.standardError.write(Data((message+"\n").utf8)) }
phase("Production musical analysis")
let analysis=try AudioAnalyzer.analyze(url:input)
phase("Review stereo cache")
let audio=try AVAudioFile(forReading:input,commonFormat:.pcmFormatFloat32,interleaved:false)
guard let buffer=AVAudioPCMBuffer(pcmFormat:audio.processingFormat,frameCapacity:8192) else {
    throw CoreError.invalidAudio("Cannot allocate the review audio buffer.")
}
FileManager.default.createFile(atPath:pcm.path,contents:nil)
let handle=try FileHandle(forWritingTo:pcm)
defer { try? handle.close(); try? FileManager.default.removeItem(at:pcm) }
var decoded: Int64=0
while decoded < audio.length {
    try audio.read(into:buffer,frameCount:AVAudioFrameCount(min(Int64(buffer.frameCapacity),audio.length-decoded)))
    let count=Int(buffer.frameLength)
    guard count > 0 else { break }
    guard let channels=buffer.floatChannelData else { throw CoreError.invalidAudio("Cannot read the review audio samples.") }
    var stereo=[Float](repeating:0,count:count*2)
    for frame in 0..<count {
        stereo[frame*2]=channels[0][frame]
        stereo[frame*2+1]=channels[Int(audio.processingFormat.channelCount) > 1 ? 1:0][frame]
    }
    try stereo.withUnsafeBytes { try handle.write(contentsOf:$0) }
    decoded += Int64(count)
}
try handle.synchronize()
guard decoded == analysis.frameCount, audio.processingFormat.sampleRate == analysis.sampleRate else {
    throw CoreError.invalidAudio("The review audio timelines do not match.")
}
phase("Production structure analysis")
let features=try MusicalStructureAnalyzer.analyze(pcm:pcm,analysis:analysis)
let arrangement=TrackArrangement.prepare(analysis:analysis,features:features,context:context)
var values=try JSONSerialization.jsonObject(with:JSONEncoder().encode(analysis.replacingWaveform([]))) as! [String:Any]
for key in ["waveform","chroma","timbre","adaptiveCandidate"] { values.removeValue(forKey:key) }
let result: [String:Any]=["analysis":values,"arrangement":try JSONSerialization.jsonObject(with:JSONEncoder().encode(arrangement)),
    "structureVersion":MusicalStructureAnalyzer.version,"vocalFormPass":"not-run-by-acoustic-probe",
    "vocalSeconds":features.filter { ($0.vocal ?? 0) >= 0.45 }.count]
try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]).write(to:output,options:.atomic)
