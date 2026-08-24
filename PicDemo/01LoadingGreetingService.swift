//
//  01LoadingGreetingService.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/18.
//

import Foundation
import SwiftUI

// 條件編譯：確認系統環境是否支援本地 AI 框架
#if canImport(FoundationModels)
import FoundationModels
#endif

struct LoadingGreetingService {
    
    // 修復：宣告為靜態常數以常駐記憶體，避免非同步回收引發 EXC_BAD_ACCESS 崩潰
    #if canImport(FoundationModels)
    @available(iOS 18.0, macOS 15.0, *)
    static func createSession() -> LanguageModelSession {
        // 1. 在這裡讀取當前最新的設定
        let aiLanguage = UserDefaults.standard.string(forKey: "aiResponseLanguage") ?? "繁體中文"
        
        // 2. 動態組合指令
        let instructions = """
        你是一款療癒系手帳 App 的數位小助理。
        請根據下方提供的使用者紀錄，寫出一句溫暖的問候與輕輕的鼓勵，或者一個令使用者意想不到的簡單靈感提案。
        嚴格限制：總共只能有一句話，總字數 40 字以內，不要使用表情符號。直接輸出問候語。
        無論上方提供的清單是什麼語言，你都必須且只能使用「\(aiLanguage)」來回答我。
        """
        
        return LanguageModelSession(instructions: instructions)
    }
    #endif
    
    // 生成啟動語的核心分流主函式
    static func generateLoadingText(userContext: String) async -> String {
        // 初始化本地儲存的預設罐頭訊息池
        let aiLanguage = UserDefaults.standard.string(forKey: "aiResponseLanguage") ?? "繁體中文"
        let defaultGreetings: [String]
        if aiLanguage == "English" {
            defaultGreetings = [
                "A fresh page is waiting for you today.",
                "This is a gentle moment to begin again.",
                "Ready to leave a small note for today?",
                "Today still has room for something good.",
                "Take a quiet breath and start with one small thing."
            ]
        } else {
            defaultGreetings = [
                "今天也是全新的一天，開啟美好的一步吧！",
                "點開手帳的這一刻，今天的美好生活就已經開始囉。",
                "準備好留點時間給自己了嗎？今天也一起記錄生活吧！",
                "今天也是充滿美好可能的一天，準備好開始了嗎？",
                "靜下心來，翻開今天的新頁面，祝你有個溫柔的一天。"
            ]
        }
        let fallbackMessage = defaultGreetings.randomElement() ?? defaultGreetings[0]
        
        // 基礎防呆：內文為空時中斷機制並回傳罐頭訊息
        if userContext.isEmpty { return fallbackMessage }
        
        // 封裝輸入資料至標準提示詞格式
        let prompt = "【使用者紀錄】\n\(userContext)\n\n請為使用者生成今日的溫暖啟動語。"
        
        // 階段一：執行本地端 Apple Intelligence 模型
        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            do {
                let session = LoadingGreetingService.createSession()
                let response = try await session.respond(to: prompt)
                
                print("🍎 使用 Apple Intelligence 成功")
                return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                print("🍎 本機 AI 無法使用或硬體不支援，切換至 Gemini：\(error)")
            }
        }
        #endif  // canImport(FoundationModels)
        
        // 階段二：執行雲端 Gemini 1.5 Flash 備援機制
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        if !apiKey.isEmpty {
            do {
                let geminiResponse = try await fetchFromGemini(prompt: prompt, apiKey: apiKey)
                print("🌌 使用 Gemini 成功")
                return geminiResponse
            } catch {
                print("🌌 Gemini 呼叫失敗，切換至罐頭訊息：\(error)")
            }
        } else {
            print("⚠️ 未設定 Gemini API Key，直接使用罐頭訊息")
        }
        
        // 階段三：前導 AI 機制均失效時之保底輸出
        return fallbackMessage
    }
    
    // 沒有apple AI：不依賴第三方 SDK，以原生網路請求串接 API
    private static func fetchFromGemini(prompt: String, apiKey: String) async throws -> String {
        // 建立與驗證 API 目標端點
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // 設定標準 HTTP 請求配置
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let aiLanguage = UserDefaults.standard.string(forKey: "aiResponseLanguage") ?? "繁體中文"
        // 定義符合官方規範之 JSON 資料結構
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "系統指令：你是一款療癒系手帳 App 的數位小助理。請根據使用者紀錄寫出一句溫暖的問候，或者一個令使用者意想不到的簡單靈感提案。嚴格限制：一句話、40字內、絕對不使用表情符號。直接輸出文字，不要有任何前言。無論上方提供的清單是什麼語言，你都必須且只能使用「\(aiLanguage)」來回答我。"]
                    ]
                ],
                [
                    "role": "model",
                    "parts": [
                        ["text": "明白了，我會嚴格遵守一句話、40字內、無表情符號的規定。請提供使用者紀錄。"]
                    ]
                ],
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 60 // 限制最大輸出長度，縮短生成延遲
            ]
        ]
        
        // 將字典序列化為 Data 二進位格式
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 配置網路超時防護，防止載入畫面無限等待
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        let session = URLSession(configuration: config)
        
        // 執行非同步資料傳輸任務
        let (data, _) = try await session.data(for: request)
        
        // 加這行印出原始回應，除錯超好用！
        if let jsonString = String(data: data, encoding: .utf8) {
            print("DEBUG: Gemini 原始回應內容: \(jsonString)")
        }
        
        // 解析嵌套 JSON 結構並擷取回傳文字
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
}
