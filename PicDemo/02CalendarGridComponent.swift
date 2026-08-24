//
//  CalendarGridComponent.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI

struct CalendarGridComponent: View {
    // 外部傳入參數
    var isOverall: Bool
    var themeColor: Color
    var targetDate: Date
    var completionData: [Int: Int]
    var maxLevel: Int
    // 點擊事件閉包
    var onDayTapped: ((Int) -> Void)? = nil
    
    @EnvironmentObject var theme: ThemeManager
    
    // 控制當前展開提示框的日期 (nil 為隱藏)
    @State private var tooltipDay: Int? = nil
    
    // 網格佈局：7等分佈滿寬度
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    let weekdays = Calendar.current.shortWeekdaySymbols
    
    // 計算目標月份總天數
    var daysInMonth: Int {
        return Calendar.current.range(of: .day, in: .month, for: targetDate)?.count ?? 30
    }
    
    // 計算當月首日前所需空白格數
    var emptyPrefixSpaces: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: targetDate)
        guard let firstDayOfMonth = calendar.date(from: components) else { return 0 }
        return calendar.component(.weekday, from: firstDayOfMonth) - 1
    }
    
    var body: some View {
        VStack(spacing: 12) {
            
            // 頂部星期標題列
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    // 星期文字外觀設定
                    Text(day).font(.caption).foregroundColor(theme.theme3).frame(maxWidth: .infinity)
                }
            }
            
            // 月曆主體網格
            LazyVGrid(columns: columns, spacing: 8) {
                // 計算網格總數量
                let totalCells = emptyPrefixSpaces + daysInMonth
                
                ForEach(0..<totalCells, id: \.self) { index in
                    
                    // 填充首日前空白格
                    if index < emptyPrefixSpaces {
                        Color.clear.aspectRatio(1.0, contentMode: .fit)
                    } else {
                        // 實際日期與透明度計算
                        let day = index - emptyPrefixSpaces + 1
                        let level = completionData[day] ?? 0
                        
                        
                        // 建立基礎日期方塊
                        let cell = RoundedRectangle(cornerRadius: 6)
                            // 依據打卡狀態填色
                            .fill(level == 0 ? Color(theme.theme1) : theme.theme2)
                            .aspectRatio(1.0, contentMode: .fit)
                            // 疊加日期數字文字
                            .overlay(
                                Text("\(day)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(isOverall ? .clear : (level > 0 ? .white : theme.theme3.opacity(0.5)))
                            )
                        
                        // 尚未打卡邏輯分支
                        if level == 0 {
                            let dateStr = DateHelper.dateString(for: day, in: targetDate)
                            
                            // 篩選今日與過去日期以啟用互動
                            if dateStr <= DateHelper.todayString {
                                // 綁定氣泡框開關事件
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        tooltipDay = (tooltipDay == day) ? nil : day
                                    }
                                }) {
                                    cell
                                }
                                .buttonStyle(.plain)
                                // ⭐️ 疊加自訂提示氣泡框
                                .overlay(
                                    ZStack {
                                        if tooltipDay == day {
                                            // ⭐️ 隱形遮罩：點擊空白處關閉氣泡
                                            Color.black.opacity(0.001)
                                                .frame(width: 1000, height: 1000)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        tooltipDay = nil
                                                    }
                                                }
                                            
                                            // 氣泡主體與倒三角形無縫拼接
                                            VStack(spacing: -2) {
                                                // 補打卡按鈕觸發事件
                                                Button(action: {
                                                    withAnimation { tooltipDay = nil }
                                                    onDayTapped?(day)
                                                }) {
                                                    // 氣泡文字外觀設定
                                                    Text("忘記打卡？")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .fixedSize(horizontal: true, vertical: false)
                                                        .foregroundColor(theme.theme3)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 6)
                                                        .background(.white.opacity(0.95))
                                                        .cornerRadius(8)
                                                }
                                                
                                                // 氣泡底部倒三角形
                                                Image(systemName: "arrowtriangle.down.fill")
                                                    .resizable()
                                                    .frame(width: 8, height: 6)
                                                    .foregroundColor(.white.opacity(0.95))
                                            }
                                            // 氣泡陰影設定
                                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                            // 邊界防撞偏移計算
                                            .offset(
                                                x: 0, y: -39
                                            )
                                            .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                                        }
                                    }
                                )
                                // 確保展開氣泡位於最上層
                                .zIndex(tooltipDay == day ? 100 : 0)
                                
                            } else {
                                // 未來日期不具互動性
                                cell
                            }
                        } else {
                            // 已打卡日期僅顯示進度
                            cell
                        }
                    }
                }
            }
        }
    }
}
