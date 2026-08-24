//
//  StickyNote.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/12.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class StickyNote {
    var id: UUID
    var content: String
    var createdAt: Date
    var colorHex: String
    
    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), colorHex: String = "DCD4C1") {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.colorHex = colorHex
    }
}

// ⭐️ 神級演算法：2D 多邊形動態裁切與反射
struct UniversalPaperShape: Shape {
    var dragX: CGFloat
    var dragY: CGFloat
    var isFoldedPart: Bool // true: 畫翻折的背面 / false: 畫靜止的底層
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(dragX, dragY) }
        set {
            dragX = newValue.first
            dragY = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // ⭐️ 核心修復：強制將過衝的負數阻擋在 0，讓紙張完美平貼桌面，杜絕反折破圖
        let dx = max(dragX, 0)
        let dy = max(dragY, 0)
        let magSq = dx * dx + dy * dy
        
        // 防呆：如果幾乎沒有滑動，直接回傳整張方形紙
        if magSq < 0.001 {
            if !isFoldedPart { path.addRect(rect) }
            return path
        }
        
        // 手指(頂點)位置 P 與 原始右下角 C
        let P = CGPoint(x: w - dx, y: h - dy)
        let C = CGPoint(x: w, y: h)
        
        // 摺痕線必定通過 CP 的中點 M
        let Mx = (C.x + P.x) / 2.0
        let My = (C.y + P.y) / 2.0
        
        // 判斷一個點在摺痕的哪一側 (大於 0 代表該點被折過去了)
        func side(_ pt: CGPoint) -> CGFloat {
            return (pt.x - Mx) * dx + (pt.y - My) * dy
        }
        
        // 將被折過去的點，沿著摺痕線進行物理反射
        func reflect(_ pt: CGPoint) -> CGPoint {
            let s = side(pt)
            let dist = s / magSq
            return CGPoint(x: pt.x - 2 * dist * dx, y: pt.y - 2 * dist * dy)
        }
        
        // 原始紙張的四個頂點
        let corners = [
            CGPoint(x: 0, y: 0),   // 左上
            CGPoint(x: w, y: 0),   // 右上
            CGPoint(x: w, y: h),   // 右下 (C)
            CGPoint(x: 0, y: h)    // 左下
        ]
        
        var points: [CGPoint] = []
        
        // ⭐️ 核心演算法：Sutherland-Hodgman 多邊形裁切
        for i in 0..<4 {
            let current = corners[i]
            let next = corners[(i + 1) % 4]
            
            let side1 = side(current)
            let side2 = side(next)
            
            // 處理當前的頂點
            if isFoldedPart {
                if side1 > 0 { points.append(reflect(current)) } // 被折過去的，反射後加入背面
            } else {
                if side1 <= 0 { points.append(current) }         // 沒被折到的，留在原地當底層
            }
            
            // 處理摺痕與紙張邊界的「交點」
            if side1 * side2 < 0 {
                let t = side1 / (side1 - side2)
                let intersection = CGPoint(
                    x: current.x + t * (next.x - current.x),
                    y: current.y + t * (next.y - current.y)
                )
                points.append(intersection) // 交點剛好在摺痕上，兩層共用
            }
        }
        
        // 連接所有計算出來的多邊形頂點
        if !points.isEmpty {
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
            path.closeSubpath()
        }
        
        return path
    }
}
