import SwiftUI
import AppKit

@main
struct VLMUIApp: App {
    // Shared state or environment objects can be injected here
    @StateObject private var appState = AppState()

    init() {
        // Ensure that running as a CLI executable correctly acts as a GUI application on macOS
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.regular)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainSplitView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .sheet(isPresented: $appState.isSettingsPresented) {
                    SettingsView()
                        .environmentObject(appState)
                }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

/// A top-level state container for managing chats, configuration, and MCP tools.
@MainActor
class AppState: ObservableObject {
    @Published var folders: [Folder] = []
    @Published var selectedThreadId: UUID? = nil
    @Published var systemInstruction: String = ""
    @Published var modelConfig = ModelConfig()
    @Published var mcpServers: [MCPServerState] = []
    @Published var isSettingsPresented: Bool = false
    
    // Shared Workspace Actions & Dialog States
    @Published var showNewFolderDialog: Bool = false
    @Published var parentFolderForNewFolder: Folder? = nil
    @Published var isRightPaneVisible: Bool = true
    
    func createNewChat(in folder: Folder? = nil) {
        let newChat = ChatThread(title: "New Chat Thread")
        newChat.messages = []
        
        if let folder = folder {
            folder.chats.append(newChat)
        } else {
            if folders.isEmpty {
                let generalFolder = Folder(name: "General", chats: [newChat])
                folders.append(generalFolder)
            } else {
                folders[0].chats.append(newChat)
            }
        }
        
        selectedThreadId = newChat.id
        saveWorkspace()
    }
    
    init() {
        // Load settings
        let settings = StorageService.shared.loadSettings()
        self.modelConfig = settings.config
        
        // Load workspace data
        let workspace = StorageService.shared.loadWorkspace()
        self.folders = workspace.folders
        self.selectedThreadId = workspace.selectedThreadId
        self.systemInstruction = workspace.systemInstruction
        
        // Load MCP tools
        self.mcpServers = StorageService.shared.readMCPServers()
        
        // Populate default layout if empty
        if self.folders.isEmpty {
            createDefaultWorkspaceStructure()
        }
    }
    
    public func saveWorkspace() {
        StorageService.shared.saveWorkspace(
            folders: folders,
            selectedThreadId: selectedThreadId,
            systemInstruction: systemInstruction
        )
    }
    
    private func createDefaultWorkspaceStructure() {
        let welcomeChat = ChatThread(
            title: "Welcome to VLMUI",
            messages: [
                Message(role: .system, content: .text("System setup initialized.")),
                Message(role: .user, content: .text("Hello! What is VLMUI?")),
                Message(role: .assistant, content: .text("VLMUI is a native Swift macOS chat client similar to Google AI Studio.\n\nIt supports:\n1. Connecting to Gemini or any OpenAI-compatible API\n2. Image attachments\n3. Retry alternatives and conversation branching\n4. MCP Tools configuration\n\nTo start, add your API key in **Settings** (gear icon at the bottom-left)."), metrics: ResponseMetrics(tfftMs: 25.0, tokensPerSecond: 95.0, tokenCount: 65, timeTaken: 0.68))
            ]
        )
        
        let demoFolder = Folder(name: "Demo Chats", chats: [welcomeChat])
        let emptyFolder = Folder(name: "Projects")
        
        self.folders = [demoFolder, emptyFolder]
        self.selectedThreadId = welcomeChat.id
        saveWorkspace()
    }
}

