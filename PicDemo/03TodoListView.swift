//
//  TodoListView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/2.
//

import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    
    // --- 原本的待辦事項狀態 ---
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todos: [TodoItem]
    @State private var newTaskTitle: String = ""
    @AppStorage("totalCompletedTodos") private var totalCompletedTodos: Int = 0
    @State private var confettiTrigger: Int = 0
    
    @EnvironmentObject var theme: ThemeManager

    @State private var showGallery: Bool = false
    
    // 取得當天 4 碼手寫日期字串
    private var handWrittenDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd"
        return formatter.string(from: Date())
    }

    var sortedTodos: [TodoItem] {
        todos.sorted { (todo1, todo2) in
            // 1. 未完成 vs 已完成：未完成排前面
            if todo1.isCompleted != todo2.isCompleted {
                return !todo1.isCompleted
            }
            
            // 2. 兩者都「未完成」
            if !todo1.isCompleted {
                // 狀況 A：兩者都「沒有」期限 -> 置頂，並依照建立時間 (越新越上面)
                if todo1.dueDate == nil && todo2.dueDate == nil {
                    return todo1.createdAt > todo2.createdAt
                }
                
                // 狀況 B：一個有一個沒有 -> 沒有期限的優先置頂
                if todo1.dueDate == nil { return true }
                if todo2.dueDate == nil { return false }
                
                // 狀況 C：兩者都「有」期限 -> 依照到期日排序 (日期越近的越上面)
                if let dueDate1 = todo1.dueDate, let dueDate2 = todo2.dueDate {
                    return dueDate1 < dueDate2
                }
                return todo1.createdAt > todo2.createdAt
            }
            
            // 3. 兩者都「已完成」
            // 依照完成時間排序，越新完成的越上面 (若無完成時間則 fallback 到建立時間)
            let date1 = todo1.completedAt ?? todo1.createdAt
            let date2 = todo2.completedAt ?? todo2.createdAt
            return date1 > date2
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 強制把背景色當成「實體圖層」鋪在最底下！
                Color(theme.bgColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ==========================================
                    // 上半部：便利貼區域
                    // ==========================================
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .bottom) {
                            HStack(spacing: 5) { // 數字跟數字之間的間距
                                ForEach(Array(handWrittenDateString.enumerated()), id: \.offset) { _, char in
                                    Image("num_\(char)") // 自動抓取對應的 "num_0", "num_6" 等圖片
                                        .renderingMode(.template) // 讓手繪線條可以被自動上色
                                        .resizable()
                                        .scaledToFit()
                                        // 調整合適的標題大小
                                        .frame(height: 36)
                                        .foregroundColor(theme.theme3)
                                }
                            }
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showGallery = true
                                }
                            }) {
                                Text("查看所有便利貼")
                                    .font(.subheadline)
                                    .foregroundColor(theme.theme3)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 9)
                        
                        StickyNoteCardView()
                    }
                    .frame(height: 309)
                    
                    // ==========================================
                    // 下半部：待辦事項區域
                    // ==========================================
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // ⭐️ 將笑臉底線圖當作基底，輸入框疊加在上方
                        ZStack(alignment: .bottomLeading) {
                            
                            // 1. 手繪基底圖 (笑臉 + 底線)
                            Image("todolist__")
                                .renderingMode(.template) // 讓圖案跟著主題變色
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(theme.theme3)
                            
                            // 2. 無邊框輸入框
                            TextField("新增待辦事項（按 Enter 儲存）...", text: $newTaskTitle)
                                .font(.system(size: 16))
                                .foregroundColor(theme.textColor)
                                .tint(theme.textColor) // 讓游標變色
                                .submitLabel(.done)
                                .onSubmit { addTodo() }
                                .padding(.horizontal, 80) // 把文字往右推開笑臉的空間
                                .padding(.bottom, 23) // 把文字往上抬，讓它剛好踩在底線上
                        }
                        .frame(height: 66)
                        .padding(.top, 40)
                        .padding(.bottom, 5)
                        .padding(.horizontal, -20)
                    
                        if todos.isEmpty {
                            Spacer()
                            VStack(spacing: 12) {
                                Text("目前沒有待辦事項")
                                    .font(.headline)
                                    .foregroundColor(theme.textColor.opacity(0.7))
                                Text("在上方輸入你想做的小事吧！")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textColor.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            Spacer()
                        } else {
                            List {
                                ForEach(sortedTodos) { todo in
                                    InteractiveTodoRow(todo: todo) {
                                        // ⭐️ 當狀態改變時（打勾或取消），執行這些事：
                                        if todo.isCompleted {
                                            handleTodoCompletion() // 判斷要不要撒紙花
                                        }
                                        
                                        // 每次狀態改變，都通知大腦重新排程！
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            TodoNotificationManager.shared.updateNotifications(todos: todos)
                                        }
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            deleteTodo(todo)
                                        } label: {
                                            Image("smalltrash")
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 21)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationBarHidden(true)
            
            // 撒紙花套件
            .confettiCannon(
                trigger: $confettiTrigger,
                num: 80,
                confettis: [.shape(.circle), .shape(.triangle), .shape(.square)],
                colors: [.blue, .red, .green, .yellow, .pink, .purple],
                rainHeight: 600,
                radius: 400
            )
            .overlay {
                if showGallery {
                    // 1. 墊一層柔和的黑色半透明遮罩，點擊它也能優雅收起卡片
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .zIndex(9)
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showGallery = false
                            }
                        }
                    
                    // 2. 懸浮便利貼畫廊卡片
                    StickyNoteGalleryView(showGallery: $showGallery)
                        .zIndex(10) // 確保置頂
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .scale(scale: 0.92).combined(with: .opacity)
                        ))
                }
            }
        }
    }
    
    // 待辦清單專屬邏輯
    private func addTodo() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        let analysis = extractTaskAndDate(from: trimmedTitle)
        let newItem = TodoItem(title: analysis.task, dueDate: analysis.date)
        modelContext.insert(newItem)
        
        newTaskTitle = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            TodoNotificationManager.shared.updateNotifications(todos: todos)
        }
    }
    
    private func extractTaskAndDate(from input: String) -> (task: String, date: Date?) {
        var finalTask = input
        var finalDate: Date? = nil
        
        let datePattern = #"\b(1[0-2]|0?[1-9])[-/](3[01]|[12][0-9]|0?[1-9])\b"#
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            
            let dateStr = (input as NSString).substring(with: match.range)
            let formatter = DateFormatter()
            formatter.dateFormat = dateStr.contains("-") ? "M-d" : "M/d"
            
            if let parsedDate = formatter.date(from: dateStr) {
                var components = Calendar.current.dateComponents([.month, .day], from: parsedDate)
                components.year = Calendar.current.component(.year, from: Date())
                finalDate = Calendar.current.date(from: components)
                finalTask = (input as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        
        if finalDate == nil, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(location: 0, length: input.utf16.count)
            let matches = detector.matches(in: input, options: [], range: range)
            
            if let match = matches.first, let extractedDate = match.date {
                let dateString = (input as NSString).substring(with: match.range)
                finalTask = input.replacingOccurrences(of: dateString, with: "")
                finalDate = extractedDate
            }
        }
        // 刪掉贅字
        var cleanTask = finalTask.trimmingCharacters(in: .whitespacesAndNewlines)
        // 掃尾：把前面的空格跟英文綁一起，中文前面可以容許沒有空格 (\s*)
        cleanTask = cleanTask.replacingOccurrences(
            of: #"(?i)(\s+on|\s+at|\s+by|\s+due|\s+in|\s+for|\s+before|\s+until|\s*於|\s*在|\s*要在|\s*要|\s*之前)\s*$"#,
            with: "",
            options: .regularExpression
        )
        
        // 掃頭
        cleanTask = cleanTask.replacingOccurrences(
            of: #"^(?i)(on\s+|at\s+|by\s+|due\s+|in\s+|for\s+|before\s+|until\s+|於\s*|在\s*|要在\s*|要\s*|之前\s*)"#,
            with: "",
            options: .regularExpression
        )
        
        return (task: cleanTask.isEmpty ? input : cleanTask, date: finalDate)
    }
    
    private func deleteTodo(_ todo: TodoItem) {
        modelContext.delete(todo)
        
        // ⭐️ 刪除待辦事項後，通知大腦重新排程，把不需要的舊通知殺掉
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TodoNotificationManager.shared.updateNotifications(todos: todos)
        }
    }
    // 每完成七次事項 噴一次紙花
    private func handleTodoCompletion() {
        totalCompletedTodos += 1
        if totalCompletedTodos > 0 && totalCompletedTodos % 7 == 0 {
            confettiTrigger += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        
        // ⭐️ 任務打勾完成後，通知大腦重新排程，把該任務的通知收回
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TodoNotificationManager.shared.updateNotifications(todos: todos)
        }
    }
}

