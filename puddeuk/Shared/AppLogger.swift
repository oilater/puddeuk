import OSLog

extension Logger {
    private static let subsystem = "com.puddeuk.alarm"

    @MainActor static let alarm = Logger(subsystem: subsystem, category: "alarm")
    @MainActor static let audio = Logger(subsystem: subsystem, category: "audio")
    @MainActor static let notification = Logger(subsystem: subsystem, category: "notification")
}
