#!/usr/bin/env python3
"""Run waveform tests with existing package objects when unrelated tests cannot compile."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
replica = root / "Replica"
built = replica / ".build/arm64-apple-macosx/debug"
developer = Path(subprocess.check_output(["xcode-select", "-p"], text=True).strip())
test_libraries = developer / "Platforms/MacOSX.platform/Developer/usr/lib"
framework = replica / ".build/artifacts/replica/whisper/whisper.xcframework/macos-arm64_x86_64"
with tempfile.TemporaryDirectory(prefix="generik-waveform-session-") as directory:
    runner = Path(directory) / "Main.swift"
    runner.write_text("import Testing\n@main struct Main { static func main() async { await Testing.__swiftPMEntryPoint() as Never } }\n")
    binary = Path(directory) / "check"
    command = ["xcrun", "swiftc", "-parse-as-library", "-target", "arm64-apple-macosx14.0", "-swift-version", "6", "-plugin-path", str(developer / "Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing"), "-I", str(built / "Modules"), "-F", str(framework), "-F", str(developer / "Platforms/MacOSX.platform/Developer/Library/Frameworks"), "-I", str(test_libraries), "-L", str(test_libraries), "-Xlinker", "-rpath", "-Xlinker", str(test_libraries)]
    for target in ["CTDJTransport", "CTDJAudioSource"]:
        command += ["-Xcc", f"-fmodule-map-file={built / (target + '.build/module.modulemap')}", "-Xcc", "-I", "-Xcc", str(replica / "Sources" / target / "include")]
    command += [str(replica / "Tests/TDJInterfaceTests/WaveformScratchContinuityTests.swift"), str(runner)]
    for target in ["TDJCore", "TDJInterface", "CTDJTransport", "CTDJAudioSource"]:
        command += list(map(str, (built / (target + ".build")).rglob("*.o")))
    command += ["-Xlinker", "-rpath", "-Xlinker", str(developer / "Platforms/MacOSX.platform/Developer/Library/Frameworks"), "-lc++", "-framework", "Accelerate", "-framework", "whisper", "-Xlinker", "-rpath", "-Xlinker", str(framework), "-o", str(binary)]
    result = subprocess.run(command, cwd=root)
    if result.returncode:
        raise SystemExit(result.returncode)
    subprocess.run([str(binary)], cwd=root, check=True)
