//
//  DiaryView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI
import SwiftData
import Photos

enum DiarySheetType: Identifiable {
    case photo
    case color
    case rules
    var id: Self { self }
}

struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var theme: ThemeManager
    @Query private var entries: [DiaryEntry]
    @State private var currentDate: Date = Date()
    @State private var dragOffset: CGFloat = 0
    
    @State private var isFABExpanded = false
    @State private var activeSheet: DiarySheetType? = nil
    
    @State private var showHabitAlert = false
    
    // 控制「前往設定開啟相簿權限」的警告窗
    @State private var showSettingsAlert = false
    
    // ⭐️ 新增：用來追蹤目前這一輪連續打卡的補登額度
    @AppStorage("backfillUsedCount") private var backfillUsedCount: Int = 0
    @AppStorage("lastRecordedStreak") private var lastRecordedStreak: Int = 0
    @AppStorage("lastBackfillStreakStartKey") private var lastBackfillStreakStartKey: String = ""
    
    // ⭐️ 新增：動態警告文字
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // ⭐️ 新增：控制沒有連續打卡時的警告彈窗
    @State private var showNoStreakAlert = false
    // ⭐️ 新增：記錄目前哪一個過去的空白日子被點擊並「顯現出氣泡 Tooltip」
    @State private var selectedMissingDay: Int? = nil
    // ⭐️ 新增：控制全螢幕放大的相片
    @State private var enlargedEntry: DiaryEntry? = nil
    // ⭐️ 新增：記錄準備要補登的具體歷史日期
    @State private var backfillTargetDate: Date? = nil
    
    // 引入習慣資料庫
    @Query private var habits: [HabitItem]
    var hasCheckedInToday: Bool {
        let today = DateHelper.todayString
        return habits.contains { $0.completedDates.contains(today) }
    }
    
    // 控制快門閃光與 Toast 彈窗的狀態變數
    @State private var showScreenshotFlash = false
    @State private var showToast = false

    // ⭐️ 新增：控制規則說明小視窗的顯示
    @State private var showRulesPopover = false
    
    var diaryMonthlyData: [Int: DiaryEntry] {
        var data: [Int: DiaryEntry] = [:]
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        let filteredEntries = entries.filter { entry in
            let entryYear = calendar.component(.year, from: entry.date)
            let entryMonth = calendar.component(.month, from: entry.date)
            return entryYear == currentYear && entryMonth == currentMonth
        }
        
        for entry in filteredEntries.sorted(by: { $0.date < $1.date }) {
            let day = calendar.component(.day, from: entry.date)
            if let existingEntry = data[day] {
                if existingEntry.imageData == nil && entry.imageData != nil {
                    data[day] = entry
                } else if existingEntry.date <= entry.date {
                    data[day] = entry
                }
            } else {
                data[day] = entry
            }
        }
        return data
    }
    
    var todayEntry: DiaryEntry? {
        entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
            .last
    }
    
    var exportablePhotoWall: some View {
        VStack {
            Spacer()
            DiaryPhotoWallGrid(
                targetDate: currentDate,
                diaryData: diaryMonthlyData,
                isExportMode: true
                // 匯出模式不需要傳入點擊事件或狀態
            )
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color.clear)
    }
    
    var body: some View {
        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(currentDate, equalTo: Date(), toGranularity: .month)
        
        ZStack {
            Color(theme.bgColor).ignoresSafeArea()
            
            // 1. 底層：相片牆主體
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(currentDate.formatted(.dateTime.month(.wide)))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(theme.theme3)
                        .onTapGesture {
                            if !isCurrentMonth {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    currentDate = Date()
                                }
                            }
                        }
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                // ⭐️ 點擊問號開關氣泡
                .overlay(alignment: .leading) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showRulesPopover.toggle()
                        }
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 22))
                            .foregroundColor(theme.theme3.opacity(0.4))
                            .padding(.leading, 24)
                    }
                }
                
                VStack {
                    // ⭐️ 傳入狀態與各種點擊事件閉包
                    DiaryPhotoWallGrid(
                        targetDate: currentDate,
                        diaryData: diaryMonthlyData,
                        isExportMode: false,
                        selectedMissingDay: selectedMissingDay,
                        onPhotoTapped: { entry in
                            // 點擊過去的有照片日子 -> 放大
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                enlargedEntry = entry
                            }
                        },
                        onBackfillTapped: { day in
                            // ⭐️ 每次點擊都先同步一下目前的連續打卡狀態
                            syncStreakStatus()
                            
                            // 情況一：點擊的是已經彈出氣泡的「補照片」按鈕
                            if selectedMissingDay == day {
                                let currentStreak = calculateMaxStreak()
                                // 計算可用額度：滿 3 天才解鎖，解鎖後 1 天可補 1 張
                                let availableQuota = currentStreak >= 3 ? max(0, currentStreak - backfillUsedCount) : 0
                                
                                if availableQuota > 0 {
                                    // 額度夠，允許開啟補登 Sheet
                                    var comps = calendar.dateComponents([.year, .month], from: currentDate)
                                    comps.day = day
                                    if let target = calendar.date(from: comps) {
                                        backfillTargetDate = target
                                        activeSheet = .photo
                                        selectedMissingDay = nil // 收起氣泡
                                    }
                                } else {
                                    // 額度不夠，根據情況給予不同提示
                                    if currentStreak == 0 {
                                        alertTitle = String(localized: "養成習慣才能補照片喔")
                                        alertMessage = String(localized: "請先認真培養習慣，連續打卡才能獲得補照片的額度喔！")
                                    } else {
                                        // 額度不夠，根據情況給予不同提示
                                        if currentStreak < 3 {
                                            // ⭐️ 針對未滿 3 天的新手提示
                                            alertTitle = String(localized: "還差一點點喔！")
                                            // 變數包在裡面，Xcode String Catalog 會自動變成 %lld
                                            alertMessage = String(localized: "必須「連續打卡滿 3 天」才能解鎖補照片的權限！你目前連續 \(currentStreak) 天，再堅持一下下！")
                                        } else {
                                            // ⭐️ 滿 3 天但額度用光的提示
                                            alertTitle = String(localized: "補照片額度已用完")
                                            alertMessage = String(localized: "目前的連續打卡為 \(currentStreak) 天，已用完可補照片的張數。請明天繼續打卡來獲得更多額度！")
                                        }
                                    }
                                    showNoStreakAlert = true
                                    withAnimation { selectedMissingDay = nil }
                                }
                            }
                            // 情況二：第一次點擊過去的空白格子
                            else {
                                // 無條件直接彈出氣泡
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedMissingDay = day
                                }
                            }
                        },
                        onCloseTooltip: {
                            // 點擊隱形遮罩時收起氣泡
                            selectedMissingDay = nil
                        }
                    )
                }
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
            }
            .offset(y: dragOffset)
            .id(currentDate.description)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .gesture( // 上下滑查看月份
                DragGesture()
                    .onChanged { value in
                        if isCurrentMonth && value.translation.height < 0 {
                            dragOffset = value.translation.height / 4
                        } else {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 60
                        if value.translation.height < -threshold {
                            let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                            if calendar.compare(nextMonth, to: Date(), toGranularity: .month) != .orderedDescending {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    currentDate = nextMonth
                                    dragOffset = 0
                                    selectedMissingDay = nil // 換月時收起氣泡
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    dragOffset = 0
                                }
                            }
                        } else if value.translation.height > threshold {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
                                dragOffset = 0
                                selectedMissingDay = nil // 換月時收起氣泡
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                // 點擊背景空白處自動收回氣泡
                withAnimation { selectedMissingDay = nil }
            }
            
            if isFABExpanded {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { toggleFAB() }
            }
            
            // 2. 按鈕層
            VStack {
                Spacer()
                ZStack {
                    SubActionButton(icon: "arrow.down.to.line", color: theme.theme3) {
                        toggleFAB()
                        checkAndSavePhotoWallImage()
                    }
                    .offset(x: isFABExpanded ? -70 : 0, y: isFABExpanded ? -55 : 0)
                    .opacity(isFABExpanded ? 1 : 0)
                    
                    SubActionButton(icon: "camera.fill", color: theme.theme3) {
                        toggleFAB()
                        if hasCheckedInToday {
                            activeSheet = .photo
                        } else {
                            showHabitAlert = true
                        }
                    }
                    .offset(x: 0, y: isFABExpanded ? -95 : 0)
                    .opacity(isFABExpanded ? 1 : 0)
                    
                    SubActionButton(icon: "paintpalette.fill", color: theme.theme3) {
                        toggleFAB()
                        activeSheet = .color
                    }
                    .offset(x: isFABExpanded ? 70 : 0, y: isFABExpanded ? -55 : 0)
                    .opacity(isFABExpanded ? 1 : 0)
                    
                    Button(action: toggleFAB) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(theme.theme3)
                            .rotationEffect(.degrees(isFABExpanded ? 45 : 0))
                            .frame(width: 64, height: 64)
                            .background(theme.theme2)
                            .clipShape(Circle())
                            .shadow(color: theme.theme3.opacity(0.1), radius: 10, x: 0, y: 4)
                    }
                }
                .padding(.bottom, 36)
            }
            
            // 3. 全螢幕相機快門閃光動效
            if showScreenshotFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(99)
            }
            
            // 4. 自動消失的 Toast 提示小膠囊
            if showToast {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(theme.theme2)
                        Text("已儲存本月照片貼紙！")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.theme1.opacity(0.9))
                    .blurBackgroundEffect(style: .systemMaterialLight)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
            }
            
            // ⭐️ 規則說明小視窗與點擊空白處收起的隱形遮罩
            if showRulesPopover {
                // 隱形全螢幕遮罩，點擊收起
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showRulesPopover = false
                        }
                    }
                    .zIndex(90)
                
                // 氣泡本體
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 14) {
                            RuleRowCompact(icon: "camera.fill", text: "今日有打卡習慣即可新增當天照片。")
                            RuleRowCompact(icon: "lock.open.fill", text: "連續打卡滿 3 天解鎖「補照片」功能。")
                            RuleRowCompact(icon: "photo.badge.plus", text: "每輪可補數量 = 連續打卡天數 - 本輪已補張數。")
                            RuleRowCompact(icon: "exclamationmark.arrow.circlepath", text: "若打卡中斷，重新連續滿 3 天會開啟新一輪額度。")
                        }
                        .padding(18)
                        .background(theme.theme1)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
                        .frame(maxWidth: 280) // 控制氣泡不要太寬
                        
                        Spacer() // 把氣泡推到左邊
                    }
                    .padding(.leading, 24) // 對齊問號的左邊距
                    .padding(.top, 60) // 往下推到問號正下方
                    
                    Spacer() // 把氣泡推到上面
                }
                .zIndex(91)
                // ⭐️ 設定動畫錨點在左上角，營造從問號展開的視覺效果
                .transition(.scale(scale: 0.5, anchor: .topLeading).combined(with: .opacity))
            }
            // ⭐️ 5. 全螢幕相片放大圖層 (完整包含底色、比例與排版)
            if let entry = enlargedEntry {
                ZStack {
                    // 微黑半透明背景
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    GeometryReader { screenGeo in
                        // ⭐️ 內層 ZStack：強制與物理螢幕(包含瀏海與 TabBar 區域)完全等大，藉此達成絕對置中！
                        ZStack {
                            // 重建放大的「完整照片小卡」
                            Color.clear
                                .aspectRatio(CGFloat(entry.aspectRatio), contentMode: .fit)
                                .frame(maxWidth: screenGeo.size.width * 0.85)
                                .overlay(
                                    GeometryReader { geo in
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(entry.moodColor)
                                            
                                            if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                                                let scaleFactor = geo.size.width / 350.0
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: geo.size.width, height: geo.size.height)
                                                    .scaleEffect(CGFloat(entry.imageScale))
                                                    .offset(x: CGFloat(entry.imageOffsetX) * scaleFactor,
                                                            y: CGFloat(entry.imageOffsetY) * scaleFactor)
                                            }
                                        }
                                        .clipped()
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                                // ⭐️ 關鍵微調：視覺置中校正 (往下推 25 點，你可以隨意更改這個數字)
                                .offset(y: 25)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                        // ⭐️ 關鍵：強制填滿 GeometryReader 的所有空間
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                    }
                }
                // ⭐️ 關鍵：強制最外層容器完全無視 TabBar 與瀏海，這樣幾何中心才會是物理螢幕的中心
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        enlargedEntry = nil
                    }
                }
                .zIndex(100) // 確保疊在最上層
            }
            
        } // ZStack 結束
        .sheet(item: $activeSheet) { sheetType in
            Group {
                if sheetType == .color {
                    ColorDiarySheetView(existingEntry: todayEntry)
                } else if sheetType == .photo {
                    AddDiaryView(
                        existingEntry: backfillTargetDate != nil ? nil : todayEntry,
                        targetDate: backfillTargetDate ?? Date(),
                        // ⭐️ 傳入成功儲存的回呼閉包
                        onSaveSuccess: {
                            // 只有「歷史補登」成功存檔時，才扣除額度
                            if backfillTargetDate != nil {
                                backfillUsedCount += 1
                            }
                        }
                    )
                }
            }
            .presentationDetents([.fraction(0.88), .large])
            .onDisappear { backfillTargetDate = nil }
        }
        .alert("無法新增照片日記", isPresented: $showHabitAlert) {
            Button("我知道了", role: .cancel) { }
        } message: {
            Text("請先完成今日的習慣打卡，才能解鎖相片日記的權限喔！")
        }
        // ⭐️ 連續打卡檢查失敗的警告窗
        .alert(alertTitle, isPresented: $showNoStreakAlert) {
            Button("我會努力", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("無法儲存照片", isPresented: $showSettingsAlert) {
            Button("取消", role: .cancel) { }
            Button("前往設定") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("您似乎尚未允許相簿存取權限。請前往系統設定中開啟，才能將相片牆下載下來喔！")
        }
    }
    
    private struct BackfillStreakState {
        let count: Int
        let startKey: String
    }

    // ⭐️ 核心演算法：計算所有習慣中最高的「目前連續打卡天數」
    private func calculateMaxStreak() -> Int {
        currentBackfillStreakState().count
    }
    
    private func currentBackfillStreakState() -> BackfillStreakState {
        var bestState = BackfillStreakState(count: 0, startKey: "")
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for habit in habits {
            var streak = 0
            var checkDate = calendar.startOfDay(for: Date())
            
            // 體感優化：如果今天還沒打卡，先看昨天有沒有完成
            let todayStr = formatter.string(from: checkDate)
            if !habit.completedDates.contains(todayStr) {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
            
            while true {
                let dateStr = formatter.string(from: checkDate)
                if habit.completedDates.contains(dateStr) {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else {
                    break
                }
            }

            guard streak > 0,
                  let startDate = calendar.date(byAdding: .day, value: 1, to: checkDate) else {
                continue
            }

            let startKey = formatter.string(from: startDate)
            if streak > bestState.count || (streak == bestState.count && startKey > bestState.startKey) {
                bestState = BackfillStreakState(count: streak, startKey: startKey)
            }
        }
        return bestState
    }
    
    // ⭐️ 新增：用連續打卡的起始日判斷是否進入新一輪，避免新一輪 3 天仍沿用舊額度
    private func syncStreakStatus() {
        let state = currentBackfillStreakState()
        if state.count == 0 {
            backfillUsedCount = 0
            lastBackfillStreakStartKey = ""
        } else if state.startKey != lastBackfillStreakStartKey {
            backfillUsedCount = 0
            lastBackfillStreakStartKey = state.startKey
        }
        lastRecordedStreak = state.count
    }
    
    private func toggleFAB() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFABExpanded.toggle()
        }
    }
    
    // 負責檢查權限的函式
    private func checkAndSavePhotoWallImage() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        if status == .authorized || status == .limited {
            Task { @MainActor in executePhotoSave() }
        } else if status == .denied || status == .restricted {
            showSettingsAlert = true
        } else {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                Task { @MainActor in
                    if newStatus == .authorized || newStatus == .limited {
                        executePhotoSave()
                    } else {
                        showSettingsAlert = true
                    }
                }
            }
        }
    }
    
    // 處理圖片渲染與存檔
    @MainActor
    private func executePhotoSave() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let screenBounds = window.screen.bounds
        let screenScale = window.screen.scale
        
        let renderView = exportablePhotoWall
            .frame(width: screenBounds.width, height: screenBounds.height)
        
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = screenScale
        renderer.isOpaque = false
        
        if let uiImage = renderer.uiImage, let pngData = uiImage.pngData() {
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: pngData, options: nil)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        showScreenshotFlash = true
                        withAnimation(.easeOut(duration: 0.35)) {
                            showScreenshotFlash = false
                        }
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showToast = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showToast = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// 幫彈窗加上超質感的蘋果原生磨砂玻璃底襯
extension View {
    func blurBackgroundEffect(style: UIBlurEffect.Style) -> some View {
        self.background(BlurRepresentable(style: style))
    }
}

