import SwiftUI
import CoreText

/// The minimal disc mark and a readable name for compact app headers.
struct GenErikBrandLockup: View {
    // Packaged Mac apps store Swift package resources in Contents/Resources.
    private static let resourceBundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("GenErikDJ_TDJInterface.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
    }()

    private static let fontRegistered: Bool = {
        guard let url = resourceBundle.url(forResource: "Rajdhani-Bold", withExtension: "ttf", subdirectory: "Fonts") else {
            return false
        }
        var error: Unmanaged<CFError>?
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }()

    private static var brandFont: Font {
        _ = fontRegistered
        return .custom("Rajdhani-Bold", size: 18, relativeTo: .headline)
    }

    private var mark: Image {
        #if os(macOS)
        // The native Swift build copies asset catalogues without compiling them.
        if let url = Self.resourceBundle.url(forResource: "GenErikMark", withExtension: "pdf",
            subdirectory: "BrandAssets.xcassets/GenErikMark.imageset"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            return Image(nsImage: image)
        }
        #endif
        return Image("GenErikMark", bundle: Self.resourceBundle).renderingMode(.template)
    }

    var body: some View {
        HStack(spacing: 8) {
            mark.renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            Text("GenErik DJ")
                .font(Self.brandFont)
                .fixedSize()
        }
        .foregroundStyle(PerformancePalette.text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("GenErik DJ")
    }
}
