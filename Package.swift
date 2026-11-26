// swift-tools-version:5.9
import PackageDescription

// Layers (dependencies point inward):
//   StatusMonitor (executable: App / UI / CLI shell)
//        └── StatusMonitorCore
//              ├── Presentation  (ViewModels, formatting)
//              ├── Application   (use cases, ports)
//              ├── Domain        (models, pure calculators)
//              └── Infrastructure (Mach / getifaddrs / UserDefaults adapters)
let package = Package(
    name: "StatusMonitor",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "StatusMonitor", targets: ["StatusMonitor"]),
    ],
    targets: [
        .target(
            name: "StatusMonitorCore",
            path: "Sources/StatusMonitorCore"
        ),
        .executableTarget(
            name: "StatusMonitor",
            dependencies: ["StatusMonitorCore"],
            path: "Sources/StatusMonitor"
        ),
        .testTarget(
            name: "StatusMonitorCoreTests",
            dependencies: ["StatusMonitorCore"],
            path: "Tests/StatusMonitorCoreTests"
        ),
    ]
)
