//
//  TodoItem.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/3.
//

import SwiftData
import Foundation

@Model
class TodoItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date // 紀錄建立時間，方便排序
    var dueDate: Date? // 不一定有期限
    var completedAt: Date? // 剛創建時沒有
    
    init(title: String, isCompleted: Bool = false, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.dueDate = dueDate
        self.completedAt = nil // 剛建立時還沒完成
    }
}
