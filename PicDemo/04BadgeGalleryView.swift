import SwiftUI
import SwiftData

struct BadgeGalleryView: View {
    // 傳入所有習慣，元件會自己過濾出「已領取徽章」的項目
    var allHabits: [HabitItem]
    @Binding var selectedBadgeHabit: HabitItem?
    // 控制是否展開的變數
    @State private var isExpanded = false
    @EnvironmentObject var theme: ThemeManager

    var claimedHabits: [HabitItem] {
        allHabits.filter { $0.hasClaimedBadge }
    }
    
    // 固定 5 縱列的網格佈局
    let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
    
    var body: some View {
        if !claimedHabits.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                // 動態展示區
                if isExpanded {
                    // 展開時變直向滑動，五個一行
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(claimedHabits) { habit in
                                BadgeIconView(habit: habit)
                                    .onTapGesture {
                                        withAnimation(.spring) {
                                            selectedBadgeHabit = habit
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                        // 底部預留一點空間給箭頭，避免最後一排的徽章被擋住
                        .padding(.bottom, 24)
                        .padding(.top, 4)
                    }
                    .frame(maxHeight: 160)
                } else {
                    // 收合時：維持橫向滑動（單行模式）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(claimedHabits) { habit in
                                BadgeIconView(habit: habit)
                                    .onTapGesture {
                                        withAnimation(.spring) {
                                            selectedBadgeHabit = habit
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        // 確保右側有留空間給箭頭
                        .padding(.trailing, 24)
                    }
                }
            }
            .padding(.top, 5)
            .padding(.bottom, 5)
            // 用 overlay 把箭頭釘在右下角
            .overlay(alignment: .bottomTrailing) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    // 箭頭外觀
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.textColor.opacity(0.3))
                        .padding(8)
                        .clipShape(Circle())
                }
                // 調整箭頭跟右下角邊緣的距離
                .padding(.trailing, 8)
                .padding(.bottom, -20) // 稍微往下一點點，讓它浮在邊界
            }
        }
    }
}

// ==========================================
// 手繪 ZStack 三層徽章元件
// ==========================================
struct BadgeIconView: View {
    var habit: HabitItem
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 1. 最底層：帶有習慣專屬代表色的半透明圓形底座
                Circle()
                    .fill(habit.color.opacity(0.18))
                    .frame(width: 48, height: 48)
                
                // 2. 中間層：SF Symbols 圖示（帶有使用者設定好的習慣顏色）
                Image(systemName: habit.icon)
                    .font(.system(size: 20, weight: .medium)) // 調整適中大小，讓它乖乖待在手繪框內
                    .foregroundColor(habit.color) // 讓圖示亮起它專屬的顏色！
                
                // 3. 最頂層：疊加手繪去背線條 PNG 圖檔
                Image(badgeImageName(for: habit.icon))
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68) // 多次調整，與底座疊合
            }
            
            // 稱號文字
            Text(habit.badgeTitle.isEmpty ? "神秘徽章" : habit.badgeTitle)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(habit.color)
                .lineLimit(1)
                .padding(.top, -5)
        }
        .frame(width: 62) // 固定整體寬度，確保 5 個一排能完美均分螢幕寬度
    }
    
    // 將舊的 SF Symbols 映射到自訂手繪圖檔   //複製到dashboard
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
}
