import Foundation

public enum LogLevel: String {
    case info
    case warn
    case error
}

public final class Logger {
    public static let shared = Logger()
    private let fm = FileManager.default
    private let logURL: URL
    private var enabled: Bool = false

    private init() {
        let support = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/MacSweeper")
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
        logURL = support.appendingPathComponent("app.log")
    }

    public func setEnabled(_ on: Bool) { enabled = on }

    public func log(_ level: LogLevel, _ message: String) {
        guard enabled else { return }
        let line = "[\(Date())] [\(level.rawValue.uppercased())] \(message)\n"
        if let data = line.data(using: .utf8) {
            if fm.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) { defer { try? handle.close() }; try? handle.seekToEnd(); try? handle.write(contentsOf: data) }
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    public func exportLogs(to url: URL) throws {
        if fm.fileExists(atPath: logURL.path) {
            try fm.copyItem(at: logURL, to: url)
        } else {
            let empty = "(空日志)\n".data(using: .utf8)!
            try empty.write(to: url)
        }
    }
}