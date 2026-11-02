#if os(macOS)
import AppKit
import SwiftUI

/// Offscreen layout inspection only. Does not start an audio check or create a window.
@main
struct AudioCheckPreview {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain:"AudioCheckPreview",code:1,userInfo:[NSLocalizedDescriptionKey:"Supply an output PNG path."])
        }
        let model=AudioCheckModel()
        let renderer=ImageRenderer(content:AudioCheckContents(model:model,share:{})
            .preferredColorScheme(.light).frame(width:834,height:1112,alignment:.top).background(Color.white))
        renderer.scale=1
        guard let image=renderer.nsImage, let tiff=image.tiffRepresentation,
              let bitmap=NSBitmapImageRep(data:tiff),let data=bitmap.representation(using:.png,properties:[:]) else {
            throw NSError(domain:"AudioCheckPreview",code:2,userInfo:[NSLocalizedDescriptionKey:"Could not render the diagnostic layout."])
        }
        try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
    }
}
#else
@main
struct AudioCheckPreview {
    static func main() {}
}
#endif
