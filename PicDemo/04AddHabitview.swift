//
//  AddHabitView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: ThemeManager
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var selectedColorHex: String = "C2E395"
    @State private var targetDays: Int = 21
    
    let icons = [
        "star.fill", "sparkles", "drop.fill", "figure.run",
        "fork.knife", "moon.fill", "book.fill", "pencil",
        "leaf.fill", "heart.fill", "music.note", "cart.fill"
    ]
    
    let colors = ["C2E395", "A8D8B9", "DCD4C1", "FFC8A2",
                  "FFB6B9", "F2A38A", "D4C4E9", "B3CDE0"]
    
    var body: some View {
        NavigationView {
            // 用 ZStack 將主題色墊在最底層
            ZStack {
                theme.theme1.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ==========================================
                    // 自己畫的導覽列 (絕對不受系統控制)...
                    // ==========================================
                    HStack {
                        Spacer()
                        Text("新增習慣")
                            .font(.headline)
                            .foregroundColor(theme.textColor)
                        Spacer()
                    }
                    // 覆蓋在右邊的自訂按鈕
                    .overlay(alignment: .trailing) {
                        Text("儲存")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(name.isEmpty ? theme.textColor.opacity(0.2) : theme.theme2)
                            .clipShape(Capsule())
                            .opacity(name.isEmpty ? 0.6 : 1.0)
                            .padding(.trailing, 16)
                            .onTapGesture {
                                guard !name.isEmpty else { return }
                                let newHabit = HabitItem(name: name, icon: selectedIcon, colorHex: selectedColorHex, targetDays: targetDays)
                                modelContext.insert(newHabit)
                                dismiss()
                            }
                    }
                    .padding(.vertical, 10)
                    .padding(.top, 24)
                    
                    // ==========================================
                    // 表單主體
                    // ==========================================
                    Form {
                        Section(header: Text("習慣名稱").foregroundColor(theme.textColor.opacity(0.7))) {
                            TextField("例如：喝水 2000cc", text: $name)
                                .listRowBackground(theme.bgColor)
                        }
                        
                        Section(header: Text("養成目標天數").foregroundColor(theme.textColor.opacity(0.7))) {
                            Picker("選擇天數", selection: $targetDays) {
                                ForEach(10...365, id: \.self) { day in
                                    Text("\(day) 天").tag(day)
                                    
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 80)
                            .listRowBackground(theme.bgColor)
                        }
                        
                        Section(header: Text("選擇圖示").foregroundColor(theme.textColor.opacity(0.7))) {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                                ForEach(icons, id: \.self) { icon in
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? Color(hex: selectedColorHex) : theme.textColor.opacity(0.4))
                                        .padding()
                                        .background(selectedIcon == icon ? Color(hex: selectedColorHex).opacity(0.2) : Color.clear)
                                        .cornerRadius(12)
                                        .onTapGesture {
                                            withAnimation { selectedIcon = icon }
                                        }
                                }
                            }
                            .listRowBackground(theme.bgColor)
                            
                        }
                        
                        Section(header: Text("代表顏色").foregroundColor(theme.textColor.opacity(0.7))) {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                                ForEach(colors, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(theme.textColor, lineWidth: selectedColorHex == hex ? 3 : 0)
                                        )
                                        .onTapGesture {
                                            withAnimation { selectedColorHex = hex }
                                        }
                                }
                            }
                            .listRowBackground(theme.bgColor)
                        }
                    }
                    // 隱藏 Form 內建的灰色表單底色，讓底層 ZStack 顏色透上來
                    .scrollContentBackground(.hidden)
                    // 讓 Form 也可以用滑動來收起鍵盤（這是 iOS 原生支援的）
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .padding(.horizontal, 10)
            .navigationBarHidden(true)
        }
        .presentationBackground(theme.theme1)
        .preferredColorScheme(ThemeEngine.isDarkBackground(hex: theme.bgColorHex) ? .dark : .light)
    }
}
