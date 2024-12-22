import Foundation

protocol AIServiceProtocol {
    func sendMessages(_ messages: [AIMessage], responseHandler: AIResponseHandler)
    func cancelCurrentRequest()
}
