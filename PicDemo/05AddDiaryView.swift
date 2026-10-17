//
//  AddDiaryView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddDiaryView: View {
    var existingEntry: DiaryEntry? // 接收今日現有日記
    
    // ⭐️ 新增：接收外面傳進來的補登日期，如果沒有傳，預設就是「現在」
    var targetDate: Date = Date()
    
    // ⭐️ 新增：用來通知外面「存檔成功了」
    var onSaveSuccess: (() -> Void)? = nil
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: ThemeManager

    // 比例定義
    let aspectRatios: [(name: String, ratio: CGFloat)] = [
        ("3:4", 3/4),
        ("1:1", 1.0),
        ("4:3", 4/3)
    ]
    @State private var selectedRatioIndex = 0
    
    @State private var moodHue: Double = 0.5
    @State private var moodSaturation: Double = 1.0
    @State private var moodBrightness: Double = 0.8
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    // 把解壓縮好的圖片直接存在這，避免畫面重繪時閃爍
    @State private var selectedUIImage: UIImage? = nil
    
    // 相片手勢狀態
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // 獨立的吸管取色模式開關
    @State private var isEyedropperMode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.bgColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 自製導覽列 (不受系統控制，與純色卡片完全一致)
                    HStack {
                        Spacer()
                        Text(existingEntry == nil ? "影像日記" : "編輯影像")
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
                                savePhotoEntry()
                            }
                    }
                    .padding(.vertical, 10)
                    .padding(.top, 24)
                    
                    ScrollView {
                        // 內容主體
                        VStack(spacing: 0) {
                            // 上方預覽卡片視圖 (外包一個固定高度容器，防止切換比例時下方表單彈跳)
                            ZStack {
                                Color.clear // 撐開空間，確保容器穩定
                                
                                Color.clear
                                    .aspectRatio(aspectRatios[selectedRatioIndex].ratio, contentMode: .fit)
                                    .frame(width: 200) // 統一寬度，只變換高度
                                    .overlay(
                                        GeometryReader { geo in
                                            ZStack {
                                                // 打底顏色
                                                Color(hue: moodHue, saturation: moodSaturation, brightness: moodBrightness)
                                                
                                                // 直接使用記憶體中準備好的圖片
                                                if let uiImage = selectedUIImage {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: geo.size.width, height: geo.size.height)
                                                        .scaleEffect(scale)
                                                        .offset(offset)
                                                } else {
                                                    Text("點選下方按鈕加入照片")
                                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                                        .foregroundColor(theme.textColor.opacity(0.3))
                                                }
                                            }
                                            // 解決超出版面觸控
                                            // 宣告觸控感應區就只有這個 ZStack 的原本大小
                                            .contentShape(Rectangle())
                                            // 把拖曳跟縮放手勢裝在 ZStack 這個容器上
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        // 加個判斷，有照片時才允許改變數值
                                                        if selectedUIImage != nil {
                                                            offset = CGSize(
                                                                width: lastOffset.width + value.translation.width,
                                                                height: lastOffset.height + value.translation.height
                                                            )
                                                        }
                                                    }
                                                    .onEnded { _ in
                                                        if selectedUIImage != nil { lastOffset = offset }
                                                    }
                                                    .simultaneously(with:
                                                        MagnificationGesture()
                                                            .onChanged { value in
                                                                if selectedUIImage != nil { scale = lastScale * value }
                                                            }
                                                            .onEnded { _ in
                                                                if selectedUIImage != nil { lastScale = scale }
                                                            }
                                                    )
                                            )
                                            .clipped()
                                            // 吸管模式也直接使用準備好的圖片
                                            .overlay(
                                                Group {
                                                    if isEyedropperMode, let uiImage = selectedUIImage {
                                                        Color.white.opacity(0.001) // 隱形觸控層
                                                            .gesture(
                                                                DragGesture(minimumDistance: 0)
                                                                    .onChanged { value in
                                                                        sampleColor(at: value.location, in: geo, uiImage: uiImage)
                                                                    }
                                                            )
                                                    }
                                                }
                                            )
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(color: Color(hue: moodHue, saturation: moodSaturation, brightness: moodBrightness).opacity(0.2), radius: 8, x: 0, y: 3)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedRatioIndex)
                            }
                            .frame(height: 260) // 設定容器的固定高度
                            .padding(.top, 24)
                            
                            // 下方設定控制面板
                            VStack(spacing: 32) {
                                // 1. 相卡比例 (與純色卡片一樣放 Picker)
                                Picker("比例", selection: $selectedRatioIndex) {
                                    ForEach(0..<aspectRatios.count, id: \.self) { index in
                                        Text(aspectRatios[index].name).tag(index)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, 40)
                                
                                // 2. 影像來源
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("影像來源")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(theme.textColor.opacity(0.7))
                                        .padding(.horizontal)
                                    
                                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                                        HStack {
                                            Image(systemName: "photo.badge.plus.fill")
                                                .foregroundColor(theme.theme2)
                                            Text(selectedImageData == nil ? "上傳照片" : "更換其他相片")
                                                .foregroundColor(theme.textColor)
                                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                            Spacer() // 把內容推到左邊
                                        }
                                        .padding()
                                        .background(theme.textColor.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .padding(.horizontal)
                                    }
                                    .onChange(of: selectedItem) { _, newItem in
                                        Task {
                                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                                selectedImageData = data
                                                if let image = UIImage(data: data) {
                                                    selectedUIImage = image
                                                }
                                                
                                                scale = 1.0
                                                lastScale = 1.0
                                                offset = .zero
                                                lastOffset = .zero
                                                isEyedropperMode = false
                                            }
                                        }
                                    }
                                }
                                
                                // 3. 照片底色與吸管
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        Text("照片底色\n(想要呈現滿版照片可雙指放大預覽窗照片)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(theme.textColor.opacity(0.7))
                                            .lineSpacing(4)
                                        
                                        Spacer()
                                        
                                        if selectedUIImage != nil {
                                            Button(action: {
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    isEyedropperMode.toggle()
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: isEyedropperMode ? "eyedropper.halffull" : "eyedropper")
                                                }
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(isEyedropperMode ? .white : theme.theme3)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(isEyedropperMode ? theme.theme2 : theme.theme1)
                                                .clipShape(Capsule())
                                            }
                                            .textCase(nil)
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    MoodSpectrumView(hue: $moodHue, saturation: $moodSaturation, brightness: $moodBrightness)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if let entry = existingEntry {
                moodHue = entry.moodHue
                moodSaturation = entry.moodSaturation
                moodBrightness = entry.moodBrightness
                
                selectedImageData = entry.imageData
                if let data = entry.imageData {
                    selectedUIImage = UIImage(data: data)
                }
                
                scale = CGFloat(entry.imageScale)
                lastScale = CGFloat(entry.imageScale)
                offset = CGSize(width: entry.imageOffsetX, height: entry.imageOffsetY)
                lastOffset = CGSize(width: entry.imageOffsetX, height: entry.imageOffsetY)
                
                if let index = aspectRatios.firstIndex(where: { abs($0.ratio - entry.aspectRatio) < 0.01 }) {
                    selectedRatioIndex = index
                }
            }
        }
    }
    
    // 提取像素顏色
    private func sampleColor(at location: CGPoint, in geo: GeometryProxy, uiImage: UIImage) {
        let viewSize = geo.size
        let imageSize = uiImage.size
        
        let viewAspect = viewSize.width / viewSize.height
        let imageAspect = imageSize.width / imageSize.height
        
        var renderedWidth: CGFloat = 0
        var renderedHeight: CGFloat = 0
        
        if imageAspect > viewAspect {
            renderedWidth = viewSize.width
            renderedHeight = viewSize.width / imageAspect
        } else {
            renderedHeight = viewSize.height
            renderedWidth = viewSize.height * imageAspect
        }
        
        let touchX = location.x - (viewSize.width / 2)
        let touchY = location.y - (viewSize.height / 2)
        
        let unoffsetX = touchX - offset.width
        let unoffsetY = touchY - offset.height
        
        let unscaledX = unoffsetX / scale
        let unscaledY = unoffsetY / scale
        
        let finalX = unscaledX + (renderedWidth / 2)
        let finalY = unscaledY + (renderedHeight / 2)
        
        let pixelX = (finalX / renderedWidth) * imageSize.width
        let pixelY = (finalY / renderedHeight) * imageSize.height
        
        if let color = uiImage.getPixelColor(at: CGPoint(x: pixelX, y: pixelY)) {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                moodHue = Double(h)
                moodSaturation = Double(s)
                moodBrightness = Double(b)
            }
        }
    }
    
    private func savePhotoEntry() {
        if let entry = existingEntry {
            entry.moodHue = moodHue
            entry.moodSaturation = moodSaturation
            entry.moodBrightness = moodBrightness
            entry.imageData = selectedImageData
            entry.aspectRatio = aspectRatios[selectedRatioIndex].ratio
            entry.imageScale = Double(scale)
            entry.imageOffsetX = Double(offset.width)
            entry.imageOffsetY = Double(offset.height)
        } else {
            // ⭐️ 1. 恢復成你原本的寫法，不要塞入 date 參數
            let newEntry = DiaryEntry(
                date: targetDate,
                content: "",
                moodHue: moodHue,
                moodSaturation: moodSaturation,
                moodBrightness: moodBrightness,
                imageData: selectedImageData,
                aspectRatio: aspectRatios[selectedRatioIndex].ratio,
                imageScale: Double(scale),
                imageOffsetX: Double(offset.width),
                imageOffsetY: Double(offset.height)
            )
            
            // ⭐️ 2. 關鍵修改：在存入資料庫前，強行把它的日期改成我們要的補登日期！
            newEntry.date = targetDate
            modelContext.insert(newEntry)
        }
        // ⭐️ 新增這行：存檔成功，通知外層扣除額度！
        onSaveSuccess?()
        
        dismiss()
    }
}

// UIImage 像素提取擴充功能
extension UIImage {
    func getPixelColor(at coordinate: CGPoint) -> UIColor? {
        let x = Int(coordinate.x)
        let y = Int(coordinate.y)
        
        guard x >= 0 && x < Int(self.size.width) &&
              y >= 0 && y < Int(self.size.height) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData: [UInt8] = [0, 0, 0, 0]
        
        guard let context = CGContext(data: &pixelData,
                                      width: 1,
                                      height: 1,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        
        UIGraphicsPushContext(context)
        context.translateBy(x: CGFloat(-x), y: CGFloat(-y))
        self.draw(at: .zero)
        UIGraphicsPopContext()
        
        return UIColor(red: CGFloat(pixelData[0]) / 255.0,
                       green: CGFloat(pixelData[1]) / 255.0,
                       blue: CGFloat(pixelData[2]) / 255.0,
                       alpha: CGFloat(pixelData[3]) / 255.0)
    }
}
