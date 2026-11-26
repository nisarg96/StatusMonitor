import Foundation
import Testing

/// Architecture guard: only `CompositionRoot` may choose concrete adapters in the executable target.
@Suite("Composition boundary")
struct CompositionBoundaryTests {
    private static let adapterConstructors = [
        "UserDefaultsSettingsRepository(", "LiveMetricSources.make(", "SudoersInstaller(", "SudoersPurgeExecutor(",
        "MemoryPressureCommand(", "MachAvailableMemorySource(", "FileRemediationLog(",
        "UserDefaultsRemediationStore(", "UserDefaultsDailyTrafficStore(", "RunLoopRefreshScheduler(",
        "SMAppLoginItemService("]

    /// `#filePath` is Tests/StatusMonitorCoreTests/Infrastructure/<this file>; four levels up is the project root.
    private static var executableSources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/StatusMonitor")
    }

    private static func swiftFiles() -> [URL] {
        let enumerator = FileManager.default.enumerator(at: executableSources, includingPropertiesForKeys: nil)
        return (enumerator?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
    }

    @Test("no executable file outside CompositionRoot constructs a concrete adapter")
    func onlyCompositionRootBuildsAdapters() throws {
        for file in Self.swiftFiles() where !file.lastPathComponent.hasPrefix("CompositionRoot.swift") {
            let text = try String(contentsOf: file, encoding: .utf8)
            for constructor in Self.adapterConstructors {
                #expect(!text.contains(constructor), "\(file.lastPathComponent) builds \(constructor)")
            }
        }
    }

    @Test("the composition root shares one purge executor with the installer")
    func sharedPurgeExecutor() throws {
        let root = try String(
            contentsOf: Self.executableSources.appendingPathComponent("App/CompositionRoot.swift"),
            encoding: .utf8
        )
        #expect(root.contains("SudoersInstaller(executor: purgeExecutor)"))
        #expect(!root.contains("SudoersInstaller()"))
    }
}
