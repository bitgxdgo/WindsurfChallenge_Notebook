import SwiftUI
import AppKit

struct AIChatView: View {
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var localPendingMessage: String?
    @State private var textEditorHeight: CGFloat = 20  // 只保留这一个高度状态
    @FocusState private var isInputFocused: Bool
    private let aiService: AIServiceProtocol = OllamaService()
    private let messagesKey = "savedMessages"
    
    // 使用静态属性来存储消息队列
    private static var pendingMessage: String? {
        didSet {
            print("AIChatView - pendingMessage 已更新为: \(String(describing: pendingMessage))")
            NotificationCenter.default.post(
                name: .init("pendingMessageChanged"),
                object: nil,
                userInfo: ["message": pendingMessage as Any]
            )
        }
    }
    
    // 添加系统提示词常量
    private let systemPrompt = """
    你是一个智能助手，帮助用户思考和解决问题。请：
    1. 保持友好和专业的态度
    2. 给出清晰和有见地的回答
    3. 如果不确定，请诚实地说明
    4. 用中文回复
    """
    
    init() {
        print("=== AIChatView 初始化开始 ===")
        _messages = State(initialValue: loadMessages())
        print("=== AIChatView 初始化完成，消息数量：\(_messages.wrappedValue.count) ===")
    }
    
    // 添加静态方法来处理消息
    static func handleIncomingMessage(_ message: String) {
        print("AIChatView - 静态方法收到消息: \(message)")
        pendingMessage = message
        print("AIChatView - pendingMessage 已设置为: \(String(describing: pendingMessage))")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("AI 对话")
                    .font(.headline)
                Spacer()
                Image(systemName: "trash")
                    .foregroundColor(.gray)
                    .onTapGesture {
                        clearMessages()
                    }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.7)
                                Spacer()
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 底部输入框
            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("输入消息...")
                            .foregroundColor(Color(nsColor: .placeholderTextColor))
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                            .font(.system(size: 14))
                    }
                    
                    CustomTextEditor(text: $inputText) {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading {
                            sendMessage()
                        }
                    }
                    .font(.system(size: 14))
                    .frame(height: max(textEditorHeight, 20))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: inputText) { newValue in
                        print("\n文本已改变: '\(newValue)'")
                        updateTextEditorHeight()
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .cornerRadius(10)
                .frame(height: max(textEditorHeight, 40))

                Image(systemName: "paperplane.fill")
                    .imageScale(.medium)
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .gray.opacity(0.5) : .white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? 0.3 : 1))
                    )
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    )
                    .onTapGesture {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading {
                            sendMessage()
                        }
                    }
            }
            .frame(height: max(textEditorHeight + 16, 56))
            .padding()
        }
        .onAppear {
            print("AIChatView - 视图出现")
            // 检查初始状态
            if let message = Self.pendingMessage {
                print("AIChatView - 发现初始待处理消息: \(message)")
                localPendingMessage = message
                Self.pendingMessage = nil
            }
            
            // 添加通知观察者
            NotificationCenter.default.addObserver(
                forName: .init("pendingMessageChanged"),
                object: nil,
                queue: .main
            ) { notification in
                if let message = notification.userInfo?["message"] as? String {
                    print("AIChatView - 收到新消息通知: \(message)")
                    localPendingMessage = message
                }
            }
        }
        .onChange(of: localPendingMessage) { newMessage in
            print("AIChatView - localPendingMessage 变化为: \(String(describing: newMessage))")
            if let message = newMessage {
                print("AIChatView - 准备发送消息")
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    sendMessage(message)
                    localPendingMessage = nil
                    print("AIChatView - 消息已发送")
                }
            }
        }
    }
    
    private func sendMessage(_ text: String? = nil) {
        let messageText = text ?? inputText
        print("AIChatView - sendMessage 被调用，消息内容: \(messageText)")
        
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            print("AIChatView - 消息内容为空，退出")
            return 
        }
        
        // 添加用户消息
        let userMessage = ChatMessage(
            id: UUID(),
            content: messageText,
            isUser: true,
            timestamp: Date()
        )
        print("AIChatView - 添加用户消息到消息列表")
        messages.append(userMessage)
        saveMessages()
        
        // 清空输入框并开始加载
        inputText = ""
        isLoading = true
        print("AIChatView - 开始加载状态")
        
        // 准备发送给 AI 的消息历史
        var allMessages = [
            AIMessage(role: .system, content: systemPrompt)
        ]
        
        allMessages.append(contentsOf: messages.suffix(10).map { message in
            AIMessage(
                role: message.isUser ? .user : .assistant,
                content: message.content
            )
        })
        
        print("AIChatView - 准备发送请求给 AI 服务")
        // 发送请求
        aiService.sendMessages(allMessages) { text in
            print("AIChatView - 收到 AI 响应流: \(text)")
            DispatchQueue.main.async {
                if let lastMessage = messages.last, !lastMessage.isUser {
                    messages[messages.count - 1].content += text
                    saveMessages()
                } else {
                    let aiMessage = ChatMessage(
                        id: UUID(),
                        content: text,
                        isUser: false,
                        timestamp: Date()
                    )
                    messages.append(aiMessage)
                    saveMessages()
                }
            }
        } handleComplete: {
            print("AIChatView - AI 响应完成")
            DispatchQueue.main.async {
                isLoading = false
            }
        } handleError: { error in
            print("AIChatView - 发生错误: \(error)")
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
    
    // 添加保存消息的方法
    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: messagesKey)
        }
    }
    
    // 添加加载消息的方法
    private func loadMessages() -> [ChatMessage] {
        print("正在从 UserDefaults 加载消息...")
        if let data = UserDefaults.standard.data(forKey: messagesKey),
           let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            print("成功加载消息，数量: \(decoded.count)")
            return decoded
        }
        print("没有找到存储的消息")
        return []
    }
    
    // 添加清空消息的方法
    private func clearMessages() {
        print("=== 开始清除消息 ===")
        print("清除前消息数量：\(messages.count)")
        messages.removeAll()
        saveMessages()
        UserDefaults.standard.synchronize()
        
        // 清除待处理的消息
        Self.pendingMessage = nil
        localPendingMessage = nil
        
        // 验证清除结果
        if let data = UserDefaults.standard.data(forKey: messagesKey),
           let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            print("警告：清除后 UserDefaults 中仍有 \(messages.count) 条消息")
        } else {
            print("确认：UserDefaults 中的消息已完全清除")
        }
        print("=== 清除消息完成 ===")
    }
    
    // 添加这个方法来更新输入框高度
    private func updateTextEditorHeight() {
        print("开始计算新高度，当前文本内容：'\(inputText)'")
        print("当前 textEditorHeight: \(textEditorHeight)")
        
        let width = NSScreen.main?.frame.width ?? 800 - 80
        print("计算使用的宽度: \(width)")
        
        let rawHeight = inputText.height(withConstrainedWidth: width, font: .systemFont(ofSize: 17))
        print("文本原始高度: \(rawHeight)")
        
        let newHeight = min(rawHeight + 20, 100)
        print("计算后的新高度: \(newHeight)")
        
        if newHeight != textEditorHeight {
            print("高度将要改变：\(textEditorHeight) -> \(newHeight)")
            textEditorHeight = newHeight
            print("高度已更新为: \(textEditorHeight)")
        } else {
            print("高度无需改变，保持在: \(textEditorHeight)")
        }
    }
}

