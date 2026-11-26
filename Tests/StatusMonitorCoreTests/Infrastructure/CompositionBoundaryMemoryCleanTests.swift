import Foundation
import Testing

/// Source-scan guard for the Memory Clean wiring. One clean use case serves Auto Clean and the manual controls,
/// and the same view model is handed to both the popover and the Settings window.
@Suite("Composition boundary: Memory Clean")
struct CompositionBoundaryMemoryCleanTests {
    /// `#filePath` is Tests/StatusMonitorCoreTests/Infrastructure/<this file>; four levels up is the project root.
    private static var executableSources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/StatusMonitor")
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: executableSources.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// The text of the call that starts at `marker`, up to its matching closing parenthesis.
    private static func call(_ marker: String, in text: String) -> String? {
        guard let start = text.range(of: marker) else { return nil }
        var depth = 0
        var index = start.lowerBound
        while index < text.endIndex {
            if text[index] == "(" { depth += 1 }
            if text[index] == ")" {
                depth -= 1
                if depth == 0 { return String(text[start.lowerBound...index]) }
            }
            index = text.index(after: index)
        }
        return nil
    }

    @Test("CompositionRoot constructs the clean use case exactly once")
    func useCaseConstructedOnce() throws {
        let root = try Self.source("App/CompositionRoot.swift")
        #expect(root.components(separatedBy: "MemoryCleanUseCase(").count - 1 == 1)
    }

    @Test("CompositionRoot builds the view model from the same use case that Auto Clean uses")
    func viewModelSharesUseCase() throws {
        let root = try Self.source("App/CompositionRoot.swift")
        #expect(root.contains("let memoryClean: MemoryCleanViewModel"))
        let viewModel = try #require(Self.call("MemoryCleanViewModel(", in: root))
        #expect(viewModel.contains("cleanUseCase"))
        let autoClean = try #require(Self.call("AutoCleanCoordinator(", in: root))
        #expect(autoClean.contains("clean: cleanUseCase"))
    }

    @Test("the app delegate hands the root's memoryClean to the status bar")
    func appDelegatePassesMemoryClean() throws {
        let app = try Self.source("App/AppDelegate.swift")
        let statusBar = try #require(Self.call("StatusBarController(", in: app))
        #expect(statusBar.contains("memoryClean: root.memoryClean"))
    }

    @Test("the status bar passes memoryClean to both the Settings window and the popover")
    func statusBarPassesMemoryCleanToBothWindows() throws {
        let statusBar = try Self.source("UI/StatusBarController.swift")
        let settingsWindow = try #require(Self.call("SettingsWindowController(", in: statusBar))
        #expect(settingsWindow.contains("memoryClean: memoryClean"))
        let popover = try #require(Self.call("PopoverView(", in: statusBar))
        #expect(popover.contains("memoryClean: memoryClean"))
    }
}
