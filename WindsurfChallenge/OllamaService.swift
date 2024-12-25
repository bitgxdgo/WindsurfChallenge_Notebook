import Foundation

class OllamaService: AIServiceProtocol {
    private let baseURL = "http://localhost:11434/v1/chat/completions"
    private let model: String
    private var currentTask: URLSessionDataTask?
    
    init(model: String = "qwen2:0.5b") {
        self.model = model
    }
    
    func sendMessages(_ messages: [AIMessage], responseHandler: AIResponseHandler) {
        guard let url = URL(string: baseURL) else {
            responseHandler.handleError(.invalidURL)
            return
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { [
                "role": $0.role.rawValue,
                "content": $0.content
            ]},
            "stream": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            responseHandler.handleError(.networkError(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                responseHandler.handleError(.networkError(error))
                return
            }
            
            guard let data = data else {
                responseHandler.handleError(.invalidResponse)
                return
            }
            
            // 解析流式响应
            if let text = String(data: data, encoding: .utf8) {
                // 处理每一行数据
                text.components(separatedBy: "\n").forEach { line in
                    if line.hasPrefix("data: ") {
                        if let jsonData = line.dropFirst(6).data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let delta = firstChoice["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            // 只发送实际的文本内容
                            responseHandler.handleStream(content)
                        }
                    }
                }
            }
            
            responseHandler.handleComplete()
        }
        
        currentTask = task
        task.resume()
    }
    
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
}
