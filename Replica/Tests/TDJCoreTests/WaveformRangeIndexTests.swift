import Testing
@testable import TDJCore

@Test func waveformRangeIndexPreservesEveryPeakAtAllZoomRanges() {
    for count in [0,1,2,3,31,128,257] {
        let bins=(0..<count).map { i in
            WaveformBin(minimum:-Float((i*17)%97)/97,maximum:Float((i*13)%89)/89,rms:0)
        }
        let index=WaveformRangeIndex(bins)
        // Minimum, maximum and RMS per node.
        #expect(index.storageBytes == count*2*12)
        for low in stride(from:-2,through:count+2,by:3) {
            for high in stride(from:low,through:count+2,by:7) {
                let values=bins[max(0,min(count,low))..<max(0,min(count,high))]
                let actual=index.extent(from:low,to:high)
                #expect(actual.minimum == values.reduce(Float(0)) { min($0,$1.minimum) })
                #expect(actual.maximum == values.reduce(Float(0)) { max($0,$1.maximum) })
            }
        }
    }
}
