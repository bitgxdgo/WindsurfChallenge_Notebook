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
    
    var body: some View {
        NavigationSplitView(
            sidebar: {
                SidebarView(selectedFolder: $selectedFolder)
                    // .toolbar {
                    //     ToolbarItem {
                    //         Button(action: addFolder) {
                    //             Label("新建文件夹", systemImage: "folder.badge.plus")
                    //         }
                    //     }
                    // }
            },
            content: {
                if let folder = selectedFolder {
                    NoteListView(folder: folder, selectedNote: $selectedNote)
                } else {
                    Text("选择一个文件夹")
                }
            },
            detail: {
                if let note = selectedNote {
                    NoteDetailView(note: note)
                } else {
                    Text("选择一个笔记")
                }
            }
        )
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
    @FetchRequest var notes: FetchedResults<WindsurfChallengeNote>
    
    init(folder: WindsurfChallengeFolder, selectedNote: Binding<WindsurfChallengeNote?>) {
        self.folder = folder
        self._selectedNote = selectedNote
        self._notes = FetchRequest(
            entity: WindsurfChallengeNote.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \WindsurfChallengeNote.updatedAt, ascending: false)],
            predicate: NSPredicate(format: "folder == %@", folder)
        )
        print("NoteListView 初始化 - 文件夹: \(folder.name ?? "未命名")")
    }
    
    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                NavigationLink(value: note) {
                    VStack(alignment: .leading, spacing: 8) {
                        // 标题
                        Text(note.title ?? "未命名")
                            .font(.headline)
                            .lineLimit(1)
                        
                        // 内容预览
                        if let content = note.content, !content.isEmpty {
                            Text(content)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                        
                        // 更新时间
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
        .id(folder.objectID)
        .toolbar {
            ToolbarItem {
                Button(action: addNote) {
                    Label("Add Note", systemImage: "plus")
                }
            }
        }
        .onAppear {
            print("NoteListView onAppear - 文件夹: \(folder.name ?? "未命名")")
            selectFirstNoteIfNeeded()
        }
        .onChange(of: folder) { newFolder in
            print("文件夹切换 - 从: \(folder.name ?? "未命名") 到: \(newFolder.name ?? "未命名")")
            selectFirstNoteIfNeeded()
        }
    }
    
    // 格式化日期的辅助函数
    private func formatDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            // 今天的显示具体时间
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.compare(date, to: now, toGranularity: .year) == .orderedSame {
            // 今年的显示月日
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        } else {
            // 往年的显示年月日
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    }
    
    private func selectFirstNoteIfNeeded() {
        DispatchQueue.main.async {
            print("执行 selectFirstNoteIfNeeded - 文件夹: \(folder.name ?? "未命名")")
            print("当前笔记数量: \(notes.count)")
            if !notes.isEmpty {
                selectedNote = notes.first
                print("选中第一条笔记: \(notes.first?.title ?? "未命名")")
            } else {
                selectedNote = nil
                print("笔记列表为空，清除选中笔记")
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
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            offsets.map { notes[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct NoteDetailView: View {
    @ObservedObject var note: WindsurfChallengeNote
    @Environment(\.managedObjectContext) private var viewContext
    @State private var title: String
    @State private var content: String
    
    init(note: WindsurfChallengeNote) {
        self.note = note
        _title = State(initialValue: note.title ?? "")
        _content = State(initialValue: note.content ?? "")
        print("NoteDetailView 初始化 - 笔记标题: \(note.title ?? "未命名")")
    }
    
    var body: some View {
        VStack {
            TextField("Title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onChange(of: title) { newValue in
                    print("标题更新 - 从: \(note.title ?? "") 到: \(newValue)")
                    note.title = newValue
                    note.updatedAt = Date()
                    try? viewContext.save()
                }
            
            TextEditor(text: $content)
                .padding()
                .onChange(of: content) { newValue in
                    print("内容更新 - 笔记: \(note.title ?? "")")
                    note.content = newValue
                    note.updatedAt = Date()
                    try? viewContext.save()
                }
        }
        .onChange(of: note) { newNote in
            title = newNote.title ?? ""
            content = newNote.content ?? ""
            print("笔记切换 - 更新到新笔记: \(newNote.title ?? "未命名")")
        }
        .onAppear {
            print("NoteDetailView 显示 - 笔记标题: \(note.title ?? "未命名")")
        }
        .onDisappear {
            print("NoteDetailView 消失 - 笔记标题: \(note.title ?? "未命名")")
        }
    }
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
            Section("快速访问") {
                NavigationLink(value: nil as WindsurfChallengeFolder?) {
                    Label("所有笔记", systemImage: "note.text")
                }
            }
            
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

// 笔记列表视图
struct NoteListViewOld: View {
    @Environment(\.managedObjectContext) private var viewContext
    let folder: WindsurfChallengeFolder?
    @Binding var selectedNote: WindsurfChallengeNote?
    
    var body: some View {
        Group {
            if let folder = folder {
                NotesList(folder: folder, selectedNote: $selectedNote)
            } else {
                Text("请选择一个文件夹")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct NotesList: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var notes: FetchedResults<WindsurfChallengeNote>
    @Binding var selectedNote: WindsurfChallengeNote?
    let folder: WindsurfChallengeFolder
    
    init(folder: WindsurfChallengeFolder, selectedNote: Binding<WindsurfChallengeNote?>) {
        self.folder = folder
        _notes = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \WindsurfChallengeNote.updatedAt, ascending: false)],
            predicate: NSPredicate(format: "folder == %@", folder)
        )
        _selectedNote = selectedNote
    }
    
    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                NavigationLink(value: note) {
                    VStack(alignment: .leading) {
                        Text(note.title ?? "未命名")
                            .font(.headline)
                        if let date = note.updatedAt {
                            Text(date.formatted())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        deleteNote(note)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    
                    Button {
                        // 重命名功能待实现
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: addNote) {
                    Label("新建笔记", systemImage: "square.and.pencil")
                }
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
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteNote(_ note: WindsurfChallengeNote) {
        withAnimation {
            if selectedNote == note {
                selectedNote = nil
            }
            viewContext.delete(note)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
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
                note.title = newValue
                note.updatedAt = Date()
                save()
            }
            .onChange(of: content) { newValue in
                note.content = newValue
                note.updatedAt = Date()
                save()
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
