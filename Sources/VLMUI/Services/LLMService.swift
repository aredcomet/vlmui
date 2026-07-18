import Foundation

@MainActor
public protocol LLMProvider {
    func generateStream(
        messages: [Message],
        systemInstruction: String?,
        config: ModelConfig,
        apiKey: String,
        baseUrl: String?,
        onToken: @escaping @MainActor (String) -> Void,
        onReasoningToken: (@MainActor (String) -> Void)?,
        onMetrics: @escaping @MainActor (ResponseMetrics) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    )
}

@MainActor
public class LLMService {
    public static let shared = LLMService()
    
    private init() {}
    
    public func runCompletion(
        providerType: String,
        apiKey: String,
        baseUrl: String?,
        messages: [Message],
        systemInstruction: String?,
        config: ModelConfig,
        onToken: @escaping @MainActor (String) -> Void,
        onReasoningToken: (@MainActor (String) -> Void)? = nil,
        onMetrics: @escaping @MainActor (ResponseMetrics) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        // Fallback to mock if API key is empty to allow local offline testing and demoing
        if apiKey.isEmpty {
            runMockCompletion(messages: messages, config: config, onToken: onToken, onMetrics: onMetrics)
            return
        }
        
        let provider: LLMProvider
        if providerType == "Google AI Studio" {
            provider = GeminiProvider()
        } else {
            provider = OpenAIProvider()
        }
        
        provider.generateStream(
            messages: messages,
            systemInstruction: systemInstruction,
            config: config,
            apiKey: apiKey,
            baseUrl: baseUrl,
            onToken: onToken,
            onReasoningToken: onReasoningToken,
            onMetrics: onMetrics,
            onError: onError
        )
    }
    
    private func runMockCompletion(
        messages: [Message],
        config: ModelConfig,
        onToken: @escaping (String) -> Void,
        onMetrics: @escaping (ResponseMetrics) -> Void
    ) {
        let text = "Hello! This is a mock response from VLMUI.\n\nSince no API Key was provided, I am running in Offline Demo Mode.\n\nHere are some of your configuration settings:\n- **Model**: \(config.modelName)\n- **Temperature**: \(config.temperature)\n- **Provider**: \(config.provider)\n\nFeel free to configure your API keys in the Settings panel (gear icon at bottom-left) to connect to live models."
        
        let words = text.components(separatedBy: " ")
        var currentIndex = 0
        let startTime = Date()
        var tfftMs: Double? = nil
        
        func sendNextWord() {
            guard currentIndex < words.count else {
                let timeTaken = Date().timeIntervalSince(startTime)
                let tokenEstimate = text.count / 4
                onMetrics(ResponseMetrics(
                    tfftMs: tfftMs ?? 50.0,
                    tokensPerSecond: Double(tokenEstimate) / timeTaken,
                    tokenCount: tokenEstimate,
                    timeTaken: timeTaken
                ))
                return
            }
            
            if currentIndex == 0 {
                tfftMs = Date().timeIntervalSince(startTime) * 1000.0
            }
            
            let word = words[currentIndex] + (currentIndex == words.count - 1 ? "" : " ")
            onToken(word)
            currentIndex += 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                sendNextWord()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            sendNextWord()
        }
    }
}

// MARK: - Gemini/Google AI Studio Implementation

@MainActor
class GeminiProvider: LLMProvider {
    func generateStream(
        messages: [Message],
        systemInstruction: String?,
        config: ModelConfig,
        apiKey: String,
        baseUrl: String?,
        onToken: @escaping @MainActor (String) -> Void,
        onReasoningToken: (@MainActor (String) -> Void)?,
        onMetrics: @escaping @MainActor (ResponseMetrics) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        let model = config.modelName.isEmpty ? "gemini-1.5-flash" : config.modelName
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            onError(NSError(domain: "VLMUI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"]))
            return
        }
        
        // Map messages to Gemini API contents format
        var contents: [[String: Any]] = []
        for msg in messages {
            var role = "user"
            if msg.role == .assistant {
                role = "model"
            }
            
            var parts: [[String: Any]] = []
            switch msg.content {
            case .text(let txt):
                parts.append(["text": txt])
            case .multipart(let items):
                for item in items {
                    switch item {
                    case .text(let t):
                        parts.append(["text": t])
                    case .imageUrl(let imgUrlPart):
                        // Parse base64 parts from data:image/jpeg;base64,...
                        let comps = imgUrlPart.url.components(separatedBy: ",")
                        if comps.count > 1, let mime = comps.first?.components(separatedBy: ";").first?.components(separatedBy: ":").last {
                            parts.append([
                                "inlineData": [
                                    "mimeType": mime,
                                    "data": comps[1]
                                ]
                            ])
                        }
                    }
                }
            }
            
            contents.append([
                "role": role,
                "parts": parts
            ])
        }
        
        var requestBody: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": config.temperature,
                "topK": config.topK,
                "topP": config.topP
            ]
        ]
        
        if let sys = systemInstruction, !sys.isEmpty {
            requestBody["systemInstruction"] = [
                "parts": [["text": sys]]
            ]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            onError(error)
            return
        }
        
        let startTime = Date()
        var tfftMs: Double? = nil
        var accumulatedText = ""
        
        let delegate = StreamingSessionDelegate(
            onChunk: { chunkString in
                // Parse Server-Sent Events (SSE) or raw JSON array items
                // Gemini streamGenerateContent returns a JSON array over time or chunks of JSON objects
                guard let data = chunkString.data(using: .utf8) else { return }
                
                // If it's a JSON fragment
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.parseGeminiChunk(json, onToken: { token in
                        if tfftMs == nil {
                            tfftMs = Date().timeIntervalSince(startTime) * 1000.0
                        }
                        accumulatedText += token
                        onToken(token)
                    })
                }
            },
            onComplete: {
                let duration = Date().timeIntervalSince(startTime)
                let tokenCount = accumulatedText.count / 4 // crude estimate
                let throughput = duration > 0 ? Double(tokenCount) / duration : 0
                onMetrics(ResponseMetrics(
                    tfftMs: tfftMs ?? 100,
                    tokensPerSecond: throughput,
                    tokenCount: tokenCount,
                    timeTaken: duration
                ))
            },
            onError: onError
        )
        
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
    
    private func parseGeminiChunk(_ json: [String: Any], onToken: (String) -> Void) {
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            return
        }
        
        for part in parts {
            if let text = part["text"] as? String {
                onToken(text)
            }
        }
    }
}

