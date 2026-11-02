import Foundation

public enum DevelopmentWorkspace {
    public static func resolve(override: String?, bundleURL: URL, currentDirectory: String) -> URL {
        if let override, !override.isEmpty { return URL(fileURLWithPath: override, isDirectory: true) }
        if bundleURL.pathExtension == "app" {
            return bundleURL.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent(".workspace", isDirectory: true)
        }
        return URL(fileURLWithPath: currentDirectory, isDirectory: true)
            .appendingPathComponent(".workspace", isDirectory: true)
    }
}
