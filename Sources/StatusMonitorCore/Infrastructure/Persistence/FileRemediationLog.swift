import Foundation

/// Appends one line per clean attempt to ~/Library/Logs/StatusMonitor/remediation.log.
/// Each line is "<ISO-8601 timestamp> <message>", so the file can be read with any text tool.
public final class FileRemediationLog: RemediationLogWriter {
    private let url: URL
    private let lock = NSLock()
    private let formatter = ISO8601DateFormatter()

    public init(url: URL = FileRemediationLog.defaultURL) {
        self.url = url
    }

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/StatusMonitor/remediation.log")
    }

    public func write(_ entry: RemediationLogEntry) {
        lock.lock()
        defer { lock.unlock() }
        let line = "\(formatter.string(from: entry.timestamp)) \(entry.message)\n"
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            } else {
                try Data(line.utf8).write(to: url, options: .atomic)
            }
        } catch {
            // A failed log write must never stop a clean or crash the app, so it is dropped here.
        }
    }
}
