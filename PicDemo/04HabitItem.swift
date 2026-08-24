//
//  HabitItem.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftData
import SwiftUI

// 變成資料庫裡的一張表
@Model
class HabitItem {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    
    // 起始日變成 Optional，因為「排隊中」的習慣還沒開始算時間
    var startDate: Date?
    var completedDates: [String]
    var targetDays: Int
    
    // 狀態：0 = 鎖定排隊中, 1 = 進行中, 2 = 50天已畢業
    var status: Int
    var createdAt: Date
    
    var hasClaimedBadge: Bool    // 是否已經領取徽章
    var badgeTitle: String       // 稱號 (例如：早起大師)
    var badgeReflection: String  // 心得感想
    var completedAt: Date?
    
    var backfillUsedCount: Int = 0

    init(name: String, icon: String, colorHex: String, targetDays: Int = 21) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.startDate = nil
        self.completedDates = []
        self.targetDays = targetDays
        self.status = 0 // 預設一律先進排隊區，由系統判定是否能轉正
        self.createdAt = Date()
        self.hasClaimedBadge = false
        self.badgeTitle = ""
        self.badgeReflection = ""
        self.completedAt = nil
    }
    
    var color: Color { Color(hex: colorHex) }
}

// 顏色轉換擴充
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

// ⭐️ 新增：習慣狀態判定大腦 (極簡滾動制)
extension HabitItem {
    
    // 1. 取得近 N 天的「打卡次數」
    var recentRollingCount: Int {
        var count = 0
        
        for i in 0..<targetDays {
            // 往回推算過去的每一天
            if let pastDate = Calendar.current.date(byAdding: .day, value: -i, to: Date()) {
                
                // ⭐️ 關鍵修正：抽出那天的「日期數字」，並交給你專案自帶的 DateHelper 去轉換！
                // 這樣產生的字串格式，絕對 100% 吻合你存進資料庫的樣子
                let day = Calendar.current.component(.day, from: pastDate)
                let dateStr = DateHelper.dateString(for: day, in: pastDate)
                
                if completedDates.contains(dateStr) {
                    count += 1
                }
            }
        }
        return count
    }

    // 2. 取得近 N 天的「完成率」
    var recentRollingRate: Double {
        return Double(recentRollingCount) / Double(targetDays)
    }
    
    // 3. 判斷是否已經達成 92% 畢業門檻
    var isGraduated: Bool {
        return recentRollingRate >= 0.92
    }
}
