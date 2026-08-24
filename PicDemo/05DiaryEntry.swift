//
//  DiaryEntry.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftData
import SwiftUI

@Model
class DiaryEntry {
    var id: UUID
    var date: Date
    var content: String
    
    // 2D 座標轉換出來的數值
    var moodHue: Double        // 色相 (0.0 ~ 1.0)
    var moodSaturation: Double
    var moodBrightness: Double // 亮度 (0.0 ~ 1.0)
    
    // 儲存卡片比例 (3/4, 1.0, 4/3)
    var aspectRatio: Double
    
    // ⭐️ 儲存相片的手勢縮放與位移數值
    var imageScale: Double
    var imageOffsetX: Double
    var imageOffsetY: Double
    
    // 儲存壓縮後的相片資料
    @Attribute(.externalStorage) var imageData: Data?
    
    init(date: Date = Date(), content: String = "", moodHue: Double = 0.5, moodSaturation: Double = 1.0, moodBrightness: Double = 0.8, imageData: Data? = nil, aspectRatio: Double = 0.75, imageScale: Double = 1.0, imageOffsetX: Double = 0.0, imageOffsetY: Double = 0.0) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.content = content
        self.moodHue = moodHue
        self.moodSaturation = moodSaturation
        self.moodBrightness = moodBrightness
        self.imageData = imageData
        self.aspectRatio = aspectRatio
        self.imageScale = imageScale
        self.imageOffsetX = imageOffsetX
        self.imageOffsetY = imageOffsetY
    }
    
    var moodColor: Color {
        Color(hue: moodHue, saturation: moodSaturation, brightness: moodBrightness)
    }
}
