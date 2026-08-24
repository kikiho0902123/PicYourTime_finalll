//
//  01ThemeManager.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/18.
//

import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    
    // 使用 @Published 即時通知畫面更新，並在數值改變時同步寫入手機記憶體
    @Published var bgColorHex: String {
        didSet { UserDefaults.standard.set(bgColorHex, forKey: "appBgColorHex") }
    }
    @Published var theme1Hex: String {
        didSet { UserDefaults.standard.set(theme1Hex, forKey: "theme1Hex") }
    }
    @Published var theme2Hex: String {
        didSet { UserDefaults.standard.set(theme2Hex, forKey: "theme2Hex") }
    }
    @Published var theme3Hex: String {
        didSet { UserDefaults.standard.set(theme3Hex, forKey: "theme3Hex") }
    }
    
    // 初始化：App 打開時，去記憶體抓取上次存的顏色（預設給抹茶燕麥主題）
    init() {
        self.bgColorHex = UserDefaults.standard.string(forKey: "appBgColorHex") ?? "#F4F1E6"
        self.theme1Hex = UserDefaults.standard.string(forKey: "theme1Hex") ?? "#E8EBCF"
        self.theme2Hex = UserDefaults.standard.string(forKey: "theme2Hex") ?? "#C2E395"
        self.theme3Hex = UserDefaults.standard.string(forKey: "theme3Hex") ?? "#35522B"
    }
    
    // 自動判斷文字顏色 (需要搭配稍早提供的 ThemeEngine.isDarkBackground)
    var textColor: Color {
        ThemeEngine.isDarkBackground(hex: bgColorHex) ? .white : Color(hex: "1C1C1E")
    }
    
    // 轉換成 SwiftUI 的 Color 方便各分頁直接套用
    var bgColor: Color { Color(hex: bgColorHex) }
    var theme1: Color { Color(hex: theme1Hex) }
    var theme2: Color { Color(hex: theme2Hex) }
    var theme3: Color { Color(hex: theme3Hex) }
}
struct ThemeEngine {
    /// 輸入 Hex 色號，自動判斷它是深色還是淺色背景
    static func isDarkBackground(hex: String) -> Bool {
        // 1. 清理字串，拿掉空格、轉大寫，並移除 # 號
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        
        // 防呆：如果字串不符合 Hex 格式，預設當作淺色
        guard hexSanitized.count == 6 else { return false }
        
        // 2. 將 Hex 轉成 RGB 數值
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16)
        let g = Double((rgbValue & 0x00FF00) >> 8)
        let b = Double(rgbValue & 0x0000FF)
        
        // 3. 套用 YIQ 亮度公式
        let brightness = (r * 299 + g * 587 + b * 114) / 1000
        
        // 4. 數值小於 125 (稍微偏嚴格一點點的深色判定)，就認定它是深色背景
        return brightness < 125
    }
}
