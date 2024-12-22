import SwiftUI

class NoteReflectionViewModel: ObservableObject {
    @Published var selectedText: String = ""
    @Published var selectedRange: NSRange?
    @Published var showReflectionButton: Bool = false
    @Published var isGeneratingReflection: Bool = false
    
    private let reflectionAssistant: ReflectionAssistant
    var onContentUpdate: ((String) -> Void)?
    
    init(reflectionAssistant: ReflectionAssistant = ReflectionAssistant()) {
        self.reflectionAssistant = reflectionAssistant
    }
    
    func generateReflection(in fullText: String) {
        guard !selectedText.isEmpty, let range = selectedRange else { return }
        
        isGeneratingReflection = true
        var accumulatedReflection = "\n[AI反思："
        var currentText = fullText
        
        reflectionAssistant.generateReflection(
            for: selectedText,
            streamHandler: { [weak self] newContent in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    // 只添加新内容
                    accumulatedReflection += newContent
                    
                    // 每次流式更新时，都用完整的反思内容替换之前的内容
                    let tempReflection = accumulatedReflection  // 暂存当前累积的内容
                    let newContent = self.insertReflection(
                        tempReflection,
                        at: range,
                        in: fullText  // 使用原始文本，而不是 currentText
                    )
                    self.onContentUpdate?(newContent)
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    if case .success = result {
                        accumulatedReflection += "]\n"
                        if let self = self {
                            // 最后一次更新，插入完整的反思内容
                            let finalContent = self.insertReflection(
                                accumulatedReflection,
                                at: range,
                                in: fullText  // 使用原始文本
                            )
                            self.onContentUpdate?(finalContent)
                            self.clearSelection()
                        }
                    }
                    self?.isGeneratingReflection = false
                }
            }
        )
    }
    
    private func insertReflection(_ reflection: String, at range: NSRange, in text: String) -> String {
        // 打印调试信息
        print("原始文本长度: \(text.count)")
        print("选中范围: location=\(range.location), length=\(range.length)")
        
        let nsString = text as NSString
        let endLocation = range.location + range.length
        
        // 验证位置是否有效
        guard endLocation <= nsString.length else {
            print("❌ 插入位置超出文本范围")
            return text
        }
        
        let before = nsString.substring(to: endLocation)
        let after = nsString.substring(from: endLocation)
        
        print("✅ 插入位置: \(endLocation)")
        print("前半部分长度: \(before.count)")
        print("后半部分长度: \(after.count)")
        
        return before + reflection + after
    }
    
    func updateSelection(_ selectedText: String, range: NSRange) {
        self.selectedText = selectedText
        self.selectedRange = range
        self.showReflectionButton = !selectedText.isEmpty
    }
    
    func clearSelection() {
        selectedText = ""
        selectedRange = nil
        showReflectionButton = false
    }
    
    func cancelReflection() {
        reflectionAssistant.cancelReflection()
        isGeneratingReflection = false
        clearSelection()
    }
}
