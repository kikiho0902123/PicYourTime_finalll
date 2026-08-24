//
//  HabitDashboardView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftUI
import SwiftData

// ⭐️ 專門用來記錄冷啟動生命週期的記憶體快取 只要 App 被滑掉關閉，裡面的資料就會自動清空
struct QuoteSessionCache {
    static var currentSessionQuote: String? = nil
}

struct HabitDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitItem.createdAt, order: .forward) private var habits: [HabitItem]
    @State private var showingAddSheet = false
    @EnvironmentObject var theme: ThemeManager
    @State private var selectedBadgeHabit: HabitItem? = nil
    @State private var showDeleteBadgeAlert = false
    @State private var aiQuoteText: String = ""
    @State private var isLoadingQuote: Bool = true
    
    // 分類習慣
    var graduatedHabits: [HabitItem] { habits.filter { $0.status == 2 && !$0.hasClaimedBadge } }
    var activeHabits: [HabitItem] { habits.filter { $0.status == 1 || ($0.isGraduated && !$0.hasClaimedBadge) } }
    var pendingHabits: [HabitItem] { habits.filter { $0.status == 0 } }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgColor.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    HabitQuoteBubbleView(text: aiQuoteText, isLoading: isLoadingQuote)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // 1. 徽章展示區
                            BadgeGalleryView(allHabits: habits, selectedBadgeHabit: $selectedBadgeHabit)
                            
                            // 空白狀態：當一個習慣都沒有時顯示的友善提示
                            if habits.isEmpty {
                                VStack(spacing: 16) {
                                    // 按鈕放在標題之下的右邊 (ScrollView 的右上角)
                                    HStack {
                                        Spacer()
                                        addHabitButton
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                    
                                    Text("目前還沒有建立任何習慣\n點擊上方的新增按鈕開始吧！")
                                        .font(.subheadline)
                                        .foregroundColor(theme.textColor.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                        .padding(.top, 30)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                // 2. 進行中打卡卡片
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(activeHabits) { habit in
                                        NavigationLink(destination: HabitDetailView(habit: habit)) {
                                            HabitCardView(habit: habit, isPending: false) {
                                                evaluateGameRules()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    if pendingHabits.isEmpty {
                                        HStack {
                                            Spacer()
                                            addHabitButton
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // 3. 等待中灰色的排隊卡片
                            if !pendingHabits.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("有好多想做的事，我們一步一步完成它！")
                                            .font(.subheadline)
                                            .foregroundColor(theme.textColor.opacity(0.4))
                                        
                                        Spacer()
                                        addHabitButton
                                    }
                                    .padding(.top, 10)
                                    
                                    ForEach(pendingHabits) { habit in
                                        HabitCardView(habit: habit, isPending: true) {}
                                            .padding(.vertical, -5)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 8)
                }
                // 呼叫抽離出來的徽章彈跳視窗！
                if let selected = selectedBadgeHabit {
                    badgePopupView(for: selected)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddSheet) {
                AddHabitView()
                    .presentationDetents([.fraction(0.8)])
            }
            .alert("確定要刪除這個徽章嗎？", isPresented: $showDeleteBadgeAlert) {
                Button("取消", role: .cancel) {}
                Button("刪除", role: .destructive) {
                    if let habitToDelete = selectedBadgeHabit {
                        modelContext.delete(habitToDelete)
                        withAnimation { selectedBadgeHabit = nil } // 關閉視窗
                    }
                }
            }
            .onAppear {
                evaluateGameRules()
                Task { await loadQuote() }
            }
            .onChange(of: habits.count) { _, _ in
                evaluateGameRules()
            }
        }
    }
    // 新增按鈕元件
    private var addHabitButton: some View {
        Button(action: { showingAddSheet = true }) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(theme.theme2)
                .clipShape(Circle())
                .shadow(color: theme.theme2.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }
    
    private func loadQuote() async {
        // 1. 檢查這次「冷啟動」的生命週期內，是不是已經抓過語錄了？
        if let sessionQuote = QuoteSessionCache.currentSessionQuote {
            // 如果已經抓過，且畫面剛好是空的（例如切換分頁回來），就直接填上，不觸發動畫也不呼叫 API
            if aiQuoteText != sessionQuote {
                aiQuoteText = sessionQuote
            }
            return
        }
        
        // 2. 如果是冷啟動後「第一次」進來，才去向 AI 要資料
        isLoadingQuote = true
        let text = await HabitQuoteService.generateQuote(habits: habits)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            aiQuoteText = text
            isLoadingQuote = false
        }
        
        // 3. 把抓到的新句子存進記憶體中。只要 App 沒被徹底關閉，這句話就會一直陪著使用者！
        QuoteSessionCache.currentSessionQuote = text
    }
    
    // ==========================================
    // 獨立出來的 UI 區塊：徽章彈跳視窗
    // ==========================================
    @ViewBuilder
    private func badgePopupView(for selected: HabitItem) -> some View {
        ZStack {
            // 半透明遮罩層：點擊此處任何非視窗的空白區域即可直接關閉
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut) { selectedBadgeHabit = nil }
                }
            
            // 漂浮卡片本體
            VStack(spacing: 20) {
                // 1. 徽章圖樣 (底座 + 顏色原圖示 + 手繪線條)
                ZStack {
                    // (1) 最底層：帶有習慣專屬代表色的半透明圓形底座
                    Circle()
                        .fill(selected.color.opacity(0.18))
                        .frame(width: 100, height: 100)
                    
                    // (2) 中間層：原生的 SF Symbols 圖示
                    Image(systemName: selected.icon)
                        .font(.system(size: 42, weight: .medium)) // 等比例放大尺寸
                        .foregroundColor(selected.color)
                    
                    // (3) 最頂層：疊加手繪去背線條 PNG 圖檔
                    Image(badgeImageName(for: selected.icon))
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150) // 與底座疊合
                }
                .padding(.top, 10)
                
                // 2. 稱號（應該不會為空）
                Text(selected.badgeTitle.isEmpty ? String(localized: "神秘徽章") : selected.badgeTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(theme.theme3)
                
                // 3. 日期資訊與統計
                VStack(spacing: 8) {
                    let startDateStr = formatFullDate(selected.startDate ?? Date())
                    let endDateStr = formatFullDate(selected.completedAt ?? Date())
                    
                    Text("\(startDateStr) - \(endDateStr)")
                        .font(.subheadline)
                        .foregroundColor(theme.textColor.opacity(0.5))
                    
                    let calendar = Calendar.current
                    let days = calendar.dateComponents([.day], from: selected.startDate ?? Date(), to: selected.completedAt ?? Date()).day ?? 0
                    let totalDays = max(days, 1)
                    
                    Text("在這 \(totalDays) 天中，你有 \(selected.completedDates.count) 天有做到\n \(selected.name)！")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(theme.theme3)
                }
                
                // 4. 心得區塊
                if !selected.badgeReflection.isEmpty {
                    Text("\(selected.badgeReflection)")
                        .font(.body)
                        .italic()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.theme2.opacity(0.1))
                        .cornerRadius(12)
                }
                // 5. 卡片左下角：手繪垃圾桶 (開關蓋動畫)
                HStack {
                    Button(action: {
                        showDeleteBadgeAlert = true // 觸發警告視窗
                    }) {
                        // 用 showDeleteBadgeAlert 來判斷要顯示哪張圖
                        Image(showDeleteBadgeAlert ? "icon_trash_open" : "icon_trash")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(theme.theme3.opacity(0.5))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showDeleteBadgeAlert)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(theme.bgColor)
            .cornerRadius(24)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .zIndex(1) // 確保在最上層
    }
    
    private func badgeImageName(for icon: String) -> String {
        switch icon {
        case "star.fill":   return "badge_star"
        case "sparkles":    return "badge_sparkles"
        case "drop.fill":   return "badge_drop"
        case "figure.run":  return "badge_run"
        case "fork.knife":  return "badge_food"
        case "moon.fill":   return "badge_moon"
        case "book.fill":   return "badge_book"
        case "pencil":      return "badge_pencil"
        case "leaf.fill":   return "badge_leaf"
        case "heart.fill":  return "badge_heart"
        case "music.note":  return "badge_music"
        case "cart.fill":   return "badge_cart"
        default:            return "badge_default"
        }
    }
    
    // ==========================================
    // 邏輯功能區
    // ==========================================
    private func evaluateGameRules() {
        let maxActiveCapacity = 3
        let currentActiveCount = habits.filter { $0.status == 1 || ($0.isGraduated && !$0.hasClaimedBadge) }.count
        var availableSlots = maxActiveCapacity - currentActiveCount
        
        if availableSlots > 0 {
            for pendingHabit in pendingHabits {
                if availableSlots > 0 {
                    pendingHabit.status = 1
                    pendingHabit.startDate = Date()
                    availableSlots -= 1
                }
            }
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

// 習慣卡片元件 (HabitCardView)
struct HabitCardView: View {
    var habit: HabitItem
    var isPending: Bool
    var onCheckIn: () -> Void
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: 16) {
            // 1. 左側圖示
            Image(systemName: habit.icon)
                .font(.title)
                .foregroundColor(isPending ? theme.textColor.opacity(0.15) : (habit.isGraduated ? .white : habit.color))
                .frame(width: 48, height: 48)
                .background(isPending ? theme.textColor.opacity(0.05) : (habit.isGraduated ? .white.opacity(0.2) : habit.color.opacity(0.1)))
                .cornerRadius(12)
            
            // 2. 中間文字與進度條
            VStack(alignment: .leading, spacing: 8) {
                // 名稱
                Text(habit.name)
                    .font(.headline)
                    .foregroundColor(isPending ? theme.textColor.opacity(0.3) : (habit.isGraduated ? .white : theme.textColor))
                
                if isPending {
                    Text("前方習慣達標後開啟紀錄")
                        .font(.caption)
                        .foregroundColor(theme.textColor.opacity(0.3))
                } else {
                    // 起始日與連續打卡
                    HStack(spacing: 8) {
                        Text("起點: \(formatShortDate(habit.startDate ?? Date()))")
                        
                        let streaks = DateHelper.calculateStreaks(from: habit.completedDates)
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                            Text("\(streaks.current) 天")
                        }
                        .foregroundColor(habit.isGraduated ? .white : .orange)
                    }
                    .font(.caption)
                    .foregroundColor(habit.isGraduated ? .white: theme.textColor.opacity(0.4))
                    
                    // ⭐️ 進度條 (使用 recentRollingRate)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // 底色軌道
                            Capsule()
                                .fill(habit.isGraduated ? theme.theme1.opacity(0.5) : theme.textColor.opacity(0.05))
                                .frame(height: 6)
                            // 填滿進度
                            Capsule()
                                .fill(habit.isGraduated ? .white : habit.color)
                                .frame(width: geo.size.width * CGFloat(min(max(habit.recentRollingRate, 0), 1)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            
            Spacer()
            
            // 3. 右側打勾按鈕
            if !isPending {
                Button(action: {
                    toggleCheckIn()
                }) {
                    let today = DateHelper.todayString
                    Image(systemName: habit.completedDates.contains(today) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 32))
                        .foregroundColor(habit.completedDates.contains(today) ? (habit.isGraduated ? .white : habit.color) : theme.textColor.opacity(0.15))
                }
                .buttonStyle(.borderless)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(theme.textColor.opacity(0.1))
            }
        }
        .padding()
        .background(isPending ? theme.bgColor : (habit.isGraduated ? habit.color : theme.theme1.opacity(0.75)))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(isPending ? 0 : 0.02), radius: 2, x: 0, y: 2)
    }
    
    private func toggleCheckIn() {
        let today = DateHelper.todayString
        withAnimation {
            // 破解同步 Bug：先拷貝一份陣列出來修改
            var updatedDates = habit.completedDates
            
            if let index = updatedDates.firstIndex(of: today) {
                updatedDates.remove(at: index) // 取消打卡
            } else {
                updatedDates.append(today)     // 新增打卡
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            
            // ⭐️ 1. 把修改好的陣列「重新賦值」回去，強制觸發 SwiftData 的資料更新
            habit.completedDates = updatedDates
            
            // ⭐️ 2. 立刻存檔，確保 DiaryView 切換過去時絕對是最新狀態！
            try? habit.modelContext?.save()
            
            onCheckIn()
        }
    }
    
    // 格式為 月/日
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}


struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 20
    var tailSize: CGFloat = 14
    var tailOffsetX: CGFloat = 36 // 尾巴距離左邊的位置

    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailSize)
        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)

        let tailStartX = bubbleRect.minX + tailOffsetX
        path.move(to: CGPoint(x: tailStartX, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: tailStartX + tailSize, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: tailStartX + tailSize / 2, y: bubbleRect.maxY + tailSize))
        path.closeSubpath()

        return path
    }
}

// AI 語錄對話框元件
struct HabitQuoteBubbleView: View {
    var text: String
    var isLoading: Bool
    @EnvironmentObject var theme: ThemeManager

    // 對話框「本體」高度：足夠放兩行 subheadline 文字並留呼吸空間
    private let bubbleContentHeight: CGFloat = 66
    // 尾巴額外佔用的高度
    private let tailHeight: CGFloat = 14

    var body: some View {
        ZStack(alignment: .top) {
            // 1. 底圖：對話框形狀
            SpeechBubbleShape(tailSize: tailHeight)
                .fill(theme.theme1.opacity(0.6))
                .frame(height: bubbleContentHeight + tailHeight)

            // 2. 文字：撐滿對話框本體高度，並在裡面垂直置中、水平靠左
            Group {
                if isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在想一句話給你...")
                            .font(.subheadline)
                            .foregroundColor(theme.textColor.opacity(0.5))
                    }
                } else {
                    Text(text)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.theme3)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 18)
            // minHeight 撐滿對話框本體，.leading 讓水平靠左、垂直自動置中
            .frame(maxWidth: .infinity, minHeight: bubbleContentHeight, alignment: .leading)
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}
