//
//  MainTabView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI
import SwiftData
import ActivityKit

struct MainTabView: View {
    @State private var selectedTab = 0
    // 控制「慶祝畫面」要不要彈出來
    @State private var showCelebration = false
    @State private var thisWeekSuccessCount = 1
    
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var theme: ThemeManager
    @AppStorage("enableConfetti") private var enableConfetti = true
    
    // 為「跳動的透明膠囊」準備動畫命名空間
    @Namespace private var tabAnimation
    
    var body: some View {
        // 最外層用 ZStack 包裹，實現真正的全螢幕 Emoji 雨與自訂字卡
        ZStack {
            
            // 底層：原本所有的主畫面與自製 TabBar
            VStack(spacing: 0) {
                // ==========================================
                // 1. 主畫面區塊 (佔滿上方剩餘空間)
                // ==========================================
                TabView(selection: $selectedTab) {
                    TodoListView()
                        .tag(0)
                        .toolbar(.hidden, for: .tabBar)
                    
                    HabitDashboardView()
                        .tag(1)
                        .toolbar(.hidden, for: .tabBar)
                    
                    DiaryView()
                        .background(theme.bgColor.ignoresSafeArea())
                        .tag(2)
                        .toolbar(.hidden, for: .tabBar)
                    
                    SettingsView()
                        .tag(3)
                        .toolbar(.hidden, for: .tabBar)
                }
                
                // ==========================================
                // 2. 自製的滿版貼底 Tab Bar
                // ==========================================
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        customTabItem(unselectedIcon: "icon_note", selectedIcon: "icon_note_s", index: 0)
                        Spacer()
                        customTabItem(unselectedIcon: "icon_habit", selectedIcon: "icon_habit_s", index: 1)
                        Spacer()
                        customTabItem(unselectedIcon: "icon_diary", selectedIcon: "icon_diary_s", index: 2)
                        Spacer()
                        customTabItem(unselectedIcon: "icon_set", selectedIcon: "icon_set_s", index: 3)
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 12)
                    .padding(.bottom, -5)
                }
                .background(theme.theme1
                    .ignoresSafeArea(edges: .bottom)
                    .opacity(0.8))
            }
            // 不要閃避鍵盤
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            // ==========================================
            // 全螢幕慶祝層
            // ==========================================
            if showCelebration {
                ZStack {
                    // (1) 半透明底色，讓後面的 App 畫面微微隱藏（手帳高級感）
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation { showCelebration = false }
                        }
                    
                    // (2) 真正的全螢幕下雨！加強 ignoresSafeArea 確保穿透動態島與底欄
                    EmojiRainView()
                        .ignoresSafeArea()
                    
                    // (3) 置中的手帳風慶祝對話框
                    VStack(spacing: 24) {
                        Text("你是最棒的！")
                            .font(.title.bold())
                            .foregroundColor(theme.textColor)
                        
                        Text("本週第 \(thisWeekSuccessCount) 次成功留意滑手機時間！")
                            .font(.body)
                            .foregroundColor(theme.textColor)
                        
                        // 點擊後同步關閉視窗，並帶你絲滑回到第一個分頁 (Tag 0)
                        Button("繼續完成待辦事項") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = 0
                                showCelebration = false  // 關閉慶祝畫面
                            }
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.theme2)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.top, 10)
                    }
                    .padding(28)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 36)
                    // 字卡跳出來的精緻動畫
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .scale(scale: 0.92).combined(with: .opacity)
                    ))
                }
                .zIndex(999) // 確保絕對蓋在所有人最上層
            }
            
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                endAllLiveActivities()
            }
        }
        .onOpenURL { url in
            if url.host == "celebrate" {
                // 記錄成功總次數
                FocusSuccessTracker.shared.recordSuccess()
                thisWeekSuccessCount = FocusSuccessTracker.shared.getThisWeekCount()
                
                // 跳出慶祝視窗時，用漂亮的彈簧動畫帶入
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    showCelebration = true
                }
                
                // （雙保險）點擊動態島按鈕進來時，把動態島和幽靈通知殺掉
                endAllLiveActivities()
            }
        }
    }
    
    // ==========================================
    // ⭐️ 自製 Tab 按鈕元件 (支援自訂圖片與縮放)
    // ==========================================
    @ViewBuilder
    private func customTabItem(unselectedIcon: String, selectedIcon: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }) {
            Image(isSelected ? selectedIcon : unselectedIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .padding(.vertical, 10)
                .padding(.horizontal, 22)
                .background(
                
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(theme.theme2.opacity(0.35))
                                .matchedGeometryEffect(id: "TabHighlight", in: tabAnimation)
                        }
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func endAllLiveActivities() {
        // 只要動態島被收起來，就一併把還沒發送的打斷通知取消掉
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["FocusTimerNotification"])
        Task {
            for activity in Activity<ScrollingTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

// ==========================================
// ⭐️ 負責記錄與計算動態島成功回歸的次數
// ==========================================
struct FocusSuccessTracker {
    static let shared = FocusSuccessTracker()
    private let storageKey = "focusSuccessHistory"
    
    // 1. 記錄一次成功的當下時間
    func recordSuccess() {
        var dates = UserDefaults.standard.array(forKey: storageKey) as? [Date] ?? []
        dates.append(Date())
        UserDefaults.standard.set(dates, forKey: storageKey)
    }
    
    // 2. 計算「本週」總共有幾次成功
    func getThisWeekCount() -> Int {
        let dates = UserDefaults.standard.array(forKey: storageKey) as? [Date] ?? []
        let calendar = Calendar.current
        let today = Date()
        
        // 過濾出「與今天屬於同一個星期」的時間記錄
        let thisWeekDates = dates.filter { date in
            calendar.isDate(date, equalTo: today, toGranularity: .weekOfYear)
        }
        return thisWeekDates.count
    }
}

#Preview {
    MainTabView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [TodoItem.self, HabitItem.self, DiaryEntry.self, StickyNote.self], inMemory: true)
}
