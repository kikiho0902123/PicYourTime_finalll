//
//  ColorDiarySheetView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/14.
//

import SwiftUI
import SwiftData

struct ColorDiarySheetView: View {
    // 接收傳進來的今日日記
    var existingEntry: DiaryEntry?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var theme: ThemeManager

    let aspectRatios: [(name: String, ratio: CGFloat)] = [
        ("3:4", 3/4),
        ("1:1", 1.0),
        ("4:3", 4/3)
    ]
    @State private var selectedRatioIndex = 0
    @State private var moodHue: Double = 0.5
    @State private var moodSaturation: Double = 1.0
    @State private var moodBrightness: Double = 0.8
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.bgColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 自製導覽列 (不受系統控制，與新增習慣統一)
                    HStack {
                        Spacer()
                        Text(existingEntry == nil ? "新增純色卡片" : "編輯純色卡片")
                            .font(.headline)
                            .foregroundColor(theme.textColor)
                        Spacer()
                    }
                    
                    // 右邊的儲存按鈕
                    .overlay(alignment: .trailing) {
                        Text("儲存")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(theme.theme2)
                            .clipShape(Capsule())
                            .padding(.trailing, 16)
                            .onTapGesture {
                                saveColorEntry()
                            }
                    }
                    .padding(.vertical, 10)
                    .padding(.top, 24)
                    
                    // 內容主體
                    ScrollView {
                        VStack(spacing: 32) {
                            // 外面包一個固定高度的隱形容器
                            ZStack {
                                Color.clear // 撐開空間，確保容器穩定
                                
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hue: moodHue, saturation: moodSaturation, brightness: moodBrightness))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                                    // 讓小卡的「寬度」固定為 200，高度由比例自動推算
                                    .aspectRatio(aspectRatios[selectedRatioIndex].ratio, contentMode: .fit)
                                    .frame(width: 160)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedRatioIndex)
                            }
                            // 設定容器的固定高度 (設 300 可以容納大多數比例，確保排版不跳動)
                            .frame(height: 220)
                            
                            Picker("比例", selection: $selectedRatioIndex) {
                                ForEach(0..<aspectRatios.count, id: \.self) { index in
                                    Text(aspectRatios[index].name).tag(index)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 40)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("今天的心情色調")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.textColor.opacity(0.7))
                                    .padding(.horizontal)
                                
                                MoodSpectrumView(
                                    hue: $moodHue,
                                    saturation: $moodSaturation,
                                    brightness: $moodBrightness
                                )
                                .padding(.horizontal)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 10)
            }
            // 把系統原生的導覽列隱藏
            .navigationBarHidden(true)
        }
        // 打開表單時，如果今天已經有紀錄，就把舊資料放回畫面上！
        .onAppear {
            if let entry = existingEntry {
                moodHue = entry.moodHue
                moodSaturation = entry.moodSaturation
                moodBrightness = entry.moodBrightness
                
                // 找出對應的比例選項
                if let index = aspectRatios.firstIndex(where: { abs($0.ratio - entry.aspectRatio) < 0.01 }) {
                    selectedRatioIndex = index
                }
            }
        }
    }
    
    private func saveColorEntry() {
        if let entry = existingEntry {
            // 如果今天已有日記，直接更新覆蓋，不要新增！
            entry.moodHue = moodHue
            entry.moodSaturation = moodSaturation
            entry.moodBrightness = moodBrightness
            entry.aspectRatio = aspectRatios[selectedRatioIndex].ratio
            entry.imageData = nil // 確保相片被洗掉，變回純色卡
        } else {
            // 如果今天是空白的，才執行新增
            let newEntry = DiaryEntry(
                content: "",
                moodHue: moodHue,
                moodSaturation: moodSaturation,
                moodBrightness: moodBrightness,
                imageData: nil,
                aspectRatio: aspectRatios[selectedRatioIndex].ratio
            )
            modelContext.insert(newEntry)
        }
        dismiss()
    }
}
