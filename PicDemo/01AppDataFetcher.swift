//
//  00AppDataFetcher.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/18.
//

import Foundation
import SwiftData

@MainActor
class AppDataFetcher {
    static func fetchRandomContextForAI(modelContext: ModelContext) -> String {
        // 建立線索備選池
        var potentialPieces: [String] = []
        
        // 擷取進行中習慣
        let habitFetch = FetchDescriptor<HabitItem>()
        if let allHabits = try? modelContext.fetch(habitFetch), !allHabits.isEmpty {
            let activeHabits = allHabits.filter { $0.status == 1 }
            if let randomHabit = activeHabits.randomElement() {
                // 只抓取「目前」的連續天數，不需要歷史紀錄
                let currentStreak = DateHelper.calculateStreaks(from: randomHabit.completedDates).current
                
                let statusDesc: String
                if currentStreak > 0 {
                    statusDesc = "目前已經連續打卡 \(currentStreak) 天"
                } else {
                    statusDesc = "但最近中斷了打卡"
                }
                
                let habitText = "使用者正在培養「\(randomHabit.name)」的習慣，\(statusDesc)。"
                potentialPieces.append(habitText)
            }
        }
        
        // 擷取未完成待辦事項
        let todoFetch = FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isCompleted })
        if let uncompletedTodos = try? modelContext.fetch(todoFetch), !uncompletedTodos.isEmpty {
            if let randomTodo = uncompletedTodos.randomElement() {
                var todoText = "今日待辦清單中有一項是「\(randomTodo.title)」"
                if let dueDate = randomTodo.dueDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd"
                    todoText += "，預計要在 \(formatter.string(from: dueDate)) 完成。"
                } else {
                    todoText += "。"
                }
                potentialPieces.append(todoText)
            }
        }
        
        // 擷取便利貼紀錄
        let noteFetch = FetchDescriptor<StickyNote>()
        if let allNotes = try? modelContext.fetch(noteFetch), !allNotes.isEmpty {
            if let randomNote = allNotes.randomElement() {
                let shortContent = String(randomNote.content.prefix(20))
                potentialPieces.append("便利貼上記著：「\(shortContent)...」")
            }
        }
        
        guard !potentialPieces.isEmpty else { return "" }
        
        // 隨機抽取 1 項線索作為 AI 語境字串
        potentialPieces.shuffle()
        let selectedPieces = Array(potentialPieces.prefix(1))
        
        return selectedPieces.joined(separator: "\n")
    }
}
