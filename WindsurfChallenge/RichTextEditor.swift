import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    var note: WindsurfChallengeNote
    
    // 添加获取选中文本的回调
    var onSelectionChange: ((String) -> Void)?
    
    class CustomTextView: NSTextView {
        // 移除 selectedText 属性，改用方法
        func getSelectedText() -> String? {
            let range = selectedRange()
            guard range.length > 0 else { return nil }
            return attributedString().attributedSubstring(from: range).string
        }
    }
    
    // 添加 createAttributedString 方法
    private func createAttributedString(from text: String, note: WindsurfChallengeNote) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        print("开始处理文本：\(text)") // 调试信息
        
        // 查找并替换图片标记
        let pattern = #"!\[image-([0-9a-fA-F-]+)\]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length)) ?? []
        
        print("找到 \(matches.count) 个图片标记") // 调试信息
        
        // 从后向前替换，以保持位置正确
        for match in matches.reversed() {
            if let idRange = Range(match.range(at: 1), in: text),
               let imageId = UUID(uuidString: String(text[idRange])) {
                
                print("处理图片ID：\(imageId)") // 调试信息
                
                // 从 CoreData 获取图片
                let fetchRequest: NSFetchRequest<WindsurfChallengeNoteImage> = WindsurfChallengeNoteImage.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@ AND note == %@", imageId as CVarArg, note)
                
                if let context = note.managedObjectContext,
                   let images = try? context.fetch(fetchRequest) {
                    print("找到 \(images.count) 个匹配的图片") // 调试信息
                    
                    if let imageData = images.first?.imageData,
                       let nsImage = NSImage(data: imageData) {
                        print("成功创建 NSImage，大小：\(nsImage.size)") // 调试信息
                        
                        // 创建图片附件
                        let attachment = NSTextAttachment()
                        attachment.image = nsImage
                        
                        // 调整图片大小
                        let maxWidth: CGFloat = 300
                        let aspectRatio = nsImage.size.width / nsImage.size.height
                        let newSize = CGSize(
                            width: min(maxWidth, nsImage.size.width),
                            height: min(maxWidth / aspectRatio, nsImage.size.height)
                        )
                        attachment.bounds = CGRect(origin: .zero, size: newSize)
                        
                        // 创建带有附件的属性字符串
                        let imageString = NSAttributedString(attachment: attachment)
                        attributedString.replaceCharacters(in: match.range, with: imageString)
                        
                        print("成功替换图片标记") // 调试信息
                    } else {
                        print("无法创建 NSImage 或获取图片数据") // 调试信息
                    }
                } else {
                    print("在 CoreData 中未找到匹配的图片") // 调试信息
                }
            }
        }
        
        return attributedString
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CustomTextView()
        
        // 配置 NSTextView
        textView.isRichText = true
        textView.allowsImageEditing = true
        textView.isEditable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.font = .systemFont(ofSize: 14) // 保持原有字体大小
        textView.delegate = context.coordinator
        
        // 确保 textView 可以成为第一响应者
        textView.isSelectable = true
        
        // 启用自动换行
        textView.textContainer?.containerSize = NSSize(width: textView.frame.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // 配置 NSScrollView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        
        // 注册选择变化的通知
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textViewSelectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomTextView else { return }
        
        // 只在内容发生实际变化时更新
        if textView.string != text {
            let attributedString = createAttributedString(from: text, note: note)
            
            // 在主线程更新 UI
            DispatchQueue.main.async {
                textView.textStorage?.beginEditing()
                textView.textStorage?.setAttributedString(attributedString)
                textView.textStorage?.endEditing()
                
                // 保持光标位置
                let selectedRanges = textView.selectedRanges
                textView.selectedRanges = selectedRanges
            }
        }
    }
    
    // 添加图片处理方法
    func handleImageInsertion(_ imageData: Data, at position: Int, in textView: CustomTextView) {
        guard let image = NSImage(data: imageData) else {
            print("无法从数据创建 NSImage")
            return
        }
        
        print("准备插入图片，大小：\(image.size)")
        
        // 在主线程中处理 CoreData 操作
        DispatchQueue.main.async {
            // 创建并保存图片到 CoreData
            let context = note.managedObjectContext!
            let noteImage = WindsurfChallengeNoteImage(context: context)
            noteImage.id = UUID()
            noteImage.imageData = imageData
            noteImage.createdAt = Date()
            
            // 设置双向关系
            noteImage.note = note
            let images = note.mutableSetValue(forKey: "images")
            images.add(noteImage)
            
            do {
                try context.save()
                print("成功保存图片到 CoreData")
                
                // 插入图片标记到文本
                let imageMarker = "![image-\(noteImage.id!.uuidString)]"
                let currentContent = textView.string
                
                let prefix = String(currentContent.prefix(position))
                let suffix = String(currentContent.dropFirst(position))
                let newContent = prefix + imageMarker + suffix
                
                print("插入的图片标记：\(imageMarker)")
                
                // 更新文本
                self.text = newContent
                
            } catch {
                print("保存图片失败: \(error)")
                // 回滚上下文
                context.rollback()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CustomTextView else { return }
            parent.text = textView.string
            
            NotificationCenter.default.post(
                name: .noteContentChanged,
                object: nil
            )
        }
        
        @objc func textViewSelectionDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CustomTextView,
                  let selectedText = textView.getSelectedText() else { return }
            
            parent.onSelectionChange?(selectedText)
        }
        
        // 修改图片粘贴处理
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // 检查粘贴板是否包含图片
            if replacementString == nil,
               let pasteboard = NSPasteboard.general.pasteboardItems?.first,
               let imageData = pasteboard.data(forType: .tiff) {
                
                // 使用父视图的方法处理图片插入
                if let customTextView = textView as? CustomTextView {
                    parent.handleImageInsertion(imageData, at: affectedCharRange.location, in: customTextView)
                }
                return false
            }
            return true
        }
    }
}
