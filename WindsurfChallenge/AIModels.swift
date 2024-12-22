import Foundation

// 基础消息模型
struct AIMessage {
    let role: AIRole
    let content: String
}

enum AIRole: String {
    case system
    case user
    case assistant
}

// AI 响应处理器
protocol AIResponseHandler {
    func handleStream(_ text: String)
    func handleComplete()
    func handleError(_ error: AIError)
}

// AI 错误类型
enum AIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case configurationError
}
