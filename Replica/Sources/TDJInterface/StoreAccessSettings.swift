import StoreKit
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

struct StoreAccessSettings: View {
    @Bindable var model: ReplicaModel
    @AppStorage(StoreAccess.customDJNameKey) private var customDJName = ""
    @State private var importingLogo = false
    @State private var personalisationMessage = ""
    private var access: StoreAccess { model.storeAccess }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("14-day all-access preview") {
                Text(access.previewIsActive
                    ? "All features are unlocked for \(previewDaysRemaining) more days. No subscription starts automatically."
                    : "Your preview has ended. Choose a monthly or lifetime unlock below.")
                Text("Monthly plans include ongoing feature updates and support. Purchases work across your Apple devices.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Monthly plans renew each month until you cancel them. The price above is charged each month.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(StoreAccessFeature.allCases) { feature in
                SettingsGroup(feature.title) {
                    Text(access.hasPurchase(for: feature) ? "Unlocked" : access.previewIsActive ? "Included in preview" : "Available to unlock")
                        .font(.caption).foregroundStyle(.secondary)
                    let offerings = access.products(for: feature)
                    if offerings.isEmpty {
                        Text(access.loading ? "Loading purchase options…" : "Purchase option unavailable")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(offerings, id: \.id) { product in
                        purchaseButton(product, title: product.id.hasSuffix(".monthly") ? "Monthly" : "Lifetime")
                        if product.id.hasSuffix(".lifetime") {
                            Text("Lifetime includes your own DJ name and logo in the app.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            SettingsGroup("All-in-One") {
                if let product = access.allInOneProduct {
                    purchaseButton(product, title: "Lifetime · \(product.displayPrice)")
                    Text("Includes all three feature unlocks and your own DJ name and logo in the app.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(access.loading ? "Loading purchase option…" : "Purchase option unavailable")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if access.personalisationIsUnlocked {
                SettingsGroup("Personalisation") {
                    TextField("DJ name", text: $customDJName)
                        .onChange(of: customDJName) { _, value in
                            if value.count > 24 { customDJName = String(value.prefix(24)) }
                        }
                    Button("Choose logo") { importingLogo = true }
                    Button("Use GenErik DJ branding", role: .destructive) {
                        customDJName = ""
                        try? FileManager.default.removeItem(at: model.store.root.appendingPathComponent("custom-dj-logo"))
                        personalisationMessage = "GenErik DJ branding is restored."
                    }
                    Text("Your name and logo replace the in-app header and About mark on this device. The Apple app name and icon stay GenErik DJ.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !personalisationMessage.isEmpty {
                        Text(personalisationMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .fileImporter(isPresented: $importingLogo, allowedContentTypes: [.image], allowsMultipleSelection: false) {
                    importLogo($0)
                }
            }
            Button("Restore Purchases") { Task { await access.restorePurchases() } }
                .disabled(access.loading)
            if let privacyURL = URL(string: "https://dj.generik.au/privacy") {
                Link("Privacy Policy", destination: privacyURL)
            }
            if let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                Link("Terms of Use", destination: termsURL)
            }
            if !access.purchaseMessage.isEmpty {
                Text(access.purchaseMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var previewDaysRemaining: Int {
        max(0, Int(ceil(access.previewEndsAt.timeIntervalSince(access.clockNow) / 86_400)))
    }

    private func purchaseButton(_ product: Product, title: String) -> some View {
        Button {
            Task { await access.purchase(product) }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(product.displayPrice).monospacedDigit()
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.disabled(access.loading)
    }

    private func importLogo(_ result: Result<[URL], Error>) {
        do {
            guard let source = try result.get().first else { return }
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: source)
            guard data.count <= 4 * 1024 * 1024 else {
                personalisationMessage = "Choose an image smaller than 4 MB."
                return
            }
            #if os(macOS)
                guard NSImage(data: data) != nil else {
                    personalisationMessage = "The selected file is not a supported image."
                    return
                }
            #else
                guard UIImage(data: data) != nil else {
                    personalisationMessage = "The selected file is not a supported image."
                    return
                }
            #endif
            let logoURL = model.store.root.appendingPathComponent("custom-dj-logo")
            try data.write(to: logoURL, options: .atomic)
            personalisationMessage = "Logo saved on this device."
        } catch {
            personalisationMessage = "The logo could not be saved. Choose another image and try again."
        }
    }
}
