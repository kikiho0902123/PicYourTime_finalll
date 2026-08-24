//
//  01SplashLoadingView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/18.
//

import SwiftUI
import SwiftData
import Combine

struct SplashLoadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isAppReady: Bool // 用來通知外部「可以進入主畫面了」
    
    @State private var loadingText: String = String(localized: "正在收集散落的記憶...")
    @State private var currentFrame: Int = 1
    @State private var textOpacity: Double = 0.5
    // ⭐️ 用來控制 UI 要不要顯示的開關，給網址一點攔截的時間
    @State private var showContent: Bool = false
    
    // 動畫計時器
    let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()
    private let aiGreetingTimeoutNanoseconds: UInt64 = 10_000_000_000
    
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        ZStack {
            // 背景色
            Color(theme.bgColor).ignoresSafeArea()
            // 如果 showContent 是 true，才把內容畫出來
            if showContent {
                VStack(spacing: 32) {
                    // 1. 手繪動畫播放區
                    Image("loading_\(currentFrame)")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                        .foregroundColor(theme.theme3)
                        .onReceive(timer) { _ in
                            // 循環切換 1 -> 2 -> 3 -> 1
                            currentFrame = (currentFrame % 3) + 1
                        }
                    
                    // 2. AI 漸變文字
                    Text(loadingText)
                        .font(.headline)
                        .foregroundColor(theme.theme3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(textOpacity)
                        .animation(.easeInOut(duration: 0.8), value: loadingText)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 3) {
            skipLoading()
        }
        .task {
            
            // ⭐️ 1. 先停頓 0.15 秒！如果這期間 .onOpenURL 觸發並把 App 切走了，這段代碼就會直接被取消，什麼都不會顯示！
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                // 熬過了 0.15 秒，代表是正常開啟，把動畫秀出來
                withAnimation { showContent = true }
                
                // ⭐️ 2. 確保可以被中斷
                try await Task.sleep(nanoseconds: 800_000_000)
                
                let context = AppDataFetcher.fetchRandomContextForAI(modelContext: modelContext)
                print("DEBUG: 抓到的使用者紀錄內容為：'\(context)'")
                
                let aiGreeting = await generateLoadingTextWithTimeout(userContext: context)
                
                withAnimation {
                    loadingText = aiGreeting
                    textOpacity = 1.0
                }
                
                try await Task.sleep(nanoseconds: 3_000_000_000)
                
                withAnimation(.easeInOut(duration: 0.6)) {
                    isAppReady = true
                }
                
            } catch {
                // 只要這段任務被提早切斷，就會安靜地結束，不會在背景作怪
                print("啟動任務已取消，直接進入主畫面")
            }
        }
    }
    
    private func skipLoading() {
        guard !isAppReady else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isAppReady = true
        }
    }
    
    private func generateLoadingTextWithTimeout(userContext: String) async -> String {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                await LoadingGreetingService.generateLoadingText(userContext: userContext)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: aiGreetingTimeoutNanoseconds)
                return nil
            }
            
            let result = await group.next() ?? nil
            group.cancelAll()
            
            if let result, !result.isEmpty {
                return result
            }
            return await LoadingGreetingService.generateLoadingText(userContext: "")
        }
    }
}
