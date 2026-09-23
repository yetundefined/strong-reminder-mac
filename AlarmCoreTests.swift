import Foundation

@main
struct AlarmCoreTests {
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let exact = Alarm(id: UUID(), title: "抢票", fireAt: now)
        let future = Alarm(id: UUID(), title: "开会", fireAt: now.addingTimeInterval(60))
        let stale = Alarm(id: UUID(), title: "过期", fireAt: now.addingTimeInterval(-7_200))

        var alarms = [exact, future, stale]
        let due = AlarmPlanner.consumeDue(from: &alarms, at: now, maxLateness: 3_600)
        precondition(due.map(\.id) == [exact.id], "到点闹钟应该只触发一次")
        precondition(alarms.map(\.id) == [future.id], "未来闹钟应保留，过期闹钟应清除")

        let repeated = AlarmPlanner.consumeDue(from: &alarms, at: now, maxLateness: 3_600)
        precondition(repeated.isEmpty, "重复检查不能重复触发")

        let snoozed = AlarmPlanner.snooze(exact, from: now, minutes: 5)
        precondition(snoozed.title == exact.title, "稍后提醒应保留标题")
        precondition(snoozed.fireAt == now.addingTimeInterval(300), "稍后提醒应延后五分钟")
        precondition(snoozed.id != exact.id, "稍后提醒应是新的闹钟")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = folder.appendingPathComponent("alarms.json")
        let store = AlarmStore(fileURL: file)
        try store.save([future])
        let loaded = try store.load()
        precondition(loaded == [future], "闹钟应能重新读取")

        let displayed = AlarmListFormatter.lines([future])
        precondition(displayed.contains("开会"), "列表文字应包含提醒内容")

        let secondsIntoMinute = now.addingTimeInterval(45)
        precondition(AlarmPlanner.alignedToMinute(secondsIntoMinute) == now, "提醒应在所选分钟开始时响起")

        print("AlarmCoreTests: 7 passed")
    }
}
