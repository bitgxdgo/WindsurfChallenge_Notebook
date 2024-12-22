import SwiftUI

struct AIChatView: View {
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var localPendingMessage: String?
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
        _messages = State(initialValue: loadMessages())
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
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // 消息列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        ChatMessageView(message: message)
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
            
            // 底部输入框
            HStack(spacing: 8) {
                TextField("输入消息...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit { sendMessage() }
                
                Button(action: { sendMessage() }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
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
        if let data = UserDefaults.standard.data(forKey: messagesKey),
           let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            return decoded
        }
        return []
    }
}

// 聊天消息模型
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    var content: String
    let isUser: Bool
    let timestamp: Date
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

#Preview {
    AIChatView()
}
