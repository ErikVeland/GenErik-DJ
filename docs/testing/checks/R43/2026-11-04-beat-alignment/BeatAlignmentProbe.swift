import Foundation
let rate=44100.0, bin=220
let binsPerSecond=rate/Double(bin)
for pattern in ["distinctive snare on beat 2", "distinctive bass on beat 1", "equal beats"] {
    let count=Int(34*binsPerSecond)
    var rms=[Double](repeating:0,count:count), bass=rms, mid=rms, high=rms
    for beat in 0..<64 {
        let index=Int(((0.25+Double(beat)*0.5)*binsPerSecond).rounded())
        for offset in 0..<12 {
            let decay=exp(-Double(offset)*0.45)
            let b=(pattern == "distinctive bass on beat 1" && beat%4 == 0 ? 2.0:0.7)*decay
            let m=(pattern == "distinctive snare on beat 2" && beat%4 == 1 ? 2.0:0.05)*decay
            bass[index+offset]=b; mid[index+offset]=m; high[index+offset]=0.02*decay
            rms[index+offset]=sqrt(b*b+m*m+0.0004*decay*decay)
        }
    }
    let frames=(0..<count).map { i in MusicalPulseFrame(rms:rms[i],bass:bass[i],middle:mid[i],high:high[i],attackFrame:Double(i*bin),rise:i > 0 ? max(0,rms[i]-rms[i-1]):rms[i]) }
    let result=try MusicalRhythmAnalyzer.analyze(frames:frames,sampleRate:rate,framesPerBin:bin,spectralActivity:0.3,configuration:.init(),checkCancellation:{})
    print(pattern, "bpm",result.bpm as Any,"anchor",result.anchorSeconds as Any,"bar offset",result.downbeat as Any,"bar confidence",result.downbeatConfidence as Any)
}
