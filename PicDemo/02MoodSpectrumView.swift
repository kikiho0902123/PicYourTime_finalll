//
//  MoodSpectrumView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI

struct MoodSpectrumView: View {
    // 雙向綁定，將選好的顏色傳回給上層的 AddDiaryView
    @Binding var hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double
    
    // 儲存手指拖曳的座標位置
    @State private var dragLocation: CGPoint? = nil
    // 記錄畫布的真實尺寸，這樣按鈕才能知道隨機範圍
    @State private var canvasSize: CGSize = .zero
    
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            
            // 1. 2D 光譜畫布區域
            ZStack {
                // 底層：上下方向的彩虹色相 (Hue)
                LinearGradient(
                    gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // 中層：左到右的白色漸層 (控制飽和度)
                LinearGradient(
                    gradient: Gradient(colors: [.white, .white.opacity(0)]),
                    startPoint: .leading,
                    endPoint: .center
                )
                .blendMode(.screen)
                
                // 上層：右到左的黑色漸層 (控制明暗度)
                LinearGradient(
                    gradient: Gradient(colors: [.black, .black.opacity(0)]),
                    startPoint: .trailing,
                    endPoint: .center
                )
                .blendMode(.multiply)
                
                // 拖曳控制點 (小白圈)
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 30, height: 30)
                    .shadow(radius: 3)
                    // 如果還沒有座標，預設停在畫布正中央
                    .position(
                        x: dragLocation?.x ?? canvasSize.width / 2,
                        y: dragLocation?.y ?? canvasSize.height / 2
                    )
            }
            .frame(height: 150) // 固定畫布高度
            .cornerRadius(16)
            // 量測畫布在不同手機螢幕上的實際寬高
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { canvasSize = geo.size }
                }
            )
            // 捕捉手指拖曳
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = min(max(value.location.x, 0), canvasSize.width)
                        let y = min(max(value.location.y, 0), canvasSize.height)
                        dragLocation = CGPoint(x: x, y: y)
                        
                        updateColor(x: x, y: y, size: canvasSize)
                    }
            )
            
            // 隨機靈感按鈕
            Button(action: {
                // 在畫布寬高範圍內，隨機噴一個座標點
                let randomX = CGFloat.random(in: 0...canvasSize.width)
                let randomY = CGFloat.random(in: 0...canvasSize.height)
                
                // 加上 spring 彈簧動畫，讓小白圈滑過去
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    dragLocation = CGPoint(x: randomX, y: randomY)
                    updateColor(x: randomX, y: randomY, size: canvasSize)
                }
                
                // 觸發一個輕微的實體震動
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }) {
                Label("隨機靈感", systemImage: "dice.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.theme2)
                    .cornerRadius(12)
            }
        }
    }
    
    // 換算顏色的數學邏輯
    private func updateColor(x: CGFloat, y: CGFloat, size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        
        hue = Double(y / size.height)
        
        let xPercent = Double(x / size.width)
        if xPercent < 0.5 {
            saturation = xPercent * 2
            brightness = 1.0
        } else {
            saturation = 1.0
            brightness = 1.0 - ((xPercent - 0.5) * 2)
        }
    }
}
