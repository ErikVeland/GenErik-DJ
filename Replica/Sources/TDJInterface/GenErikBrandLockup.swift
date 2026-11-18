import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

struct GenErikBrandLockup: View {
    @Bindable var model: ReplicaModel
    var showsWordmark = true
    @AppStorage(StoreAccess.customDJNameKey) private var customDJName = ""
    private static let resourceBundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("GenErikDJ_TDJInterface.bundle"),
            let bundle = Bundle(url: url)
        {
            return bundle
        }
        return .module
    }()

    private static func artwork(_ name: String) -> Image? {
        guard
            let url = resourceBundle.url(forResource: name, withExtension: "png")
                ?? resourceBundle.url(forResource: name, withExtension: "png", subdirectory: "HeaderArtwork")
        else { return nil }
        #if os(macOS)
            guard let image = NSImage(contentsOf: url) else { return nil }
            image.isTemplate = true
            return Image(nsImage: image).renderingMode(.template)
        #else
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            return Image(uiImage: image.withRenderingMode(.alwaysTemplate)).renderingMode(.template)
        #endif
    }

    private var customLogo: Image? {
        guard model.storeAccess.personalisationIsUnlocked else { return nil }
        let url = model.store.root.appendingPathComponent("custom-dj-logo")
        #if os(macOS)
            guard let image = NSImage(contentsOf: url) else { return nil }
            return Image(nsImage: image)
        #else
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            return Image(uiImage: image)
        #endif
    }

    private var displayName: String {
        model.storeAccess.personalisationIsUnlocked && !customDJName.isEmpty ? customDJName : "GenErik DJ"
    }

    var body: some View {
        HStack(spacing: 8) {
            if let mark = customLogo ?? Self.artwork("GenErikHeaderMark") {
                mark.resizable().scaledToFit().frame(width: 32, height: 32)
            }
            if showsWordmark {
                Text(displayName).font(.system(size: 20, weight: .bold)).lineLimit(1).fixedSize()
            }
        }.foregroundStyle(PerformancePalette.text).accessibilityElement(children: .ignore)
            .accessibilityLabel(displayName)
    }
}