struct BlurRepresentable: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// 米奇按鈕實作
struct SubActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.theme3)
                .frame(width: 50, height: 50)
                .background(theme.theme1)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }
}

// ==========================================
// 日記照片網格
// ==========================================
struct DiaryPhotoWallGrid: View {
    var targetDate: Date
    var diaryData: [Int: DiaryEntry]
    var isExportMode: Bool = false
    
    // ⭐️ 接收從外層傳來的狀態與閉包
    var selectedMissingDay: Int? = nil
    var onPhotoTapped: ((DiaryEntry) -> Void)? = nil
    var onBackfillTapped: ((Int) -> Void)? = nil
    var onCloseTooltip: (() -> Void)? = nil
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .center), count: 5)
    @EnvironmentObject var theme: ThemeManager
    
    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: targetDate)?.count ?? 31
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(1...daysInMonth, id: \.self) { day in
                let timeState = getTimeState(for: day)
                
                DiaryPhotoCell(
                    day: day,
                    entry: diaryData[day],
                    timeState: timeState,
                    isExportMode: isExportMode,
                    selectedMissingDay: selectedMissingDay,
                    onPhotoTapped: onPhotoTapped,
                    onBackfillTapped: onBackfillTapped,
                    onCloseTooltip: onCloseTooltip
                )
            }
        }
        .shadow(color: isExportMode ? .clear : Color.black.opacity(0.01), radius: 5, x: 1, y: 2)
    }
    
    enum TimeState { case past, today, future }
    
    private func getTimeState(for day: Int) -> TimeState {
        let calendar = Calendar.current
        let today = Date()
        
        var comps = calendar.dateComponents([.year, .month], from: targetDate)
        comps.day = day
        guard let cellDate = calendar.date(from: comps) else { return .future }
        
        if calendar.isDate(cellDate, inSameDayAs: today) {
            return .today
        } else if cellDate < today {
            return .past
        } else {
            return .future
        }
    }
}

