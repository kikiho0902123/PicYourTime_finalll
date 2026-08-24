//
//  HabitDetailView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI
import SwiftData

struct HabitDetailView: View {
    var habit: HabitItem
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: ThemeManager

    // 控制這個習慣專屬月曆的月份
    @State private var currentDate: Date = Date()
    
    @State private var showConfirmAlert = false
    @State private var selectedMissingDay: Int? = nil
    
    @State private var showBadgePopup = false
    @State private var draftBadgeTitle = ""
    @State private var draftBadgeReflection = ""
    
    @State private var showDeleteAlert = false
    
    // 計算當月打卡狀況給月曆網格使用
    var habitCompletionData: [Int: Int] {
        var data: [Int: Int] = [:]
        let days = Calendar.current.range(of: .day, in: .month, for: currentDate)?.count ?? 30
        for day in 1...days {
            let dayStr = DateHelper.dateString(for: day, in: currentDate)
            data[day] = habit.completedDates.contains(dayStr) ? 1 : 0
        }
        return data
    }
    
    var body: some View {
        ZStack {
            theme.theme1.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 24) {
                                        
                    // 1. 頂部狀態 Banner 與大圖示
                    VStack(spacing: 12) {
                        Image(systemName: habit.icon)
                            .font(.system(size: 60))
                            .foregroundColor(habit.color)
                            .padding(.top, 20)
                            // 如果達標了，圖示加上發光特效
                            .shadow(color: habit.isGraduated ? habit.color.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)
                    }
                    
                    // ==========================================
                    // ⭐️ 2. 統一規格數據儀表板
                    // ==========================================
                    VStack(spacing: 20) {
                        // 第一列：開始日期、完成率
                        HStack(spacing: 0) {
                            // ⭐️ 手動包上 String(localized:)
                            DataBlockView(title: String(localized: "開始日期"), value: formatDate(habit.startDate), unit: "", valueColor: theme.textColor.opacity(0.8))
                            
                            Divider().frame(height: 40)
                            
                            let rateString = String(format: "%.0f", min(habit.recentRollingRate * 100, 100))
                            // ⭐️ "%" 全世界通用不用包，但 "完成率" 要包
                            DataBlockView(title: String(localized: "完成率"), value: rateString, unit: "%", valueColor: habit.color)
                        }

                        Divider().padding(.horizontal, 20)
                        
                        // 第二列：最高連續打卡、近期打卡、目標天數
                        HStack(spacing: 0) {
                            let streaks = DateHelper.calculateStreaks(from: habit.completedDates)
                            // ⭐️ 單位 "天" 也需要翻譯（英文會變成 Days）
                            DataBlockView(title: String(localized: "最高連續"), value: "\(streaks.max)", unit: String(localized: "天"), valueColor: habit.color)
                            
                            Divider().frame(height: 40)
                            
                            DataBlockView(title: String(localized: "近期打卡"), value: "\(habit.recentRollingCount)", unit: String(localized: "次"), valueColor: habit.color)
                            
                            Divider().frame(height: 40)
                            
                            DataBlockView(title: String(localized: "目標天數"), value: "\(habit.targetDays)", unit: String(localized: "天"), valueColor: .gray)
                        }
                    }
                    .padding(.vertical, 20)
                    .background(theme.bgColor)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                    .padding(.horizontal)
                    
                    // ==========================================
                    // ⭐️ 3. 領取徽章按鈕區塊 (只在達標且未領取時出現)
                    // ==========================================
                    if habit.isGraduated && !habit.hasClaimedBadge {
                        Button(action: {
                            // 打開視窗並加入微震動回饋
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                showBadgePopup = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("成功培養習慣！領取徽章")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(habit.color)
                            .cornerRadius(16)
                            .shadow(color: habit.color.opacity(0.3), radius: 8, x: 0, y: 4)
                            .padding(.horizontal)
                        }
                    } else if habit.hasClaimedBadge {
                        // 如果已經領取了，低調展示一下他的專屬稱號 //應該不會觸發這個才對
                        HStack {
                            Image(systemName: "medal.fill")
                                .foregroundColor(.orange)
                            Text("已獲得徽章：\(habit.badgeTitle)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 8)
                    }
                    
                    // 3. 月份控制列與月曆
                    MonthNavigationHeader(currentDate: $currentDate)
                        .padding(.horizontal)
                    
                    // 4. 當月打卡月曆網格
                    CalendarGridComponent(
                        isOverall: false,
                        themeColor: habit.color,
                        targetDate: currentDate,
                        completionData: habitCompletionData,
                        maxLevel: 1,
                        onDayTapped: { (day: Int) in
                            // 點擊 Menu 裡的按鈕後，直接觸發第二段拷問
                            self.selectedMissingDay = day
                            self.showConfirmAlert = true
                        }
                    )
                    .padding()
                    .background(theme.bgColor)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                    .padding(.horizontal)
                    
                    // ==========================================
                    // 5. 淺色垃圾桶按鈕
                    // ==========================================
                    HStack {
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Image(showDeleteAlert ? "icon_trash_open" : "icon_trash")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(theme.theme3.opacity(0.6))
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showDeleteAlert)
                        }
                        Spacer() // 把它推到左邊對齊
                    }
                    .padding(.horizontal, 24) // 對齊上方的卡片邊緣
                    .padding(.top, 8)
                    
                }
                .padding(.bottom, 40)
                .padding(.horizontal, 10)
            }
            
            // ==========================================
            // 領取徽章的彈出視窗 (疊加在最上層)
            // ==========================================
            if showBadgePopup {
                // 半透明黑色遮罩
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showBadgePopup = false }
                    }
                
