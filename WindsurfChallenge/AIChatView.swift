import SwiftUI

struct AIChatView: View {
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    private let aiService: AIServiceProtocol = OllamaService()
    
    // 添加系统提示词常量
    private let systemPrompt = """
    你是一个智能助手，帮助用户思考和解决问题。请：
    1. 保持友好和专业的态度
    2. 给出清晰和有见地的回答
    3. 如果不确定，请诚实地说明
    4. 用中文回复
    """
    
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
                    .onSubmit(sendMessage)
                
                Button(action: sendMessage) {
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
        .background(Color.white)
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 添加用户消息
        let userMessage = ChatMessage(
            id: UUID(),
            content: inputText,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // 清空输入框并开始加载
        let userInput = inputText
        inputText = ""
        isLoading = true
        
        // 准备发送给 AI 的消息历史，添加系统提示词
        var aiMessages = [AIMessage(role: .system, content: systemPrompt)]
        
        // 添加最近的对话历史
        aiMessages.append(contentsOf: messages.suffix(10).map { message in
            AIMessage(
                role: message.isUser ? .user : .assistant,
                content: message.content
            )
        })
        
        // 发送请求
        aiService.sendMessages(aiMessages) { text in
            DispatchQueue.main.async {
                if let lastMessage = messages.last, !lastMessage.isUser {
                    // 如果最后一条是 AI 消息，则附加到该消息
                    messages[messages.count - 1].content += text
                } else {
                    // 否则创建新的 AI 消息
                    let aiMessage = ChatMessage(
                        id: UUID(),
                        content: text,
                        isUser: false,
                        timestamp: Date()
                    )
                    messages.append(aiMessage)
                }
            }
        } handleComplete: {
            DispatchQueue.main.async {
                isLoading = false
            }
        } handleError: { error in
            DispatchQueue.main.async {
                isLoading = false
                // 可以添加错误处理UI
                print("Error: \(error)")
            }
        }
    }
}

// 聊天消息模型
struct ChatMessage: Identifiable {
    let id: UUID
    var content: String // 改为可变
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
