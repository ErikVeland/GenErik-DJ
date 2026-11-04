import Foundation
import TDJRuntimeChecks

@main struct RuntimeValidation {
    @MainActor static func main() async {
        await Task(priority: .userInitiated) {
            do {
                let args = CommandLine.arguments
                guard (3...4).contains(args.count), let seconds = Double(args[2]),
                    args.count == 3 || args[3] == "sequential"
                else {
                    throw NSError(
                        domain: "Validation", code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Usage: tdj-runtime-validation OUTPUT_DIRECTORY SECONDS [sequential]"
                        ])
                }
                let result = try await AudioRuntimeChecks.run(
                    outputDirectory: URL(fileURLWithPath: args[1], isDirectory: true), seconds: seconds,
                    sequential: args.count == 4)
                print(result.passed ? "PASS" : "FAIL")
                if !result.passed { exit(1) }
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
        }.value
    }
}
