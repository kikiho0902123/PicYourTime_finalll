//
//  07StickyNoteGalleryView.swift
//  PicDemo
//
//  Created by kikiho on 2026/6/12.
//

import SwiftUI
import SwiftData

struct StickyNoteGalleryView: View {
    // 宣告這個變數是與外部 (TodoListView) 連動的綁定狀態
    @Binding var showGallery: Bool
    
    // 依據建立時間反向排序，最新的在最上面
    @Query(sort: \StickyNote.createdAt, order: .reverse) private var notes: [StickyNote]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var theme: ThemeManager
    
    // 記錄下拉手勢的拖曳距離
    @State private var dragOffset: CGFloat = 0
    @State private var selectedNote: StickyNote? = nil
    
    @State private var showDeleteAlert = false
    @State private var noteToDelete: StickyNote? = nil
    @State private var vanishingNote: StickyNote? = nil
    
    @State private var draftText: String = ""
    
    @Namespace private var animation
    
    @FocusState private var isEditorFocused: Bool
    
    // 定義兩欄式的網格佈局
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            
            // ==========================================
            // 底層：懸浮畫廊卡片主體 (鎖定不動)
            // ==========================================
            GeometryReader { geo in
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        ScrollView {
                            if notes.isEmpty {
                                VStack(spacing: 12) {
                                    Text("還沒有任何靈感紀錄")
                                        .font(.subheadline)
                                        .foregroundColor(theme.textColor.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 120)
                            } else {
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(notes) { note in
                                        VStack(alignment: .leading) {
                                            Text(note.content)
                                                .font(.system(size: 15))
                                                .foregroundColor(theme.textColor)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(5)
                                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                            
                                            Spacer()
                                            
                                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 8.8))
                                                .foregroundColor(theme.textColor.opacity(0.6))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        .padding(12)
                                        .frame(height: 135)
                                        .background(Color(hex: note.colorHex))
                                        .matchedGeometryEffect(id: note.id, in: animation)
                                        .opacity((selectedNote?.id == note.id || vanishingNote?.id == note.id) ? 0 : 1)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 2)
                                        .onTapGesture {
                                            draftText = note.content
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                selectedNote = note
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .padding(.bottom, 24)
                                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: notes)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.76)
                    .background(theme.bgColor)
                    .cornerRadius(24)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height) // 強制鎖定畫廊容器大小
            }
            .ignoresSafeArea(.keyboard) // 這裡加上去，告訴畫廊無視鍵盤推擠

            // ==========================================
            // 頂層：點擊後放大的單一便利貼
            // ==========================================
            if let note = selectedNote {
                GeometryReader { geo in
                    ZStack {
                        Color.black.opacity(0.1) // 遮罩
                            .ignoresSafeArea()
                            .onTapGesture {
                                if isEditorFocused {
                                    // 第一階段：只收鍵盤
                                    isEditorFocused = false
                                } else {
                                    // 第二階段：鍵盤已收，關閉便利貼
                                    dismissKeyboardAndSave(note: note)
                                }
                            }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // 大張便利貼
                            VStack(alignment: .leading) {
                                TextEditor(text: $draftText)
                                    .font(.system(size: 18))
                                    .foregroundColor(theme.textColor)
                                    .scrollContentBackground(.hidden)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .focused($isEditorFocused) // 綁定焦點
                                
                                Spacer(minLength: 16)
                                
                                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textColor.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(24)
                            .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                            .background(Color(hex: note.colorHex))
                            .matchedGeometryEffect(id: note.id, in: animation)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
                            
                            Button(action: {
                                noteToDelete = note
                                showDeleteAlert = true
                            }) {
                                Image(showDeleteAlert ? "icon_trash_open" : "icon_trash")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .foregroundColor(theme.theme3)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showDeleteAlert)
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 讓便利貼在「剩下的螢幕空間」裡置中
                }
                .zIndex(100)
            }
        }
        .alert("確定要刪除這張便利貼嗎？", isPresented: $showDeleteAlert, presenting: noteToDelete) { noteToDel in
            Button("取消", role: .cancel) {
                noteToDelete = nil
            }
            
            Button("刪除", role: .destructive) {
                vanishingNote = noteToDel
                
                withAnimation(nil) {
                    selectedNote = nil
                }
                
                modelContext.delete(noteToDel)
            }
        }
    }
    
    // 抽出重複邏輯：收起鍵盤並儲存內容
    private func dismissKeyboardAndSave(note: StickyNote) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        note.content = draftText
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedNote = nil
        }
    }

    private func closeGallery() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showGallery = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dragOffset = 0
        }
    }
}
