import Foundation

@main struct CheckWaveformMotion {
    static func main() {
        var checks = 0
        func expect(_ condition: Bool, _ label: String) {
            checks += 1
            precondition(condition,label)
        }
        for span in [44100.0,192000,960000] {
            for grab in [0.1,0.5,0.9] {
                var drag = WaveformDragMotion(frame:2000000,x:grab,time:0,span:span,limit:4000000)
                expect(drag.frame == 2000000,"grab anywhere without a jump")
                drag.move(x:grab+0.125,time:0.1)
                expect(abs(drag.frame-(2000000-span*0.125))<0.00001,"waveform follows rightward finger 1:1")
                expect(drag.velocity<0,"rightward drag plays backward")
                drag.move(x:grab-0.125,time:0.2)
                expect(abs(drag.frame-(2000000+span*0.125))<0.00001,"leftward reversal follows finger 1:1")
                expect(drag.velocity>0,"leftward drag plays forward")
                let coast = drag.coast(at:0.21)!
                let first = coast.sample(at:0.21)
                expect(first.frame==drag.frame,"release has no position jump")
                let later = coast.sample(at:0.31)
                expect(later.frame>first.frame && later.velocity<first.velocity,"throw continues and slows")
                let settled = coast.sample(at:6)
                expect(settled.finished && settled.velocity==0,"coast comes to rest")
                expect(drag.coast(at:0.4)==nil,"holding before release prevents a stale throw")
                drag.move(x:grab-0.125,time:0.3)
                expect(drag.coast(at:0.31)==nil,"stationary touch stops motion")
            }
        }
        var edge = WaveformDragMotion(frame:5,x:0.5,time:0,span:100,limit:100)
        edge.move(x:0.7,time:0.1)
        expect(edge.frame==0,"start bound clamps")
        edge.move(x:0.6,time:0.2)
        expect(abs(edge.frame-10)<0.00001,"reverse responds immediately at bound")
        let coast = WaveformCoast(frame:90,velocity:100,time:0,span:100,limit:100)
        expect(coast.sample(at:2).frame==100 && coast.sample(at:2).finished,"throw stops at end bound")
        print("\(checks) waveform motion assertions passed")
    }
}