// 支援「手指真實劃線」與「多重日期顯示」的互動式列
struct InteractiveTodoRow: View {
    @Bindable var todo: TodoItem
    @State private var dragProgress: CGFloat = 0.0
    @EnvironmentObject var theme: ThemeManager

    var onStatusChanged: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            
            // 1. 左側圈圈
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(todo.isCompleted ? Color(theme.theme3).opacity(0.8) : theme.textColor.opacity(0.4))
                .onTapGesture {
                    withAnimation {
                        todo.isCompleted.toggle()
                        if todo.isCompleted {
                            todo.completedAt = Date() // ⭐️ 打勾的瞬間，記錄完成時間
                        } else {
                            todo.completedAt = nil // 取消打勾時，清空完成時間
                        }
                    }
                    onStatusChanged() // ⭐️ 狀態一改變，馬上回報給外層
                }
            
            // 2. 解析出的日期 (放在勾選格右方、文字前方)
            if let dueDate = todo.dueDate {
                Text("\(formattedDate(dueDate))")
                    .font(.caption.bold())
                    .foregroundColor(todo.isCompleted ? theme.textColor.opacity(0.2) : theme.theme3.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(todo.isCompleted ? theme.textColor.opacity(0.01) : theme.theme2.opacity(0.2))
                    .cornerRadius(6)
            }
            
            // 3. 任務文字與手勢劃線區塊
            Text(todo.title)
                .font(.system(size: 18))
                .foregroundColor(todo.isCompleted ? theme.textColor.opacity(0.3) : theme.textColor)
                .overlay(
                    GeometryReader { geo in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geo.size.height / 2 + 1))
                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2 - 1))
                        }
                        .trim(from: 0, to: todo.isCompleted ? 1.0 : dragProgress)
                        .stroke(theme.textColor.opacity(0.6), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        
                        Color.white.opacity(0.001)
                            .gesture(
                                // ⭐️ 將觸發距離稍微拉長到 15，避免手指輕輕點擊就被當成拖曳
                                DragGesture(minimumDistance: 15)
                                    .onChanged { value in
                                        if !todo.isCompleted {
                                            // 限制起點 必須從文字最左側（大約 40 point 內，約前兩個字）開始畫
                                            guard value.startLocation.x < 40 else { return }
                                            
                                            // 限制垂直偏移 如果手指向下或向上滑動超過 30 point，視為列表滾動，不觸發畫線
                                            guard abs(value.translation.height) < 30 else { return }
                                            
                                            // 只能向右畫，不能向左畫
                                            guard value.translation.width > 0 else { return }
                                            
                                            let progress = value.translation.width / geo.size.width
                                            dragProgress = max(0, min(progress, 1.0))
                                        }
                                    }
                                    .onEnded { value in
                                        if !todo.isCompleted {
                                            // 結束時同樣要擋掉不合法的起點
                                            guard value.startLocation.x < 40 else {
                                                // 如果不合法但有畫出一點點殘影，讓它彈回去
                                                withAnimation(.spring()) { dragProgress = 0.0 }
                                                return
                                            }
                                            
                                            if dragProgress > 0.5 {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    todo.isCompleted = true
                                                    todo.completedAt = Date() // 手指劃掉的瞬間，記錄完成時間
                                                    dragProgress = 0.0
                                                }
                                                onStatusChanged()
                                                
                                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                                impact.impactOccurred()
                                            } else {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    dragProgress = 0.0
                                                }
                                            }
                                        }
                                    }
                            )
                    }
                )
            
            Spacer(minLength: 8)
            
            // 4. 右側的對比時間區塊 (創建日期 vs 完成日期)
            HStack(spacing: 6) {
                // 創建日期
                Text("\(formattedDate(todo.createdAt))")
                    .foregroundColor(theme.textColor.opacity(0.3))
                
                // 完成日期 (只有在打勾完成時才會顯示)
                if todo.isCompleted, let completedAt = todo.completedAt {
                    Text("\(formattedDate(completedAt))")
                        .foregroundColor(theme.theme3.opacity(0.7))
                }
            }
            .font(.system(size: 11))
        }
        .padding(.vertical, 1)
    }
    
    // 把 Date 變成短短的 "6/15" 格式
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
