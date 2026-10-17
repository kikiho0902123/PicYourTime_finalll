//
//  PicDemoApp.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/2.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct PicDemoApp: App {
    @StateObject private var themeManager = ThemeManager() // 建立全域唯一的主題管理員
    @State private var isAppReady = false // 控管狀態
    @State private var useAnimation = true // 控制要不要跑啟動頁的轉場動畫
    @Environment(\.scenePhase) private var scenePhase // 監聽 App 的生命週期
    @Query private var allTodos: [TodoItem] // 獲取資料庫 (用來查詢所有待辦)
    
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .zIndex(0) // ⭐️ 讓主畫面「永遠存在」於底層。這樣它從第 0 秒就能監聽 .onOpenURL，不會錯過動態島按鈕的廣播
                
                // ⭐️ 如果還沒準備好，就把 Loading 畫面「蓋」在最上面
                if !isAppReady {
                    SplashLoadingView(isAppReady: $isAppReady)
                        // 使用 .identity 取代 nil，確保瞬間切換時沒有殘影
                        .transition(useAnimation ? .opacity : .identity)
                        .zIndex(1) // 確保它在最上層
                }
            }
            // ⭐️ 根據情境動態決定要跑 0.6 秒漸變，還是瞬間切換 (nil)
            .animation(useAnimation ? .easeInOut(duration: 0.6) : nil, value: isAppReady)
            // 把主題管理員發送給裡面所有的子頁面
            .environmentObject(themeManager)
            // 強制整個 App 的系統環境（包含原生 Alert、鍵盤、選單）由背景色亮度決定！
            .preferredColorScheme(ThemeEngine.isDarkBackground(hex: themeManager.bgColorHex) ? .dark : .light)
            // ⭐️ 攔截動態島按鈕的深度連結
            .onOpenURL { url in
                if url.host == "celebrate" {
                    // 只要是按按鈕進來的，跳過 Loading 畫面
                    useAnimation = false
                    isAppReady = true
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                guard newPhase == .active else { return }
                TodoNotificationManager.shared.updateNotifications(todos: allTodos)
            }
        }
        // 資料庫容器維持不變
        .modelContainer(for: [TodoItem.self, HabitItem.self, DiaryEntry.self, StickyNote.self])
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 讓通知在 App 前景時也能顯示 banner + 聲音
        completionHandler([.banner, .sound, .list])
    }
}
