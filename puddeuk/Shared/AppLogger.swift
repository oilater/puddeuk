import OSLog

extension Logger {
    private static let subsystem = "com.puddeuk.alarm"

    static let alarm = Logger(subsystem: subsystem, category: "alarm")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let notification = Logger(subsystem: subsystem, category: "notification")
}
