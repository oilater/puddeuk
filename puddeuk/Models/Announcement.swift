import Foundation

struct Announcement: Identifiable {
    let id: String
    let date: Date
    let titleKey: String
    let contentKey: String

    static let announcements: [Announcement] = [
        Announcement(
            id: "2026-02-23-multilingual",
            date: Date(timeIntervalSince1970: 1740268800), // 2026-02-23
            titleKey: "announcement.multilingual.title",
            contentKey: "announcement.multilingual.content"
        ),
        Announcement(
            id: "2026-02-18-alarmkit",
            date: Date(timeIntervalSince1970: 1739836800), // 2026-02-18
            titleKey: "announcement.alarmkit.title",
            contentKey: "announcement.alarmkit.content"
        )
    ]

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