                // 置中的輸入卡片
                VStack(spacing: 20) {
                    Text("為這個好習慣命名吧！")
                        .font(.headline)
                        .foregroundStyle(theme.textColor)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("稱號").font(.caption).foregroundColor(theme.textColor.opacity(0.5))
                        TextField("例如：早起大師", text: $draftBadgeTitle)
                            .padding(12)
                            .background(theme.theme1.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("一路走來的心得").font(.caption).foregroundColor(theme.textColor.opacity(0.5))
                        TextEditor(text: $draftBadgeReflection)
                            .frame(height: 80)
                            .padding(8)
                            .background(theme.theme1.opacity(0.2))
                            .cornerRadius(10)
                            .scrollContentBackground(.hidden)
                    }
                    
                    Button(action: {
                        // ⭐️ 儲存資料、標記已領取，並更新狀態為已畢業 (status = 2)
                        habit.badgeTitle = draftBadgeTitle.isEmpty ? String(localized: "習慣大師") : draftBadgeTitle
                        habit.badgeReflection = draftBadgeReflection
                        habit.hasClaimedBadge = true
                        habit.status = 2
                        habit.completedAt = Date()
                        
                        withAnimation(.spring()) {
                            showBadgePopup = false
                        }
                    }) {
                        Text("收下徽章")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(habit.color)
                            .cornerRadius(12)
                    }
                    .padding(.top, 10)
                }
                .padding(24)
                .background(theme.bgColor)
                .cornerRadius(24)
                .shadow(radius: 20)
                .padding(.horizontal, 30)
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("真的嗎？", isPresented: $showConfirmAlert) {
            Button("好吧沒有", role: .cancel) {}
            Button("真的") {
                if let day = selectedMissingDay {
                    let dateStr = DateHelper.dateString(for: day, in: currentDate)
                    // 確認沒打過卡再補上去
                    if !habit.completedDates.contains(dateStr) {
                        habit.completedDates.append(dateStr)
                    }
                }
            }
        } message: {
            Text("我有做但我忘記打卡")
        }
        .alert("確定要刪除這個習慣嗎？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                modelContext.delete(habit)
                dismiss() // 刪除後自動返回上一頁
            }
        } message: {
            Text("刪除後，這項習慣的所有的紀錄都會消失喔！")
        }
    }
    
    // 日期格式化
    private func formatDate(_ date: Date?) -> String {
        guard let validDate = date else { return "尚未開始" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: validDate)
    }
}

// 數據塊輔助元件
struct DataBlockView: View {
    @EnvironmentObject var theme: ThemeManager
    
    let title: String
    let value: String
    let unit: String
    let valueColor: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textColor.opacity(0.5))
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(valueColor)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textColor.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
