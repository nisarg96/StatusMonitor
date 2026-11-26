import Foundation

/**
 Appends one line per clean attempt to ~/Library/Logs/StatusMonitor/remediation.log.

 Each line is "<ISO-8601 timestamp> <message>", so the file can be read with any text tool.
 */
public final class FileRemediationLog: RemediationLogWriter {
    private let url: URL
    private let lock = NSLock()
    private let formatter = ISO8601DateFormatter()

    /**
     Creates a log that appends to a file.

     - Parameters:
       - url: The log file. Its directory is created on the first write.
     */
    public init(url: URL = FileRemediationLog.defaultURL) {
        self.url = url
    }

    /// The default log file, `remediation.log` under `~/Library/Logs/StatusMonitor/`, in the current user's home.
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/StatusMonitor/remediation.log")
    }

    /**
     Appends the entry as one line, creating the file and its directory when needed.

     Write failures are ignored. A failed log write must never stop a clean or crash the app, so the error is dropped.

     - Parameters:
       - entry: The timestamp and message to record.
     */
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
        }
    }
}
