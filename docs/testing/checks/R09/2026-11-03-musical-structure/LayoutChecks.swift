import Foundation
@main struct Checks {
    static func main() {
        for available in [300.0,619,800,1024] {
            for share in [-1.0,0.1,0.28,0.5,0.72,1,Double.nan] {
                let h=AdaptivePerformanceLayout.deckHeight(available:available,browserVisible:true,share:share)
                precondition(h.isFinite && h >= 0 && h <= available)
                precondition(available-h-AdaptivePerformanceLayout.dividerHeight >= 0)
            }
        }
        let duo=AdaptivePerformanceLayout.deckHeight(available:619,browserVisible:true,share:0.72)
        let waveform=AdaptiveDeckGeometry(height:(duo-2)/2-8).waveformHeight
        precondition(waveform >= 110)
        precondition(AdaptivePerformanceLayout.deckHeight(available:619,browserVisible:false,share:0.72) == 619-AdaptivePerformanceLayout.dividerHeight)
        var previous=AdaptiveDeckGeometry(height:44)
        for height in 45...700 {
            let current=AdaptiveDeckGeometry(height:Double(height))
            precondition(abs(current.headerHeight-previous.headerHeight) <= 1)
            precondition(abs(current.waveformHeight-previous.waveformHeight) <= 1.00001)
            precondition(current.headerHeight+current.sectionHeight+current.footerHeight+current.overviewHeight+current.hotcueHeight+current.waveformHeight <= Double(height)+0.001)
            previous=current
        }
        print("Continuous layout bounds passed; Duo calculated main waveform height: \(waveform) points")
    }
}
