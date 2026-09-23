import Foundation

struct Alarm: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let fireAt: Date
}

enum AlarmPlanner {
    static func alignedToMinute(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .minute, for: date)!.start
    }

    static func consumeDue(from alarms: inout [Alarm], at now: Date, maxLateness: TimeInterval) -> [Alarm] {
        let due = alarms.filter { $0.fireAt <= now && now.timeIntervalSince($0.fireAt) <= maxLateness }
        alarms.removeAll { $0.fireAt <= now }
        return due
    }

    static func snooze(_ alarm: Alarm, from now: Date, minutes: Int) -> Alarm {
        Alarm(id: UUID(), title: alarm.title, fireAt: now.addingTimeInterval(TimeInterval(minutes * 60)))
    }
}

struct AlarmStore {
    let fileURL: URL

    func load() throws -> [Alarm] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([Alarm].self, from: Data(contentsOf: fileURL))
    }

    func save(_ alarms: [Alarm]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(alarms)
        try data.write(to: fileURL, options: .atomic)
    }
}

enum AlarmListFormatter {
    static func lines(_ alarms: [Alarm]) -> String {
        guard !alarms.isEmpty else { return "还没有待提醒事项" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE HH:mm"
        return alarms.enumerated().map { index, alarm in
            "\(index + 1). \(formatter.string(from: alarm.fireAt))  ·  \(alarm.title)"
        }.joined(separator: "\n")
    }
}
