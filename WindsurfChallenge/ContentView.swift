//
//  ContentView.swift
//  WindsurfChallenge
//
//  Created by Zhuanz1密码0000 on 2024/12/12.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WindsurfChallengeFolder.name, ascending: true)],
        animation: .default)
    private var folders: FetchedResults<WindsurfChallengeFolder>
    
    @State private var selectedFolder: WindsurfChallengeFolder?
    @State private var selectedNote: WindsurfChallengeNote?
    @State private var isEditing = false
    @State private var isFileImporterPresented = false
    @State private var isAIChatPresented = false
    @State private var chatPanelWidth: CGFloat = 300 // 默认宽度
    
    // 保持一个持久的 AIChatView 引用
    private let aiChatView = AIChatView()
    
    var body: some View {
        NavigationSplitView(
            sidebar: {
                SidebarView(selectedFolder: $selectedFolder)
            },
            content: {
                if let folder = selectedFolder {
                    NoteListView(folder: folder, selectedNote: $selectedNote)
                } else {
                    Text("选择一个文件夹")
                }
            },
            detail: {
                HStack(spacing: 0) {
                    if let note = selectedNote {
                        NoteDetailView(note: note, isAIChatPresented: $isAIChatPresented)
                    } else {
                        Text("选择一个笔记")
                    }
                    
                    if isAIChatPresented {
                        Divider()
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.resizeLeftRight.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newWidth = max(250, min(600, chatPanelWidth - value.translation.width))
                                        chatPanelWidth = newWidth
                                    }
                            )
                        
                        aiChatView  // 使用持久的实例
                            .frame(width: chatPanelWidth)
                            .transition(.move(edge: .trailing))
                    }
                }
                .animation(.spring(duration: 0.3), value: isAIChatPresented)
            }
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button(action: { isFileImporterPresented = true }) {
                        Label("上传文件", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { isAIChatPresented.toggle() }) {
                        Label("AI对话", systemImage: "message")
                            .foregroundColor(isAIChatPresented ? .blue : .primary)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleSelectedFile(result)
        }
        .onAppear {
            // 如果没有选中的文件夹,则自动选中第一个
            if selectedFolder == nil && !folders.isEmpty {
                selectedFolder = folders.first
            }
        }
    }
    
    private func handleSelectedFile(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let selectedUrl = urls.first else { return }
            
            // 确保文件可访问
            guard selectedUrl.startAccessingSecurityScopedResource() else {
                print("无法访问选中的文件")
                return
            }
            
            defer {
                selectedUrl.stopAccessingSecurityScopedResource()
            }
            
            let data = try Data(contentsOf: selectedUrl)
            let decoder = JSONDecoder()
            let importItems = try decoder.decode([NoteImportItem].self, from: data)
            
            // 确保有选中的文件夹
            guard let currentFolder = selectedFolder else {
                print("请先选择一个文件夹")
                return
            }
            
            // 批量创建笔记
            importItems.forEach { item in
                createNote(from: item, in: currentFolder)
            }
            
        } catch {
            print("处理文件失败: \(error.localizedDescription)")
        }
    }
    
    private func createNote(from item: NoteImportItem, in folder: WindsurfChallengeFolder) {
        let newNote = WindsurfChallengeNote(context: viewContext)
        newNote.title = item.title
        newNote.content = item.answer
        newNote.folder = folder
        newNote.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("创建笔记失败: \(error.localizedDescription)")
        }
    }
    
    private func addFolder() {
        withAnimation {
            let newFolder = WindsurfChallengeFolder(context: viewContext)
            newFolder.name = "新建文件夹"
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteFolder(folder: WindsurfChallengeFolder) {
        withAnimation {
            viewContext.delete(folder)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct NoteListView: View {
    @ObservedObject var folder: WindsurfChallengeFolder
    @Binding var selectedNote: WindsurfChallengeNote?
    @Environment(\.managedObjectContext) private var viewContext
    
    // 使用 FetchRequest 直接按 updatedAt 降序排序
    @FetchRequest private var notes: FetchedResults<WindsurfChallengeNote>
    
    // 追踪前一个文件夹的 objectID
    @State private var previousFolderID: NSManagedObjectID?
    
    init(folder: WindsurfChallengeFolder, selectedNote: Binding<WindsurfChallengeNote?>) {
        self.folder = folder
        self._selectedNote = selectedNote
        self._notes = FetchRequest(
            entity: WindsurfChallengeNote.entity(),
            sortDescriptors: [
                NSSortDescriptor(keyPath: \WindsurfChallengeNote.updatedAt, ascending: false)
            ],
            predicate: NSPredicate(format: "folder == %@", folder)
        )
    }
    
    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                NavigationLink(value: note) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.title ?? "未命名")
                            .font(.headline)
                            .lineLimit(1)
                        
                        if let content = note.content, !content.isEmpty {
                            Text(content)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                        
                        if let updatedAt = note.updatedAt {
                            Text(formatDate(updatedAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteNotes)
        }
        .toolbar {
            ToolbarItem {
                Button(action: addNote) {
                    Label("新建笔记", systemImage: "plus")
                }
            }
        }
        .onAppear {
            // 初始化 previousFolderID
            previousFolderID = folder.objectID
            selectFirstNoteIfNeeded(currentFolder: folder)
        }
        .onChange(of: folder) { newFolder in
            // 检查文件夹是否真的发生了变化
            if previousFolderID != newFolder.objectID {
                previousFolderID = newFolder.objectID
                selectFirstNoteIfNeeded(currentFolder: newFolder)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.compare(date, to: now, toGranularity: .year) == .orderedSame {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    }
    
    private func selectFirstNoteIfNeeded(currentFolder: WindsurfChallengeFolder) {
        DispatchQueue.main.async {
            if !notes.isEmpty {
                // 仅在切换文件夹时自动选中第一笔记
                if selectedNote?.folder != currentFolder {
                    selectedNote = notes.first
                }
            } else {
                selectedNote = nil
            }
        }
    }
    
    private func addNote() {
        withAnimation {
            let newNote = WindsurfChallengeNote(context: viewContext)
            newNote.title = "新建笔记"
            newNote.content = ""
            newNote.folder = folder
            newNote.updatedAt = Date()
            
            do {
                try viewContext.save()
                selectedNote = newNote
            } catch {
                let nsError = error as NSError
                print("创建笔记失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            offsets.map { notes[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
                // 如果删除的是当前选中的笔记，重新选择第一条笔记
                if selectedNote == nil {
                    selectedNote = notes.first
                }
            } catch {
                let nsError = error as NSError
                print("删除笔记失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct NoteDetailView: View {
    @ObservedObject var note: WindsurfChallengeNote
    @Environment(\.managedObjectContext) private var viewContext
    @State private var title: String
    @State private var content: String
    @Binding var isAIChatPresented: Bool
    
    init(note: WindsurfChallengeNote, isAIChatPresented: Binding<Bool>) {
        self.note = note
        _title = State(initialValue: note.title ?? "")
        _content = State(initialValue: note.content ?? "")
        _isAIChatPresented = isAIChatPresented
        print("NoteDetailView 初始化 - 笔记标题: \(note.title ?? "未命名")")
    }
    
    private func getSelectedText() -> String {
        if let textView = NSApplication.shared.keyWindow?.firstResponder as? NSTextView {
            return textView.selectedText ?? ""
        }
        return ""
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 日期显示移到最上方
                    if let date = note.updatedAt {
                        Text(formatDate(date))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                    }
                    
                    // 标题
                    TextField("标题", text: $title)
                        .font(.system(size: 20, weight: .bold))
                        .textFieldStyle(.plain)
                        .padding(.bottom, 16)
                    
                    // 内容
                    TextEditor(text: $content)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .scrollContentBackground(.hidden)
                }
                .padding(20)
            }
            
            // 反思按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ReflectionButton(isGenerating: false) {
                        print("反思按钮被点击")
                        // 1. 显示 AI 会话栏
                        isAIChatPresented = true
                        
                        // 2. 获取选中文本并发送消息
                        let selectedText = getSelectedText()
                        let message = selectedText.isEmpty 
                            ? "我想你了！" 
                            : "你是我的日记助手，帮我对这段笔记内容进行反思:\(selectedText)"
                        
                        print("准备发送消息: \(message)")
                        
                        // 3. 直接调用 AIChatView 的静态方法
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // 添加小延迟确保 AI 会话栏已经显示
                            AIChatView.handleIncomingMessage(message)
                        }
                        print("已调用消息处理方法")
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .onChange(of: title) { newValue in
            if newValue != note.title {
                print("标题更新 - 从: \(note.title ?? "") 到: \(newValue)")
                note.title = newValue
                note.updatedAt = Date()
                saveContext()
            }
        }
        .onChange(of: content) { newValue in
            if newValue != note.content {
                print("内容更新 - 笔记: \(note.title ?? "")")
                note.content = newValue
                note.updatedAt = Date()
                saveContext()
            }
        }
        .onChange(of: note) { newNote in
            if newNote != note {
                title = newNote.title ?? ""
                content = newNote.content ?? ""
                print("笔记切换 - 更新到新笔记: \(newNote.title ?? "未命名")")
            }
        }
        .onAppear {
            print("NoteDetailView 显示 - 笔记标题: \(note.title ?? "未命名")")
        }
        .onDisappear {
            print("NoteDetailView 消失 - 笔记标题: \(note.title ?? "未命名")")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("保存笔记失败: \(error.localizedDescription)")
        }
    }
}

// 修正 NSTextView 扩展
extension NSTextView {
    var selectedText: String? {
        let range = selectedRange()
        guard range.length > 0 else { return nil }
        return attributedString().attributedSubstring(from: range).string
    }
}

// 取消注释并启用反思按钮视图
struct ReflectionButton: View {
    let isGenerating: Bool
    let action: () -> Void
    
    var body: some View {
        if isGenerating {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
        } else {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .onTapGesture {
                    action()
                }
        }
    }
}

// 添加新的通知名称
extension Notification.Name {
    static let noteContentChanged = Notification.Name("noteContentChanged")
    static let sendReflectionMessage = Notification.Name("sendReflectionMessage")
}

// 侧边栏视图
struct SidebarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedFolder: WindsurfChallengeFolder?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WindsurfChallengeFolder.name, ascending: true)],
        predicate: NSPredicate(format: "parentFolder == nil"),
        animation: .default)
    private var rootFolders: FetchedResults<WindsurfChallengeFolder>
    
    enum DialogType: Identifiable {
        case newFolder
        case renameFolder(WindsurfChallengeFolder)
        
        var id: Int {
            switch self {
            case .newFolder:
                return 0
            case .renameFolder:
                return 1
            }
        }
    }
    
    @State private var activeDialog: DialogType?
    @State private var newFolderName: String = ""
    
    var body: some View {
        List(selection: $selectedFolder) {
            // Section("快速访问") {
            //     NavigationLink(value: nil as WindsurfChallengeFolder?) {
            //         Label("所有笔记", systemImage: "note.text")
            //     }
            // }
            
            Section("文件夹") {
                ForEach(rootFolders) { folder in
                    NavigationLink(value: folder) {
                        Label(folder.name ?? "", systemImage: "folder")
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteFolder(folder: folder)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            newFolderName = folder.name ?? ""
                            activeDialog = .renameFolder(folder)
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: {
                    newFolderName = ""
                    activeDialog = .newFolder
                }) {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(item: $activeDialog) { dialogType in
            switch dialogType {
            case .newFolder:
                FolderNameDialog(
                    title: "新建文件夹",
                    buttonTitle: "创建",
                    folderName: $newFolderName,
                    onSubmit: { name in
                        addFolder(name: name)
                    },
                    onCancel: {
                        activeDialog = nil
                    }
                )
            case .renameFolder(let folder):
                FolderNameDialog(
                    title: "重命名文件夹",
                    buttonTitle: "确定",
                    folderName: $newFolderName,
                    onSubmit: { name in
                        renameFolder(folder: folder, newName: name)
                    },
                    onCancel: {
                        activeDialog = nil
                    }
                )
            }
        }
    }
    
    private func addFolder(name: String) {
        withAnimation {
            let newFolder = WindsurfChallengeFolder(context: viewContext)
            newFolder.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
        activeDialog = nil
    }
    
    private func deleteFolder(folder: WindsurfChallengeFolder) {
        withAnimation {
            viewContext.delete(folder)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func renameFolder(folder: WindsurfChallengeFolder, newName: String) {
        withAnimation {
            folder.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
        activeDialog = nil
    }
}

struct FolderNameDialog: View {
    let title: String
    let buttonTitle: String
    @Binding var folderName: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            
            TextField("文件夹名称", text: $folderName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            HStack(spacing: 20) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button(buttonTitle) {
                    onSubmit(folderName)
                }
                .keyboardShortcut(.return)
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 150)
    }
}

struct FolderItemView: View {
    let folder: WindsurfChallengeFolder
    
    var body: some View {
        NavigationLink(value: folder) {
            Label(folder.name ?? "", systemImage: "folder")
        }
    }
}

// 笔记编辑视图
struct NoteEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let note: WindsurfChallengeNote?
    @State private var title: String = ""
    @State private var content: String = ""
    
    var body: some View {
        if let note = note {
            VStack {
                TextField("标题", text: $title)
                    .textFieldStyle(.plain)
                    .font(.title)
                    .padding(.horizontal)
                
                TextEditor(text: $content)
                    .padding(.horizontal)
            }
            .onAppear {
                title = note.title ?? ""
                content = note.content ?? ""
            }
            .onChange(of: title) { newValue in
                if newValue != note.title {
                    note.title = newValue
                    note.updatedAt = Date()
                    save()
                }
            }
            .onChange(of: content) { newValue in
                if newValue != note.content {
                    note.content = newValue
                    note.updatedAt = Date()
                    save()
                }
            }
        } else {
            Text("请选择一个笔记")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving note: \(error)")
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}