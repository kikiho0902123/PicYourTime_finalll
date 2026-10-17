//
//  TodoNotificationManager.swift
//  PicDemo
//

import Foundation
import UserNotifications
import SwiftData

class TodoNotificationManager {
    static let shared = TodoNotificationManager()

    private init() {}

    // 有時間標籤的待辦：暫存「哪一天要推播、該推播裡有哪些待辦與剩餘天數」
    private struct TimedReminderEntry {
        let todo: TodoItem
        let daysRemaining: Int
    }

    func updateNotifications(todos: [TodoItem]) {
        let center = UNUserNotificationCenter.current()

        let defaults = UserDefaults.standard
        let oldIds = defaults.stringArray(forKey: "scheduledTodoNotifIds") ?? []
        if !oldIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: oldIds)
            center.removeDeliveredNotifications(withIdentifiers: oldIds)
        }

        var newScheduledIds: [String] = []

        let isTimedEnabled = defaults.bool(forKey: "isTodoNotifEnabled")
        let isStatelessEnabled = defaults.bool(forKey: "isStatelessTodoNotifEnabled")

        guard isTimedEnabled || isStatelessEnabled else {
            defaults.set(newScheduledIds, forKey: "scheduledTodoNotifIds")
            return
        }

        let daysAhead = defaults.integer(forKey: "todoDaysAhead")
        let hour = defaults.integer(forKey: "todoNotifHour")
        let minute = defaults.integer(forKey: "todoNotifMinute")
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent

        var statelessInterval = defaults.integer(forKey: "statelessTodoInterval")
        if statelessInterval == 0 { statelessInterval = 1 }

        let unfinishedTodos = todos.filter { !$0.isCompleted }

        // ==========================================
        // 處理 A：有時間標籤的待辦 —— 依「觸發日」分組，合併成一則
        // ==========================================
        if isTimedEnabled {
            let timedTodos = unfinishedTodos.filter { $0.dueDate != nil }
            print("🔍 timedTodos 數量: \(timedTodos.count)")

            // key：觸發日期（已去除時分秒的當天 00:00），value：當天要合併呈現的所有待辦
            var groupedByFireDay: [Date: [TimedReminderEntry]] = [:]

            for todo in timedTodos {
                guard let dueDate = todo.dueDate else { continue }

                for offset in 0...daysAhead {
                    var targetDate = calendar.date(byAdding: .day, value: -offset, to: dueDate) ?? dueDate
                    targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate) ?? targetDate

                    guard targetDate > Date() else {
                        print("⏭️ 跳過「\(todo.title)」提前 \(offset) 天的提醒，時間 \(targetDate) 已過去")
                        continue
                    }

                    let fireDay = calendar.startOfDay(for: targetDate)
                    groupedByFireDay[fireDay, default: []].append(TimedReminderEntry(todo: todo, daysRemaining: offset))
                }
            }

            for (fireDay, entries) in groupedByFireDay {
                let targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: fireDay) ?? fireDay
                guard targetDate > Date() else { continue }

                let bodyLines = entries
                    .sorted { $0.daysRemaining < $1.daysRemaining }
                    .map { entry -> String in
                        let suffix = entry.daysRemaining == 0
                                        ? String(localized: "今天做！")
                                        : String(localized: "\(entry.daysRemaining) 天後面對")
                                    return "・\(entry.todo.title)（\(suffix)）"
                    }
                let body = bodyLines.joined(separator: "\n")

                let id = "todo_timed_\(Int(fireDay.timeIntervalSince1970))"
                let title = entries.count > 1
                        ? String(localized: "你有 \(entries.count) 件最近要完成的事喔")
                        : String(localized: "待辦提醒")
                scheduleLocalNotification(id: id, title: title, body: body, targetDate: targetDate)
                newScheduledIds.append(id)
            }
        }

        // ==========================================
        // 處理 B：無時間標籤的待辦 —— 同一次推播全部合併、列點呈現
        // ==========================================
        if isStatelessEnabled {
            let statelessTodos = unfinishedTodos.filter { $0.dueDate == nil }
            print("🔍 statelessTodos 數量: \(statelessTodos.count)")

            if !statelessTodos.isEmpty {
                var scheduledCount = 0
                var dayOffset = 0

                while scheduledCount < 5 {
                    let intervalDays = dayOffset * statelessInterval
                    if let baseDate = calendar.date(byAdding: .day, value: intervalDays, to: Date()),
                       let finalDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) {

                        if finalDate > Date() {
                            let bodyLines = statelessTodos.map { "・\($0.title)" }
                            let body = bodyLines.joined(separator: "\n")

                            let id = "todo_stateless_\(scheduledCount)"
                            let title = statelessTodos.count > 1
                                ? String(localized: "這裡有 \(statelessTodos.count) 件事，今天或許能解決它！")
                                : String(localized: "待辦提醒")
                            
                            scheduleLocalNotification(id: id, title: title, body: body, targetDate: finalDate)
                            newScheduledIds.append(id)
                            scheduledCount += 1
                        } else {
                            print("⏭️ 跳過第 \(scheduledCount) 次無標籤提醒，時間 \(finalDate) 已過去")
                        }
                    }
                    dayOffset += 1
                    if dayOffset > 365 { break } // 保險：避免理論上的無窮迴圈
                }
            }
        }

        defaults.set(newScheduledIds, forKey: "scheduledTodoNotifIds")
    }

    private func scheduleLocalNotification(id: String, title: String, body: String, targetDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
        components.calendar = calendar
        components.timeZone = .autoupdatingCurrent
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚨 排程失敗: \(error.localizedDescription)")
            } else {
                print("✅ 成功排程 (ID: \(id))，將於 \(targetDate) 觸發")
            }
        }
    }
}
