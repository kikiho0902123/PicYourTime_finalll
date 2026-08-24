//
//  StartFocusTimerIntent.swift
//  PicDemo
//

import AppIntents
import ActivityKit
import Foundation
import UserNotifications

// ==========================================
// 1. 啟動滑手機時間提醒：開啟 App 就立刻啟動，不再等待
// ==========================================
struct StartFocusTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "啟動滑手機時間提醒"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        // 防呆：已經有活躍中的動態島，就不要重複啟動
        let activeActivities = Activity<ScrollingTimerAttributes>.activities.filter { $0.activityState == .active }
        if !activeActivities.isEmpty { return .result() }

        // ⭐️ 記錄「這次開始計時」的時間點，交給關閉時的 Intent 判斷是否為短暫開啟
        UserDefaults.standard.set(Date(), forKey: "focusSessionStartTime")

        let defaults = UserDefaults.standard
        let userMinutes = defaults.integer(forKey: "timerDuration")
        let finalMinutes = userMinutes > 0 ? userMinutes : 5
        let timerDuration: TimeInterval = TimeInterval(finalMinutes * 60)
        let targetEndTime = Date().addingTimeInterval(timerDuration)

        let notifTitle = defaults.string(forKey: "notifTitle") ?? String(localized: "要不要休息一下")
        let notifBody = defaults.string(forKey: "notifBody") ?? String(localized: "時間到了，該讓眼睛和大腦活動活動喔～")
        let lockScreenTitle = defaults.string(forKey: "lockScreenTitle") ?? String(localized: "你現在真的想滑手機嗎？")
        let actionButtonText = defaults.string(forKey: "actionButtonText") ?? String(localized: "不滑了！")
        let theme3Hex = defaults.string(forKey: "theme3Hex") ?? "FFFFFF"
        let theme2Hex = defaults.string(forKey: "theme2Hex") ?? "FFFFFF"

        let attributes = ScrollingTimerAttributes(
            lockScreenTitle: lockScreenTitle,
            actionButtonText: actionButtonText,
            themeColorHex: theme3Hex,
            theme2ColorHex: theme2Hex
        )
        let contentState = ScrollingTimerAttributes.ContentState(startTime: Date(), endTime: targetEndTime)

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = notifTitle
        content.body = notifBody
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timerDuration, repeats: false)
        let request = UNNotificationRequest(identifier: "FocusTimerNotification", content: content, trigger: trigger)

        try? await center.add(request)
        let _ = try? Activity.request(
            attributes: attributes,
            content: .init(state: contentState, staleDate: nil),
            pushType: nil
        )

        return .result()
    }
}

// ==========================================
// 2. 關閉時判斷：如果 60 秒內就關閉，視為一分鐘離開緩衝，取消剛剛啟動的一切
// ==========================================
struct RecordLeaveTimeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "一分鐘離開緩衝"

    init() {}

    private let gracePeriodSeconds: Double = 60

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let sessionStart = UserDefaults.standard.object(forKey: "focusSessionStartTime") as? Date else {
            // 沒有記錄開始時間（代表根本沒有啟動過計時），沒事可做
            return .result()
        }

        let elapsed = Date().timeIntervalSince(sessionStart)

        if elapsed < gracePeriodSeconds {
            // ⭐️ 這次開啟不到 60 秒就關閉了，判定為無沉迷，把剛剛啟動的動態島與通知都取消掉
            for activity in Activity<ScrollingTimerAttributes>.activities {
                let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
                // 讓動態島立刻從鎖屏和通知中心徹底消失！
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
            
            // 把沒發送的、跟已經跑到通知中心的，全部一起殺掉
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["FocusTimerNotification"])
            center.removeDeliveredNotifications(withIdentifiers: ["FocusTimerNotification"])
            
            // 💡 養成好習慣：清除 UserDefaults 裡的暫存時間，避免下次啟動時產生混亂
            UserDefaults.standard.removeObject(forKey: "focusSessionStartTime")
        }
        // 超過 60 秒才關閉：視為真的有在使用 App，動態島與通知維持原樣繼續倒數

        return .result()
    }
}

// ==========================================
// 3. 註冊捷徑的廣播器（不需要改）
// ==========================================
struct PicDemoShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusTimerIntent(),
            phrases: [
                "在 \(.applicationName) 啟動滑手機時間提醒",
                "Start a scrolling time reminder with \(.applicationName)"
            ],
            shortTitle: "滑手機提醒",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: RecordLeaveTimeIntent(),
            phrases: [
                "在 \(.applicationName) 啟動一分鐘離開緩衝",
                "Start a one minute exit buffer with \(.applicationName)"
            ],
            shortTitle: "離開緩衝",
            systemImageName: "clock.badge.exclamationmark"
        )
    }
}
