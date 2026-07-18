import Foundation

@MainActor
public class StorageService {
    public static let shared = StorageService()
    
    // Paths are based in the workspace root for portability
    private let workspacePath = "/Users/bran/src/play/vlmui"
    
    private var dataFileUrl: URL {
        URL(fileURLWithPath: workspacePath).appendingPathComponent("data/chats_db.json")
    }
    
    private var settingsFileUrl: URL {
        URL(fileURLWithPath: workspacePath).appendingPathComponent("data/settings_db.json")
    }
    
    public var mcpConfigFileUrl: URL {
        URL(fileURLWithPath: workspacePath).appendingPathComponent("data/mcp.json")
    }
    
    private init() {
        let dataDirUrl = URL(fileURLWithPath: workspacePath).appendingPathComponent("data")
        try? FileManager.default.createDirectory(at: dataDirUrl, withIntermediateDirectories: true)
    }
    
    // MARK: - Save and Load Workspace (Folders & Threads)
    
    public func saveWorkspace(folders: [Folder], selectedThreadId: UUID?, systemInstruction: String) {
        let payload = WorkspacePayload(
            folders: folders,
            selectedThreadId: selectedThreadId,
            systemInstruction: systemInstruction
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            try data.write(to: dataFileUrl, options: .atomic)
            print("Successfully saved workspace data to \(dataFileUrl.path)")
        } catch {
            print("Failed to save workspace data: \(error)")
        }
    }
    
    public func loadWorkspace() -> (folders: [Folder], selectedThreadId: UUID?, systemInstruction: String) {
        guard FileManager.default.fileExists(atPath: dataFileUrl.path) else {
            return (folders: [], selectedThreadId: nil, systemInstruction: "")
        }
        
        do {
            let data = try Data(contentsOf: dataFileUrl)
            let decoder = JSONDecoder()
            let payload = try decoder.decode(WorkspacePayload.self, from: data)
            return (folders: payload.folders, selectedThreadId: payload.selectedThreadId, systemInstruction: payload.systemInstruction)
        } catch {
            print("Failed to load workspace data: \(error)")
            return (folders: [], selectedThreadId: nil, systemInstruction: "")
        }
    }
    
    // MARK: - Save and Load Settings (API Configurations)
    
    public static func getDefaultProviders() -> [ProviderConfig] {
        return [
            ProviderConfig(
                name: "Google AI Studio",
                type: .google,
                endpointUrl: "https://generativelanguage.googleapis.com",
                availableModels: ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash"],
                selectedModels: ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash"],
                isEnabled: true
            ),
            ProviderConfig(
                name: "OpenAI Compatible",
                type: .openai,
                endpointUrl: "https://api.openai.com/v1",
                availableModels: ["gpt-4o", "gpt-4o-mini", "o1-mini"],
                selectedModels: ["gpt-4o", "gpt-4o-mini", "o1-mini"],
                isEnabled: true
            )
        ]
    }
    
