import Foundation
final class CancellationFlag: @unchecked Sendable {
 private let lock=NSLock();private var cancelled=false
 func cancel() { lock.withLock { cancelled=true } }
 func check() throws { if lock.withLock({ cancelled }) { throw CancellationError() } }
}

if CommandLine.arguments.contains("--harmony") || CommandLine.arguments.contains("--bar-frames") {
 let file=try FileHandle(forReadingFrom:URL(fileURLWithPath:CommandLine.arguments[1]));defer { try? file.close() }
 let rate=44100.0,spectrum=try MusicalSpectrumAnalyzer(sampleRate:44100)
 var previous=0.0,filtered=0.0,count=0
 var pulses=MusicalPulseAccumulator(sampleRate:rate)
 let limit=CommandLine.arguments.contains("--bar-frames") ? 22746240:Int(32*rate)
 let coefficient=exp(-2 * Double.pi * 20/rate)
 while count < limit {
  let data=try file.read(upToCount:min(32768,limit-count)*8) ?? Data()
  if data.isEmpty { break }
  data.withUnsafeBytes { raw in
   let samples=raw.bindMemory(to:Float.self)
   for i in stride(from:0,to:samples.count,by:2) {
    let x=Double(samples[i]*0.5+samples[i+1]*0.5)
    filtered=x-previous+coefficient*filtered;previous=x;spectrum.consume(filtered);pulses.consume(filtered)
   }
   count += samples.count/2
  }
 }
 if CommandLine.arguments.contains("--bar-frames") {
  pulses.finish()
  let beats=try MusicalRhythmAnalyzer.barFrames(frames:pulses.frames,binsPerSecond:rate/Double(pulses.framesPerBin),
   period:60/136.01776928783116,anchor:0.18057436481436,harmonicFrames:spectrum.harmonicFrames,checkCancellation:{})
  try JSONEncoder().encode(beats).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
  print("Full-source bar replay",try MusicalRhythmAnalyzer.barStart(beats:beats));exit(0)
 }
 let values=spectrum.harmonicFrames.map { ["seconds":$0.seconds,"chroma":$0.chroma] as [String:Any] }
 try JSONSerialization.data(withJSONObject:values).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
 print(values.count,"harmonic frames");exit(0)
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
