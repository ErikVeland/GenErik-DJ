import AppKit
import ImageIO
import UniformTypeIdentifiers

let replica = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let markURL = replica.appendingPathComponent("Sources/TDJInterface/Resources/HeaderArtwork/GenErikHeaderMark.png")
let outputURL = replica.appendingPathComponent("Branding/AppStore/header-current-3840x1646.png")
let width = 3840
let height = 1646
let bitmap = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
let context = NSGraphicsContext(cgContext: bitmap, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor(srgbRed: 0.045, green: 0.05, blue: 0.055, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Match the interface's 32-point mark, 8-point gap and 20-point bold wordmark.
let scale: CGFloat = 10
let markSize: CGFloat = 32 * scale
let gap: CGFloat = 8 * scale
let foreground = NSColor(white: 0.9, alpha: 1)
let title = NSAttributedString(string: "GenErik DJ", attributes: [
    .font: NSFont.systemFont(ofSize: 20 * scale, weight: .bold),
    .foregroundColor: foreground,
])
let titleSize = title.size()
let x = (CGFloat(width) - markSize - gap - titleSize.width) / 2
let y = (CGFloat(height) - markSize) / 2
let source = NSImage(contentsOf: markURL)!
let tinted = NSImage(size: source.size)
tinted.lockFocus()
source.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
foreground.setFill()
NSRect(origin: .zero, size: source.size).fill(using: .sourceIn)
tinted.unlockFocus()
tinted.draw(in: NSRect(x: x, y: y, width: markSize, height: markSize))
title.draw(at: NSPoint(x: x + markSize + gap, y: (CGFloat(height) - titleSize.height) / 2))
NSGraphicsContext.restoreGraphicsState()

try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, bitmap.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
print(outputURL.path)
