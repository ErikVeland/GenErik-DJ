import Foundation
final class CancellationFlag: @unchecked Sendable {
 private let lock=NSLock();private var cancelled=false
 func cancel() { lock.withLock { cancelled=true } }
 func check() throws { if lock.withLock({ cancelled }) { throw CancellationError() } }
}
let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
if CommandLine.arguments.contains("--cache") {
 let analysis=try JSONDecoder().decode(AudioAnalysis.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[3])))
 let flag=CancellationFlag(),started=Date()
 if CommandLine.arguments.contains("--cancel") { DispatchQueue.global().asyncAfter(deadline:.now()+0.05) { flag.cancel() } }
 let result:BeatGridDetection?
 do { result=try AudioAnalyzer.detectBeatGrid(pcm:URL(fileURLWithPath:CommandLine.arguments[1]),matching:analysis,checkCancellation:{ try flag.check() }) }
 catch is CancellationError { print("Grid detection cancelled after",Date().timeIntervalSince(started),"seconds");exit(0) }
 if CommandLine.arguments.contains("--cancel") { fatalError("The cancellation fixture completed before cancellation.") }
 try encoder.encode(result).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
 print(result as Any)
} else {
 let result=try AudioAnalyzer.analyze(url:URL(fileURLWithPath:CommandLine.arguments[1]))
 try encoder.encode(result.replacingWaveform([])).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
 print("BPM",result.bpm as Any,"anchor",result.beatAnchorFrame.map{$0/result.sampleRate} as Any,"bar",result.detectedDownbeatOffset as Any,"confidence",result.tempoConfidence)
}
