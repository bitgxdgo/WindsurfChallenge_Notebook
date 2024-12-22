import Foundation

class ReflectionAssistant {
    private let aiService: AIServiceProtocol
    
    init(aiService: AIServiceProtocol = OllamaService()) {
        self.aiService = aiService
    }
    
    func generateReflection(
        for text: String,
        streamHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, AIError>) -> Void
    ) {
        let messages = [
            AIMessage(
                role: .system,
                content: "你是一个善于思考和提问的助手。请对用户输入的内容进行深入的思考和提问，帮助用户进行反思。"
            ),
            AIMessage(
                role: .user,
                content: text
            )
        ]
        
        let handler = ReflectionResponseHandler(
            streamHandler: streamHandler,
            completion: completion
        )
        
        aiService.sendMessages(messages, responseHandler: handler)
    }
    
    func cancelReflection() {
        aiService.cancelCurrentRequest()
    }
}

private class ReflectionResponseHandler: AIResponseHandler {
    private let streamHandler: (String) -> Void
    private let completion: (Result<Void, AIError>) -> Void
    
    init(
        streamHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, AIError>) -> Void
    ) {
        self.streamHandler = streamHandler
        self.completion = completion
    }
    
    func handleStream(_ text: String) {
        streamHandler(text)
    }
    
    func handleComplete() {
        completion(.success(()))
    }
    
    func handleError(_ error: AIError) {
        completion(.failure(error))
    }
}
