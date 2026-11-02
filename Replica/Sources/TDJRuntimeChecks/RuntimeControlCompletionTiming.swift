import Foundation

/// Uses retained clock instants. The scheduled deadline stays unchanged through the entire batch.
struct RuntimeControlCompletionTiming: Codable, Sendable {
    struct Sample: Codable, Equatable, Sendable {
        let batch:Int
        let totalMilliseconds:Double
        let beforeWorkMilliseconds:Double
        let workMilliseconds:Double
    }
    struct MissExample: Codable, Equatable, Sendable {
        let sample:Sample
        // Elapsed times share the control loop's retained start instant.
        let dueElapsedMilliseconds:Double?
        let workBeganElapsedMilliseconds:Double?
        let workEndedElapsedMilliseconds:Double?
        let threadCPUWorkMilliseconds:Double?
        let nativeTimerEventLatenessMilliseconds:Double?
        let nativeTimerEventToControlMilliseconds:Double?
        let unavailableFields:[String]

        init(sample:Sample,dueElapsedMilliseconds:Double?,threadCPUWorkMilliseconds:Double?,
             nativeTimerEventLatenessMilliseconds:Double?,nativeTimerEventToControlMilliseconds:Double?) {
            self.sample=sample
            self.dueElapsedMilliseconds=dueElapsedMilliseconds
            workBeganElapsedMilliseconds=dueElapsedMilliseconds.map { $0+sample.beforeWorkMilliseconds }
            workEndedElapsedMilliseconds=dueElapsedMilliseconds.map { $0+sample.totalMilliseconds }
            self.threadCPUWorkMilliseconds=threadCPUWorkMilliseconds
            self.nativeTimerEventLatenessMilliseconds=nativeTimerEventLatenessMilliseconds
            self.nativeTimerEventToControlMilliseconds=nativeTimerEventToControlMilliseconds
            var unavailable:[String]=[]
            if dueElapsedMilliseconds == nil { unavailable.append("controlLoopElapsedTimeline") }
            if threadCPUWorkMilliseconds == nil { unavailable.append("threadCPUWorkMilliseconds") }
            if nativeTimerEventLatenessMilliseconds == nil { unavailable.append("nativeTimerEventLatenessMilliseconds") }
            if nativeTimerEventToControlMilliseconds == nil { unavailable.append("nativeTimerEventToControlMilliseconds") }
            unavailableFields=unavailable
        }
    }
    private(set) var missExamples:[MissExample]=[]
    private(set) var samples=0
    private(set) var deadlineMisses=0
    private(set) var invalidTimelines=0
    private(set) var maximumMilliseconds=0.0
    private(set) var worstSample:Sample?
    var qualified:Bool { samples>0 && deadlineMisses==0 && invalidTimelines==0 }

    init() { missExamples.reserveCapacity(32) }

    private enum CodingKeys:String,CodingKey {
        case samples,deadlineMisses,invalidTimelines,maximumMilliseconds,worstSample,missExamples
    }
    init(from decoder:Decoder) throws {
        let values=try decoder.container(keyedBy:CodingKeys.self)
        samples=try values.decode(Int.self,forKey:.samples)
        deadlineMisses=try values.decode(Int.self,forKey:.deadlineMisses)
        invalidTimelines=try values.decode(Int.self,forKey:.invalidTimelines)
        maximumMilliseconds=try values.decode(Double.self,forKey:.maximumMilliseconds)
        worstSample=try values.decodeIfPresent(Sample.self,forKey:.worstSample)
        missExamples=Array((try values.decodeIfPresent([MissExample].self,forKey:.missExamples) ?? []).prefix(32))
    }

    mutating func observe(batch:Int,due:ContinuousClock.Instant,workBegan:ContinuousClock.Instant,
                          workEnded:ContinuousClock.Instant,dueElapsedMilliseconds:Double?=nil,
                          threadCPUWorkMilliseconds:Double?=nil,
                          nativeTimerEventLatenessMilliseconds:Double?=nil,
                          nativeTimerEventToControlMilliseconds:Double?=nil) {
        samples+=1
        guard workBegan<=workEnded else { invalidTimelines+=1;return }
        let total=milliseconds(due.duration(to:workEnded))
        let sample=Sample(batch:batch,totalMilliseconds:total,
            beforeWorkMilliseconds:milliseconds(due.duration(to:workBegan)),
            workMilliseconds:milliseconds(workBegan.duration(to:workEnded)))
        if let worst=worstSample {
            if total>worst.totalMilliseconds { worstSample=sample }
        } else { worstSample=sample }
        maximumMilliseconds=max(maximumMilliseconds,total)
        if total>20 {
            deadlineMisses+=1
            if missExamples.count<32 {
                missExamples.append(.init(sample:sample,dueElapsedMilliseconds:dueElapsedMilliseconds,
                    threadCPUWorkMilliseconds:threadCPUWorkMilliseconds,
                    nativeTimerEventLatenessMilliseconds:nativeTimerEventLatenessMilliseconds,
                    nativeTimerEventToControlMilliseconds:nativeTimerEventToControlMilliseconds))
            }
        }
    }
    private func milliseconds(_ value:Duration) -> Double {
        let parts=value.components
        return Double(parts.seconds)*1000+Double(parts.attoseconds)/1e15
    }
}