// MARK: - OpenAI Provider Implementation

@MainActor
class OpenAIProvider: LLMProvider {
    func generateStream(
        messages: [Message],
        systemInstruction: String?,
        config: ModelConfig,
        apiKey: String,
        baseUrl: String?,
        onToken: @escaping @MainActor (String) -> Void,
        onReasoningToken: (@MainActor (String) -> Void)?,
        onMetrics: @escaping @MainActor (ResponseMetrics) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        let base = baseUrl?.isEmpty == false ? baseUrl! : "https://api.openai.com/v1"
        let urlString = "\(base)/chat/completions"
        
        guard let url = URL(string: urlString) else {
            onError(NSError(domain: "VLMUI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI URL"]))
            return
        }
        
        var requestMessages: [[String: Any]] = []
        
        if let sys = systemInstruction, !sys.isEmpty {
            requestMessages.append([
                "role": "system",
                "content": sys
            ])
        }
        
        for msg in messages {
            var requestMsg: [String: Any] = [
                "role": msg.role.rawValue
            ]
            
            switch msg.content {
            case .text(let t):
                requestMsg["content"] = t
            case .multipart(let items):
                var parts: [[String: Any]] = []
                for item in items {
                    switch item {
                    case .text(let textVal):
                        parts.append([
                            "type": "text",
                            "text": textVal
                        ])
                    case .imageUrl(let imgUrlPart):
                        parts.append([
                            "type": "image_url",
                            "image_url": [
                                "url": imgUrlPart.url
                            ]
                        ])
                    }
                }
                requestMsg["content"] = parts
            }
            requestMessages.append(requestMsg)
        }
        
        let requestBody: [String: Any] = [
            "model": config.modelName,
            "messages": requestMessages,
            "temperature": config.temperature,
            "top_p": config.topP,
            "stream": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            onError(error)
            return
        }
        
        let startTime = Date()
        var tfftMs: Double? = nil
        var accumulatedText = ""
        
        let delegate = StreamingSessionDelegate(
            onChunk: { chunkString in
                let lines = chunkString.components(separatedBy: "\n")
                for line in lines {
                    let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard cleaned.hasPrefix("data: ") else { continue }
                    let dataContent = cleaned.dropFirst(6)
                    if dataContent == "[DONE]" { continue }
                    
                    guard let data = dataContent.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let delta = firstChoice["delta"] as? [String: Any] else {
                        continue
                    }
                    
                    if let reasoningText = delta["reasoning_content"] as? String {
                        if tfftMs == nil {
                            tfftMs = Date().timeIntervalSince(startTime) * 1000.0
                        }
                        accumulatedText += reasoningText
                        onReasoningToken?(reasoningText)
                    } else if let text = delta["content"] as? String {
                        if tfftMs == nil {
                            tfftMs = Date().timeIntervalSince(startTime) * 1000.0
                        }
                        accumulatedText += text
                        onToken(text)
                    }
                }
            },
            onComplete: {
                let duration = Date().timeIntervalSince(startTime)
                let tokenCount = accumulatedText.count / 4
                let throughput = duration > 0 ? Double(tokenCount) / duration : 0
                onMetrics(ResponseMetrics(
                    tfftMs: tfftMs ?? 100,
                    tokensPerSecond: throughput,
                    tokenCount: tokenCount,
                    timeTaken: duration
                ))
            },
            onError: onError
        )
        
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
}

// MARK: - Helper URLSessionDelegate for Chunk-by-Chunk Streaming

final class StreamingSessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let onChunk: @MainActor (String) -> Void
    private let onComplete: @MainActor () -> Void
    private let onError: @MainActor (Error) -> Void
    private var buffer = Data()
    
    init(onChunk: @escaping @MainActor (String) -> Void, onComplete: @escaping @MainActor () -> Void, onError: @escaping @MainActor (Error) -> Void) {
        self.onChunk = onChunk
        self.onComplete = onComplete
        self.onError = onError
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        
        if let string = String(data: buffer, encoding: .utf8) {
            // Check if we have complete lines or JSON objects
            // Simple split by newline works for SSE stream, and we clear buffer for processed parts
            let lines = string.components(separatedBy: "\n")
            if lines.count > 1 {
                // process all except the last incomplete line
                let completeText = lines.dropLast().joined(separator: "\n")
                Task { @MainActor in
                    onChunk(completeText)
                }
                if let lastLine = lines.last, let lastData = lastLine.data(using: .utf8) {
                    buffer = lastData
                } else {
                    buffer = Data()
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                onError(error)
            }
        } else {
            // Process remaining buffer
            if !buffer.isEmpty, let remainingStr = String(data: buffer, encoding: .utf8) {
                Task { @MainActor in
                    onChunk(remainingStr)
                }
            }
            Task { @MainActor in
                onComplete()
            }
        }
    }
}
