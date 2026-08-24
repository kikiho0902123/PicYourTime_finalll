//
//  StickyNoteCardView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/12.
//

import SwiftUI
import SwiftData

struct StickyNoteCardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var theme: ThemeManager
    
    @AppStorage("currentNoteText") private var noteText: String = ""

    @State private var dragX: CGFloat = 0.0
    @State private var dragY: CGFloat = 0.0
    @State private var tearOpacity: Double = 1.0
    
    let threshold: CGFloat = 160 // 物理撕下臨界點
    
    // 將 Hex 轉換為實際的 Color 物件供便利貼使用
    var dynamicStickyColor: Color {
        theme.theme1
    }
    
    var body: some View {
        GeometryReader { noteGeo in
            let w = noteGeo.size.width
            let h = noteGeo.size.height
            
            // 包覆「靜止底座」與「動態頂層」
            ZStack {
                
                // ==========================================
                // 1. 靜止的便利貼底座
                // ==========================================
                ZStack {
                    // 假厚度底層 2
                    UniversalPaperShape(dragX: 0, dragY: 0, isFoldedPart: false)
                        .fill(dynamicStickyColor)
                        .overlay(
                            UniversalPaperShape(dragX: 0, dragY: 0, isFoldedPart: false)
                                .fill(Color.black.opacity(0.02))
                        )
                        .offset(x: 5, y: 5)
                        .rotationEffect(Angle(degrees: 2))
                    
                    // 假厚度底層 1
                    UniversalPaperShape(dragX: 0, dragY: 0, isFoldedPart: false)
                        .fill(dynamicStickyColor)
                        .overlay(
                            UniversalPaperShape(dragX: 0, dragY: 0, isFoldedPart: false)
                                .fill(Color.black.opacity(0.01))
                        )
                        .offset(x: 2, y: 5)
                        .rotationEffect(Angle(degrees: -1))
                    
                    // 底座最上層：原色，負責產生打在背景上的主陰影
                    UniversalPaperShape(dragX: 0, dragY: 0, isFoldedPart: false)
                        .fill(dynamicStickyColor)
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 2, y: 4)
                }
                
                // ==========================================
                // 2. 原本可撕下的便利貼
                // ==========================================
                ZStack {
                    // 1. 底層靜止本體
                    UniversalPaperShape(dragX: dragX, dragY: dragY, isFoldedPart: false)
                        .fill(dynamicStickyColor)
                        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
                    
                    // 2. 內容層 (文字編輯框)
                    TextEditor(text: $noteText)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(theme.textColor)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(UniversalPaperShape(dragX: dragX, dragY: dragY, isFoldedPart: false))
                    
                    // 3. 頂層翻折背面 (疊加 15% 黑色遮罩模擬背面陰影)
                    UniversalPaperShape(dragX: dragX, dragY: dragY, isFoldedPart: true)
                        .fill(dynamicStickyColor)
                        .overlay(
                            UniversalPaperShape(dragX: dragX, dragY: dragY, isFoldedPart: true)
                                .fill(Color.black.opacity(0.02))
                        )
                        .shadow(color: .black.opacity(0.2),
                                radius: max(dragX, dragY) * 0.08,
                                x: -2,
                                y: -2)
                }
                .opacity(tearOpacity) // 撕下飛走時，只有這層會變透明
                
                // 熱區右下角
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: 100, height: 100)
                        .offset(x: 10, y: 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // 解除限制，允許無限往左上角拉扯
                                    dragX = max(0.1, -value.translation.width * 0.9)
                                    dragY = max(0.1, -value.translation.height * 0.9)
                                }
                                .onEnded { _ in handleRelease(w: w, h: h) }
                        )
                }
            }
        }
        .aspectRatio(1.2, contentMode: .fit) // 比例
        .frame(maxWidth: 300)              // 在這裡控制最大尺寸
        .frame(maxWidth: .infinity)        // 讓變小後的便利貼乖乖在畫面上置中
        .padding(.top, 10)
    }
    
    // ⭐️ 判定釋放時要回彈還是儲存
    private func handleRelease(w: CGFloat, h: CGFloat) {
        let pullDistance = sqrt(dragX * dragX + dragY * dragY)
        
        if pullDistance > threshold {
            saveAndResetNote(w: w, h: h)
        } else {
            // 彈回原位
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                dragX = 0.0
                dragY = 0.0
            }
        }
    }
    
    // ⭐️ 寫入資料庫並執行「極限拉扯飛走」動畫
    private func saveAndResetNote(w: CGFloat, h: CGFloat) {
        // 寫入資料庫
        if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let newNote = StickyNote(content: noteText)
            // 撕下的瞬間，把這張紙的顏色記憶在資料庫裡，這樣畫廊才認得！
            newNote.colorHex = theme.theme1Hex
            modelContext.insert(newNote)
        }
        
        // 飛走動畫 (使用演算法把角折到最大來營造撕下的視覺張力)
        withAnimation(.easeIn(duration: 0.3)) {
            dragX = w * 2
            dragY = h * 2
            tearOpacity = 0.0
        }
        
        // 重置並換新紙
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            noteText = ""
            dragX = 0.0
            dragY = 0.0
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                tearOpacity = 1.0
            }
        }
    }
}
