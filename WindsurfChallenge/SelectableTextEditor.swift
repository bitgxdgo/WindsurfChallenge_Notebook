import SwiftUI
import AppKit

struct SelectableTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onSelectionChange: (String, NSRange) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("Expected an NSTextView in scrollView.documentView")
        }
        
        textView.delegate = context.coordinator
        textView.isRichText = true  // 启用富文本支持
        textView.font = .systemFont(ofSize: 16)
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // 设置背景色为透明
        textView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        // 设置文本容器以使用滚动视图的宽度
        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textContainer.widthTracksTextView = true
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != text && !textView.hasMarkedText() {
            let selectedRanges = textView.selectedRanges
            let cursorLocation = textView.selectedRange().location
            
            // 查找所有 AI 反思的范围
            let nsText = text as NSString
            var searchRange = NSRange(location: 0, length: nsText.length)
            var reflectionRanges: [NSRange] = []
            
            while searchRange.location < nsText.length {
                let range = nsText.range(
                    of: "[AI反思：",
                    options: [],
                    range: searchRange
                )
                
                // 如果找不到开始标记，退出循环
                if range.location == NSNotFound { break }
                
                // 在开始标记之后查找结束标记
                let remainingRange = NSRange(
                    location: range.location,
                    length: nsText.length - range.location
                )
                let endRange = nsText.range(
                    of: "]",
                    options: [],
                    range: remainingRange
                )
                
                // 如果找不到结束标记，退出循环
                if endRange.location == NSNotFound { break }
                
                // 添加完整的反思范围
                let fullRange = NSRange(
                    location: range.location,
                    length: endRange.location - range.location + 1
                )
                reflectionRanges.append(fullRange)
                
                // 更新搜索范围
                searchRange = NSRange(
                    location: endRange.location + 1,
                    length: nsText.length - (endRange.location + 1)
                )
            }
            
            // 设置文本
            textView.string = text
            
            // 为每个反思文本设置样式
            for range in reflectionRanges {
                let italicFont = NSFontManager.shared.convert(
                    NSFont.systemFont(ofSize: 16),
                    toHaveTrait: NSFontTraitMask.italicFontMask
                )
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.systemOrange,
                    .font: italicFont
                ]
                textView.textStorage?.addAttributes(attributes, range: range)
            }
            
            // 恢复选择范围和光标位置
            if !selectedRanges.isEmpty {
                textView.selectedRanges = selectedRanges
            } else {
                let newPosition = min(cursorLocation, (text as NSString).length)
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableTextEditor
        
        init(_ parent: SelectableTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // 只在非输入法编辑状态下更新文本
            if !textView.hasMarkedText() {
                parent.text = textView.string
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // 只在非输入法编辑状态下处理选择
            if !textView.hasMarkedText() {
                let selectedRange = textView.selectedRange()
                if selectedRange.length > 0 {
                    let selectedText = (textView.string as NSString).substring(with: selectedRange)
                    parent.onSelectionChange(selectedText, selectedRange)
                } else {
                    parent.onSelectionChange("", NSRange())
                }
            }
        }
    }
}