// 聊天消息模型
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    let isUser: Bool
    let timestamp: Date
    
    // 实现 Equatable 协议
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.content == rhs.content &&
               lhs.isUser == rhs.isUser &&
               lhs.timestamp == rhs.timestamp
    }
}

// 消息气泡视图
struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content)
                .padding(10)
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(12)
                .textSelection(.enabled)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// 创建一个 ResponseHandler 类来实现 AIResponseHandler 协议
class ChatResponseHandler: AIResponseHandler {
    private let onStream: (String) -> Void
    private let onComplete: () -> Void
    private let onError: (AIError) -> Void
    
    init(
        onStream: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (AIError) -> Void
    ) {
        self.onStream = onStream
        self.onComplete = onComplete
        self.onError = onError
    }
    
    func handleStream(_ text: String) {
        onStream(text)
    }
    
    func handleComplete() {
        onComplete()
    }
    
    func handleError(_ error: AIError) {
        onError(error)
    }
}

// 扩展 AIService 以支持更简洁的回调语法
extension AIServiceProtocol {
    func sendMessages(
        _ messages: [AIMessage],
        handleStream: @escaping (String) -> Void,
        handleComplete: @escaping () -> Void,
        handleError: @escaping (AIError) -> Void
    ) {
        let handler = ChatResponseHandler(
            onStream: handleStream,
            onComplete: handleComplete,
            onError: handleError
        )
        sendMessages(messages, responseHandler: handler)
    }
}

// 添加 View 扩展来支持条件修饰符
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// 在文件末尾添加这个 PreferenceKey
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// 修改 String 扩展
extension String {
    func height(withConstrainedWidth width: CGFloat, font: NSFont) -> CGFloat {
        let text = self.isEmpty ? " " : self  // 确保空字符串也有高度
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
        )
        
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingRect = attributedString.boundingRect(
            with: constraintRect,
            options: [.usesFontLeading, .usesLineFragmentOrigin]
        )
        
        return ceil(boundingRect.height)
    }
}

// 在文件末尾添加这个扩展
extension NSView {
    func findTextView() -> NSTextView? {
        if let textView = self as? NSTextView {
            return textView
        }
        for subview in self.subviews {
            if let textView = subview.findTextView() {
                return textView
            }
        }
        return nil
    }
}

#Preview {
    AIChatView()
}