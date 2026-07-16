import Foundation

// MARK: - Folder & Workspace Structure

public class Folder: Identifiable, Codable, ObservableObject {
    public let id: UUID
    public var name: String
    public var subfolders: [Folder]
    public var chats: [ChatThread]
    
    public init(id: UUID = UUID(), name: String, subfolders: [Folder] = [], chats: [ChatThread] = []) {
        self.id = id
        self.name = name
        self.subfolders = subfolders
        self.chats = chats
    }
}

// MARK: - OpenAI Harmony Format (Chat Threads)

public class ChatThread: Identifiable, Codable, ObservableObject {
    public let id: UUID
    public var title: String
    public var messages: [Message]
    public var systemInstruction: String?
    public var modelConfig: ModelConfig?
    
    // UI Metadata (not persisted if not required, but helpful for retry branches)
    // We can keep them in the thread for retry/branching.
    
    public init(id: UUID = UUID(), title: String, messages: [Message] = [], systemInstruction: String? = nil, modelConfig: ModelConfig? = nil) {
        self.id = id
        self.title = title
        self.messages = messages
        self.systemInstruction = systemInstruction
        self.modelConfig = modelConfig
    }
}

// MARK: - Message Schema (OpenAI Compatible)

public struct Message: Identifiable, Codable {
    public let id: UUID
    public var role: MessageRole
    public var content: MessageContent
    public var timestamp: Date
    
    // Metrics for assistant responses
    public var metrics: ResponseMetrics?
    
    // For handling multiple retries (retry branches)
    // Each message can have references to sibling retries, or we can store list of alternative contents.
    public var alternativeContents: [MessageContent]?
    public var activeAlternativeIndex: Int?
    
    public init(id: UUID = UUID(), role: MessageRole, content: MessageContent, timestamp: Date = Date(), metrics: ResponseMetrics? = nil, alternativeContents: [MessageContent]? = nil, activeAlternativeIndex: Int? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metrics = metrics
        self.alternativeContents = alternativeContents
        self.activeAlternativeIndex = activeAlternativeIndex
    }
}

public enum MessageRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

public enum MessageContent: Codable {
    case text(String)
    case multipart([ContentPart])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let textVal = try? container.decode(String.self) {
            self = .text(textVal)
            return
        }
        if let partsVal = try? container.decode([ContentPart].self) {
            self = .multipart(partsVal)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Mismatched MessageContent")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .multipart(let parts):
            try container.encode(parts)
        }
    }
    
    public var textString: String {
        switch self {
        case .text(let text):
            return text
        case .multipart(let parts):
            return parts.compactMap { part -> String? in
                if case .text(let text) = part { return text }
                return nil
            }.joined(separator: "\n")
        }
    }
}

public enum ContentPart: Codable {
    case text(String)
    case imageUrl(ImageUrlPart)
    
    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }
    
    public struct ImageUrlPart: Codable {
        public var url: String // base64 representation data:image/jpeg;base64,...
        public init(url: String) {
            self.url = url
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageUrl = try container.decode(ImageUrlPart.self, forKey: .imageUrl)
            self = .imageUrl(imageUrl)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unknown content part type: \(type)"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageUrl(let imageUrl):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageUrl, forKey: .imageUrl)
        }
    }
}

// MARK: - Metrics

public struct ResponseMetrics: Codable {
    public var tfftMs: Double?         // Time for First Token in milliseconds
    public var tokensPerSecond: Double? // Generation throughput
    public var tokenCount: Int?        // Number of tokens
    public var timeTaken: Double?       // Total time in seconds
    
    public init(tfftMs: Double? = nil, tokensPerSecond: Double? = nil, tokenCount: Int? = nil, timeTaken: Double? = nil) {
        self.id = UUID()
        self.tfftMs = tfftMs
        self.tokensPerSecond = tokensPerSecond
        self.tokenCount = tokenCount
        self.timeTaken = timeTaken
    }
    
    // Synthesized coding key for uniqueness if needed, but simple Codable properties are fine
    private let id: UUID
}

// MARK: - Configurations & MCP

public struct ModelConfig: Codable, Equatable {
    public var provider: String = "Google AI Studio"
    public var modelName: String = "gemini-1.5-flash"
    
    public var temperature: Double = 0.7
    public var topK: Int = 40
    public var repeatPenalty: Double = 1.0
    public var topP: Double = 0.95
    public var minP: Double = 0.05
    
    // Additional configurations can go in a metadata dictionary
    public var customSettings: [String: String] = [:]
    
    public init(provider: String = "Google AI Studio", modelName: String = "gemini-1.5-flash") {
        self.provider = provider
        self.modelName = modelName
    }
}

public struct MCPTool: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var description: String
    public var isEnabled: Bool = true
    public var permission: PermissionType = .ask
    
    public enum PermissionType: String, Codable, CaseIterable {
        case ask = "Ask Permission"
        case alwaysAllowed = "Always Allowed"
    }
    
    public init(id: UUID = UUID(), name: String, description: String, isEnabled: Bool = true, permission: PermissionType = .ask) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.permission = permission
    }
}
