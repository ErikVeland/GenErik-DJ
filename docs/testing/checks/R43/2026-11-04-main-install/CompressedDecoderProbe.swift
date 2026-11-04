import Foundation
@main struct Probe {
 static func main() async throws {
  let url=URL(fileURLWithPath:CommandLine.arguments[1])
  let source=try await DecodedAudioSource.asset(url:url)
  let reference=try DecodedAudioSource.file(url:url)
  var checks=[[String:Any]]()
  var maximum=0.0
  for first:Int64 in [0,4096,8192,16447,44100,22050,min(source.frames,reference.frames)-16384] {
   var actual=[Float](repeating:0,count:8192*2),expected=actual
   try actual.withUnsafeMutableBufferPointer { try source.read(first:first,count:8192,into:$0.baseAddress!) }
   try expected.withUnsafeMutableBufferPointer { try reference.read(first:first,count:8192,into:$0.baseAddress!) }
   let difference=zip(actual,expected).map { abs(Double($0)-Double($1)) }.max() ?? 0
   maximum=max(maximum,difference)
   checks.append(["firstFrame":first,"frames":8192,"maximumSampleDifference":difference])
  }
  let result:[String:Any]=["assetFrames":source.frames,"fileFrames":reference.frames,"sampleRate":source.rate,"checks":checks,"maximumSampleDifference":maximum,"passed":maximum<0.00001]
  let encoder=try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
  try encoder.write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
  print(String(data:encoder,encoding:.utf8)!)
  if maximum>=0.00001 { throw PCMStreamingError.readFailed }
 }
}
