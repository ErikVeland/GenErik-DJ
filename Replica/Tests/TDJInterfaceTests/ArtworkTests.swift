import Foundation
import CoreGraphics
import ImageIO
import Testing
@testable import TDJInterface

@Test func artworkIsDownsampledAndConcurrentRequestsReuseDecodedThumbnail() async throws {
    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".png")
    defer { try? FileManager.default.removeItem(at:url) }
    let context=try #require(CGContext(data:nil,width:1024,height:512,bitsPerComponent:8,bytesPerRow:4096,
        space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
    let source=try #require(context.makeImage())
    let destination=try #require(CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil))
    CGImageDestinationAddImage(destination,source,nil)
    #expect(CGImageDestinationFinalize(destination))
    let cache=ArtworkThumbnails()
    async let first=cache.load(url)
    async let second=cache.load(url)
    let (a,b)=await (first,second)
    let image=try #require(a?.image)
    #expect(image.width == 192 && image.height == 96)
    #expect(image === b?.image)
    let reused=await cache.load(url)
    #expect(image === reused?.image)
}
