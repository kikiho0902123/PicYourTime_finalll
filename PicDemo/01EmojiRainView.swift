//
//  01EmojiRainView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/9.
//

import SwiftUI

struct EmojiDrop: Identifiable {
    let id = UUID()
    let character: String
    let xPosition: CGFloat
    let size: CGFloat
    let duration: Double
    let delay: Double
}

// 滿版隨機掉落動畫視圖
struct EmojiRainView: View {
    // 狀態：控制動畫起迄與掉落物陣列
    @State private var isAnimating = false
    @State private var drops: [EmojiDrop] = []
    
    // 內建表情符號圖庫
    let emojiPool = [
        "🎉", "🙌", "🔥", "🚀", "🌟", "🥳", "💯", "✨", "👏", "💪",
        "🎈", "🎁", "🎊", "🤩", "🧁", "🍪", "☕️", "🍀", "🍄", "🐱",
        " Foxes", "🦊", "🐻", "🧸", "🐼", "🐨", "🐰", "🐯", "🦁", "🦖",
        "🦄", "🥑", "🍕", "🌈", "☀️", "🌙", "🔮", "🎀", "🔑", "❤️",
        "💛", "💚", "💙", "💜", "🧡", "💖", "🍿", "🍩", "🎯", "🎮",
        "🎨", "🎼", "🎸", "🌸", "🌻", "🌿", "🐾", "🎐", "🍡", "🍦",
        "🍎", "🍋", "🍓", "🍉", "🥞", "🍟", "🍙", "🧋", "⛱️", "🪅"
    ]
    
    var body: some View {
        // 取得當前螢幕尺寸以利計算掉落邊界
        GeometryReader { geo in
            ZStack {
                // 依序渲染每一顆掉落物
                ForEach(drops) { drop in
                    Text(drop.character)
                        .font(.system(size: drop.size))
                        // 動畫軌跡：未啟動時在畫面上方 (-60)，啟動後移動至畫面底部外
                        .position(x: drop.xPosition, y: isAnimating ? geo.size.height + 60 : -60)
                        // 設定無限迴圈，並套用各自專屬的掉落速度與延遲
                        .animation(
                            .linear(duration: drop.duration)
                            .delay(drop.delay)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                // 視圖載入時產生掉落物
                generateDrops(width: geo.size.width)
                
                // 確保佈局完成後再觸發狀態變更，啟動位移動畫
                DispatchQueue.main.async {
                    isAnimating = true
                }
            }
        }
        // 穿透點擊事件，避免整層動畫遮擋底層主畫面的互動
        .allowsHitTesting(false)
    }
    
    // 產生隨機掉落物陣列的邏輯
    private func generateDrops(width: CGFloat) {
        // 每次只抽取單一種圖案作為當次主題
        let currentTheme = emojiPool.shuffled().prefix(1)
        
        var newDrops: [EmojiDrop] = []
        // 產生 40 顆掉落物
        for _ in 0..<40 {
            newDrops.append(
                EmojiDrop(
                    character: currentTheme.randomElement() ?? "🎉",
                    // 亂數決定 X 軸座標、字體大小、掉落秒數與出場延遲
                    xPosition: CGFloat.random(in: 0...width),
                    size: CGFloat.random(in: 20...40),
                    duration: Double.random(in: 1.5...3.0),
                    delay: Double.random(in: 0...2.0)
                )
            )
        }
        drops = newDrops
    }
}
