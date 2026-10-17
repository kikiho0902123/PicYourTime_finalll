//
//  SettingsView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/8.12.
//

import SwiftUI
import SwiftData
import UserNotifications

struct AppTheme: Identifiable, Equatable {
    let id: Int
    let name: String
    let bgColorHex: String
    let theme1Hex: String
    let theme2Hex: String
    let theme3Hex: String
}

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    
    // --- API 與動態島設置 ---
    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("timerDuration") private var timerDuration = 25
    
    // --- 動態島與通知自訂文字 ---
    @AppStorage("notifTitle") private var notifTitle = String(localized: "要不要休息一下")
    @AppStorage("notifBody") private var notifBody = String(localized: "時間到了，該讓眼睛和大腦活動活動喔～")
    @AppStorage("lockScreenTitle") private var lockScreenTitle = String(localized: "你現在真的想滑手機嗎？")
    @AppStorage("actionButtonText") private var actionButtonText = String(localized: "不滑了！")
    
    // 讓設定頁可以撈到所有待辦事項，好交給通知大腦排程
    @Query private var allTodos: [TodoItem]
    
    // 待辦通知設定的儲存變數
    @AppStorage("isTodoNotifEnabled") private var isTodoNotifEnabled = false
    @AppStorage("todoDaysAhead") private var todoDaysAhead = 0 // 0=當天, 1=前一天...
    @AppStorage("todoNotifHour") private var todoNotifHour = 8
    @AppStorage("todoNotifMinute") private var todoNotifMinute = 0
    @AppStorage("isStatelessTodoNotifEnabled") private var isStatelessTodoNotifEnabled = false
    @AppStorage("statelessTodoInterval") private var statelessTodoInterval = 1 // 1~7天
    @State private var selectedTime: Date = Date() // 用於 UI 綁定時間選擇器的中介變數
    
    // --- 日記打卡通知的儲存變數 ---
    @AppStorage("isDiaryNotifEnabled") private var isDiaryNotifEnabled = false
    @AppStorage("diaryNotifHour") private var diaryNotifHour = 23 // 預設 23 點
    @AppStorage("diaryNotifMinute") private var diaryNotifMinute = 0  // 預設 0 分
    
    // 預設讓 AI 用繁體中文回覆
    @AppStorage("aiResponseLanguage") private var aiResponseLanguage = "繁體中文"
    
    // --- 鎖定時間的自訂綁定---
    private var todoTimeBinding: Binding<Date> {
        Binding(
            get: {
                var calendar = Calendar.autoupdatingCurrent
                calendar.timeZone = .autoupdatingCurrent
                return calendar.date(bySettingHour: todoNotifHour, minute: todoNotifMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                var calendar = Calendar.autoupdatingCurrent
                calendar.timeZone = .autoupdatingCurrent
                let components = calendar.dateComponents([.hour, .minute], from: newValue)
                todoNotifHour = components.hour ?? 8
                todoNotifMinute = components.minute ?? 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    TodoNotificationManager.shared.updateNotifications(todos: allTodos)
                }
            }
        )
    }
    
    // --- 控制提前天數的自訂綁定 ---
    private var daysAheadBinding: Binding<Int> {
        Binding(
            get: { todoDaysAhead },
            set: { newValue in
                todoDaysAhead = newValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    TodoNotificationManager.shared.updateNotifications(todos: allTodos)
                }
            }
        )
    }
    
    // --- 控制提醒頻率的自訂綁定 ---
    private var statelessIntervalBinding: Binding<Int> {
        Binding(
            get: { statelessTodoInterval },
            set: { newValue in
                statelessTodoInterval = newValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    TodoNotificationManager.shared.updateNotifications(todos: allTodos)
                }
            }
        )
    }
    
    private var diaryTimeBinding: Binding<Date> {
        Binding(
            get: {
                var calendar = Calendar.autoupdatingCurrent
                calendar.timeZone = .autoupdatingCurrent
                return calendar.date(bySettingHour: diaryNotifHour, minute: diaryNotifMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                var calendar = Calendar.autoupdatingCurrent
                calendar.timeZone = .autoupdatingCurrent
                let components = calendar.dateComponents([.hour, .minute], from: newValue)
                diaryNotifHour = components.hour ?? 23
                diaryNotifMinute = components.minute ?? 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateDiaryNotification()
                }
            }
        )
    }
    
    // --- 主題控制狀態 ---
    @AppStorage("selectedThemeID") private var selectedThemeID = 0
    @AppStorage("isCustomTheme") private var isCustomTheme = false
    
    // --- 自訂輸入框的暫存狀態 ---
    @State private var customBgInput: String = ""
    @State private var customTheme1Input: String = ""
    @State private var customTheme2Input: String = ""
    @State private var customTheme3Input: String = ""
    
    // --- 警示視窗控制 ---
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showCustomThemeWarning = false
    @State private var showTutorialPopup = false
    
    // --- ⭐️ 新增：四大主分類折疊狀態控制 ---
    @State private var isShortcutsExpanded = false
    @State private var isNotificationsExpanded = false
    @State private var isAppearanceExpanded = false
    @State private var isAIExpanded = false
    
    private var areAllSectionsClosed: Bool {
        !isShortcutsExpanded && !isNotificationsExpanded && !isAppearanceExpanded && !isAIExpanded
    }
    
    let presetThemes: [AppTheme] = [
        AppTheme(id: 0, name: String(localized: "抹茶燕麥"), bgColorHex: "F4F1E6", theme1Hex: "E8EBCF", theme2Hex: "C2E395", theme3Hex: "35522B"),
        AppTheme(id: 1, name: String(localized: "夕陽蜜桃"), bgColorHex: "FCF6F2", theme1Hex: "F7E1D7", theme2Hex: "F9B2A6", theme3Hex: "8E4A42"),
        AppTheme(id: 2, name: String(localized: "深夜星際"), bgColorHex: "1A1B20", theme1Hex: "2A2C37", theme2Hex: "4E5467", theme3Hex: "A5B4FC")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgColor.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        
                        Image(.loading3)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 280)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(theme.theme2)
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                        
                        // ==========================================
                        // Section 1: 捷徑功能
                        // ==========================================
                        sectionToggle(title: "捷徑功能", isExpanded: $isShortcutsExpanded) {
                            
                            // 1. 計時長度
                            HStack {
                                Text("計時長度")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textColor)
                                
                                Spacer()
                                
                                HStack(spacing: 10) {
                                    // 減號按鈕
                                    Button(action: {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        
                                        if timerDuration > 5 { timerDuration -= 5 }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(timerDuration > 5 ? theme.theme3 : theme.textColor.opacity(0.2))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // 顯示目前時間
                                    Text("\(timerDuration) 分")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(theme.theme3)
                                        .frame(width: 60, alignment: .center)
                                    
                                    // 加號按鈕
                                    Button(action: {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        
                                        if timerDuration < 60 { timerDuration += 5 }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(timerDuration < 50 ? theme.theme3 : theme.textColor.opacity(0.2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            
                            // 2. 自訂文字 (攤開並縮排)
                            VStack(alignment: .leading, spacing: 16) {
                                Text("自訂橫幅與通知文字")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textColor)
                                
                                // 輸入框與預覽整包一起向右縮排
                                VStack(alignment: .leading, spacing: 16) {
                                    
                                    // 輸入區
                                    VStack(spacing: 12) {
                                        customTextInputRow(label: "通知標題", text: $notifTitle)
                                        customTextInputRow(label: "通知內文", text: $notifBody)
                                        customTextInputRow(label: "鎖屏標題", text: $lockScreenTitle)
                                        customTextInputRow(label: "按鈕文字", text: $actionButtonText)
                                    }
                                    .padding(.leading, 20)
                                    
                                    // 預覽區
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("效果預覽")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(theme.textColor.opacity(0.5))
                                            .padding(.top, 8)
                                        
                                        // 預覽：推播通知橫幅
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "app.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 36, height: 36)
                                                .foregroundColor(theme.theme2.opacity(0.5))
                                                .background(Color.white)
                                                .cornerRadius(8)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(notifTitle.isEmpty ? String(localized: "通知標題") : notifTitle)
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundColor(theme.textColor)
                                                Text(notifBody.isEmpty ? String(localized: "通知內文") : notifBody)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(theme.textColor.opacity(0.8))
                                                    .lineLimit(2)
                                            }
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(theme.theme1.opacity(0.6))
                                        .cornerRadius(16)
                                        
                                        // 預覽：鎖定畫面
                                        VStack(spacing: 12) {
                                            Text(lockScreenTitle.isEmpty ? String(localized: "鎖屏標題") : lockScreenTitle)                                   .font(.system(size: 14, weight: .bold))
                                            
                                            ProgressView(value: 0.6)
                                                .progressViewStyle(.linear)
                                                .tint(theme.theme3)
                                            
                                            Text(actionButtonText.isEmpty ? String(localized: "按鈕文字") : actionButtonText)
                                                .font(.headline)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(theme.theme3)
                                                .foregroundColor(.white)
                                                .cornerRadius(12)
                                        }
                                        .padding(16)
                                        .background(Color.black.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(20)
                                        
                                        // 預覽：動態島展開
                                        VStack(spacing: 16) {
                                            HStack {
                                                Image("island_icon")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundColor(theme.theme2)
                                                    .frame(width: 22, height: 22)
                                                Spacer()
                                                Text("\(timerDuration):00") // 預覽時間與設定連動
                                                    .monospacedDigit()
                                                    .foregroundColor(theme.theme3)
                                                    .font(.headline)
                                            }
                                            
                                            ProgressView(value: 0.6)
                                                .progressViewStyle(.linear)
                                                .tint(theme.theme3)
                                            
                                            Text(actionButtonText.isEmpty ? String(localized: "按鈕文字") : actionButtonText)
                                                .font(.headline)
                                                .padding(.vertical, 10)
                                                .frame(maxWidth: .infinity)
                                                .background(theme.theme3)
                                                .foregroundColor(theme.theme2)
                                                .cornerRadius(20)
                                        }
                                        .padding(16)
                                        .background(Color.black.opacity(0.9))
                                        .cornerRadius(24)
                                    }
                                }
                            }
                                                        
                            // 3. 如何設置捷徑
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    showTutorialPopup = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                    Text("如何設定捷徑通知？")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textColor)
                            }
                            .buttonStyle(.plain)
                            .padding( .top, 10)
                        }
                        
                        thinDivider
                        
                        // ==========================================
                        // Section 2: 通知
                        // ==========================================
                        sectionToggle(title: "通知", isExpanded: $isNotificationsExpanded) {
                            
                            // 1. 有日期標籤的待辦提醒
                            customToggle(label: "有日期標籤的待辦提醒", isOn: $isTodoNotifEnabled) {
                                updateTodoNotificationsAfterPermissionChange()
                            }
                            
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("提前")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(theme.textColor)
                                    Spacer()
                                    Picker("提前天數", selection: $todoDaysAhead) {
                                        Text("當天").tag(0)
                                        Text("前一天").tag(1)
                                        Text("前兩天").tag(2)
                                        Text("前三天").tag(3)
                                    }
                                    .pickerStyle(.menu)
                                    .tint(theme.theme3)
                                }
                            }
                            .padding(.leading, 20)
                            .disabled(!isTodoNotifEnabled) // 關閉時自動變灰且無法互動
                            
                            
                            // 2. 無標籤的待辦提醒
                            customToggle(label: "無標籤的待辦提醒", isOn: $isStatelessTodoNotifEnabled) {
                                updateTodoNotificationsAfterPermissionChange()
                            }
                            
                            HStack {
                                Text("頻率")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textColor)
                                Spacer()
                                Picker("提醒頻率", selection: $statelessTodoInterval) {
                                    Text("每天").tag(1)
                                    Text("每 2 天").tag(2)
                                    Text("每 3 天").tag(3)
                                }
                                .pickerStyle(.menu)
                                .tint(theme.theme3)
                            }
                            .padding(.leading, 20)
                            .disabled(!isStatelessTodoNotifEnabled) // 關閉時自動變灰且無法互動
                            
                            DatePicker("提醒時間", selection: todoTimeBinding, displayedComponents: .hourAndMinute)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textColor)
                                .tint(theme.theme3)
                                .disabled(!isTodoNotifEnabled && !isStatelessTodoNotifEnabled)
                            
                            Divider().background(theme.theme1).padding(.vertical, 8)
                            
                            // 3. 每日打卡提醒
                            customToggle(label: "每日打卡提醒", isOn: $isDiaryNotifEnabled) {
                                updateDiaryNotificationAfterPermissionChange()
                            }
                            
                            DatePicker("提醒時間", selection: diaryTimeBinding, displayedComponents: .hourAndMinute)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textColor)
                                .tint(theme.theme3)
                                .disabled(!isDiaryNotifEnabled) // 關閉時自動變灰且無法互動
                        }
                        
                        thinDivider
                        
                        // ==========================================
                        // Section 3: 外觀
                        // ==========================================
                        sectionToggle(title: "外觀", isExpanded: $isAppearanceExpanded) {
                            
                            // 1. 選擇主題
                            HStack {
                                Text("選擇主題")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textColor)
                                Spacer()
                                Picker("選擇主題", selection: $selectedThemeID) {
                                    ForEach(presetThemes) { theme in
                                        Text(theme.name).tag(theme.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(theme.theme3)
                                .disabled(isCustomTheme)
                                .onChange(of: selectedThemeID) { _, newID in
                                    if !isCustomTheme, let preset = presetThemes.first(where: { $0.id == newID }) {
                                        applyTheme(preset)
                                    }
                                }
                            }
                            
                            // 2. 自訂主題開關 (使用自訂 Toggle)
                            customToggle(label: "自訂主題", isOn: Binding(
                                get: { isCustomTheme },
                                set: { newValue in
                                    if newValue {
                                        withAnimation { isCustomTheme = true }
                                        customBgInput = theme.bgColorHex
                                        customTheme1Input = theme.theme1Hex
                                        customTheme2Input = theme.theme2Hex
                                        customTheme3Input = theme.theme3Hex
                                    } else {
                                        if hasCustomEdits() {
                                            showCustomThemeWarning = true
                                        } else {
                                            withAnimation { isCustomTheme = false }
                                            if let preset = presetThemes.first(where: { $0.id == selectedThemeID }) {
                                                applyTheme(preset)
                                            }
                                        }
                                    }
                                }
                            )){ }
                            
                            // 3. 自訂顏色輸入區
                            VStack(spacing: 14) {
                                customColorInputField(label: "背景色", placeholder: "F4F1E6", text: $customBgInput)
                                customColorInputField(label: "主題色 1", placeholder: "E8EBCF", text: $customTheme1Input)
                                customColorInputField(label: "主題色 2", placeholder: "C2E395", text: $customTheme2Input)
                                customColorInputField(label: "主題色 3", placeholder: "35522B", text: $customTheme3Input)
                                
                                HStack {
                                    Spacer()
                                    Button(action: validateAndApplyCustomTheme) {
                                        Text("確認變更")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(theme.theme3)
                                            .cornerRadius(16)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.leading, 20)
                            .disabled(!isCustomTheme) // 關閉時無法操作
                        }
                        
                        thinDivider
                        
                        // ==========================================
                        // Section 4: AI功能
                        // ==========================================
                        sectionToggle(title: "AI功能", isExpanded: $isAIExpanded) {
                            HStack {
                                Text("回覆語言")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textColor)
                                Spacer()
                                Picker("AI 語言", selection: $aiResponseLanguage) {
                                    Text("繁體中文").tag("繁體中文")
                                    Text("English").tag("English")
                                }
                                .pickerStyle(.menu)
                                .tint(theme.theme3)
                            }
                                                        
                            VStack(alignment: .leading, spacing: 14) {
                                Text("如果是 i15pro 以下的機型，\n在此輸入您的 API 金鑰即可享有完整文字體驗。")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.textColor.opacity(0.7))
                                    .padding(.top, 4)
                                
                                SecureField("請輸入 Gemini API Key", text: $geminiAPIKey)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(theme.textColor)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(theme.theme1.opacity(0.5))
                                    .cornerRadius(16)
                                
                                if !geminiAPIKey.isEmpty {
                                    Text("✨ Gemini 已就緒")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        // 出現不出現的狗勾
                        if areAllSectionsClosed {
                            Image(.egg)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 360)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, -10)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))

                        }
                        
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                }
                .onTapGesture {
                    // iOS 原生的強制收起鍵盤
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                
                // ==========================================
                // 教學浮動視窗與暗色遮罩
                // ==========================================
                if showTutorialPopup {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeTutorialAndRequestPermission()
                        }
                        .transition(.opacity)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.title2)
                                .foregroundColor(theme.theme3)
                            Text("捷徑通知設定步驟")
                                .font(.headline)
                                .foregroundColor(theme.textColor)
                            Spacer()
                        }
                        .padding(.top, 10)
                        .padding(.leading, 12)
                        
                        // ⭐️ 改用 TabView 達成橫向翻頁，共 8 頁，每頁 2 張圖片
                        TabView {
                            ForEach(0..<6, id: \.self) { pageIndex in
                                HStack(spacing: 12) {
                                    // 左邊圖片 (1, 3, 5...)
                                    Image("shortcut_\(pageIndex * 2 + 1)")
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(10)
                                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                    
                                    // 右邊圖片 (2, 4, 6...)
                                    Image("shortcut_\(pageIndex * 2 + 2)")
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(10)
                                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.bottom, 45) // 留空間給底部的翻頁小圓點
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        // 加上半透明膠囊底色，避免小圓點在淺色背景看不清楚
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                        .frame(height: 450) // 💡 依據你圖片的實際長寬比，可以微調這個高度
                    }
                    .padding(12)
                    .background(theme.bgColor)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                if alertMessage.contains("權限") {
                    return Alert(
                        title: Text("需要通知權限"),
                        message: Text(alertMessage),
                        primaryButton: .default(Text("前往設定")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        secondaryButton: .cancel(Text("稍後再說"))
                    )
                } else {
                    return Alert(
                        title: Text("格式錯誤"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("了解"))
                    )
                }
            }
            .alert("確定要關閉自訂主題嗎？", isPresented: $showCustomThemeWarning) {
                Button("取消", role: .cancel) { }
                Button("確定關閉", role: .destructive) {
                    withAnimation { isCustomTheme = false }
                    if let preset = presetThemes.first(where: { $0.id == selectedThemeID }) {
                        applyTheme(preset)
                    }
                }
            } message: {
                Text("關閉後將切換回預設主題，您目前的自訂色碼將不會被保存。\n建議您可以先截圖，以免想再次使用這組顏色！")
            }
        }
        .tint(theme.theme3)
    }
    
    @ViewBuilder
    func customToggle(label: LocalizedStringKey, isOn: Binding<Bool>, action: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.textColor)
            
            Spacer()
            
            Capsule()
                .fill(isOn.wrappedValue ? theme.theme3 : Color.gray.opacity(0.3))
                .frame(width: 40, height: 22)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(2)
                        // 這裡直接使用 .animation，SwiftUI 會自動幫這個偏移量加上彈性效果
                        .offset(x: isOn.wrappedValue ? 9 : -9)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6, blendDuration: 0), value: isOn.wrappedValue)
                )
                .onTapGesture {
                    // 觸發狀態改變
                    isOn.wrappedValue.toggle()
                    action()
                    
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
        }
    }
    
    // ==========================================
    // ⭐️ 核心佈局元件：標題無底色，內容獨立透明圓角底色
    // ==========================================
    @ViewBuilder
    private func sectionToggle(
        title: LocalizedStringKey,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            // 1. 標題列 (永遠沒有底色)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)
                    
                    Spacer()
                    
                    // 模擬原生的折疊箭頭
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isExpanded.wrappedValue ? theme.theme3 : theme.textColor)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle()) // 讓整行空白處都可以點擊
            }
            .buttonStyle(.plain)
            
            // 2. 展開的內容區塊 (這裡才有透明圓角底色)
            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding(16) // 內容與底色邊緣的內距
                .background(theme.theme1.opacity(0.4))
                .cornerRadius(16)
                .padding(.horizontal, 12) // 對齊兩側邊界
                .padding(.bottom, 12)
                // 加上平滑的往下滑出與淡入動畫
                .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
            }
        }
        .clipped() // 防止動畫過程中有東西突出去
    }
    
    // 細橫線元件
    private var thinDivider: some View {
        Rectangle()
            .fill(theme.textColor.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 10)
    }
    
    // ==========================================
    // 輔助元件：自訂文字輸入與色碼輸入橫排
    // ==========================================
    @ViewBuilder
    private func customTextInputRow(label: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(theme.textColor)
                .frame(width: 67, alignment: .leading)
            
            TextField("", text: text)
                .font(.system(size: 14))
                .foregroundColor(theme.theme3)
                .textFieldStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func customColorInputField(label: LocalizedStringKey, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(theme.textColor)
            Spacer()
            Text("#")
                .font(.system(size: 14))
                .foregroundColor(theme.textColor.opacity(0.4))
            TextField(placeholder, text: text)
                .font(.system(size: 14))
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
                .autocapitalization(.allCharacters)
                .foregroundColor(theme.theme3)
                .textFieldStyle(.plain)
        }
    }
    
    // ==========================================
    // 邏輯功能區
    // ==========================================
    
    private func requestNotificationPermission(onGranted: @escaping () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { onGranted() }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            onGranted()
                        } else {
                            alertMessage = String(localized: "請到設定開啟通知權限，否則無法收到提醒喔！")
                            showAlert = true
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    alertMessage = String(localized: "請到設定開啟通知權限，否則無法收到提醒喔！")
                    showAlert = true
                }
            @unknown default:
                break
            }
        }
    }
    
    private func updateTodoNotificationsAfterPermissionChange() {
        if isTodoNotifEnabled || isStatelessTodoNotifEnabled {
            requestNotificationPermission {
                TodoNotificationManager.shared.updateNotifications(todos: allTodos)
            }
        } else {
            TodoNotificationManager.shared.updateNotifications(todos: allTodos)
        }
    }
    
    private func updateDiaryNotificationAfterPermissionChange() {
        if isDiaryNotifEnabled {
            requestNotificationPermission {
                updateDiaryNotification()
            }
        } else {
            updateDiaryNotification()
        }
    }
    
    private func updateDiaryNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_diary_reminder"])
        
        if isDiaryNotifEnabled {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "該打卡囉！")
            content.body = String(localized: "快來記錄今天的照片日記吧，別讓回憶溜走啦～")
            content.sound = .default
            
            var components = DateComponents()
            components.calendar = .autoupdatingCurrent
            components.timeZone = .autoupdatingCurrent
            components.hour = diaryNotifHour
            components.minute = diaryNotifMinute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "daily_diary_reminder", content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("日記提醒排程失敗: \(error.localizedDescription)")
                } else {
                    print("✅ 成功預約每日打卡提醒：每天 \(diaryNotifHour):\(String(format: "%02d", diaryNotifMinute))")
                }
            }
        }
    }
    
    private func hasCustomEdits() -> Bool {
        if let preset = presetThemes.first(where: { $0.id == selectedThemeID }) {
            return cleanHex(customBgInput) != preset.bgColorHex ||
                   cleanHex(customTheme1Input) != preset.theme1Hex ||
                   cleanHex(customTheme2Input) != preset.theme2Hex ||
                   cleanHex(customTheme3Input) != preset.theme3Hex
        }
        return false
    }
    
    private func closeTutorialAndRequestPermission() {
        withAnimation(.easeOut(duration: 0.2)) {
            showTutorialPopup = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { settings in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                            if granted { print("使用者已授權通知權限！") }
                        }
                    case .denied:
                        alertMessage = String(localized: "你目前關閉了通知權限喔！\n請到 iOS 的「設定」中為此 App 開啟通知，才能有順暢地打斷體驗！")
                        showAlert = true
                    case .authorized, .provisional, .ephemeral:
                        print("已經授權過囉！可以順利推播。")
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
    
    private func applyTheme(_ preset: AppTheme) {
        theme.bgColorHex = preset.bgColorHex
        theme.theme1Hex = preset.theme1Hex
        theme.theme2Hex = preset.theme2Hex
        theme.theme3Hex = preset.theme3Hex
    }
    
    private func validateAndApplyCustomTheme() {
        let inputs = [
            (String(localized: "背景色"), customBgInput),
            (String(localized: "主題色 1"), customTheme1Input),
            (String(localized: "主題色 2"), customTheme2Input),
            (String(localized: "主題色 3"), customTheme3Input)
        ]
        
        for input in inputs {
            if !isValidHex(input.1) {
                alertMessage = String(localized: "「\(input.0)」的值 (\(input.1)) 不是有效的 Hex 色碼！請輸入 6 碼英數字 (例如 FFFFFF).")
                showAlert = true
                return
            }
        }
        
        theme.bgColorHex = cleanHex(customBgInput)
        theme.theme1Hex = cleanHex(customTheme1Input)
        theme.theme2Hex = cleanHex(customTheme2Input)
        theme.theme3Hex = cleanHex(customTheme3Input)
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
    
    private func cleanHex(_ hex: String) -> String {
        return hex.trimmingCharacters(in: .whitespacesAndNewlines)
                  .replacingOccurrences(of: "#", with: "")
                  .uppercased()
    }
    
    private func isValidHex(_ hex: String) -> Bool {
        let cleanStr = cleanHex(hex)
        let hexRegex = "^[0-9A-F]{6}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", hexRegex)
        return predicate.evaluate(with: cleanStr)
    }
}