// ==========================================
// 日記照片卡片
// ==========================================
struct DiaryPhotoCell: View {
    let day: Int
    let entry: DiaryEntry?
    let timeState: DiaryPhotoWallGrid.TimeState
    var isExportMode: Bool = false
    
    var selectedMissingDay: Int?
    var onPhotoTapped: ((DiaryEntry) -> Void)?
    var onBackfillTapped: ((Int) -> Void)?
    var onCloseTooltip: (() -> Void)?
    
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        Color.clear
            .aspectRatio(0.83, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        if !isExportMode {
                            Image("\(day)")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(timeState == .today ? theme.theme2 : theme.theme3.opacity(0.12))
                                .padding(12)
                        }
                        
                        if let entry {
                            DiaryPhotoCard(entry: entry, availableSize: geo.size)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let entry, entry.imageData != nil, timeState == .past {
                    onPhotoTapped?(entry)
                } else if entry == nil, timeState == .past {
                    onBackfillTapped?(day)
                }
            }
            .overlay {
                if entry == nil, selectedMissingDay == day, !isExportMode {
                    ZStack {
                        Color.black.opacity(0.001)
                            .frame(width: 1000, height: 1000)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onCloseTooltip?()
                                }
                            }
                        
                        VStack(spacing: -2) {
                            Button(action: {
                                onBackfillTapped?(day)
                            }) {
                                Text("補照片")
                                    .font(.system(size: 10, weight: .bold))
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundColor(theme.theme3)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.95))
                                    .cornerRadius(8)
                            }
                            
                            Image(systemName: "arrowtriangle.down.fill")
                                .resizable()
                                .frame(width: 8, height: 6)
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .offset(x: 0, y: -39)
                    }
                }
            }
            .zIndex(selectedMissingDay == day ? 100 : 0)
    }
    
}

