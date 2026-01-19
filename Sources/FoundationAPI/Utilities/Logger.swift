import Foundation

enum LogLevel {
    case debug
    case normal
}

actor LoggerActor {
    static let shared = LoggerActor()
    
    private var level: LogLevel = .normal
    
    func setLevel(_ newLevel: LogLevel) {
        self.level = newLevel
    }
    
    func debug(_ message: String) {
        guard level == .debug else { return }
        fputs("[DEBUG] \(message)\n", stderr)
    }
    
    func error(_ message: String) {
        fputs("[ERROR] \(message)\n", stderr)
    }
    
    func info(_ message: String) {
        fputs("[INFO] \(message)\n", stderr)
    }
}

struct Logger {
    static func setDebugMode() async {
        await LoggerActor.shared.setLevel(.debug)
    }
    
    static func debug(_ message: String) async {
        await LoggerActor.shared.debug(message)
    }
    
    static func error(_ message: String) async {
        await LoggerActor.shared.error(message)
    }
    
    static func info(_ message: String) async {
        await LoggerActor.shared.info(message)
    }
}