    public func saveSettings(config: ModelConfig, connectors: [String: String], providers: [ProviderConfig]) {
        let payload = SettingsPayload(config: config, connectors: connectors, providers: providers)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(payload)
            try data.write(to: settingsFileUrl, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    public func loadSettings() -> (config: ModelConfig, connectors: [String: String], providers: [ProviderConfig]) {
        guard FileManager.default.fileExists(atPath: settingsFileUrl.path) else {
            return (config: ModelConfig(), connectors: [:], providers: Self.getDefaultProviders())
        }
        
        do {
            let data = try Data(contentsOf: settingsFileUrl)
            let decoder = JSONDecoder()
            let payload = try decoder.decode(SettingsPayload.self, from: data)
            let loadedProviders = payload.providers ?? []
            let finalProviders = loadedProviders.isEmpty ? Self.getDefaultProviders() : loadedProviders
            return (config: payload.config, connectors: payload.connectors, providers: finalProviders)
        } catch {
            print("Failed to load settings: \(error)")
            return (config: ModelConfig(), connectors: [:], providers: Self.getDefaultProviders())
        }
    }
    
    // MARK: - Read mcp.json (Manually Edited Config)
    
    public func readMCPServers() -> [MCPServerState] {
        guard FileManager.default.fileExists(atPath: mcpConfigFileUrl.path) else {
            createDefaultMCPConfig()
            return getStubMCPServers()
        }
        
        do {
            let data = try Data(contentsOf: mcpConfigFileUrl)
            let decoder = JSONDecoder()
            let rawConfig = try decoder.decode(RawMCPConfig.self, from: data)
            
            var servers: [MCPServerState] = []
            let sortedServers = rawConfig.mcpServers.sorted(by: { $0.key < $1.key })
            for (serverName, serverInfo) in sortedServers {
                let description: String
                if let cmd = serverInfo.command {
                    let args = serverInfo.args?.joined(separator: " ") ?? ""
                    description = "Command: \(cmd) \(args)"
                } else if let url = serverInfo.url {
                    description = "URL: \(url)"
                } else {
                    description = "Configured Server"
                }
                
                // Populate realistic mock tools for testing (default disabled)
                let tools: [MCPToolState]
                if serverName == "duckduckgo" || serverName == "ddg-search" {
                    tools = [
                        MCPToolState(name: "search", isEnabled: false, permission: .alwaysAllowed),
                        MCPToolState(name: "fetch_content", isEnabled: false, permission: .alwaysAllowed),
                        MCPToolState(name: "get_current_date", isEnabled: false, permission: .alwaysAllowed)
                    ]
                } else if serverName == "huggingface" {
                    tools = [
                        MCPToolState(name: "text_generation", isEnabled: false, permission: .ask),
                        MCPToolState(name: "image_classification", isEnabled: false, permission: .alwaysAllowed)
                    ]
                } else if serverName == "ragsearch" {
                    tools = [
                        MCPToolState(name: "query_kb", isEnabled: false, permission: .alwaysAllowed)
                    ]
                } else if serverName == "datacommons-mcp" {
                    tools = [
                        MCPToolState(name: "get_data", isEnabled: false, permission: .ask),
                        MCPToolState(name: "query_stats", isEnabled: false, permission: .ask)
                    ]
                } else {
                    tools = [
                        MCPToolState(name: "execute", isEnabled: false, permission: .ask)
                    ]
                }
                
                servers.append(MCPServerState(
                    name: serverName,
                    description: description,
                    isEnabled: false,
                    permissionMode: .perTool,
                    tools: tools
                ))
            }
            return servers
        } catch {
            print("Failed to parse mcp.json: \(error). Using fallback stubs.")
            return getStubMCPServers()
        }
    }
    
    private func getStubMCPServers() -> [MCPServerState] {
        return [
            MCPServerState(name: "fetch-url", description: "Retrieves webpage content using HTTP GET", isEnabled: false, tools: [
                MCPToolState(name: "fetch_webpage", isEnabled: false, permission: .alwaysAllowed)
            ]),
            MCPServerState(name: "filesystem", description: "Performs sandbox filesystem access", isEnabled: false, tools: [
                MCPToolState(name: "read_file", isEnabled: false, permission: .ask),
                MCPToolState(name: "write_file", isEnabled: false, permission: .ask)
            ])
        ]
    }
    
    private func createDefaultMCPConfig() {
        let sample = RawMCPConfig(
            mcpServers: [
                "weather": RawMCPServer(command: "npx", args: ["-y", "@modelcontextprotocol/server-weather"]),
                "filesystem": RawMCPServer(command: "node", args: ["/path/to/filesystem-server.js", "/Users/bran/src/play/vlmui"])
            ]
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sample)
            try data.write(to: mcpConfigFileUrl, options: .atomic)
            print("Created default mcp.json at \(mcpConfigFileUrl.path)")
        } catch {
            print("Failed to write default mcp.json: \(error)")
        }
    }
}

// MARK: - Storage Payloads

struct WorkspacePayload: Codable {
    var folders: [Folder]
    var selectedThreadId: UUID?
    var systemInstruction: String
}

struct SettingsPayload: Codable {
    var config: ModelConfig
    var connectors: [String: String]
    var providers: [ProviderConfig]?
}

struct RawMCPConfig: Codable {
    var mcpServers: [String: RawMCPServer]
}

struct RawMCPServer: Codable {
    var command: String?
    var args: [String]?
    var env: [String: String]?
    var url: String?
    var headers: [String: String]?
}