struct DiaryPhotoCard: View {
    let entry: DiaryEntry
    let availableSize: CGSize
    @State private var uiImage: UIImage?
    
    var body: some View {
        let cardSize = fittedCardSize(aspectRatio: CGFloat(entry.aspectRatio), in: availableSize)
        let cornerRadius: CGFloat = 3
        
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius).fill(entry.moodColor)
            if let uiImage {
                let scaleFactor = cardSize.width / 350.0
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: cardSize.width, height: cardSize.height)
                    .scaleEffect(CGFloat(entry.imageScale))
                    .offset(x: CGFloat(entry.imageOffsetX) * scaleFactor,
                            y: CGFloat(entry.imageOffsetY) * scaleFactor)
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear(perform: updateImage)
        .onChange(of: entry.imageData) { _, _ in
            updateImage()
        }
    }
    
    private func updateImage() {
        if let imageData = entry.imageData {
            uiImage = UIImage(data: imageData)
        } else {
            uiImage = nil
        }
    }
    
    private func fittedCardSize(aspectRatio: CGFloat, in availableSize: CGSize) -> CGSize {
        guard aspectRatio > 0, availableSize.width > 0, availableSize.height > 0 else {
            return .zero
        }
        
        let availableRatio = availableSize.width / availableSize.height
        if availableRatio > aspectRatio {
            let height = availableSize.height
            return CGSize(width: height * aspectRatio, height: height)
        } else {
            let width = availableSize.width
            return CGSize(width: width, height: width / aspectRatio)
        }
    }
}

// ==========================================
// 規則說明氣泡的小排版元件
// ==========================================
struct RuleRowCompact: View {
    var icon: String // Icon 名稱是給系統找圖的，維持 String，不用翻譯
    var text: LocalizedStringKey
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(theme.theme3.opacity(0.7))
                .frame(width: 20, alignment: .center)
            
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(theme.textColor.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
