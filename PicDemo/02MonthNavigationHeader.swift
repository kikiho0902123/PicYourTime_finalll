//
//  MonthNavigationHeader.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI

struct MonthNavigationHeader: View {
    @Binding var currentDate: Date
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundColor(theme.textColor)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // 直接把中間的月份文字變成一個按鈕
            Button(action: {
                // 點擊後，以優雅的動畫滑回今天所在的月份
                withAnimation { currentDate = Date() }
            }) {
                Text(monthYearString(from: currentDate))
                    .font(.headline)
                    .foregroundColor(theme.textColor)
            }
            
            Spacer()
            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(theme.textColor)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentDate) {
            withAnimation { currentDate = newDate }
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        // 中文會顯示「2026年7月」，英文會自動顯示「Jul 2026」
        return date.formatted(.dateTime.year().month())
    }
}
