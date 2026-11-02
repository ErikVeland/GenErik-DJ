import SwiftUI

/// The minimal disc mark and a readable name for compact app headers.
struct GenErikBrandLockup: View {
    // Packaged Mac apps store Swift package resources in Contents/Resources.
    private static let resourceBundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("GenErikDJ_TDJInterface.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
    }()

    static var markImage: Image { Self().mark }
    private var mark: Image {
        #if os(macOS)
        // The native Swift build copies asset catalogues without compiling them.
        if let url = Self.resourceBundle.url(forResource: "GenErikMinimal", withExtension: "png",
            subdirectory: "BrandAssets.xcassets/GenErikMinimal.imageset"),
           let image = NSImage(contentsOf: url) {
            return Image(nsImage: image)
        }
        #endif
        return Image("GenErikMinimal", bundle: Self.resourceBundle)
    }

    var body: some View {
        HStack(spacing: 8) {
            mark
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .accessibilityHidden(true)
            Text("GenErik DJ")
                .font(.system(size: 15, weight: .bold))
                .fixedSize()
        }
        .foregroundStyle(Color(white: 0.94))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("GenErik DJ")
    }
}

/// The mark alone, for the far end of the header.
struct GenErikBrandMark: View {
    var body: some View {
        GenErikBrandLockup.markImage.resizable().scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 7)).accessibilityHidden(true)
    }
}
