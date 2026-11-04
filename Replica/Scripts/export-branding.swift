import AppKit
import CoreGraphics

// Run from Replica. Export each size from the minimal master artwork.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Branding/GenErik-Minimal-master.png")
let image = NSImage(contentsOf: source)!
let artwork = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let iconset = root.appendingPathComponent("Branding/GenErikDJ.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func export(size: Int, to url: URL) throws {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(artwork, in: CGRect(x: 0, y: 0, width: size, height: size))
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
for size in [16, 32, 128, 256, 512] {
    try export(size: size, to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try export(size: size * 2, to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try export(size: 1024, to: root.appendingPathComponent("iPad/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
try export(size: 512, to: root.appendingPathComponent("Branding/AppIcon-preview.png"))
