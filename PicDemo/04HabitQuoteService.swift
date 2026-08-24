//
//  04HabitQuoteService.swift
//  PicDemo
//
//  Created by kikiho on 2026/7/8.
//

import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct HabitQuoteService {

    // MARK: - 習慣類別（附具體範例）

    private struct HabitCategory {
        let name: String
        let examples: [String]
    }

    private static let habitCategories: [HabitCategory] = [
        HabitCategory(name: "睡眠品質", examples: ["十二點前上床", "睡前十分鐘不滑手機", "固定時間起床"]),
        HabitCategory(name: "運動與活動量", examples: ["每天走 6000 步", "每週跑步兩次", "睡前拉筋十分鐘"]),
        HabitCategory(name: "飲水與飲食", examples: ["每天喝 2000cc 水", "三餐定時", "少喝含糖飲料"]),
        HabitCategory(name: "學習與閱讀", examples: ["每天讀書十分鐘", "學一個新單字", "聽一集知識型 Podcast"]),
        HabitCategory(name: "人際與社交", examples: ["每週主動聯絡一位朋友", "每天稱讚一個人", "每週和家人通話一次"]),
        HabitCategory(name: "理財與記帳", examples: ["每天記帳", "每週檢視支出", "每月存下固定金額"]),
        HabitCategory(name: "正念與放鬆", examples: ["每天靜坐五分鐘", "睡前寫三件感恩的事", "每天深呼吸練習"]),
        HabitCategory(name: "居家與整理收納", examples: ["每天整理書桌五分鐘", "每週清一次冰箱", "東西隨手歸位"]),
        HabitCategory(name: "數位健康與減少滑手機", examples: ["睡前一小時不滑手機", "設定每日螢幕使用上限", "吃飯時不看手機"]),
        HabitCategory(name: "創意與興趣嗜好", examples: ["每天畫五分鐘", "練習一首新歌", "寫下一個新點子"])
    ]

    // MARK: - 罐頭語錄庫

    private static let encourageCheckInQuotes = [
        "先放下手機，去做一件你今天還沒完成的小事吧～",
        "今天的紀錄還沒畫上句點，趁現在把它補上！",
        "只差臨門一腳，今天的習慣還在等你打卡呢。",
        "休息一下喝杯水，順便看看今天還有什麼沒做到的。",
        "累積的每一天都算數，今天也別缺席喔！"
    ]
    
    private static let englishEncourageCheckInQuotes = [
        "Put the phone down and finish one small thing today.",
        "There’s still time to check in for today.",
        "One small check-in can keep your streak alive.",
        "Take a quick break, then come back to today’s habit.",
        "Every day counts, and today can count too."
    ]

    private static let suggestNewHabitQuotes = [
        "最近過得不錯，要不要挑戰看看新的小目標？",
        "手帳還有空位喔，想好下一個要養成什麼習慣了嗎？",
        "從一件小事開始，今天就能種下一個新習慣的種子。",
        "生活還有點餘裕，也許可以試試對你有意義的新目標。",
        "培養習慣的路上，隨時都能開啟下一站冒險。"
    ]
    
    private static let englishSuggestNewHabitQuotes = [
        "Maybe today is a good day to try one small new habit.",
        "There’s room for a new habit when you’re ready.",
        "Start with one tiny action and let it grow from there.",
        "A small new habit could fit gently into your day.",
        "When you’re ready, choose one habit for the next chapter."
    ]

    // MARK: - Swift 端先決定好的「計畫」（確保事實正確、不會重複）

    private enum QuotePlan {
        case encourageUnchecked(habitName: String, streak: Int)
        case praiseAllDone(habitName: String?, streak: Int)
        case suggestSpecificHabit(name: String, categoryName: String)
        case suggestUpgrade(fromHabitName: String)
        case suggestGeneric
    }

    // MARK: - 對外主函式

    static func generateQuote(habits: [HabitItem]) async -> String {
        let today = DateHelper.todayString
        let plan = decidePlan(habits: habits, today: today)

        // 階段一：Apple Intelligence —— 用「窄、單一事實」的 prompt，避免它自己判斷出錯
        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            do {
                let narrowContext = buildNarrowContext(from: plan)
                let session = createSession()
                // ⭐️ 微調：英文單字較長，將最大 Token 數稍微提高到 80 避免 API 端截斷
                let options = GenerationOptions(temperature: 0.8, maximumResponseTokens: 80)
                let response = try await session.respond(to: narrowContext, options: options)
                print("🍎 習慣語錄：使用 Apple Intelligence 成功（計畫：\(plan)）")
                return sanitize(response.content, trimToFirstSentence: true)
            } catch {
                print("🍎 習慣語錄：本機 AI 無法使用，切換至 Gemini：\(error)")
            }
        }
        #endif

        // 階段二：Gemini —— 用「完整表格」的 rich context，維持它原本的發揮空間
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        if !apiKey.isEmpty {
            do {
                let richContext = buildRichContext(from: habits, today: today, plan: plan)
                let result = try await fetchFromGemini(context: richContext, apiKey: apiKey)
                print("🌌 習慣語錄：使用 Gemini 成功（計畫：\(plan)）")
                return sanitize(result, trimToFirstSentence: false)
            } catch {
                print("🌌 習慣語錄：Gemini 呼叫失敗，切換至罐頭語錄：\(error)")
            }
        } else {
            print("⚠️ 習慣語錄：未設定 Gemini API Key，直接使用罐頭語錄")
        }

        // 階段三：本地罐頭語錄
        let aiLanguage = UserDefaults.standard.string(forKey: "aiResponseLanguage") ?? "繁體中文"
        switch plan {
        case .encourageUnchecked, .praiseAllDone:
            let quotes = aiLanguage == "English" ? englishEncourageCheckInQuotes : encourageCheckInQuotes
            return quotes.randomElement() ?? quotes[0]
        case .suggestSpecificHabit, .suggestUpgrade, .suggestGeneric:
            let quotes = aiLanguage == "English" ? englishSuggestNewHabitQuotes : suggestNewHabitQuotes
            return quotes.randomElement() ?? quotes[0]
        }
    }

    // MARK: - Swift 端決定計畫（篩選、比對都在這裡完成，兩邊 AI 都不用自己判斷）

    private static func decidePlan(habits: [HabitItem], today: String) -> QuotePlan {
        let activeHabits = habits.filter { $0.status == 1 || ($0.isGraduated && !$0.hasClaimedBadge) }
        let graduatedHabits = habits.filter { $0.status == 2 }
        let allExistingNames = habits.map { $0.name }

        let uncheckedHabits = activeHabits.filter { !$0.completedDates.contains(today) }

        let leanEncourage: Bool
        if activeHabits.isEmpty {
            leanEncourage = false
        } else if activeHabits.count >= 3 {
            leanEncourage = !uncheckedHabits.isEmpty ? true : Double.random(in: 0...1) < 0.7
        } else {
            leanEncourage = Bool.random()
        }

        if leanEncourage {
            if let target = uncheckedHabits.randomElement() {
                let streak = DateHelper.calculateStreaks(from: target.completedDates).current
                return .encourageUnchecked(habitName: target.name, streak: streak)
            } else if let target = activeHabits.randomElement() {
                let streak = DateHelper.calculateStreaks(from: target.completedDates).current
                return .praiseAllDone(habitName: target.name, streak: streak)
            }
        }

        if !graduatedHabits.isEmpty, Double.random(in: 0...1) < 0.35, let upgradeFrom = graduatedHabits.randomElement() {
            return .suggestUpgrade(fromHabitName: upgradeFrom.name)
        }

        for category in habitCategories.shuffled() {
            let safeExamples = category.examples.filter { example in
                !allExistingNames.contains { existing in
                    existing.contains(example) || example.contains(existing)
                }
            }
            if let picked = safeExamples.randomElement() {
                return .suggestSpecificHabit(name: picked, categoryName: category.name)
            }
        }

        return .suggestGeneric
    }

    // MARK: - Apple 用：窄、單一事實 context

    private static func buildNarrowContext(from plan: QuotePlan) -> String {
        switch plan {
        case .encourageUnchecked(let name, let streak):
            return "使用者有一個習慣「\(name)」，今天還沒打卡，目前已經連續 \(streak) 天。請用朋友輕鬆的口吻，寫一句話鼓勵使用者去完成它。"
        case .praiseAllDone(let name, let streak):
            if let name = name {
                return "使用者今天的習慣都已經打卡完成了，其中「\(name)」已經連續 \(streak) 天。請用朋友輕鬆的口吻，寫一句話稱讚使用者。"
            } else {
                return "使用者今天的習慣都已經打卡完成了。請用朋友輕鬆的口吻，寫一句話稱讚使用者。"
            }
        case .suggestSpecificHabit(let name, let categoryName):
            return "請用朋友輕鬆邀請的口吻，寫一句話建議使用者培養「\(name)」這個習慣（屬於\(categoryName)方向）。"
        case .suggestUpgrade(let fromName):
            return "使用者已經完成培養「\(fromName)」這個習慣了。請用朋友輕鬆的口吻，寫一句話建議使用者挑戰它的進階版本（請自己想一個合理的進階版本）。"
        case .suggestGeneric:
            return "請用朋友輕鬆邀請的口吻，寫一句話邀請使用者思考要培養什麼新習慣。"
        }
    }

    // MARK: - Gemini 用：完整表格 rich context（維持原本的豐富資訊量）

    private static func buildRichContext(from habits: [HabitItem], today: String, plan: QuotePlan) -> String {
        let activeHabits = habits.filter { $0.status == 1 || ($0.isGraduated && !$0.hasClaimedBadge) }
        let pendingHabits = habits.filter { $0.status == 0 }
        let graduatedHabits = habits.filter { $0.status == 2 }
        let allExistingNames = habits.map { $0.name }

        var lines: [String] = []

        lines.append("進行中的習慣：")
        if activeHabits.isEmpty {
            lines.append("目前沒有進行中的習慣。")
        } else {
            for habit in activeHabits {
                let checkedIn = habit.completedDates.contains(today) ? "今天已打卡" : "今天尚未打卡"
                let streak = DateHelper.calculateStreaks(from: habit.completedDates).current
                lines.append("- \(habit.name)：\(checkedIn)，目前連續 \(streak) 天。")
            }
        }

        lines.append("已完成培養的習慣（可作為升級建議的參考）：")
        if graduatedHabits.isEmpty {
            lines.append("目前還沒有已完成培養的習慣。")
        } else {
            for habit in graduatedHabits {
                lines.append("- \(habit.name)（已達成 \(habit.targetDays) 天目標）")
            }
        }

        lines.append("排隊中、尚未開始的習慣：")
        lines.append(pendingHabits.isEmpty ? "目前沒有排隊中的習慣。" : pendingHabits.map { $0.name }.joined(separator: "、"))

        lines.append("所有已存在的習慣名稱，建議新習慣時請勿重複：")
        lines.append(allExistingNames.isEmpty ? "無" : allExistingNames.joined(separator: "、"))

        // ⭐️ 額外提示：這次「保底建議」是什麼（已保證不重複），Gemini 可以參考、也可以自己在完整資料中發揮
        lines.append("本次任務指示：")
        switch plan {
        case .encourageUnchecked(let name, let streak):
            lines.append("請根據上方資料，用朋友聊天的輕鬆口吻，鼓勵使用者完成今天還沒打卡的項目，可以優先提及「\(name)」（已連續\(streak)天）。不要建議新習慣。")
        case .praiseAllDone:
            lines.append("使用者今天所有進行中的習慣都已經打卡完成了，請根據上方資料，用朋友聊天的輕鬆口吻，給予具體的稱讚。不要建議新習慣。")
        case .suggestSpecificHabit(let name, let categoryName):
            lines.append("用朋友聊天的輕鬆口吻，邀請使用者新增一個習慣。可以參考「\(name)」（屬於\(categoryName)方向）這個保底建議，也可以根據上方資料自行發想更適合的方向，但絕對不能跟已存在的習慣名稱重複或高度相似。")
        case .suggestUpgrade(let fromName):
            lines.append("使用者已完成培養「\(fromName)」這個習慣，用朋友聊天的輕鬆口吻，建議一個合理的進階版本。")
        case .suggestGeneric:
            lines.append("用朋友聊天的輕鬆口吻，邀請使用者思考要培養什麼新習慣，絕對不能跟已存在的習慣名稱重複或高度相似。")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 清洗 AI 輸出

    private static func sanitize(_ text: String, trimToFirstSentence: Bool) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimToFirstSentence {
            let sentenceEnders: [Character] = ["。", "！", "？", ".", "!", "?"]
            if let firstEnderIndex = result.firstIndex(where: { sentenceEnders.contains($0) }) {
                result = String(result[result.startIndex...firstEnderIndex])
            }
        }

        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "`", with: "")
        result = result.replacingOccurrences(of: "#", with: "")

        let charsToStrip: [Character] = ["「", "」", "『", "』", "《", "》", "\"", "\u{2018}", "\u{2019}"]
        result = String(result.filter { !charsToStrip.contains($0) })

        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "*-•· \n"))
        
        return result
    }

    // MARK: - Apple Intelligence Session

    #if canImport(FoundationModels)
    @available(iOS 18.0, macOS 15.0, *)
    private static func createSession() -> LanguageModelSession {
        let aiLanguage = UserDefaults.standard.string(forKey: "aiResponseLanguage") ?? "繁體中文"

        let instructions = """
        你是使用者的熟識朋友。使用者訊息會直接告訴你明確的事實與這次要做的任務，你只需要把這個事實，用輕鬆自然、口語化的一句話講出來，不需要自己額外判斷或推理其他資訊。

        語氣要求：
        - 像朋友輕鬆搭話，不要像系統在報告，避免「建議新增」「建議你」這類制式開頭。
        - 可以用疑問句、邀請語氣。

        格式要求（非常重要，違反視為失敗）：
        - 只能輸出一句純文字，講完就結束，不要補充原因或優點，不要有第二句。
        - 絕對不可以使用任何符號來強調文字，包含但不限於：「」『』《》**__`#*-•等符號。
        - 不要使用表情符號。
        - 如果回答語言是中文，總字數必須在 30 字以內。如果是英文或其它拼音語言，請控制在簡短的一句話（12個單字以內）。
        
        無論資料是什麼語言，你都必須且只能使用「\(aiLanguage)」來回答我。
        """

        return LanguageModelSession(instructions: instructions)
    }
    #endif

    // MARK: - Gemini 備援

    private static func fetchFromGemini(context: String, apiKey: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let aiLanguage = UserDefaults.standard.string(forKey: "aiResponseLanguage") ?? "繁體中文"

        let systemPrompt = """
        你是使用者的熟識朋友，用輕鬆自然、口語化的語氣跟他聊聊今天的習慣打卡狀況，或建議一個具體的新習慣。
        使用者訊息會提供完整的習慣紀錄，以及本次任務指示告訴你這次要生成哪種類型的語句，請照著指示的類型與方向生成。

        語氣要求：
        - 像朋友輕鬆搭話，不要像系統在報告或給建議，避免「建議新增」「建議你」「你可以考慮」這類制式開頭。
        - 可以用疑問句、邀請語氣，例如「要不要試試看...」「今天...了嗎？」「來...吧」。
        - 如果任務是建議新習慣，句子裡必須包含一個具體、可執行的行動或習慣名稱，不能只是空泛的關心或提問。

        格式要求（非常重要，違反視為失敗）：
        - 只能輸出一句純文字，不可以有任何前言、說明、或多餘內容。
        - 不需使用任何符號來強調文字，例如「」『』《》**__`#*-•等符號。
        - 不要使用表情符號。
        - 如果是中文，總字數 30 字以內。其他語言則簡短、完整的一句話即可，不超過 18 個單字。

        無論資料是什麼語言，都必須且只能使用「\(aiLanguage)」回答。
        """

        let requestBody: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": systemPrompt]]],
                ["role": "model", "parts": [["text": "明白了，我會用朋友聊天的輕鬆口吻，只輸出一句純文字，建議新習慣時會包含具體行動，不使用任何符號或表情符號，簡短句子。請提供使用者習慣紀錄。"]]],
                ["role": "user", "parts": [["text": context]]]
            ],
            "generationConfig": [
                "temperature": 1.0,
                "maxOutputTokens": 80
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        let session = URLSession(configuration: config)

        let (data, _) = try await session.data(for: request)

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
