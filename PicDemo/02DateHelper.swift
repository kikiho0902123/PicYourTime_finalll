//
//  DateHelper.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import Foundation

struct DateHelper {
    
    // 取得「今天」的日期字串
    static var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // 取得特定月份中「某一天」的日期字串
    static func dateString(for day: Int, in monthDate: Date) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: monthDate)
        components.day = day
        guard let date = calendar.date(from: components) else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // 計算連續天數
    static func calculateStreaks(from dateStrings: [String]) -> (current: Int, max: Int) {
        guard !dateStrings.isEmpty else { return (0, 0) }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // 將字串轉為日期並排序
        let dates = Array(Set(dateStrings))
            .compactMap { formatter.date(from: $0) }
            .map { Calendar.current.startOfDay(for: $0) }
            .sorted()
        
        guard !dates.isEmpty else { return (0, 0) }
        
        // 1. 計算「歷史最高連續天數」
        var maxStreak = 1
        var tempStreak = 1
        for i in 1..<dates.count {
            let diff = Calendar.current.dateComponents([.day], from: dates[i-1], to: dates[i]).day ?? 0
            if diff == 1 {
                tempStreak += 1
                maxStreak = max(maxStreak, tempStreak)
            } else if diff > 1 {
                tempStreak = 1
            }
        }
        
        // 2. 計算「目前連續天數」(從今天或昨天往回推)
        var currentStreak = 0
        let today = Calendar.current.startOfDay(for: Date())
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return (0, maxStreak) }
        
        if dates.contains(today) {
            currentStreak = 1
            var checkDate = yesterday
            while dates.contains(checkDate) {
                currentStreak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
            }
        } else if dates.contains(yesterday) {
            currentStreak = 1
            var checkDate = Calendar.current.date(byAdding: .day, value: -1, to: yesterday)!
            while dates.contains(checkDate) {
                currentStreak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
            }
        }
        
        return (currentStreak, max(maxStreak, currentStreak))
    }
}
